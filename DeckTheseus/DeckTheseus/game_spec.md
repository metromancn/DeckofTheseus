# Deck of Theseus — Design Document (Current Build)

> This document describes the game **as it is currently implemented**. Sections tagged
> _(planned)_ are part of the long-term vision but not yet built. The original concept
> targeted an HTML5-canvas web app; the shipped game is a native **SwiftUI** app, so this
> spec has been rewritten to match reality.

## 1. Architecture & Visual Style
* **Genre:** Roguelike Deckbuilder (Slay-the-Spire style).
* **Platform:** Native **SwiftUI** app (runs on iOS and macOS).
* **State:** The `@Observable` macro (Observation framework) drives all reactive state —
  `GameEngine`, `Player`, `Enemy`, `DeckManager`. No Redux/canvas game loop.
* **Visual Style:** Hand-authored **pixel-art PNG assets** in the Xcode asset catalog
  (sprites, cards, hearts, orbs, relics, VFX frames) — *not* programmatically drawn.
  Sprites live on a 64px transparent canvas and are trimmed at render time by a
  `CroppedSprite` view (double-frame + clip using measured content bounds).
* **Font:** `VT323` retro pixel font, registered at runtime in `DeckTheseusApp`.
* **Key files:** `GameEngine.swift` (all state + logic), `ContentView.swift` (all UI),
  `DeckTheseusApp.swift` (app entry + font registration).

## 2. Core State (The Engine)
* **Player:** `maxHp`/`currentHp` (start 80), `maxEnergy`/`currentEnergy` (3, refreshed each
  turn), `currentBlock`, `gold` (**starts at 0**).
* **Deck (`DeckManager`):** five arrays — `masterDeck`, `drawPile`, `discardPile`,
  `exhaustPile`, `hand`.
* **Relics:** `playerRelics` (owned), one `equippedRelicId` active at a time.
* **Progression:** `currentAct`, `currentFloor`.
* **Gold rewards:** `clearedFloors` (which floors have been won — gates the first-win bonus),
  plus `lastGoldEarned` / `lastFirstWinBonus` for the victory-screen breakdown.
* **Turn buffs:** `extraEnergyNextTurn` (Thunder), `blockPersists` (Barricade — stops block
  resetting), `amberBlockCountdown` (Mysterious Amber's delayed mid-combat block).

## 3. UI Screens & Layout
### Combat Screen (the main view)
* **Top-left HUD:** Act-Floor number, Turn counter, and a **gold** indicator
  (placeholder coin icon + amount owned).
* **Player** on the left, **enemies clustered on the right** (tight spacing so multi-enemy
  fights stay out of the player's side of the arena).
* Each combatant shows a name, sprite (aligned to a shared ground line), a row of **hearts**
  (each heart = 20 HP; full / half / empty art), and a **shield** icon when block > 0.
* **Enemy intent** is telegraphed above/next to each enemy (move name + value).
* **Target reticle** (▼) marks the currently targeted enemy; tap any enemy sprite to retarget.
* **Bottom bar:** draw-pile count + face-down pile (left); a fanned **hand** of cards (center)
  that lifts/highlights on select and shows a **tooltip** on hold; energy orb, relic bar, and
  **END TURN** button (right).
* **Dev SKIP button** (top-right) — instantly wins the current combat (for testing).

### Result Screens (Victory / Defeat)
Victory and Defeat share one full-screen layout: the **Act-Floor number** above a **title
banner**, the hero sprite centered, a **rewards bar**, and a right-aligned row of buttons.
* **Victory** — gold "VICTORY" title; the rewards bar shows the gold earned, with the
  **first-win bonus** chip (carrying a "First Win" bubble) in front of the normal gold chip;
  buttons **Try Again · Exit · Next Stage**.
* **Defeat** — red "DEFEAT" title; **empty** rewards bar; buttons **Try Again · Exit**.
* **Exit** is a no-op for now (reserved to return to the Map once mapping exists). **Try Again**
  restarts the current fight; **Next Stage** advances.

### Other Overlays
* **Rest Site** — see §7.
* **Card Draft** — tap a card to highlight, then **SELECT CARD**.
* **Shop** — placeholder screen with a **LEAVE SHOP** button (see §6).
* **Act Complete** — end-of-run screen after the boss.
* **Relic reveal banner** — pops the moment an elite drops a relic ("tap anywhere to close").

### Map screen — _(planned)_
Progression is currently **linear** (no branching map).

## 4. The Game Loop
The full game is envisioned as **3 Acts × 15 Floors**. **Act 1 (the Slime Biome) is fully
implemented**; Acts 2–3 are _(planned)_. Encounters are **fixed per floor** (hand-tuned into a
fair difficulty curve — no randomness), configured by `setupCurrentFloor()`:

| Floor | Type | Encounter | Notes |
|------:|------|-----------|-------|
| 1 | Beginner combat | 1 Slime | Tutorial: single target |
| 2 | Combat | 2 Slimes | Multi-target basics |
| 3 | Combat | 1 Slime + 1 Red Slime | Focus the dangerous target |
| 4 | **Rest Site** | Heal or draft (1st card) | |
| 5 | **Elite 1** | Acid Slime + 1 Slime | Drops **Vampire Tooth** |
| 6 | Combat | 2 Red Slimes | Burst check |
| 7 | Combat | 3 Slimes | Endurance wall (rewards AOE) |
| 8 | Combat | 2 Slimes + 1 Red Slime | Mixed, sustained |
| 9 | **Rest Site** | Heal or draft (2nd card) | |
| — | **Shop** | Between Floors 9 and 10 | Placeholder |
| 10 | Combat | 1 Slime + 2 Red Slimes | High burst |
| 11 | **Elite 2** | Spiked Slime + 2 Slimes | Drops **Mysterious Amber** |
| 12 | Combat | 3 Slimes | Grind breather after the elite |
| 13 | Combat | 3 Red Slimes | Final gauntlet (max burst) |
| 14 | **Rest Site** | Heal only (no draft) | Top off for the boss |
| 15 | **Boss** | Slime King | Act finale |
| 16 | Run complete | "Act 1 Complete" screen | |

The difficulty ramps in step with the player's power spikes: Floors 1–3 use only the starter
deck; the jumps to 2- and 3-enemy fights land *after* the draft rooms (4, 9) and the Shop.

## 5. Combat Mechanics
* **Turn start:** draw **5 cards**; energy refreshed to `maxEnergy` (± next-turn modifiers).
* **Playing cards:** select any affordable cards, then END TURN plays them in order. Energy
  is spent per card; unaffordable cards can't be selected.
* **End of turn:** all remaining hand cards are discarded, then every living enemy executes
  its telegraphed move.
* **Block:** absorbs incoming damage like temporary HP, shown as a shield.
  Block **resets to 0 at the start of each side's own turn** — the player's at the start of
  their turn, an enemy's at the start of its turn. Because the reset happens *after* the
  opponent's turn, block always gets to absorb the incoming attacks first. **Barricade** makes
  the player's block stop resetting for the rest of that combat.
* **Reshuffling:** when `drawPile` empties, the `discardPile` is shuffled back into it.
* **Exhaust:** exhaustible cards (e.g., the Slime status card) go to the `exhaustPile` when
  played and don't return this combat.
* **Damage math:** `floor(baseDamage × vulnerableMultiplier)`, then block absorbs the rest.
* **Targeting:** single-target cards hit the reticle'd enemy; **Cleave** hits **all** enemies.
* **Victory** when every enemy is at 0 HP; **Defeat** when the player hits 0 HP.

### Status Effects
* **Vulnerable:** target takes **+50% damage per stack** (2 stacks = +100%). It **persists**
  (does not tick down each turn) and applies to *future* attacks; the boss's Harden clears it.
* **Strength:** enemy stat that adds flat damage to attacks (boss gains it via Harden).
* **Energy drain:** Goo Spit reduces next turn's energy by 1 (clamped ≥ 0).

## 6. Gold & Shop
* **Gold rewards** (granted on combat victory, including the dev SKIP):
  * per enemy — **Normal 15**, **Elite 30**, **Boss 100** (summed across the encounter).
  * **+15 first-win bonus** the first time each floor is cleared (replays give base gold only).
* **Shop** — sits between Floor 9 and Floor 10. Reached automatically after leaving the Floor-9
  rest site; **LEAVE SHOP** starts Floor 10's combat. Currently a **placeholder** with no
  wares — inventory/economy _(planned)_.

## 7. Rest Site (Floors 4, 9, 14)
* **Rest** — heal **30% of max HP** (always available).
* **Train** — open a **card draft**: pick 1 of **Cleave / Thunder / Barricade** to add a copy
  to your master deck. Duplicates are allowed (drafting the same card twice yields two copies).
  Train is hidden on **Floor 14** (heal only).
* Card **upgrade** at Rest Sites — _(planned)_.

## 8. Cards
**Starter Deck (10 cards):**
* 5× **Strike** — 1 energy, 6 damage
* 4× **Defend** — 1 energy, 5 block
* 1× **Bash** — 2 energy, 8 damage + apply **1 Vulnerable**

**Draftable Cards (Rest Site → Train):**
* **Cleave** — 2 energy, 8 damage to **all** enemies (AOE)
* **Thunder** — 2 energy, 15 damage, +1 energy next turn
* **Barricade** — 1 energy, 8 block; **your block no longer resets at the start of your turn**
  (rest of combat). The Juggernaut enabler.

**Status Card:**
* **Slime** — unplayable; costs 1 energy to remove from hand, then exhausts. Injected into the
  discard pile by the boss's Goo Spit.

_Poison / Venom archetype — (planned)._

## 9. Enemies (Act 1 — Slime Biome)
Intents are telegraphed; each enemy walks a repeating **rotation** by turn number.

| Enemy | Role | HP | Gold | Rotation |
|-------|------|----|-----:|----------|
| **Slime** | Normal | 40 | 15 | Tackle 6 |
| **Red Slime** | Normal | 20 | 15 | Tackle 10 → Defend 3 |
| **Acid Slime** | Elite (F5) | 60 | 30 | Tackle 10 → Defend 15 · drops Vampire Tooth |
| **Spiked Slime** | Elite (F11) | 80 | 30 | Tackle 8 → Spike (5 dmg + 10 block) · drops Mysterious Amber |
| **Slime King** | Boss (F15) | 160 | 100 | Tackle 12 → Goo Spit ×2 → Harden (15 block + 2 Strength, clears debuffs) |

**Intent types:** Tackle (damage), Defend (block), Spike (damage + block), Goo Spit (inject
Slime status cards + drain energy), Harden (block + Strength + cleanse own debuffs).

## 10. Relics
Passive modifiers. **Every relic the player owns is active** — there is no equip/unequip.
The relic bar (bottom-right) shows all owned relic icons; tapping opens the inventory and
holding an icon shows its description. Effects apply the moment a relic is obtained.

* **Vampire Tooth** (Acid Slime, F5) — 50% chance to heal 2 HP when you play an Attack card.
* **Mysterious Amber** (Spiked Slime, F11) — Gain **6 Block at the start of combat**, and
  **5 Block at the start of every 3rd turn**. Anti-abuse: the start-of-combat block only
  applies if you already *owned* Amber when the fight began; earning it **mid-combat** instead
  starts a **3-turn countdown** before the +6 lands.

**Drop rules:** each relic only drops from its specific elite, and currently drops at **100%**.
Newly earned relics are immediately active; duplicates are kept in the inventory (dedicated
upgrade behavior is _planned_).

## 11. Presentation / Animations
* **Turn banners** — "Player Turn" / "Enemy Turn" between phases.
* **Combat VFX** — frame-by-frame sprite animations: `basic_attack_animation` (hits),
  `heal_debuff_animation2` (heal/debuff), and a `goo_spit_animation` projectile that flies
  from the boss to the player on Goo Spit.
* **Card animations** — deal-in, flip, and play-out; relic reveal banner.

## 12. Not Yet Implemented (Roadmap)
* Branching **Map** screen; **Shop** wares/economy (the shop screen exists as a placeholder).
* **Acts 2 & 3** and their bosses.
* **Card upgrades** at Rest Sites; **relic duplicate** upgrades.
* **Poison** archetype and synergy relics.
* **Ascension** difficulty ladder and the **global leaderboard**.
