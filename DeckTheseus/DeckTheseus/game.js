class Player {
  constructor() {
    this.maxHp = 80;
    this.currentHp = 80;
    this.maxEnergy = 3;
    this.currentEnergy = 3;
    this.gold = 99;
    this.currentBlock = 0;
  }
}

class Enemy {
  constructor() {
    this.name = "Slime King";
    this.maxHp = 140;
    this.currentHp = 140;
    this.intent = null;
  }
}

class Card {
  constructor(name, type, energyCost, damage = 0, block = 0) {
    this.name = name;
    this.type = type;
    this.energyCost = energyCost;
    this.damage = damage;
    this.block = block;
  }
}

class DeckManager {
  constructor() {
    this.masterDeck = [];
    this.drawPile = [];
    this.discardPile = [];
    this.hand = [];
  }

  initializeDeck() {
    this.masterDeck = [];

    for (let i = 0; i < 5; i += 1) {
      this.masterDeck.push(new Card("Strike", "attack", 1, 6, 0));
    }

    for (let i = 0; i < 4; i += 1) {
      this.masterDeck.push(new Card("Defend", "skill", 1, 0, 5));
    }

    this.masterDeck.push(new Card("Bash", "attack", 2, 8, 0));
  }

  startCombat() {
    this.drawPile = [...this.masterDeck];
    this.discardPile = [];
    this.hand = [];
    this.shuffle(this.drawPile);
  }

  drawCards(amount) {
    for (let i = 0; i < amount; i += 1) {
      if (this.drawPile.length === 0) {
        if (this.discardPile.length === 0) {
          return;
        }

        this.drawPile = [...this.discardPile];
        this.discardPile = [];
        this.shuffle(this.drawPile);
      }

      this.hand.push(this.drawPile.pop());
    }
  }

  shuffle(cards) {
    for (let i = cards.length - 1; i > 0; i -= 1) {
      const randomIndex = Math.floor(Math.random() * (i + 1));
      const currentCard = cards[i];
      cards[i] = cards[randomIndex];
      cards[randomIndex] = currentCard;
    }
  }
}

function playCard(handIndex) {
  const card = deckManager.hand[handIndex];
  if (!card) {
    return;
  }

  if (player.currentEnergy < card.energyCost) {
    console.log("Not enough energy");
    return;
  }

  player.currentEnergy -= card.energyCost;

  if (card.damage > 0) {
    enemy.currentHp -= card.damage;
  }

  if (card.block > 0) {
    player.currentBlock += card.block;
  }

  deckManager.hand.splice(handIndex, 1);
  deckManager.discardPile.push(card);

  console.log(`Played ${card.name} | Energy: ${player.currentEnergy}/${player.maxEnergy} | Block: ${player.currentBlock} | Enemy HP: ${enemy.currentHp}/${enemy.maxHp}`);
}

function endTurn() {
  while (deckManager.hand.length > 0) {
    deckManager.discardPile.push(deckManager.hand.pop());
  }

  player.currentEnergy = player.maxEnergy;
  player.currentBlock = 0;

  deckManager.drawCards(5);

  console.log(`Turn ended | Draw Pile: ${deckManager.drawPile.length} | Discard Pile: ${deckManager.discardPile.length}`);
}

const player = new Player();
const enemy = new Enemy();
const deckManager = new DeckManager();

deckManager.initializeDeck();
deckManager.startCombat();
deckManager.drawCards(5);

console.log("Hand:", deckManager.hand.map(c => c.name));
playCard(0);
endTurn();
console.log("New Hand:", deckManager.hand.map(c => c.name));
