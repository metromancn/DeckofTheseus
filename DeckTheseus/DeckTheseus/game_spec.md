# Vibe-Coding Master Design Document: Deck of Theseus

## 1. Global Architecture & Visual Style
* **Genre:** Roguelike Deckbuilder.
* **Visual Style:** Programmatic Pixel Art. The AI must render all graphics using 2D arrays on an HTML5 `<canvas>` (e.g., a 16x16 grid system with a fixed 16-color retro palette). No external PNGs or JPEGs.
* **UI Framework:** Single Page Application (SPA) using clean CSS Flexbox and Grid. Screens are toggled using `display: none`.

## 2. Core State Variables (The Engine)
The AI must maintain these variables globally:
* **Player State:** `hp`, `maxHp` (starts at 80), `energy` (starts at 3 per turn, resets every turn), `gold` (starts at 99).
* **Deck State:** Four arrays: `masterDeck` (all owned cards), `drawPile`, `discardPile`, and `hand` (max 5 cards).
* **Status Effects:** Integers tracking durations or stacks (e.g., `vulnerableStacks`, `poisonStacks`, `block`).
* **Global Tracker:** `totalTurns` (increments every time the player clicks "End Turn" to track for the Global Leaderboard).

## 3. The UI Screens & Layouts
### A. The Map Screen (Stages)
* **Layout:** Vertical scrolling container. Nodes branch upwards from bottom to top, connected by SVG lines. You can only click nodes connected to your current location.
* **Node Types:** ⚔️ Normal Fight, 💀 Elite Fight, ⛺ Rest Site, 💰 Shop.

### B. The Combat Screen
* **Top (Status Bar):** Player HP (`[██████░░] 60/80`), Gold (`💰 150`), Floor Number, and a row of collected Relic icons.
* **Middle (The Arena):** The HTML5 Canvas. Player sprite on the left, Enemy sprite on the right. Above the enemy is the Intent Icon (e.g., ⚔️ 12) showing their exact next move.
* **Bottom (Control Deck):** Energy counter, Draw Pile count. Center area contains the Hand (horizontal row of clickable card `div`s that pop up on hover). Far right has an "END TURN" button and Discard Pile count.

### C. The Shop Screen
* **Layout:** Pixel-art shopkeeper and dialogue box at the top. A 3x2 CSS Grid for the inventory. A "Leave Shop" button at the bottom.

## 4. The Game Loop
The game consists of **3 Acts**, each with **15 Floors**.
* **Floors 1-14:** Choose a path on the Map screen.
    * *Normal Fight:* Rewards Gold and 1 Card Draft (choose 1 of 3).
    * *Elite Fight:* Rewards Gold, 1 Card Draft, and 1 Relic.
    * *Rest Site:* Choose to Heal 30% of Max HP **OR** Upgrade a card.
    * *Shop:* Spend Gold.
* **Floor 15 (Boss):** Massive encounter. Rewards full heal, a Boss Relic, and advances to the next Act.

## 5. Combat Mechanics & Rules
* **Drawing:** Draw 5 cards at the start of the turn.
* **Discarding:** At the end of the turn, *all* cards (played and unplayed) go to the discard pile. Block resets to 0.
* **Reshuffling:** When `drawPile` is empty, shuffle `discardPile` and move it to `drawPile`.
* **Math (Use integer flooring `Math.floor()` to prevent decimals):**
    * *Vulnerable:* Target takes 50% more damage.
    * *Weak:* Target deals 25% less damage.

## 6. Cards & Archetypes
**Starter Deck (10 Cards):**
* 5x Strike (1 Energy, 6 Damage)
* 4x Defend (1 Energy, 5 Block)
* 1x Bash (2 Energy, 8 Damage + Apply 2 Vulnerable)

**Draft Archetypes (Examples to build around):**
* **The Juggernaut:** Uses Block as a weapon. (e.g., *Barricade*: Block no longer resets. *Shield Slam*: Deal damage equal to current Block).
* **The Venom:** Exponential damage over time. (e.g., *Poison Stab*: Apply Poison. *Catalyst*: Double enemy's current Poison stacks).

## 7. The Shop Economy
The shop always sells exactly 6 items:
1.  **Common Card:** 50 Gold
2.  **Uncommon Card:** 75 Gold
3.  **Rare Card:** 150 Gold
4.  **Common Relic:** 150 Gold
5.  **Rare Relic:** 250 Gold
6.  **Card Removal Service:** 75 Gold (Lets player permanently delete 1 card from `masterDeck`. Price increases by +25 Gold every time it is used).

## 8. The Relic System
Relics are passive modifiers.
* **Combat Starter:** e.g., *Rusty Anchor* (Start combat with +10 Block).
* **Synergy Relic:** e.g., *Viper's Fang* (Adds +1 to all Poison applied).
* **Boss Relic:** e.g., *Cursed Chalice* (+1 Energy per turn, but Rest Sites no longer heal).
* **Edge Case Safety (Consumable Payout):** If the `relicPool` array is empty when a player defeats an Elite, the game MUST NOT crash. Instead, trigger a Consumable Payout: `player.gold += 150` and `player.maxHp += 5`.

## 9. Act 1 Boss: The Slime King
* **Stats:** 140 HP. Visual: 16x16 pulsing green blob.
* **Intent Pattern (Loops infinitely):**
    1.  *Turn 1 (Tackle):* Deals 12 direct damage.
    2.  *Turn 2 (Goo Spit):* Adds 2 "Slime" status cards into the player's *discard pile*. (Slime Card: Useless card that costs 1 Energy just to remove from your hand).
    3.  *Turn 3 (Harden):* Boss gains 15 Block and clears all Poison/Debuffs.

## 10. The Ascension System (Difficulty Ladder)
Unlocked sequentially after beating the game. Modifiers stack.
* **Level 1:** Rest Sites heal for 15% instead of 30%.
* **Level 2:** Normal enemies deal 15% more damage.
* **Level 3:** Elite enemies gain 20% more HP and Damage.
* **Level 4:** Player Max HP starts at 68 instead of 80.
* **Level 5:** Bosses gain an extra mechanic (e.g., Slime King clears debuffs every 2 turns instead of 3).

## 11. Global Leaderboard
* **Metric:** Total Turns Taken to complete the run (lowest score wins).
* **Tech Stack:** Use a free BaaS (like Supabase). The AI will write a JavaScript `fetch()` request when the Act 3 Boss dies to send: `{ playerName: String, difficultyLevel: Int, totalTurns: Int }`.
* **UI:** A "Global Rankings" HTML table on the main menu fetching the top 10 lowest turn counts per difficulty.
