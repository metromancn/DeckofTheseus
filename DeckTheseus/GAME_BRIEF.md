# Deck of Theseus — game brief

Context for writing about the game: what it is, what's in it, and which decisions are worth
talking about. Paste this (with `DeckTheseus/game_spec.md` and a few screenshots) into any
conversation that needs to understand the project without reading the code.

Facts here are checked against the source. Tone is deliberately flat — reshape it freely.

---

## What it is

A roguelike deckbuilder with light RPG systems, built natively in SwiftUI for iPhone and Mac.
You climb a run of floors with a deck of cards, an energy budget per turn, and a character sheet
that grows — spending stat points, equipping gear and collecting relics between fights.

Pixel art throughout, VT323 for type, landscape only on phone.

## The shape of a run

**Act 1 — the Slime Biome.** 18 floors: 15 fights plus rest sites, a card draft and a shop.

| | |
|---|---|
| Normal enemies | Slime, Red Slime |
| Elites | Acid Slime (floor 5), Spiked Slime (floor 13) |
| Mini-boss | Giant Slime (floor 9) |
| Boss | Slime King (floor 18) |

Fights are one to three enemies. Win, take gold and a reward, spend stat points, move on. Die and
the run ends — unless you revive.

## What's in it

**Cards.** A starting deck plus 10 unlockable cards (Bash, Cleave, Thunder, Barricade, Poison,
Fortify, Turtle, Catalyst, Corrode, Spikes), earned from rest-site drafts or bought in the shop.
Played by dragging up into the arena; plays queue so you can fire several without waiting on
animations. Hidden card combos fire when the right sequence lands in a turn.

**Seven stats, each with a real identity.** STR and DEX were the only ones worth taking early on,
so every stat got a job: INT grants extra max energy at thresholds, FTH drives healing and
lifesteal, CON is max HP, LCK affects drops and gold, CHA discounts the shop and widens its stock.
Stats feed derived values — crit chance, dodge, guard — that resolve visibly in combat as floating
CRIT / DODGE / GUARD text.

**A universal status system.** Vulnerable, Weak, Frail, Poison, Stun, Strength and Thorns are one
model shared by the player and every enemy — the same code resolves both directions, so anything
the player can suffer, an enemy can too, and vice versa. Enemies also carry the same stat spreads,
so they dodge, guard and crit exactly like you do.

**Enemy intent.** Each enemy telegraphs its next move with an icon above its head. Deliberately
coarse: you learn *that* a debuff is coming, never which one. Attacks show a number, and that
number is the damage that will actually land — computed through the same code combat uses, after
the enemy's own Strength and Weak — so the telegraph cannot lie to you.

**Relics and equipment.** Three relics (Vampire Tooth — lifesteal on attacks; Mysterious Amber —
periodic Block; Slime Core — shuffles a Slime card into every combat), all always active,
duplicates stack. Equipment slots feed the stat sheet.

**A story layer.** A scripted dialogue system with speaker portraits, per-line full-screen story
backdrops, and scenes that trigger at fixed points — an opening before the first fight, banter
before certain enemies, an epilogue that plays before the victory screen. Every scene is
mandatory and plays on every run.

**Audio.** Five looping tracks that follow game state (title, opening, normal combat, boss,
rest) plus one-shot effects. Crossfaded, never restarted mid-fight, with a music slider and an
SFX toggle in settings.

**Persistence.** Runs survive quitting the app entirely — floor, HP, deck, relics, stats,
equipment and whether the revive has been used.

## RevenueCat integration

**Gems** are a premium currency, bought with real money and owned by the *player* rather than the
run: the balance survives death, new runs and app launches, unlike the gold you earn inside a run.

- RevenueCat SDK 5.87.1 via SPM, currently pointed at the **Test Store**
- One offering, one consumable pack (15 Gems)
- A persistent gem bar with a **+** button is reachable everywhere, including the title screen —
  you never have to die to find the shop

**What Gems buy: a revive.** When HP hits zero, the game offers to bring you back for 10 Gems —
40% of max HP, debuffs cleared, Block reset. **Once per run.**

The monetisation stance is deliberate and worth stating plainly: the revive is optional, capped at
one per run, and the game is completable without ever buying anything. It sells a second chance,
not power — no stat boosts, no better cards, nothing that makes a paying run stronger than a free
one. The cap is what keeps it from becoming a way to buy your way through a bad run.

Under the hood the purchase path is a single function returning purchased / cancelled / failed;
everything else in the game just asks for a pack. Adding a second pack is one array entry.

## Technical decisions worth mentioning

**Combatants stand on the painted floor.** The arena background is drawn `.fill`, so how the art
maps to the screen changes with window shape — the same stone floor sits at 0.62 of the height on
a Mac and 0.65 on a phone. Rather than hardcode a screen fraction, `ArenaGeometry` runs the same
transform the image does and converts the art's own pixel coordinates to screen points. The floor
line is a constant measured off the artwork. The enemy line is then *fitted* to the visible ledge,
because a squarer window crops more off the sides while simultaneously drawing bigger sprites — a
fixed "shrink when crowded" rule overflowed on iPad and wasted room on a wide Mac.

**A fighting-game HUD.** Health bars are docked along the top — player left, enemies stacked
right — instead of hanging off each sprite. Partly style, mostly arithmetic: three sprite-attached
bars need about 450pt of a ledge that's only 275pt wide. Detaching them is what let the sprites
come down onto the floor at all.

**Audio latency.** Card-flip sounds were audibly late against the deal animation. Building an
`AVAudioPlayer` at fire time costs file I/O and decoder setup — measured at 224ms. Pre-warmed
voice pools brought it to 14ms, with several voices per sound so a five-card deal overlaps
cleanly.

**Per-frame state lives in the smallest view that reads it.** The card drag offset was state on
the root view, rewritten on every gesture callback — so each frame of every drag re-evaluated the
entire ~990-line combat body. It now lives on the card. A drag redraws one card.

**Verified by measurement, not by eye.** Layout geometry is asserted across four device shapes
before shipping, and combat rules are tested against the real engine — Thorns retaliation, for
instance, over 200 simulated attacks.

## State

Builds clean with zero warnings on macOS and iOS. Landscape-locked on phone, with combatants and
HUD inset out of the Dynamic Island's column.

All 13 bundled sounds are licence-traced and credited in-app on a Credits screen reachable from
the title menu and from Settings mid-run. Two tracks are CC BY-NC; the build is non-commercial
(Test Store, no real transactions).

**Placeholder art still outstanding:** title background, epilogue backdrop, a dedicated Giant
Slime sprite, dialogue portraits, and icons for Poison / Weak / Stun.
