import Foundation

// MARK: - Saved run
//
// A run is persisted so "Continue" survives quitting the app. Cards and relics are stored
// by NAME and rebuilt from their factories on load — that keeps the save small and means
// balance changes to a card apply to saved runs instead of resurrecting stale numbers.
// Equipment is stored in full, since its stat rolls are generated per drop.
//
// Combat itself is never mid-flight in a save: the player can only leave from the victory
// or defeat screen, and any other state re-enters the floor from its start.

struct SavedEquipment: Codable {
    var name: String
    var slot: String
    var bonuses: [String: Int]
    var sellValue: Int
    var iconName: String?
    /// Optional so saves written before rarity existed still decode — they load as Common,
    /// which is what every piece effectively was.
    var rarity: String?

    init(_ item: Equipment) {
        name = item.name
        slot = item.slot.rawValue
        bonuses = Dictionary(uniqueKeysWithValues: item.statBonuses.map { ($0.key.rawValue, $0.value) })
        sellValue = item.sellValue
        iconName = item.iconName
        rarity = item.rarity.rawValue
    }

    /// Nil if the slot no longer exists (e.g. the game dropped that slot in an update).
    var equipment: Equipment? {
        guard let slot = EquipmentSlot(rawValue: slot) else { return nil }
        var stats: [StatKind: Int] = [:]
        for (key, value) in bonuses {
            if let stat = StatKind(rawValue: key) { stats[stat] = value }
        }
        return Equipment(name: name, slot: slot, statBonuses: stats,
                         sellValue: sellValue,
                         rarity: rarity.flatMap(EquipmentRarity.init(rawValue:)) ?? .common,
                         iconName: iconName)
    }
}

struct RunSave: Codable {
    var act: Int
    var floor: Int
    var state: String                 // GameState raw value at the time of saving

    var currentHp: Int
    var gold: Int
    var statAllocations: [String: Int]
    var unspentStatPoints: Int
    var equipped: [String: SavedEquipment]
    var inventory: [SavedEquipment]

    var relicNames: [String]
    var deckCardNames: [String]
    var clearedFloors: [Int]

    // The victory screen's reward breakdown, so resuming onto it shows the same numbers.
    var lastGoldEarned: Int
    var lastBonusGold: Int
    var lastBonusEarned: Bool
    var lastStatPoints: Int
    /// Whether this run's one revive is already spent — persisted so Save & Quit →
    /// Continue can't restore it.
    var reviveUsed: Bool?
}

/// Where a run lives between launches.
enum SaveStore {
    private static let key = "deckTheseusRunSave"

    static var hasSave: Bool { UserDefaults.standard.data(forKey: key) != nil }

    static func write(_ save: RunSave) {
        guard let data = try? JSONEncoder().encode(save) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func read() -> RunSave? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RunSave.self, from: data)
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}

// MARK: - Engine <-> save

extension GameEngine {

    func makeSave() -> RunSave {
        RunSave(
            act: currentAct,
            floor: currentFloor,
            state: gameState.rawValue,
            currentHp: player.currentHp,
            gold: player.gold,
            statAllocations: Dictionary(uniqueKeysWithValues:
                player.statAllocations.map { ($0.key.rawValue, $0.value) }),
            unspentStatPoints: player.unspentStatPoints,
            equipped: Dictionary(uniqueKeysWithValues:
                player.equippedItems.map { ($0.key.rawValue, SavedEquipment($0.value)) }),
            // Written as a closure, not `map(SavedEquipment.init)`: an unapplied reference to a
            // main-actor-isolated initialiser converts to a *nonisolated* function type, which
            // the compiler rightly flags. A closure written here inherits this context's
            // isolation instead.
            inventory: player.equipmentInventory.map { SavedEquipment($0) },
            relicNames: playerRelics.map(\.name),
            deckCardNames: deck.masterDeck.map(\.name),
            clearedFloors: Array(clearedFloors),
            lastGoldEarned: lastGoldEarned,
            lastBonusGold: lastBonusGold,
            lastBonusEarned: lastBonusEarned,
            lastStatPoints: lastStatPoints,
            reviveUsed: reviveUsed
        )
    }

    /// Persist the run as it stands. Safe to call whenever the run is at rest.
    func saveRun() { SaveStore.write(makeSave()) }

    /// Restore a saved run. Combat is rebuilt from the floor rather than resumed mid-fight.
    func loadSave(_ save: RunSave) {
        currentAct = save.act
        currentFloor = save.floor

        player.statAllocations = [:]
        for (key, value) in save.statAllocations {
            if let stat = StatKind(rawValue: key) { player.statAllocations[stat] = value }
        }
        player.unspentStatPoints = save.unspentStatPoints

        player.equippedItems = [:]
        for (slotKey, saved) in save.equipped {
            if let slot = EquipmentSlot(rawValue: slotKey), let item = saved.equipment {
                player.equippedItems[slot] = item
            }
        }
        player.equipmentInventory = save.inventory.compactMap(\.equipment)

        // maxHp is computed from CON + gear, so set HP only once both are in place.
        player.currentHp = min(max(1, save.currentHp), player.maxHp)
        player.gold = save.gold
        player.currentBlock = 0
        player.combatFlash = nil

        // Closures rather than `compactMap(Relic.named)` — see the note in `makeSave()`.
        playerRelics = save.relicNames.compactMap { Relic.named($0) }
        deck.masterDeck = save.deckCardNames.compactMap { Card.named($0) }
        clearedFloors = Set(save.clearedFloors)

        lastGoldEarned = save.lastGoldEarned
        lastBonusGold = save.lastBonusGold
        lastBonusEarned = save.lastBonusEarned
        lastStatPoints = save.lastStatPoints
        restoreReviveUsed(save.reviveUsed ?? false)

        justEarnedRelic = nil
        justEarnedEquipment = []
        justTriggeredCombo = nil
        isResolvingTurn = false
        shopCards = []
        shopRelics = []

        // Land back on the screen they left from. A run saved anywhere else (mid-combat,
        // rest, shop) re-enters that floor cleanly instead of resuming a half-fight.
        switch GameState(rawValue: save.state) {
        case .victory, .defeat:
            enemies = []
            gameState = GameState(rawValue: save.state) ?? .victory
        default:
            restoreCurrentFloor()
        }
    }
}
