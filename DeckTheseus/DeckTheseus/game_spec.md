# Deck of Theseus — Design Document (Current Build)

> Describes the game **as currently implemented**. `_(planned)_` marks the long-term vision.
> The shipped game is a native **SwiftUI** app (the original HTML5-canvas concept was dropped).
> It fuses Slay-the-Spire deckbuilding with an *An Average Campaign*-style RPG stat/gear layer.

## 1. Architecture & Visual Style
* **Genre:** solo Roguelike Deckbuilder + light RPG (stats, equipment).
* **Platform:** native **SwiftUI** (iOS + macOS). `@Observable` drives all state
  (`GameEngine`, `Player`, `Enemy`, `DeckManager`).
* **Visual Style:** hand-authored **pixel-art PNGs** trimmed at render time by `CroppedSprite`.
  Its crop box is exactly content-sized and **centred**, so art that isn't centred in its
  canvas renders wrong: relic icons pass `clipToContent: false` to avoid being shaved, and
  enemies pass a measured `contentOffsetY` so every sprite stands on the same ground line
  regardless of how tall its art is (the Spiked Slime's spikes make it taller, which
  otherwise floated it above the other slimes).
  Font: **VT323**, registered at runtime.
* **Arena background:** `fight_background` (1536×864, 14 colours, no anti-aliasing — pixel art
  drawn on a large canvas, so `interpolation(.none)` is still correct). It is drawn `.fill`, then
  covered by a **flat 34% black scrim plus a radial vignette**. The art is bright enough to
  swallow the sprites, intent icons and HUD text, and one layer over the background fixes that
  without touching a single UI element — per-element shadows would mean blurred halos against
  hard pixel edges, in dozens of places.
* **Key files:** `GameEngine.swift` (state + logic), `ContentView.swift` (all UI),
  `Dialogue.swift` (story scenes), `AudioManager.swift` (music + SFX),
  `SaveGame.swift` (run persistence), `DeckTheseusApp.swift` (entry + font).

## 2. Core State
* **Player:** `currentHp`; `maxHp` is **computed** = `baseMaxHp (80)` + effective CON. Energy
  `maxEnergy (3)` (+1 per Slime Core relic → `effectiveMaxEnergy`); `currentBlock`; `gold`
  (starts 0). Stat allocations, equipped gear, and equipment inventory all live here.
* **Deck:** `masterDeck`, `drawPile`, `discardPile`, `exhaustPile`, `hand`.
* **Relics:** `playerRelics` — **all owned relics are always active**; duplicates stack.
* **Progression:** `currentAct`, `currentFloor`, `clearedFloors`. `damageTakenThisCombat`
  tracks the Clean Fight bonus. `runId` bumps on every `startGame()`, which is what tells the
  view a new run began (and to replay the opening).

## 3. Combat Screen & Interaction
* **Top-left HUD:** Act-Floor, Turn, **gold** (coin + amount), owned **relic icons** (hover/hold
  for name + description), and a **STATS (N)** button (N = unspent stat points).
* **Fighting-game HUD.** Every combatant's name plate, **numeric HP bar** (`cur/max`), **shield**
  (block) and status badges sit in a fixed slot along the top of the screen — the player on the
  **left**, enemies stacked downward on the **right** — not hanging off the sprite. Player bar
  and enemy bars mirror each other, so each bar hugs its own screen edge with the status badges
  trailing toward the middle. This is what frees the sprites to stand on the painted floor, and
  it's the only way three enemies fit: the right ledge is ~275pt on a Mac window, which three
  sprite-attached bars overrun twice over.
  * The **player's** bar is the last row of the top-left HUD stack, so it always clears the gold
    row however many relics have widened it — nothing to measure by hand. Its badges may wrap to
    a second line (nothing sits below it). **Enemy** badges stay on one line so the stacked rows
    keep a fixed height; a heavily statused fight can't grow the band down over the sprites.
  * Bars are **slim** (`0.32 ×` the heart metric). At the old sprite-attached thickness three
    stacked rows formed a solid block that crowded down onto the enemies.
  * Badges render at **0.82×** the sprite-attached size: at full size a fully statused player and
    a fully statused enemy reach far enough across the top to meet in the middle.
  * HUD status bubbles drop **below** the badge (`tooltipBelow`) — docked at the top of the
    screen there is no room above.
* **Pairing a bar with a body — by selection.** Ten of the run's fifteen fights field two or
  three *identically named* enemies ("Slime · Slime · Slime"), so with the bars docked at the top
  a name tag alone can't say which bar is whose. **Tap an enemy sprite** (not its bar) and that
  enemy glows gold *and* its bar, border and name plate go gold together; every other bar stays
  plain. Bar order also always matches sprite order left-to-right. An earlier build gave each
  enemy a persistent identity colour on both its bar and a stripe at its feet — replaced by this,
  which keeps the arena clean at the cost of showing the link only for the selected enemy.
* **Standing on the floor.** `ArenaGeometry` runs the same `contentMode: .fill` transform the
  background image does, converting the art's own pixel coordinates to screen points. The ledge
  the combatants stand on is a *measured constant off the art* (`floorArtY = 538`), not a screen
  fraction — the same floor sits at 0.62 of the height in a Mac window and 0.65 on a phone in
  landscape, so a hardcoded fraction drifts. Both sides are positioned by their feet. Ledge spans
  are also clamped to the **safe area**: the root view is `ignoresSafeArea`, which is right for
  the art (it should fill the window) but put the far enemy under the **Dynamic Island** in
  landscape — so combatants and the enemy bars are inset by `geo.safeAreaInsets`. On an iPhone
  that costs the right ledge ~58pt, which the fit-scale then absorbs.
* **The enemy line is fitted to the stone.** Its natural width is measured, then scaled to the
  *visible* ledge. A fixed "shrink when crowded" rule can't work: a squarer window scales the art
  up to cover the height and crops far more off the sides, leaving an iPad ~230pt of ledge while
  its sprites are simultaneously *larger* (they key off `min(w,h)`) — the same trio overflows
  there and leaves room to spare on a wide Mac.
* **Enemy intent** — a small icon riding **above** each living enemy's own head showing what's
  coming. Above rather than beside is what keeps it out of the *horizontal* budget: a badge is
  wider than a small slime, so on a ledge this narrow a side-mounted one reached straight over
  its neighbour. Icon and number sit **side by side**, not stacked — floating above the sprite a
  tall badge runs into the HUD bars, and a phone leaves only ~30pt of clear air over a head.
  It is lifted by a **fixed `0.60 ×` offset**, not an alignment guide: `overlay(alignment:)`
  silently ignores custom alignment guides, which left the badge sitting on the sprite's face.
  It's deliberately **coarse**: `EnemyIntent.Category` (attack / defend / debuff /
  attack+defend / attack+debuff / defend+buff) picks the icon, title and one-line blurb, so
  the player learns *that* a debuff is coming, never which one. **Only attacks show a
  number**, and that number is the damage that will actually land — after the enemy's own
  Strength and Weak (a Weakened 10 reads as **8**), via the same `StatusEffects.damageDealt`
  combat uses, so the telegraph can't lie. Hold or hover for the blurb; the bubble floats
  *above* the icon, lifted fully clear of the badge, and the whole enemy cluster is raised to
  **zIndex 800** while it shows — the HUD bars (690) and the top-left block (700) are both drawn
  after the arena and would otherwise paint over it. It is an **overlay**, anchored to the
  sprite's leading edge — overlays don't take part in layout, so the sprites stay evenly spaced
  along the ledge whatever the intent is.
* **Target marking** — the selected enemy's **sprite glows gold** and its HUD bar, border and
  name plate go gold with it; unselected enemies and bars stay plain. Tap a **sprite** to
  retarget (bars are not tap targets); an AOE card being dragged marks *all* enemies. (A
  floating ▼ used to do this, but once the intent badge moved above the head the two collided —
  a phone has only ~30pt of air over an enemy to share.)
* **Floating combat text:** damage numbers, gold **CRIT!**, blue **DODGE**, green **GUARD**,
  purple **poison**, green **heal**, brown **THORNS** — so stat rolls are visible.
  * It must be attached as an **`.overlay`, never as a sibling in the sprite's stack.** A
    `CombatFlash` is never cleared once set — only its opacity animates away — so as a sibling
    its invisible `Text` keeps its width forever. An enemy that had dodged ("DODGE" ≈ 85pt) or
    critted ("CRIT!" ≈ 110pt) stayed permanently wider than its own ~79pt sprite, which spread
    the enemy line unevenly, shoved the far enemy off the ledge, and changed the arena depending
    on *which* enemy you had hit and in what order.
* **Playing cards — drag-to-play, queued:**
  * **Tap** a card to select it (multi-select; selected cards reserve their energy in the
    HUD counter). **Drag** a card up into the middle and release to play it.
  * A played card **leaves the hand instantly** (energy spent) and is **queued**; the queue
    resolves plays one at a time — each parks in the center, holds, fades, then its effect +
    animation fire. So you can fire several cards without waiting on animations.
  * Each card hits the enemy you aimed at **when you played it** — unless that enemy has since
    died to an earlier card in the same queue, in which case it follows the reticle to a living
    one (`liveTarget(aimedAt:)`). Aim worth preserving is aim at something alive: queuing three
    Strikes into an enemy the second one kills used to waste the third on the corpse, silently,
    along with its energy. A card that kills its *own* target still doesn't debuff the body.
    Hold a card for its tooltip.
  * **`HandCardView` owns its own drag offset**, and this matters for frame rate. The offset was
    once `@State` on `ContentView`, rewritten on every gesture callback — so each frame of every
    drag invalidated the whole ~990-line combat body (background, HUD, sprites, bars, the rest of
    the hand). Nothing outside the card ever read it. The parent is told only when a drag starts
    and ends. **Any per-frame value belongs in the smallest view that reads it** — that body is
    large enough that re-evaluating it at 60–120 Hz is the one reliable way to make this game
    stutter.
  * **Tooltips show the numbers you'll actually get.** A card's rules text is built from
    clauses with the number split out, so a value your statuses have moved is recomputed and
    coloured — **red when a debuff shrank it** (Frail 1 turns Defend's "Gain 5 block" into a
    red **4**), green when Strength grew it. The same `StatusEffects.damageDealt` /
    `blockGained` helpers drive both the tooltip and combat, so the two can't drift.
* **END TURN** runs the enemy phase (disabled while the queue is draining).
* **Settings** (gear, top-right — hidden on the title page and during dialogue so it never
  collides with their own controls):
  * **Music** — a drag bar with a speaker glyph stepping three waves → two → one → slash as it
    falls; tapping the speaker mutes/restores. 0 is silent regardless of device volume, and the
    track keeps running silently so raising the bar resumes it instantly. Looping music only,
    never SFX.
  * **Sound Effects** — a plain on/off.
  * **Developer** — Go to Stage (floor picker), Win Fight, **Die Now** (0 HP, to exercise the
    revive offer → defeat path) and **Remove Gems** (empties the wallet, to test the
    "can't afford → Buy Gems" branch).
  * **Save & Quit to Title**, and Resume.
  * Both audio settings apply live and persist between launches.

## 3b. Title Page
The game opens on a **title page**, not a fight — it owns the whole screen, and nothing of a
run (cards, music) runs behind it. Menu: **Start Run / New Run**, **Continue Run** (only when a
resumable run is saved), and **Quit Game** (macOS, quits the app). The background is
`art_title_background` **if that asset exists**; otherwise the page stands on a plain dark ground
of its own — a vertical wash from `#171233` into `bgDeep` with a faint gold bloom behind the
title. Adding the asset switches it over automatically and re-enables the darkening scrim that
keeps the menu legible over artwork (the plain ground doesn't need it, and it would crush the
gradient). Nothing here is labelled as a placeholder — this is shippable as it stands.

### Developer tools — hidden, and DEBUG only
Two independent locks, because they answer different questions:
* **`#if DEBUG`** around the floor picker, "Win Fight", "Die Now", "Remove Gems" and the engine's
  `devJumpToFloor` / `devJumpToShop` / `devKillPlayer` / `devWinCombat` — so none of it can exist
  in a Release build. Verified by symbol table: in a Release binary `restHealAndAdvance` and
  `liveTarget` resolve while every `dev*` function is absent.
* **`DevTools.enabled`** (top of `ContentView.swift`, default `false`) hides them in **Debug**
  builds too — which is what Xcode runs, so the compile-time guard alone still left the panel on
  screen during ordinary play-testing. Flip that one line to `true` to get the floor picker back.

Kept rather than deleted: these are how the game gets tested, and a switch is more reliable than
remembering to strip code before each build.

The dialogue **SKIP** button is *not* a dev tool — it's for players replaying the run — and stays.
`DialogueBackdropView` no longer draws a missing asset's name on screen; it fails to plain black,
so a failed load can't put developer text in front of a player.

### Credits
`Credits.swift` holds the attribution list and the screen that shows it, reachable from the
**title menu** and from **Settings** mid-run (so attribution isn't behind quitting). Entries carry
Title / Author / Source / License **plus a link to the licence itself and a note of any change
made** — Creative Commons asks for all of it, and Freesound's ready-made string omits the licence
link. `sfx_bossloop` is marked "converted to .m4a" for that reason. **Only assets that actually
ship are listed.**

**Two tracks are CC BY-NC 4.0 — NonCommercial — and that is a considered decision, not an
oversight:** `sfx_introloop` (title page) and `sfx_restloop` (rest sites, the same Freesound
upload once mis-filed as "sfx_shoploop"). NC turns on the *use*, not the user: "not primarily
intended for or directed toward commercial advantage or monetary compensation." Gems run against
RevenueCat's **Test Store**, so no money moves and nothing is sold; as a portfolio / hackathon
build this reads as non-commercial. Two changes would break that, and both are one step away:
* **Swapping `GemStore.apiKey` from the `test_` key to a production one.** Purchases become real
  and the argument is gone. Re-check the music at the same time — now *both* loops, not one.
* **Prize money.** A submission competing for a cash prize sits nearer "monetary compensation"
  than a portfolio piece does. Grey rather than settled, but it's the weakest point.

Replacing either is cheap — one file in `Sounds/`, one entry in `Credits.audio`.

`sfx_block`, `sfx_heal`, `sfx_win` and `sfx_start` are **CC0** and need no credit; they're listed
anyway as a courtesy. `sfx_lose` is **CC BY 3.0**, a different licence from the 4.0 used
elsewhere — keep its deed URL distinct. `sfx_bossloop` and `sfx_fightloop` were converted to
`.m4a`, which CC BY counts as a change, so both say so.

**All 12 files in `Sounds/` are traced** — 5 × CC BY 4.0, 1 × CC BY 3.0, 2 × CC BY-NC 4.0,
4 × CC0. Anything added later needs its licence recorded at download time; a sound whose licence
can't be named can't be complied with, whatever it turns out to be.

### Saving
* **Exit** (victory/defeat screens) and **Save & Quit** (settings) return here and **save the
  run** — floor, HP, gold, deck, relics, stats and equipment — so *Continue Run* resumes it
  **even after quitting the app**. The run is also checkpointed at every floor.
* **A defeat ends the run.** The save is cleared the moment the player dies, so no *Continue
  Run* is offered for a lost run however they leave the screen.
* Saves are JSON in `UserDefaults` (~0.7KB). Cards and relics are stored **by name** and rebuilt
  from their factories, so balance changes apply to saved runs instead of resurrecting stale
  numbers; equipment is stored in full, since its stat rolls are generated per drop.
* Combat is never resumed mid-fight: a run saved anywhere other than a result screen re-enters
  that floor from its start.
* *New Run* clears the save and replays the opening; *Continue Run* does not replay it.

The title plays `sfx_introloop`; **Start Run / New Run / Continue Run** fire `sfx_start`.

## 4. Result / Progression Screens
* **Victory:** Act-Floor + "VICTORY", hero centered, rewards bar (gold, **Clean Fight** bonus,
  `+N Stat Points`). Buttons: **Exit** (back to the title page, run kept) and **Next** → opens the
  full **stats page**, whose confirm button reads **"Next Stage ▶"** (commits your point
  allocation and advances). So every advance routes through the allocation screen.
* **Defeat:** red "DEFEAT", empty rewards bar. **Try Again** = **full run restart** from Act 1
  Floor 1 (HP/gold/relics/gear/deck all wiped — Slay-the-Spire style); **Exit** → title page,
  with the save cleared (a lost run can't be continued).
* **Clean Fight bonus (+15 gold):** awarded on any floor cleared having lost **at most a
  quarter of max HP** (20 at the base 80, and it scales with CON). Replaces the old one-time
  first-clear bonus, which made no sense on a linear run you never revisit.
* **Ending:** clearing Floor 18 ends the story — "YOUR KINGDOM IS AVENGED" + THE END, with
  **Play Again** returning to the title page.
* **Rest Site / Card Draft / Shop / Act Complete / relic + equipment reveal banners / combo
  banner** — see below.

## 4b. Revive (Gems)
When HP hits 0 the run doesn't end immediately: a **REVIVE** prompt appears — a title, one
narrative nudge ("Get up. The kingdom is still waiting."), the cost and your balance, and
either **Revive** (enough Gems) or **Buy Gems** (not enough), alongside **No Thanks**.

* **Once per run, ever.** `reviveUsed` lives on the engine, resets only in `startGame()`, and
  is **persisted in the save** — Save & Quit → Continue can't hand it back. If it's already
  spent, the prompt never appears and HP-0 goes straight to defeat.
* **Reward earned →** back to **40% of max HP** (32 at base 80, scales with CON), debuffs
  cleared, Block reset, and the **interrupted enemy turn ends there** — enemies still queued
  to act don't get to, so the revive can't be spent and immediately wasted. A fresh hand is
  dealt and it's your turn.
* **Declined →** normal defeat. Declining does *not* spend the revive or any Gems.
* Because the prompt is its own `GameState` (`.reviveOffer`), the defeat path — lose stinger,
  the 3-line defeat card, clearing the save — only fires once the offer is turned down.
* **Gems** (`GemStore.swift`) are the premium currency: bought with real money, and unlike
  Gold they belong to the **player, not the run** — stored in `UserDefaults`, untouched by
  `startGame()` and absent from the run save, so they survive death, new runs and relaunches.
  A revive costs `GemStore.reviveCost` (10).
* **Gem bar** — a pill (gem icon, balance, and a **+** that opens the shop) sits top-right
  **everywhere**, including the title page, so Gems can be bought without having to die first.
  In-run the Settings gear sits beside it. Both hide behind a dialogue scene, the gem shop and
  the settings panel, which own the screen while they're up.
* **Purchasing** goes through `GemStore.purchase(_:)`, the single storefront touchpoint.
  `GemStore.packs` lists the buyable bundles (`earn_15_gems` → 15 Gems); adding a pack is one
  array entry. The RevenueCat implementation (Offering `"default"`, matched by product id) is
  live: the **RevenueCat SPM package (purchases-ios 5.87.1) is installed**, and
  `Purchases.configure(withAPIKey:)` runs at launch in `DeckTheseusApp.init()` using
  `GemStore.apiKey`. That key is RevenueCat's **Test Store** key (`test_` prefix), so
  purchases are simulated and never charge anyone — a real App Store build would need the
  `appl_` key instead. The `#if canImport(RevenueCat)` guards remain so the project still
  builds if the package is ever removed.

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
| 16 | **Rest** | heal / draft — the same two choices as every rest (Shop immediately after) |
| 17 | Combat | 3 Red Slimes (final gauntlet) |
| 18 | **Boss** | Slime King |
| 19 | Story ends | "YOUR KINGDOM IS AVENGED" |

**Two shops**, listed in `GameEngine.shopFloors` — one before Floor 11, one before Floor 17, each
directly after a rest so the beat reads the same both times: recover, spend, fight. The second
exists because gold outran its uses in the back half: by Floor 16 a run earns 30–50 a fight with
nothing to buy and unsold elite drops piling up. It sits before 17 rather than before the boss so
a purchase has two fights to matter in — a card bought immediately before the boss might never be
drawn.

Floor 16 used to be heal-only; it now offers the draft as well, but as the same **choice** every
other rest site presents. Granting both at once was tried and pulled — a free heal *and* a free
card immediately before the final stretch is a power spike, not a send-off.

Progression is **linear**; a branching **Map** and **Acts 2–3** are _(planned)_. More enemy
variety / a second biome is the intended cure for repetition _(planned)_.

## 6. Combat Mechanics
* **Turn start:** draw 5; energy refreshed to `effectiveMaxEnergy` (± next-turn modifiers);
  chance for +1 energy (Energy Gain stat).
* **Block** absorbs damage like temp HP and **resets at the start of each side's own turn**
  (after it has absorbed the opponent's hits). **Barricade** stops the player's block resetting
  for that combat.
* **Both sides run the same stat system.** A player attack rolls the player's Crit, then the
  **enemy's Dodge** (negates outright — no Thorns either) and **Guard**, then Vulnerable, then
  its block. An enemy attack rolls **that enemy's Crit**, then the player's Dodge → Guard →
  block → HP. **Each enemy attacks as its own hit**, so multi-enemy turns roll separately.
  Enemy stat spreads express identity — see §13.
* **Reshuffle** discard→draw when empty. **Exhaust** cards leave the deck until next combat.

### Status effects — universal
One `StatusEffects` model is shared by the **player and every enemy**: anything that can be
inflicted can be inflicted on either side, and each rule reads identically for both. Timed
statuses lose a stack at the start of their owner's own turn; buffs last the combat.

| Status | Effect | Player gets it from | Enemies get it from |
|--------|--------|---------------------|---------------------|
| **Vulnerable** | takes +50% damage per stack (no decay) | — | Bash |
| **Poison** | 3 damage at the start of its turn, **bypassing Block**; −1/turn | — | Poison card |
| **Weak** | deals −25% damage; −1/turn | **Slime King** (Goo Spit) | Poison Combo |
| **Frail** | gains −25% Block from every source; −1/turn | **Acid Slime** (Corrode) | Corrode card |
| **Stun** | skips its turn (Poison still bites); −1/turn | — *(held back deliberately: losing a whole turn is too punishing)* | Shield Combo |
| **Strength** | +flat damage dealt (lasts the combat) | — | Harden |
| **Thorns** | whatever attacks it takes that much, **bypassing Block** (lasts the combat); a fully dodged hit never made contact, so it doesn't trigger. The retaliation flashes as **"N THORNS"** in brown — an unexplained 3 HP tick during your own attack reads as nothing happening, which is how a working Thorns looks broken | Spikes card | **Spiked Slime** (innate 3) |

The boss's **Toxic Slam** (`.venom`) is his damage turn and leaves **3 Poison** behind. 3 stacks
is roughly the three turns his rotation takes to come back round, so the pressure is close to
permanent — and because Poison bypasses Block, turtling through his fight stops working. It
raises the fight's floor without raising the number he hits for.

**Harden** (boss) clears Vulnerable / Poison / Weak / Frail from itself; Strength and Thorns
survive, being buffs. Statuses never carry between fights. Badges and hover/hold explanations
render identically for both sides via one `StatusRowView`. *(All still text badges, no sprites.)*

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
* **25 pieces, exactly 5 per slot — 3 Common, 1 Rare, 1 Legendary each.** The even spread is
  deliberate: Legs and Feet used to hold two pieces each against Weapon's four, so those slots
  repeated twice as often. Every slot carrying every tier matters too — a rarity system where the
  weapon slot could never roll high reads as broken rather than unlucky.
* **Rarity (`EquipmentRarity`).** The 25% drop *chance* is unchanged; rarity only weights *what*
  falls out — per item, Common 10 / Rare 4 / Legendary 2, which lands at about **71% / 23% / 6%**.
  Tiers track worth: a Common is one modest stat, a Rare adds a second, a Legendary is a
  three-stat piece with no ordinary equivalent, and in every slot the Legendary out-stats and
  out-sells everything below it. Previously a +2 CON cap and a +4 CON/+2 STR chestplate were
  equally likely, which made good gear feel arbitrary rather than earned.
* **Reading it:** the genre's own shorthand — parchment / **blue** / **orange** — on the item
  name, its border and the drop banner, with a glow and a tier badge on Legendaries only.
  Commons stay unmarked; labelling two thirds of all drops "Common" is noise.
* Rarity is persisted, and saves written before it existed decode as Common.
* **Stat coverage is the other half of that.** CHA appeared on *nothing*, and LCK on two pieces,
  so neither could be built into even by a player who wanted to — which is what made the Merchant
  and Lucky Drop identities feel inert. Both now appear across all three tiers. CHA and LCK gear
  carries a small sell-value premium, since neither raises survivability.

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
| Corrode | Common | 0 | Apply 2 **Frail** (target gains 25% less Block) |
| Spikes | Uncommon | 0 | Gain 3 **Thorns** — attackers take 3 |
| Barricade | Rare | 3 | 8 Block; block no longer resets this combat |
| Catalyst | Rare | 2 | **Double** the enemy's Poison; **Exhaust** |

Bash (2⚡, 8 dmg + 1 Vulnerable) is also offered, so the pool is **10 cards**.

**Status card — Slime:** unplayable; 1⚡ to remove (exhausts). Injected by the boss's Goo Spit
and by the Slime Core relic. **One pool feeds both the Rest draft and the Shop**
(`Card.obtainableCards`): everything except the Strike/Defend starters and the Slime status
card. The draft rolls **3 at random** each visit rather than a fixed trio.

## 10. Relics
All owned relics are active; the top-left HUD shows their icons; **duplicates stack**.
* **Vampire Tooth** (Acid Slime, F5) — on each Attack card, per owned copy: 50% chance to heal
  2 HP (+Lifesteal stats). Two copies = two rolls.
* **Mysterious Amber** (Spiked Slime, F13) — +6 Block at combat start and +5 Block every 3rd
  turn, **per copy** (2 copies = 12 / 10).
* **Slime Core** (Shop) — +1 Max Energy, but start each combat with a Slime
  card mixed into your deck (per copy).

**Drops:** elites drop their relic at 100% on floor clear.

## 11. Shop (after the Floor-10 rest)
* **Cards (5):** 2 Common / 2 Uncommon / 1 Rare from the pool, priced 50 / 60 / 75, **+1 extra
  offer per 20 CHA**. Buying adds the card to your deck and marks it SOLD; hold a card to read it.
* **Relics (2–3):** random from the pool (duplicates buyable), 150–300 gold, with descriptions.
* **CHA discounts every price** (up to 50% off), applied when the stock is rolled.
* **Sell Equipment:** sell spare inventory gear for its sell value.
* **LEAVE SHOP** starts Floor 11.
* _(Cut for now: crafting, merge-equipment, card removal.)_

## 12. Hidden Combos
Undocumented in-game; a center-screen **"✦ COMBO!"** banner fires when conditions are met.
**Repeatable:** triggering a combo *spends* its tally rather than latching it off, so it fires
as often as you can rebuild it — but the cards must be played again each time (otherwise a met
condition would re-fire on every later card). Progress still resets between combats.
* **Poison Combo** — Poison + Catalyst on one enemy in a single turn, *or* 2 Poison + 1 Catalyst
  on one enemy over the fight → that enemy takes **direct damage = its current Poison** and
  gains **Weak**.
* **Shield Combo** — play Fortify + Turtle + Barricade + Defend during one fight → the
  **lowest-HP** enemy takes **direct damage = your current Block**, is **Stunned**, and you
  **gain 8 Block**.

## 12b. Narrative Dialogue
Cookie-Run-Kingdom-style scenes: a portrait to one side, a gold **name pill** above a
translucent box along the bottom, one line at a time, **tap anywhere** to advance (▼ blinks),
**SKIP** top-right. Captions (no speaker) drop the portrait/pill and center their text.
Fully **data-driven** in `Dialogue.swift` — a `DialogueScene` is an array of `DialogueLine`s
looked up by `DialogueTrigger` in `DialogueScript.scenes`; adding beats never touches the renderer.

| Scene | Trigger | Lines |
|-------|---------|------:|
| Opening | run start (before Floor 1) | 4 |
| Acid Slime pre / post | before / after Floor 5 | 2 / 1 |
| Spiked Slime pre / post | before / after Floor 13 | 3 / 1 |
| Slime King pre / epilogue | before / after Floor 18 | 4 / 5 |

* **Post-fight scenes land before the reward banners + VICTORY screen** — a dying taunt after
  a rewards screen reads wrong.
* **Every scene is mandatory.** There is no seen-once tracking anywhere — each scene plays
  every time its trigger fires, on every run, with **SKIP** always available for repeat
  viewings. The opening fires on every `runId` bump — i.e. **Start/New Run** from the title and
  **Try Again** after a defeat — but *not* at app launch (the title comes first) and not on
  *Continue Run*. A black curtain covers the frame between a run starting and its opening
  scene rendering, so the arena never flashes.
* **Death has no dialogue** — it goes straight to the REVIVE prompt, then the DEFEAT screen.
  Basic/Red Slime have no dialogue either. (`DialoguePresentation.autoTimed` still exists for
  future caption-only cards, but nothing uses it.)
* **Backdrops:** `.arena` (battlefield visible + dimmed — the pre/post-fight banter) or
  `.art("name")` (full-screen story art replacing the arena). A **line** can also set one,
  and the change **sticks** until another line changes it, so a scene can cut between images
  mid-dialogue (crossfaded). The **opening** cuts from `art_castle` (the kingdom standing) to
  `art_destroyedcastle` on its second line, which then holds for the knight's lines.
  A named asset that isn't in the catalog yet renders as a labelled black placeholder, so
  dropping artwork in later needs **no code change**.
  The epilogue is still `.arena`; switching it is a one-line change once its art is drawn.
* **Portraits are placeholders** — they reuse the existing combat sprites (knight =
  `player_sprite`); swap for real portrait art without touching anything else.

## 12c. Audio
All sound runs through `AudioManager.swift` (AVFoundation). Files live in `DeckTheseus/Sounds/`
and are bundled automatically; lookup tries .wav/.mp3/.flac at the bundle root or in `Sounds/`,
so formats can be mixed freely. SFX play at 85%; music defaults to 30% and is set by the
player in Settings (persisted in `UserDefaults`, applied live).

**Music** — exactly one looping track at a time, crossfaded (0.45s) and never restarted if
already playing. `syncMusic()` derives it from state:

| Track | When |
|-------|------|
| `sfx_fightloop` | in a normal combat |
| `sfx_bossloop` | elite, mini-boss or boss combat (from `isEliteOrBossEncounter`, derived from the enemies, not hard-coded floors) |
| `sfx_restloop` | rest site, card draft, shop, stats/character screen, victory, act complete |
| `sfx_introloop` | the title page |
| `sfx_openingloop` | the opening story scene |
| *(silence)* | defeat — under the lose stinger |

The title page and the opening set their tracks **directly** (in `syncMusic`'s guard and in
`startRun()` respectively) rather than through `syncMusic()`, which reads the *run's* state — and
during those two the run hasn't begun. Ending the opening hands back to `syncMusic()`, which
crossfades into the first fight.

**Per-track level.** `Music.gain` scales a track against the player's music slider, so one track
can sit lower without the slider lying about what it controls — it multiplies through both
`playMusic` and the slider's `didSet`. `sfx_openingloop` runs at **0.60**: it plays *under*
narration and has to stay beneath the dialogue, unlike a combat loop that owns the screen.

**One-shot SFX**

| Sound | Trigger |
|-------|---------|
| `sfx_attack` | any player damage to an enemy — attack cards, both combos, poison ticks (hooked in `dealDamage`) |
| `sfx_block` | an incoming hit is Guarded or absorbed by Block |
| `sfx_damage` | an incoming hit reaches HP (not when fully blocked) |
| `sfx_heal` | player **or** enemy gains Block, and any heal (Vampire Tooth, rest, FTH combat-end) |
| `sfx_cardflip` | each card as it flips face-up while a hand is dealt — one per card, on its own stagger |
| `sfx_win` / `sfx_lose` | combat resolves to victory / defeat |
| `sfx_start` | "Next Stage ▶", and Start / New / Continue Run on the title |

Repeats of the same sound inside 70ms are suppressed, so an AOE hitting three enemies reads as
one impact instead of three stacked copies. `play(_:debounced:)` opts out of that — the card
flip uses it so every dealt card is heard, however tight the stagger.

The two long loops are **AAC/m4a** (160 kbps, converted from 31/30MB WAVs — 3.5MB combined,
identical durations), keeping the whole bundle ~15MB.

Playback is **session-tokened**: each appearing view claims playback via `beginSession()`, and
`shutdown(token:)` is ignored unless it is the current owner — Xcode's Canvas tears an old view
down *after* its replacement appears, and without this the stale teardown silenced the live one.
For the same reason `playMusic` only treats a repeat request as a no-op while the track is
*genuinely still playing*, so a stale `currentMusic` can't leave the game permanently silent.

## 13. Enemies (Act 1)
Telegraphed intents; each walks a repeating rotation by turn.

Each enemy carries a `stats` spread feeding the same `DerivedStats.derive()` the player uses,
so they crit, dodge and guard by identical formulas (everyone has a 5% dodge / 5% crit floor):

| Enemy | Stats | Dodge | Guard | Crit | Identity |
|-------|-------|------:|------:|-----:|----------|
| Slime | — | 5.0% | 0% | 5.0% | baseline; teaches the basics |
| Red Slime | DEX 20, LCK 10 | 8.2% | 0% | 11.0% | quick and reckless — slips hits, crits often |
| Acid Slime | STR 18, CON 20, DEX 8 | 6.5% | 6.0% | 8.5% | elite, sturdier all round |
| Spiked Slime | STR 45, CON 30, DEX 4 | 5.8% | 12.5% | 11.2% | armoured — guards a lot, rarely dodges |
| Giant Slime | STR 30, CON 55 | 5.0% | 9.2% | 8.8% | a wall — soaks hits, too big to dodge |
| Slime King | STR 45, DEX 22, CON 45, LCK 20 | 8.5% | 12.5% | 19.9% | strong at everything |

| Enemy | Role | HP | Gold | Rotation |
|-------|------|---:|-----:|----------|
| Slime | Normal | 30 | 15 | Tackle 5 |
| Red Slime | Normal | 20 | 15 | Tackle 8 → Defend 3 |
| Acid Slime | Elite (F5) | 55 | 30 | **Corrode (9 dmg + 2 Frail)** → Defend 15 · drops Vampire Tooth |
| Spiked Slime | Elite (F13) | 72 | 30 | Tackle 8 → Spike (5 dmg + 10 block) · **innate Thorns 3** · drops Mysterious Amber |
| Giant Slime | Mini-boss (F9) | 100 | 50 | Tackle 12 → Harden (10 block + 1 Str) · **2 guaranteed gear** · placeholder art |
| Slime King | Boss (F18) | 160 | 100 | **Toxic Slam (12 dmg + 3 Poison)** → **Goo Spit ×2 (+2 Weak, −1 energy)** → Harden (15 block + 2 Str, clears debuffs) |

## 14. Presentation
Turn banners; frame-by-frame VFX (`basic_attack_animation`, `heal_debuff_animation2`,
`goo_spit_animation`); card deal/flip/play; relic + equipment reveal banners; combo banner;
title page; settings panel.

## 15. Not Yet Implemented (Roadmap)
* Branching **Map**; **Acts 2 & 3** and a **second biome / new enemy types**.
* Real **art** for: the **title background** (`art_title_background`), the **epilogue**
  backdrop, Giant Slime, Poison/Weak/Stun status icons, and dialogue **portraits** (which
  currently reuse combat sprites). Each is a named placeholder that swaps in with no code change.
* **Saving mid-combat** — a run is only checkpointed at floor boundaries and result screens.
* **Classes** (base stats + starting decks), **subclasses via encounters**, an **encounter**
  framework (AAC-style 3-choice nodes).
* **Ascension** difficulty ladder; **global leaderboard**; card **upgrades**.
