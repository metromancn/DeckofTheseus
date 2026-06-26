import Foundation
import Observation

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

    init(name: String, type: CardType, energyCost: Int, damage: Int, block: Int, imageName: String?,
         vulnerableApply: Int = 0, isExhaustible: Bool = false) {
        self.name = name
        self.type = type
        self.energyCost = energyCost
        self.damage = damage
        self.block = block
        self.imageName = imageName
        self.vulnerableApply = vulnerableApply
        self.isExhaustible = isExhaustible
    }

    var description: String {
        if type == .status {
            return "Unplayable. Costs \(energyCost) energy to remove from your deck for this combat."
        }
        var parts: [String] = []
        if damage > 0 { parts.append("Deal \(damage) damage.") }
        if vulnerableApply > 0 { parts.append("Apply \(vulnerableApply) Vulnerable.") }
        if block > 0 { parts.append("Gain \(block) block.") }
        if isExhaustible { parts.append("Exhaust.") }
        return parts.joined(separator: " ")
    }

    static func slime() -> Card {
        Card(name: "Slime", type: .status, energyCost: 1, damage: 0, block: 0,
             imageName: "card_slimed_status", isExhaustible: true)
    }
}

// MARK: - Enemy Intent

enum EnemyIntent {
    case tackle(baseDamage: Int)
    case gooSpit(slimeCount: Int)
    case harden(block: Int, strengthGain: Int)

    var displayName: String {
        switch self {
        case .tackle: return "Tackle"
        case .gooSpit: return "Goo Spit"
        case .harden: return "Harden"
        }
    }

    func displayValue(strength: Int) -> String {
        switch self {
        case .tackle(let base): return "\(base + strength)"
        case .gooSpit(let count): return "×\(count)"
        case .harden(let blk, _): return "\(blk)"
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
class Enemy {
    var name = "Slime King"
    var maxHp = 140
    var currentHp = 140
    var currentBlock = 0
    var strength = 0
    var vulnerableTurns = 0
    var nextMove: EnemyIntent = .tackle(baseDamage: 12)

    func clearDebuffs() {
        vulnerableTurns = 0
    }

    func advanceIntent(forTurn turn: Int) {
        switch (turn - 1) % 3 {
        case 0: nextMove = .tackle(baseDamage: 12)
        case 1: nextMove = .gooSpit(slimeCount: 2)
        case 2: nextMove = .harden(block: 15, strengthGain: 2)
        default: break
        }
    }

    func reset() {
        currentHp = maxHp
        currentBlock = 0
        strength = 0
        vulnerableTurns = 0
        nextMove = .tackle(baseDamage: 12)
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
    var enemy = Enemy()
    var deck = DeckManager()
    var selectedCardIds: Set<UUID> = []
    var currentTurn = 1
    var gameState: GameState = .playing

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
        deck.startCombat()
        deck.drawCards(5)
        enemy.advanceIntent(forTurn: currentTurn)
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
        if enemy.currentHp <= 0 {
            enemy.currentHp = 0
            player.currentHp = player.maxHp
            gameState = .victory
        } else if player.currentHp <= 0 {
            player.currentHp = 0
            gameState = .defeat
        }
    }

    // MARK: - Play Cards

    func playSelectedCards() {
        guard gameState == .playing else { return }
        let selected = deck.hand.filter { selectedCardIds.contains($0.id) }
        for card in selected {
            if card.damage > 0 {
                var raw = card.damage
                if enemy.vulnerableTurns > 0 {
                    raw = Int(floor(Double(raw) * 1.5))
                }
                let afterBlock = applyDamageToEnemy(raw)
                enemy.currentHp = max(0, enemy.currentHp - afterBlock)
            }
            if card.block > 0 {
                player.currentBlock += card.block
            }
            if card.vulnerableApply > 0 {
                enemy.vulnerableTurns += card.vulnerableApply
            }

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

    private func applyDamageToEnemy(_ raw: Int) -> Int {
        let absorbed = min(raw, enemy.currentBlock)
        enemy.currentBlock -= absorbed
        return raw - absorbed
    }

    // MARK: - Enemy Turn

    private func executeEnemyTurn() {
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

        case .harden(let block, let strengthGain):
            enemy.currentBlock += block
            enemy.strength += strengthGain
            enemy.clearDebuffs()
        }

        checkCombatResolution()
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
        enemy.advanceIntent(forTurn: currentTurn)
        deck.drawCards(5)
    }

    // MARK: - Restart

    func restartCombat() {
        player.currentHp = player.maxHp
        player.currentBlock = 0
        player.currentEnergy = player.maxEnergy

        enemy.reset()

        deck.startCombat()
        deck.drawCards(5)

        selectedCardIds.removeAll()
        currentTurn = 1
        enemy.advanceIntent(forTurn: currentTurn)
        gameState = .playing
    }
}
