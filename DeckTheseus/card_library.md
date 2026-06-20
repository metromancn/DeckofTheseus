# Deck of Theseus - Master Card Library

This document serves as the comprehensive repository for all draftable cards in the game. It is designed to be fed into the AI code generator during Phase 4 of development, keeping the core game engine context separate from the content pool.

## 1. Common Cards (The Bread and Butter)
**Design Philosophy:** Simple, reliable, and straightforward. These cards are slightly better than the starting Strikes and Defends, but they do not break the rules of the game. They usually just do one thing very well.

| Card Name | Type | Cost | Effect | Build Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **Poison Stab** | Attack | 1 | Deal 5 damage. Apply 3 Poison. | Venom |
| **Heavy Blade** | Attack | 2 | Deal 14 damage. | Generic |
| **Fortify** | Skill | 2 | Gain 15 Block. | Juggernaut |
| **Quick Dodge** | Skill | 1 | Gain 4 Block. Draw 1 card. | Generic |

## 2. Uncommon Cards (The Engine Pieces)
**Design Philosophy:** These cards require synergy to be useful. On their own, they might seem weak, but when combined with the right Common cards, they start to snowball. They introduce slightly more complex math.

| Card Name | Type | Cost | Effect | Build Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **Shield Slam** | Attack | 1 | Deal damage equal to your current Block. | Juggernaut |
| **Noxious Fumes** | Power | 1 | At the start of your turn, apply 2 Poison to all enemies. | Venom |
| **Bloodletting** | Skill | 0 | Lose 3 HP. Gain 2 Energy. | Generic |
| **Entrench** | Skill | 2 | Double your current Block. | Juggernaut |

## 3. Rare Cards (The Rule Breakers)
**Design Philosophy:** Build-defining cards. These drastically alter how you play the game. They are expensive, rare, and usually "Powers" that last the entire combat, or cards with massive, fight-ending effects.

| Card Name | Type | Cost | Effect | Build Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **Barricade** | Power | 3 | Block is no longer removed at the end of your turn. | Juggernaut |
| **Catalyst** | Skill | 2 | Double the enemy's current Poison stacks. Exhausts after use. | Venom |
| **Demon Form** | Power | 3 | At the start of your turn, all attacks deal +2 damage permanently. | Generic |
| **Omniscience** | Skill | 3 | Choose a card in your draw pile. Play it twice. Exhaust. | Generic |

## 4. Expansion Directives for the AI
When generating new cards to expand this library in the future, adhere to the following logic restrictions:
* All damage and block scaling must rely strictly on integer math (no floating point numbers). Use `Math.floor()` for any percentage-based modifiers.
* Common cards should rarely cost more than 2 energy.
* Cards that apply permanent scaling (like Demon Form) must have high energy costs (3) to prevent the player from playing them alongside defensive cards on the same turn.