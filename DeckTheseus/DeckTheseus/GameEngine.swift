import Foundation
import Observation

enum CardType: String {
    case attack
    case skill
}

struct Card: Identifiable {
    let id = UUID()
    let name: String
    let type: CardType
    let energyCost: Int
    let damage: Int
    let block: Int
    let imageName: String?

    var description: String {
        var parts: [String] = []
        if damage > 0 { parts.append("Deal \(damage) damage.") }
        if block > 0 { parts.append("Gain \(block) block.") }
        return parts.joined(separator: " ")
    }
}

@Observable
class Player {
    var maxHp = 80
    var currentHp = 80
    var maxEnergy = 3
    var currentEnergy = 3
    var gold = 99
    var currentBlock = 0
}

@Observable
class Enemy {
    var name = "Slime King"
    var maxHp = 140
    var currentHp = 140
    var currentBlock = 0
}

@Observable
class DeckManager {
    var masterDeck: [Card] = []
    var drawPile: [Card] = []
    var discardPile: [Card] = []
    var hand: [Card] = []

    func initializeDeck() {
        masterDeck = []

        for _ in 0..<5 {
            masterDeck.append(Card(name: "Strike", type: .attack, energyCost: 1, damage: 6, block: 0, imageName: "card_strike_attack"))
        }

        for _ in 0..<4 {
            masterDeck.append(Card(name: "Defend", type: .skill, energyCost: 1, damage: 0, block: 5, imageName: "card_defend_skill"))
        }

        masterDeck.append(Card(name: "Bash", type: .attack, energyCost: 2, damage: 8, block: 0, imageName: "card_bash_attack"))
    }

    func startCombat() {
        drawPile = masterDeck
        discardPile = []
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
}

@Observable
class GameEngine {
    var player = Player()
    var enemy = Enemy()
    var deck = DeckManager()
    var selectedCardIds: Set<UUID> = []
    var currentTurn = 1

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
    }

    func canAfford(_ card: Card) -> Bool {
        if selectedCardIds.contains(card.id) { return true }
        return remainingEnergy >= card.energyCost
    }

    func toggleSelection(_ cardId: UUID) {
        if selectedCardIds.contains(cardId) {
            selectedCardIds.remove(cardId)
        } else {
            guard let card = deck.hand.first(where: { $0.id == cardId }) else { return }
            guard remainingEnergy >= card.energyCost else { return }
            selectedCardIds.insert(cardId)
        }
    }

    func playSelectedCards() {
        let selected = deck.hand.filter { selectedCardIds.contains($0.id) }
        for card in selected {
            if card.damage > 0 {
                enemy.currentHp = max(0, enemy.currentHp - card.damage)
            }
            if card.block > 0 {
                player.currentBlock += card.block
            }
        }
        player.currentEnergy -= usedEnergy
        deck.hand.removeAll { selectedCardIds.contains($0.id) }
        deck.discardPile.append(contentsOf: selected)
        selectedCardIds.removeAll()
    }

    func endTurn() {
        playSelectedCards()

        while !deck.hand.isEmpty {
            deck.discardPile.append(deck.hand.removeLast())
        }

        player.currentEnergy = player.maxEnergy
        currentTurn += 1
        deck.drawCards(5)
    }
}
