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
    var intent: String? = nil
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
            masterDeck.append(Card(name: "Strike", type: .attack, energyCost: 1, damage: 6, block: 0))
        }

        for _ in 0..<4 {
            masterDeck.append(Card(name: "Defend", type: .skill, energyCost: 1, damage: 0, block: 5))
        }

        masterDeck.append(Card(name: "Bash", type: .attack, energyCost: 2, damage: 8, block: 0))
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

    init() {
        deck.initializeDeck()
        deck.startCombat()
        deck.drawCards(5)
    }

    func playCard(at handIndex: Int) {
        guard handIndex < deck.hand.count else { return }
        let card = deck.hand[handIndex]

        guard player.currentEnergy >= card.energyCost else {
            print("Not enough energy")
            return
        }

        player.currentEnergy -= card.energyCost

        if card.damage > 0 {
            enemy.currentHp -= card.damage
        }

        if card.block > 0 {
            player.currentBlock += card.block
        }

        let played = deck.hand.remove(at: handIndex)
        deck.discardPile.append(played)

        print("Played \(card.name) | Energy: \(player.currentEnergy)/\(player.maxEnergy) | Block: \(player.currentBlock) | Enemy HP: \(enemy.currentHp)/\(enemy.maxHp)")
    }

    func endTurn() {
        while !deck.hand.isEmpty {
            deck.discardPile.append(deck.hand.removeLast())
        }

        player.currentEnergy = player.maxEnergy
        player.currentBlock = 0

        deck.drawCards(5)

        print("Turn ended | Draw Pile: \(deck.drawPile.count) | Discard Pile: \(deck.discardPile.count)")
    }
}
