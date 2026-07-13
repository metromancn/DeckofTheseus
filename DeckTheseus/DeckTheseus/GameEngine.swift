import Foundation
import Observation
import CoreGraphics

// MARK: - Card Types

enum CardType: String {
    case attack
    case skill
    case status
}

// MARK: - Game State

enum GameState {
    case playing
    case victory
    case defeat
    case restSite      // Floor 3 — choose Heal or Draft
    case drafting      // Floor 3 — pick a card to add to the deck
    case actComplete   // "To Be Continued" placeholder between acts
}

// MARK: - Floor Nodes

enum FloorNode {
    case combat   // standard enemy
    case elite    // harder enemy
    case rest     // rest site
    case boss     // boss encounter
}

// MARK: - Turn / VFX State

enum TurnBanner {
    case none
    case playerTurn
    case enemyTurn
}

enum SpriteVFX {
    case none
    case attack       // basic_attack_animation
    case healDebuff   // heal_debuff_animation2
}

// MARK: - Relics

struct Relic: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let iconName: String

    static var vampireTooth: Relic {
        Relic(name: "Vampire Tooth",
              description: "Heal 2 HP when you play an Attack card",
              iconName: "relic_vampire_tooth")
    }
}

struct Card: Identifiable {
    let id = UUID()
    let name: String
    let type: CardType
    let energyCost: Int
    let damage: Int
    let block: Int
    let vulnerableApply: Int
    let imageName: String?
    let isExhaustible: Bool
    let hitsAllEnemies: Bool     // AOE damage (Cleave)
    let energyNextTurn: Int      // extra energy next turn (Thunder)
    let blockNextTurn: Int       // extra block next turn (Barricade)

    init(name: String, type: CardType, energyCost: Int, damage: Int, block: Int, imageName: String?,
         vulnerableApply: Int = 0, isExhaustible: Bool = false,
         hitsAllEnemies: Bool = false, energyNextTurn: Int = 0, blockNextTurn: Int = 0) {
        self.name = name
        self.type = type
        self.energyCost = energyCost
        self.damage = damage
        self.block = block
        self.imageName = imageName
        self.vulnerableApply = vulnerableApply
        self.isExhaustible = isExhaustible
        self.hitsAllEnemies = hitsAllEnemies
        self.energyNextTurn = energyNextTurn
        self.blockNextTurn = blockNextTurn
    }

    var description: String {
        if type == .status {
            return "Unplayable. Costs \(energyCost) energy to remove from your deck for this combat."
        }
        var parts: [String] = []
        if damage > 0 {
            parts.append(hitsAllEnemies ? "Deal \(damage) damage to ALL enemies." : "Deal \(damage) damage.")
        }
        if vulnerableApply > 0 { parts.append("Apply \(vulnerableApply) Vulnerable.") }
        if block > 0 { parts.append("Gain \(block) block.") }
        if energyNextTurn > 0 { parts.append("Gain \(energyNextTurn) energy next turn.") }
        if blockNextTurn > 0 { parts.append("Gain \(blockNextTurn) block next turn.") }
        if isExhaustible { parts.append("Exhaust.") }
        return parts.joined(separator: " ")
    }

    static func slime() -> Card {
        Card(name: "Slime", type: .status, energyCost: 1, damage: 0, block: 0,
             imageName: "card_slimed_status", isExhaustible: true)
    }

    /// The three cards offered at the Floor 3 draft.
    static var availableDraftCards: [Card] {
        [
            Card(name: "Cleave", type: .attack, energyCost: 2, damage: 8, block: 0,
                 imageName: "card_cleave_attack", hitsAllEnemies: true),
            Card(name: "Thunder", type: .attack, energyCost: 2, damage: 15, block: 0,
                 imageName: "card_thunder_attack", energyNextTurn: 1),
            Card(name: "Barricade", type: .skill, energyCost: 1, damage: 0, block: 8,
                 imageName: "card_barricade_skill", blockNextTurn: 2),
        ]
    }
}

// MARK: - Enemy Intent

enum EnemyIntent {
    case tackle(baseDamage: Int)
    case gooSpit(slimeCount: Int)
    case harden(block: Int, strengthGain: Int)
    case defend(block: Int)

    var displayName: String {
        switch self {
        case .tackle: return "Tackle"
        case .gooSpit: return "Goo Spit"
        case .harden: return "Harden"
        case .defend: return "Defend"
        }
    }

    func displayValue(strength: Int) -> String {
        switch self {
        case .tackle(let base): return "\(base + strength)"
        case .gooSpit(let count): return "×\(count)"
        case .harden(let blk, _): return "\(blk)"
        case .defend(let blk): return "\(blk)"
        }
    }
}

// MARK: - Player

@Observable
class Player {
    var maxHp = 80
    var currentHp = 80
    var maxEnergy = 3
    var currentEnergy = 3
    var gold = 99
    var currentBlock = 0
}

// MARK: - Enemy

@Observable
class Enemy: Identifiable {
    let id = UUID()
    var name: String
    var maxHp: Int
    var currentHp: Int
    var currentBlock = 0
    var strength = 0
    var vulnerableTurns = 0
    var vfx: SpriteVFX = .none

    // Sprite art + crop bounds (fraction of the 64px canvas).
    var spriteName: String
    var spriteContentW: CGFloat
    var spriteContentH: CGFloat
    var spriteScale: CGFloat   // display size relative to the boss sprite height

    // Repeating list of moves; advanceIntent walks through it by turn number.
    var rotation: [EnemyIntent]
    var nextMove: EnemyIntent

    // Relic awarded to the player when this enemy dies (Elites drop relics).
    let dropsRelic: Relic?

    init(name: String, maxHp: Int, spriteName: String,
         spriteContentW: CGFloat, spriteContentH: CGFloat, rotation: [EnemyIntent],
         spriteScale: CGFloat = 1.0, dropsRelic: Relic? = nil) {
        self.name = name
        self.maxHp = maxHp
        self.currentHp = maxHp
        self.spriteName = spriteName
        self.spriteContentW = spriteContentW
        self.spriteContentH = spriteContentH
        self.spriteScale = spriteScale
        self.rotation = rotation
        self.nextMove = rotation.first ?? .tackle(baseDamage: 0)
        self.dropsRelic = dropsRelic
    }

    var isAlive: Bool { currentHp > 0 }

    func clearDebuffs() {
        vulnerableTurns = 0
    }

    func advanceIntent(forTurn turn: Int) {
        guard !rotation.isEmpty else { return }
        nextMove = rotation[(turn - 1) % rotation.count]
    }

    // MARK: - Enemy factories

    /// Floor 1 — standard slime (small).
    static func basicOoze() -> Enemy {
        Enemy(name: "Slime", maxHp: 40, spriteName: "enemy_slime_basic",
              spriteContentW: 0.453, spriteContentH: 0.375,
              rotation: [.tackle(baseDamage: 6), .defend(block: 5)],
              spriteScale: 0.5)
    }

    /// Floor 2 Elite — alternates a 10-damage attack and a 10 block defend.
    /// Drops the Vampire Tooth relic the moment it dies.
    static func acidSlime() -> Enemy {
        Enemy(name: "Acid Slime", maxHp: 60, spriteName: "enemy_acid_slime_elite",
              spriteContentW: 0.453, spriteContentH: 0.375,
              rotation: [.tackle(baseDamage: 10), .defend(block: 10)],
              spriteScale: 0.78, dropsRelic: .vampireTooth)
    }

    /// Floor 2 — second (small) slime.
    static func basicSlime() -> Enemy {
        Enemy(name: "Slime", maxHp: 40, spriteName: "enemy_slime_basic",
              spriteContentW: 0.453, spriteContentH: 0.375,
              rotation: [.tackle(baseDamage: 9), .defend(block: 6), .tackle(baseDamage: 6)],
              spriteScale: 0.5)
    }

    /// Floor 4 — the Act boss.
    static func slimeKing() -> Enemy {
        Enemy(name: "Slime King", maxHp: 160, spriteName: "boss_slime",
              spriteContentW: 0.61, spriteContentH: 0.578,
              rotation: [.tackle(baseDamage: 12), .gooSpit(slimeCount: 2), .harden(block: 15, strengthGain: 2)])
    }
}

// MARK: - Deck Manager

@Observable
class DeckManager {
    var masterDeck: [Card] = []
    var drawPile: [Card] = []
    var discardPile: [Card] = []
    var exhaustPile: [Card] = []
    var hand: [Card] = []

    func initializeDeck() {
        masterDeck = []

        for _ in 0..<5 {
            masterDeck.append(Card(name: "Strike", type: .attack, energyCost: 1, damage: 6, block: 0, imageName: "card_strike_attack"))
        }

        for _ in 0..<4 {
            masterDeck.append(Card(name: "Defend", type: .skill, energyCost: 1, damage: 0, block: 5, imageName: "card_defend_skill"))
        }

        masterDeck.append(Card(name: "Bash", type: .attack, energyCost: 2, damage: 8, block: 0,
                                imageName: "card_bash_attack", vulnerableApply: 1))
    }

    func startCombat() {
        drawPile = masterDeck
        discardPile = []
        exhaustPile = []
        hand = []
        drawPile.shuffle()
    }

    func drawCards(_ amount: Int) {
        for _ in 0..<amount {
            if drawPile.isEmpty {
                if discardPile.isEmpty { return }
                drawPile = discardPile
                discardPile = []
                drawPile.shuffle()
            }
            hand.append(drawPile.removeLast())
        }
    }

    func injectIntoDiscard(_ cards: [Card]) {
        discardPile.append(contentsOf: cards)
    }
}

// MARK: - Game Engine

@Observable
class GameEngine {
    var player = Player()
    var enemies: [Enemy] = []
    var targetIndex: Int = 0
    var deck = DeckManager()
    var selectedCardIds: Set<UUID> = []
    var currentTurn = 1
    var gameState: GameState = .playing

    // Roguelike progression
    var currentAct = 1
    var currentFloor = 1

    // Next-turn buffs (applied at the start of the player's turn)
    var extraEnergyNextTurn: Int = 0
    var extraBlockNextTurn: Int = 0

    // Relics — the player owns many but only one is equipped (active).
    var playerRelics: [Relic] = []
    var equippedRelicId: UUID? = nil
    var justEarnedRelic: Relic? = nil   // set when a relic is awarded, for the UI banner

    func hasRelic(named name: String) -> Bool {
        playerRelics.contains { $0.name == name }
    }

    var equippedRelic: Relic? {
        guard let id = equippedRelicId else { return nil }
        return playerRelics.first { $0.id == id }
    }

    /// Equip the relic, or unequip it if it's already the equipped one.
    func toggleEquip(_ id: UUID) {
        equippedRelicId = (equippedRelicId == id) ? nil : id
    }

    /// Award relics for any enemy that just died carrying one. Auto-equips the
    /// first relic earned so its effect is active immediately.
    private func checkRelicDrops() {
        for enemy in enemies where !enemy.isAlive {
            guard let relic = enemy.dropsRelic, !hasRelic(named: relic.name) else { continue }
            playerRelics.append(relic)
            if equippedRelicId == nil { equippedRelicId = relic.id }
            justEarnedRelic = relic
        }
    }

    // Turn-flow + VFX presentation state (driven by the view's orchestrator)
    var turnBanner: TurnBanner = .none
    var playerVFX: SpriteVFX = .none
    var isResolvingTurn = false

    // The enemy the player's single-target cards will hit.
    var currentTarget: Enemy? {
        guard enemies.indices.contains(targetIndex) else { return nil }
        return enemies[targetIndex]
    }

    var allEnemiesDead: Bool {
        !enemies.isEmpty && enemies.allSatisfy { $0.currentHp <= 0 }
    }

    /// If the current target is dead, move the reticle to the first living enemy.
    private func retargetIfNeeded() {
        guard let t = currentTarget, t.isAlive else {
            if let firstAlive = enemies.firstIndex(where: { $0.isAlive }) {
                targetIndex = firstAlive
            }
            return
        }
    }

    var usedEnergy: Int {
        deck.hand
            .filter { selectedCardIds.contains($0.id) }
            .reduce(0) { $0 + $1.energyCost }
    }

    var remainingEnergy: Int {
        player.currentEnergy - usedEnergy
    }

    var pendingPlayerBlock: Int {
        deck.hand
            .filter { selectedCardIds.contains($0.id) }
            .reduce(0) { $0 + $1.block }
    }

    var displayPlayerBlock: Int {
        player.currentBlock + pendingPlayerBlock
    }

    init() {
        deck.initializeDeck()
        currentAct = 1
        currentFloor = 1
        startFloorCombat()
    }

    func canAfford(_ card: Card) -> Bool {
        if selectedCardIds.contains(card.id) { return true }
        return remainingEnergy >= card.energyCost
    }

    func toggleSelection(_ cardId: UUID) {
        guard gameState == .playing else { return }
        if selectedCardIds.contains(cardId) {
            selectedCardIds.remove(cardId)
        } else {
            guard let card = deck.hand.first(where: { $0.id == cardId }) else { return }
            guard remainingEnergy >= card.energyCost else { return }
            selectedCardIds.insert(cardId)
        }
    }

    // MARK: - Combat Resolution

    private func checkCombatResolution() {
        // A combat is "won" once every enemy is at 0 HP. The floor logic (auto-
        // advance vs. terminal victory) is decided by the turn orchestrator.
        // (Relics are awarded on the individual enemy's death via checkRelicDrops.)
        if allEnemiesDead {
            gameState = .victory
        } else if player.currentHp <= 0 {
            player.currentHp = 0
            gameState = .defeat
        }
    }

    /// Vulnerable multiplier: each stack adds +50% damage (2 stacks = +100%).
    private func vulnerableMultiplier(_ stacks: Int) -> Double {
        1.0 + 0.5 * Double(max(0, stacks))
    }

    /// Deal a card's damage to one enemy (vulnerable applied, block absorbed, HP clamped).
    private func dealDamage(_ base: Int, to enemy: Enemy) {
        let raw = Int(floor(Double(base) * vulnerableMultiplier(enemy.vulnerableTurns)))
        let absorbed = min(raw, enemy.currentBlock)
        enemy.currentBlock -= absorbed
        enemy.currentHp = max(0, enemy.currentHp - (raw - absorbed))
    }

    // MARK: - Play Cards

    func playSelectedCards() {
        guard gameState == .playing else { return }
        let selected = deck.hand.filter { selectedCardIds.contains($0.id) }
        for card in selected {
            if card.damage > 0 {
                if card.hitsAllEnemies {
                    // AOE — ignore targetIndex, hit every living enemy.
                    for enemy in enemies where enemy.isAlive {
                        dealDamage(card.damage, to: enemy)
                    }
                } else if let target = currentTarget, target.isAlive {
                    dealDamage(card.damage, to: target)
                }
            }
            if let target = currentTarget, target.isAlive, card.vulnerableApply > 0 {
                target.vulnerableTurns += card.vulnerableApply
            }
            if card.block > 0 {
                player.currentBlock += card.block
            }
            if card.energyNextTurn > 0 {
                extraEnergyNextTurn += card.energyNextTurn
            }
            if card.blockNextTurn > 0 {
                extraBlockNextTurn += card.blockNextTurn
            }

            // Relic: Vampire Tooth (only when equipped) — heal 2 HP on a damaging card.
            if card.damage > 0, equippedRelic?.name == "Vampire Tooth" {
                player.currentHp = min(player.maxHp, player.currentHp + 2)
            }

            checkRelicDrops()   // award a relic the instant an elite dies
            retargetIfNeeded()
            checkCombatResolution()
            if gameState != .playing { break }
        }
        player.currentEnergy -= usedEnergy
        deck.hand.removeAll { selectedCardIds.contains($0.id) }

        for card in selected {
            if card.isExhaustible {
                deck.exhaustPile.append(card)
            } else {
                deck.discardPile.append(card)
            }
        }
        selectedCardIds.removeAll()
    }

    // MARK: - Enemy Turn

    private func executeEnemyTurn() {
        // Every living enemy executes its queued move.
        for enemy in enemies where enemy.isAlive {
            switch enemy.nextMove {
            case .tackle(let baseDamage):
                let totalDamage = baseDamage + enemy.strength
                let remaining = totalDamage - player.currentBlock
                player.currentBlock = max(0, player.currentBlock - totalDamage)
                if remaining > 0 {
                    player.currentHp = max(0, player.currentHp - remaining)
                }

            case .gooSpit(let count):
                var slimeCards: [Card] = []
                for _ in 0..<count {
                    slimeCards.append(.slime())
                }
                deck.injectIntoDiscard(slimeCards)
                // Energy-drain debuff — reduces next turn's energy (can go negative).
                extraEnergyNextTurn -= 1

            case .harden(let block, let strengthGain):
                enemy.currentBlock += block
                enemy.strength += strengthGain
                enemy.clearDebuffs()

            case .defend(let block):
                enemy.currentBlock += block
            }

            checkCombatResolution()
            if gameState != .playing { return }
        }
    }

    // MARK: - End Turn

    func endTurn() {
        guard gameState == .playing else { return }

        playSelectedCards()
        if gameState != .playing { return }

        while !deck.hand.isEmpty {
            deck.discardPile.append(deck.hand.removeLast())
        }

        executeEnemyTurn()
        if gameState != .playing { return }

        player.currentEnergy = player.maxEnergy
        currentTurn += 1
        for enemy in enemies { enemy.advanceIntent(forTurn: currentTurn) }
        deck.drawCards(5)
    }

    // MARK: - Granular Turn Steps (for animated orchestration)

    /// Move any remaining cards in hand to the discard pile.
    func discardHand() {
        while !deck.hand.isEmpty {
            deck.discardPile.append(deck.hand.removeLast())
        }
    }

    /// Public wrapper so the view can run the enemy's queued move on its own beat.
    func runEnemyTurn() {
        guard gameState == .playing else { return }
        executeEnemyTurn()
    }

    /// Refresh energy, apply next-turn buffs, advance the intents, and draw.
    func beginNextTurn() {
        guard gameState == .playing else { return }
        // Start-of-turn buffs/debuffs (energy clamped so it never goes below 0).
        player.currentBlock += extraBlockNextTurn
        player.currentEnergy = max(0, player.maxEnergy + extraEnergyNextTurn)
        extraEnergyNextTurn = 0
        extraBlockNextTurn = 0

        currentTurn += 1
        for enemy in enemies { enemy.advanceIntent(forTurn: currentTurn) }
        deck.drawCards(5)
    }

    // Detection helpers for choosing which VFX to play.
    var selectedDealsDamage: Bool {
        deck.hand.contains { selectedCardIds.contains($0.id) && $0.damage > 0 }
    }

    var selectedGivesBlock: Bool {
        deck.hand.contains { selectedCardIds.contains($0.id) && $0.block > 0 }
    }

    /// Any living enemy is about to attack the player this turn.
    var anyEnemyAttacks: Bool {
        enemies.contains { enemy in
            guard enemy.isAlive else { return false }
            if case .tackle = enemy.nextMove { return true }
            return false
        }
    }

    /// A living enemy is about to spit goo at the player this turn.
    var anyEnemyGooSpits: Bool {
        enemies.contains { enemy in
            guard enemy.isAlive else { return false }
            if case .gooSpit = enemy.nextMove { return true }
            return false
        }
    }

    /// Indices of living enemies whose queued move is a self-buff (defend/harden).
    var buffingEnemyIndices: [Int] {
        enemies.indices.filter { i in
            let enemy = enemies[i]
            guard enemy.isAlive else { return false }
            switch enemy.nextMove {
            case .harden, .defend: return true
            default: return false
            }
        }
    }

    // MARK: - Progression

    func nodeForFloor(_ floor: Int) -> FloorNode {
        switch floor {
        case 1: return .combat
        case 2: return .elite
        case 3: return .rest
        case 4: return .boss
        default: return .combat
        }
    }

    var isBossFloor: Bool { nodeForFloor(currentFloor) == .boss }

    private func spawnEnemies(for node: FloorNode) -> [Enemy] {
        switch node {
        case .combat: return [.basicOoze()]
        case .elite:  return [.acidSlime(), .basicSlime()]
        case .boss:   return [.slimeKing()]
        case .rest:   return []
        }
    }

    /// Set up (or reset) the combat encounter for the current floor. Player HP is
    /// left untouched so it can carry over between floors — callers that want a
    /// full reset (dev retry) restore it themselves before calling this.
    func startFloorCombat() {
        let node = nodeForFloor(currentFloor)
        enemies = spawnEnemies(for: node)
        targetIndex = 0
        for enemy in enemies { enemy.advanceIntent(forTurn: 1) }

        player.currentBlock = 0
        player.currentEnergy = player.maxEnergy
        extraEnergyNextTurn = 0
        extraBlockNextTurn = 0

        deck.startCombat()   // reshuffle masterDeck into drawPile, clear temp piles
        deck.drawCards(5)

        selectedCardIds.removeAll()
        currentTurn = 1
        turnBanner = .none
        playerVFX = .none
        isResolvingTurn = false
        gameState = .playing
    }

    /// Load whatever node the current floor points at (combat or rest site).
    private func loadCurrentFloor() {
        switch nodeForFloor(currentFloor) {
        case .rest:
            gameState = .restSite
        default:
            startFloorCombat()
        }
    }

    /// Advance one floor and load its node (combat or rest site).
    func advanceToNextFloor() {
        currentFloor += 1
        loadCurrentFloor()
    }

    /// Terminal boss victory → move on to the next act (placeholder for now).
    func advanceToNextAct() {
        currentAct += 1
        currentFloor = 1
        gameState = .actComplete
    }

    // MARK: - Rest Site (Floor 3)

    /// "Rest" — heal 30% of max HP (clamped), then head to Floor 4.
    func restHealAndAdvance() {
        let healAmount = Int(Double(player.maxHp) * 0.30)
        player.currentHp = min(player.maxHp, player.currentHp + healAmount)
        advanceToNextFloor()
    }

    /// "Train" — open the card draft.
    func chooseTrainDraft() {
        gameState = .drafting
    }

    /// Draft — add exactly one copy of `card` to the master deck, then Floor 4.
    /// Guarded so a double-fired tap can't add the card twice.
    func draftCard(_ card: Card) {
        guard gameState == .drafting else { return }
        deck.masterDeck.append(card)
        advanceToNextFloor()
    }

    /// Draft — skip the reward and head to Floor 4.
    func skipDraft() {
        guard gameState == .drafting else { return }
        advanceToNextFloor()
    }

    /// DEV ONLY — instantly kill every enemy so the round resolves as a normal win
    /// (awards the floor's relic, triggers the relic reveal + victory screen).
    func devWinCombat() {
        for enemy in enemies { enemy.currentHp = 0; enemy.vfx = .none }
        turnBanner = .none
        playerVFX = .none
        isResolvingTurn = true   // suppress the overlay until the win sequence finishes
        checkRelicDrops()        // award drops for the enemies we just killed
        gameState = .victory
    }

    // MARK: - Restart (dev-mode retry of the exact current fight)

    func restartCombat() {
        // Full reset of health pools for a clean re-attempt of the same floor.
        player.currentHp = player.maxHp
        // Reuse the floor-combat setup (reshuffles masterDeck, resets enemy,
        // energy, block, turn/VFX state) without touching currentFloor/currentAct
        // or the masterDeck itself.
        startFloorCombat()
    }
}
