# Deck of Theseus — Design Document (Current Build)

> Describes the game **as currently implemented**. `_(planned)_` marks the long-term vision.
> The shipped game is a native **SwiftUI** app (the original HTML5-canvas concept was dropped).
> It fuses Slay-the-Spire deckbuilding with an *An Average Campaign*-style RPG stat/gear layer.

## 1. Architecture & Visual Style
* **Genre:** solo Roguelike Deckbuilder + light RPG (stats, equipment).
* **Platform:** native **SwiftUI** (iOS + macOS). `@Observable` drives all state
  (`GameEngine`, `Player`, `Enemy`, `DeckManager`).
* **Visual Style:** hand-authored **pixel-art PNGs** trimmed at render time by `CroppedSprite`.
  Font: **VT323**, registered at runtime.
* **Key files:** `GameEngine.swift` (state + logic), `ContentView.swift` (all UI),
  `DeckTheseusApp.swift` (entry + font).

## 2. Core State
* **Player:** `currentHp`; `maxHp` is **computed** = `baseMaxHp (80)` + effective CON. Energy
  `maxEnergy (3)` (+1 per Slime Core relic → `effectiveMaxEnergy`); `currentBlock`; `gold`
  (starts 0). Stat allocations, equipped gear, and equipment inventory all live here.
* **Deck:** `masterDeck`, `drawPile`, `discardPile`, `exhaustPile`, `hand`.
* **Relics:** `playerRelics` — **all owned relics are always active**; duplicates stack.
* **Progression:** `currentAct`, `currentFloor`, `clearedFloors` (first-win tracking).

## 3. Combat Screen & Interaction
* **Top-left HUD:** Act-Floor, Turn, **gold** (coin + amount), owned **relic icons** (hover/hold
  for name + description), and a **STATS (N)** button (N = unspent stat points).
* **Player left, enemies clustered right.** Each combatant shows a name, sprite, a **numeric HP
  bar** (`cur/max`), a **shield** icon (block), and status badges. Enemy bars narrow when 3+
  enemies are present so they never overlap the player's stats.
* **Enemy intent** telegraphed per enemy; **▼ reticle** marks the target (tap a sprite to
  retarget; an AOE card being dragged marks *all* enemies).
* **Floating combat text:** damage numbers, gold **CRIT!**, blue **DODGE**, green **GUARD**,
  purple **poison**, green **heal** — so stat rolls are visible.
* **Playing cards — drag-to-play, queued:**
  * **Tap** a card to select it (multi-select; selected cards reserve their energy in the
    HUD counter). **Drag** a card up into the middle and release to play it.
  * A played card **leaves the hand instantly** (energy spent) and is **queued**; the queue
    resolves plays one at a time — each parks in the center, holds, fades, then its effect +
    animation fire. So you can fire several cards without waiting on animations.
  * Each card hits the enemy you aimed at **when you played it**; hold a card for its tooltip.
* **END TURN** runs the enemy phase (disabled while the queue is draining).
* **Dev SKIP** (top-right) instant-wins the fight.

## 4. Result / Progression Screens
* **Victory:** Act-Floor + "VICTORY", hero centered, rewards bar (gold, first-win bonus, `+N
  Stat Points`). Buttons: **Exit** (no-op, reserved for the Map) and **Next** → opens the
  full **stats page**, whose confirm button reads **"Next Stage ▶"** (commits your point
  allocation and advances). So every advance routes through the allocation screen.
* **Defeat:** red "DEFEAT", empty rewards bar. **Try Again** = **full run restart** from Act 1
  Floor 1 (HP/gold/relics/gear/deck all wiped — Slay-the-Spire style); **Exit** no-op.
* **Rest Site / Card Draft / Shop / Act Complete / relic + equipment reveal banners / combo
  banner** — see below.

## 5. The Game Loop — Act 1 (18 floors, Slime Biome)
Encounters are **fixed per floor** (`setupCurrentFloor()`), hand-tuned into a fair curve.

| Floor | Type | Encounter |
|------:|------|-----------|
| 1 | Combat | 1 Slime (tutorial) |
| 2 | Combat | 2 Slimes |
| 3 | Combat | 1 Slime + 1 Red Slime |
| 4 | **Rest** | heal / invest / gear |
| 5 | **Elite 1** | Acid Slime + Slime → **Vampire Tooth** |
| 6 | Combat | 2 Red Slimes |
| 7 | Combat | 3 Slimes |
| 8 | Combat | 2 Slimes + 1 Red |
| 9 | **Mini-boss** | **Giant Slime** |
| 10 | **Rest** | (Shop immediately after) |
| 11 | Combat | 1 Slime + 2 Red |
| 12 | Combat | 3 Red Slimes |
| 13 | **Elite 2** | Spiked Slime + 2 Slimes → **Mysterious Amber** |
| 14 | Combat | 3 Slimes |
| 15 | Combat | 2 Slimes + 1 Red |
| 16 | **Rest** | heal only (no draft) |
| 17 | Combat | 3 Red Slimes (final gauntlet) |
| 18 | **Boss** | Slime King |
| 19 | Run complete | "Act 1 Complete" |

Progression is **linear**; a branching **Map** and **Acts 2–3** are _(planned)_. More enemy
variety / a second biome is the intended cure for repetition _(planned)_.

## 6. Combat Mechanics
* **Turn start:** draw 5; energy refreshed to `effectiveMaxEnergy` (± next-turn modifiers);
  chance for +1 energy (Energy Gain stat).
* **Block** absorbs damage like temp HP and **resets at the start of each side's own turn**
  (after it has absorbed the opponent's hits). **Barricade** stops the player's block resetting
  for that combat.
* **Player attacks** roll **Crit** (per hit; ×Crit Damage), then Vulnerable, then the enemy's
  block absorbs. **Incoming hits** roll **Dodge** (negate) → **Guard** (reduce by Guard DR) →
  block shield → HP. **Each enemy attacks as its own hit**, so multi-enemy turns are separate
  hits and Guard/Dodge roll per hit.
* **Reshuffle** discard→draw when empty. **Exhaust** cards leave the deck until next combat.

### Status effects
* **Vulnerable** — +50% damage taken per stack; persists; cleared by the boss's Harden.
* **Poison** — 3 damage at the start of the poisoned enemy's turn (bypasses block), −1 stack
  per turn. Cleared by Harden. *(text badge, no sprite yet)*
* **Weak** — the enemy's attacks deal −25% for one turn. Cleared by Harden. *(placeholder)*
* **Stun** — the enemy skips its turn (Poison still ticks); −1 per turn. *(placeholder)*
* **Strength** — enemy stat adding flat attack damage (gained via Harden).

## 7. Stats (RPG layer)
Seven stats — **STR, DEX, CON, INT, FTH, LCK, CHA** — each raised by **stat points** or gear.
`effectiveStats = allocations + equipped gear bonuses`, feeding a pure `DerivedStats.derive()`.
Each stat has a **distinct identity** so all seven are worth investing in:

| Stat | Identity | Effect |
|------|----------|--------|
| **STR** | Power | Guard chance (block part of a hit, diminishing) + Crit damage |
| **DEX** | Agility | Dodge chance (negate a hit, diminishing) + Crit chance |
| **CON** | Toughness | +1 Max HP/pt + Guard reduction (how much a guarded hit is cut) |
| **INT** | Focus | **+1 Max Energy every 15 INT** (breakpoint) + small energy-gain chance |
| **FTH** | Spirit | Heals received are stronger (+1%/pt) + heal FTH/5 HP after each combat + lifesteal +FTH/10 |
| **LCK** | Fortune | +1%/pt gear-drop chance (cap 75%) + +1%/pt gold from enemies |
| **CHA** | Merchant | Shop discount (up to 50% off) + 1 extra shop card per 20 CHA |

Guard/Dodge/Guard-DR use asymptotic (diminishing) formulas; crit/heal/economy scale linearly.
Base values: Crit 5% / Crit Dmg 130% / Guard DR 50% / Dodge 5%. Lifesteal base is Vampire
Tooth's 50% / 2 HP, which FTH adds to.

**Stat points:** granted on floor clear — Normal +2, Elite +4, Mini-boss +5, Boss +6. Spent on
the **character/stats screen** (STATS button mid-run, or the post-victory "ALLOCATE POINTS"
page): ▲/▼ allocate, a live derived-stats preview, Confirm commits. Each stat's label carries a
**"?"** — hover (pointer) or hold (touch) to read what it does and its next breakpoint.

## 8. Equipment (RPG gear)
Stat-boosting gear (distinct from relics, which are passives). Five slots: **Helmet, Chest,
Legs, Feet, Weapon** — one item per slot; extras sit in the **inventory**.
* **Drops:** each defeated **normal** enemy has a **25% + Lucky Drop** chance to drop a random
  piece (elites drop relics *only*; the **mini-boss guarantees 2**). Dropped gear pops an
  "EQUIPMENT FOUND!" banner.
* **Equip/manage** on the character screen (EQUIPMENT panel + scrollable inventory); equipping
  updates derived stats and Max HP live. **Sell** spares at the shop.
* No crafting/materials (cut). Art is **placeholder-free** — gear shows as text (name + bonuses).

## 9. Cards
**Starter (10):** 5× Strike (1⚡, 6 dmg), 4× Defend (1⚡, 5 block), 1× Bash (2⚡, 8 dmg + 1 Vulnerable).

**Card pool** (rarities; drafted at Rest or bought at Shop):
| Card | Rarity | Cost | Effect |
|------|--------|:----:|--------|
| Cleave | Common | 2 | 8 dmg to **all** enemies |
| Fortify | Common | 2 | 15 Block |
| Poison | Common | 1 | 5 dmg + 3 **Poison** |
| Thunder | Uncommon | 2 | 15 dmg, +1 energy next turn |
| Turtle | Uncommon | 2 | **Double** your current Block |
| Barricade | Rare | 3 | 8 Block; block no longer resets this combat |
| Catalyst | Rare | 2 | **Double** the enemy's Poison; **Exhaust** |

**Status card — Slime:** unplayable; 1⚡ to remove (exhausts). Injected by the boss's Goo Spit
and by the Slime Core relic. The **Rest-Site draft** offers only Cleave / Thunder / Barricade.

## 10. Relics
All owned relics are active; the top-left HUD shows their icons; **duplicates stack**.
* **Vampire Tooth** (Acid Slime, F5) — on each Attack card, per owned copy: 50% chance to heal
  2 HP (+Lifesteal stats). Two copies = two rolls.
* **Mysterious Amber** (Spiked Slime, F13) — +6 Block at combat start and +5 Block every 3rd
  turn, **per copy** (2 copies = 12 / 10).
* **Slime Core** (Shop, placeholder icon) — +1 Max Energy, but start each combat with a Slime
  card mixed into your deck (per copy).

**Drops:** elites drop their relic at 100% on floor clear.

## 11. Shop (after the Floor-10 rest)
* **Cards (5):** 2 Common / 2 Uncommon / 1 Rare from the pool, priced 50 / 60 / 75. Buying adds
  the card to your deck and marks it SOLD; hold a card to read it.
* **Relics (2–3):** random from the pool (duplicates buyable), 150–300 gold, with descriptions.
* **Sell Equipment:** sell spare inventory gear for its sell value.
* **LEAVE SHOP** starts Floor 11.
* _(Cut for now: crafting, merge-equipment, card removal.)_

## 12. Hidden Combos
Undocumented in-game; a center-screen **"✦ COMBO!"** banner fires when conditions are met.
* **Poison Combo** — Poison + Catalyst on one enemy in a single turn, *or* 2 Poison + 1 Catalyst
  on one enemy over the fight → that enemy takes **direct damage = its current Poison** and
  gains **Weak**.
* **Shield Combo** — play Fortify + Turtle + Barricade + Defend during one fight → the
  **lowest-HP** enemy takes **direct damage = your current Block**, is **Stunned**, and you
  **gain 8 Block**.

## 13. Enemies (Act 1)
Telegraphed intents; each walks a repeating rotation by turn.

| Enemy | Role | HP | Gold | Rotation |
|-------|------|---:|-----:|----------|
| Slime | Normal | 30 | 15 | Tackle 5 |
| Red Slime | Normal | 20 | 15 | Tackle 8 → Defend 3 |
| Acid Slime | Elite (F5) | 55 | 30 | Tackle 9 → Defend 15 · drops Vampire Tooth |
| Spiked Slime | Elite (F13) | 72 | 30 | Tackle 8 → Spike (5 dmg + 10 block) · drops Mysterious Amber |
| Giant Slime | Mini-boss (F9) | 100 | 50 | Tackle 12 → Harden (10 block + 1 Str) · **2 guaranteed gear** · placeholder art |
| Slime King | Boss (F18) | 160 | 100 | Tackle 12 → Goo Spit ×2 → Harden (15 block + 2 Str, clears debuffs) |

## 14. Presentation
Turn banners; frame-by-frame VFX (`basic_attack_animation`, `heal_debuff_animation2`,
`goo_spit_animation`); card deal/flip/play; relic + equipment reveal banners; combo banner.

## 15. Not Yet Implemented (Roadmap)
* Branching **Map**; **Acts 2 & 3** and a **second biome / new enemy types**.
* Real **art** for: Giant Slime, Slime Core relic, Poison/Weak/Stun status icons.
* **Classes** (base stats + starting decks), **subclasses via encounters**, an **encounter**
  framework (AAC-style 3-choice nodes).
* **Ascension** difficulty ladder; **global leaderboard**; card **upgrades**.
