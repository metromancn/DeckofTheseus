import Foundation
import Observation
import CoreGraphics

// MARK: - Card Types

enum CardType: String {
    case attack
    case skill
    case status
}

// MARK: - Game State

enum GameState: String {
    case playing
    case victory
    case defeat
    case reviveOffer   // HP hit 0 and a revive is still available — offer it before defeat
    case restSite      // Rest floors — choose Heal or Draft
    case drafting      // Rest floors — pick a card to add to the deck
    case shop          // Between Floor 9 and Floor 10
    case actComplete   // "To Be Continued" placeholder between acts
}

// MARK: - Floor Nodes

enum FloorNode {
    case combat   // standard enemy
    case elite    // harder enemy
    case rest     // rest site
    case boss     // boss encounter
}

// MARK: - Turn / VFX State

enum TurnBanner {
    case none
    case playerTurn
    case enemyTurn
}

enum SpriteVFX {
    case none
    case attack       // basic_attack_animation
    case healDebuff   // heal_debuff_animation2
}

// MARK: - Statuses
//
// One universal set, shared by the player and every enemy. Anything that can be inflicted
// can be inflicted on either side, and every rule below reads the same for both — so a
// card that applies Frail and an enemy move that applies Frail mean exactly the same thing.

struct StatusEffects {
    var vulnerable = 0   // takes +50% damage per stack; lasts until cleared
    var weak = 0         // deals -25% damage; -1 at the start of its own turn
    var frail = 0        // gains -25% Block; -1 at the start of its own turn
    var poison = 0       // 3 damage at the start of its turn (bypasses Block); -1 per turn
    var stun = 0         // skips its turn; -1 per turn
    var strength = 0     // +flat damage dealt (lasts the combat)
    var thorns = 0       // attackers take this much, bypassing Block (lasts the combat)

    var hasAny: Bool {
        vulnerable > 0 || weak > 0 || frail > 0 || poison > 0 || stun > 0 || thorns > 0
    }

    /// +50% damage taken per Vulnerable stack.
    var vulnerableMultiplier: Double { 1.0 + 0.5 * Double(max(0, vulnerable)) }
    /// -25% damage dealt while Weak.
    var weakMultiplier: Double { weak > 0 ? 0.75 : 1.0 }
    /// Damage this combatant actually deals from a base value: Strength adds, Weak scales.
    func damageDealt(_ base: Int) -> Int {
        Int((Double(base + strength) * weakMultiplier).rounded())
    }

    /// Block actually gained from a source of `amount`, after Frail.
    func blockGained(_ amount: Int) -> Int {
        frail > 0 ? Int((Double(amount) * 0.75).rounded()) : amount
    }

    /// Timed statuses lose a stack at the start of that combatant's own turn. Poison ticks
    /// its own damage separately; Strength and Thorns are buffs and don't decay.
    mutating func tickDurations() {
        if weak > 0 { weak -= 1 }
        if frail > 0 { frail -= 1 }
        if stun > 0 { stun -= 1 }
    }

    /// Wiped by the boss's Harden. Buffs (Strength, Thorns) survive.
    mutating func clearDebuffs() {
        vulnerable = 0; weak = 0; frail = 0; poison = 0
    }
}

// MARK: - Relics

struct Relic: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let iconName: String
    /// Where the art actually sits inside its 64px canvas, so every relic icon renders at
    /// the same on-screen size (see `CroppedSprite`). Measured per asset.
    let iconContentW: CGFloat
    let iconContentH: CGFloat

    static var vampireTooth: Relic {
        Relic(name: "Vampire Tooth",
              description: "50% chance to heal 2 HP when you play an Attack card.",
              iconName: "relic_vampire_tooth",
              iconContentW: 0.578, iconContentH: 0.266)
    }

    /// Floor 11 elite reward — a defensive block relic.
    static var mysteriousAmber: Relic {
        Relic(name: "Mysterious Amber",
              description: "Gain 6 Block at the start of combat. At the start of every 3rd turn, gain 5 Block.",
              iconName: "relic_mysterious_amber",
              iconContentW: 0.297, iconContentH: 0.312)
    }

    /// Shop relic — energy for a small deck-dilution cost.
    static var slimeCore: Relic {
        Relic(name: "Slime Core",
              description: "+1 Max Energy. Start each combat with a Slime card mixed into your deck.",
              iconName: "relic_slime_core",
              iconContentW: 0.297, iconContentH: 0.297)
    }

    /// Rebuild a relic from its name — saved runs store names, not whole relics.
    static func named(_ name: String) -> Relic? {
        switch name {
        case "Vampire Tooth":   return vampireTooth
        case "Mysterious Amber": return mysteriousAmber
        case "Slime Core":      return slimeCore
        default:                return nil
        }
    }

    /// Every relic the Shop can stock.
    static var shopPool: [Relic] { [vampireTooth, mysteriousAmber, slimeCore] }
}

enum CardRarity { case common, uncommon, rare }

/// Whether a status pushed a card's number up or down.
enum CardValueChange { case reduced, increased }

/// One clause of a card's rules text, with its number split out so it can be coloured
/// independently when a status has changed it.
struct CardTextPart {
    var prefix: String = ""
    var value: String? = nil
    var suffix: String = ""
    var change: CardValueChange? = nil

    var plain: String { prefix + (value ?? "") + suffix }
}

struct Card: Identifiable {
    let id = UUID()
    let name: String
    let type: CardType
    let energyCost: Int
    let damage: Int
    let block: Int
    let vulnerableApply: Int
    let poisonApply: Int         // Poison — stacks applied to the target
    let frailApply: Int          // Frail — turns applied to the target (Corrode)
    let thornsGain: Int          // Thorns — gained by the PLAYER for the combat (Spikes)
    let imageName: String?
    let isExhaustible: Bool
    let hitsAllEnemies: Bool     // AOE damage (Cleave)
    let energyNextTurn: Int      // extra energy next turn (Thunder)
    let blockNextTurn: Int       // extra block next turn (generic next-turn block)
    let permanentBlock: Bool     // Barricade — block stops resetting each turn (rest of combat)
    let doublesPoison: Bool      // Catalyst — doubles the target's Poison
    let doublesBlock: Bool       // Turtle — doubles the player's current Block
    let rarity: CardRarity

    init(name: String, type: CardType, energyCost: Int, damage: Int, block: Int, imageName: String?,
         vulnerableApply: Int = 0, poisonApply: Int = 0, frailApply: Int = 0,
         thornsGain: Int = 0, isExhaustible: Bool = false,
         hitsAllEnemies: Bool = false, energyNextTurn: Int = 0, blockNextTurn: Int = 0,
         permanentBlock: Bool = false, doublesPoison: Bool = false, doublesBlock: Bool = false,
         rarity: CardRarity = .common) {
        self.name = name
        self.type = type
        self.energyCost = energyCost
        self.damage = damage
        self.block = block
        self.imageName = imageName
        self.vulnerableApply = vulnerableApply
        self.poisonApply = poisonApply
        self.frailApply = frailApply
        self.thornsGain = thornsGain
        self.isExhaustible = isExhaustible
        self.hitsAllEnemies = hitsAllEnemies
        self.energyNextTurn = energyNextTurn
        self.blockNextTurn = blockNextTurn
        self.permanentBlock = permanentBlock
        self.doublesPoison = doublesPoison
        self.doublesBlock = doublesBlock
        self.rarity = rarity
    }

    /// Rules text, split so the UI can colour a number that the owner's statuses moved
    /// (Frail shrinks Block, Weak shrinks damage, Strength grows it).
    func descriptionParts(for status: StatusEffects = StatusEffects()) -> [CardTextPart] {
        if type == .status {
            return [CardTextPart(prefix: "Unplayable. Costs ", value: "\(energyCost)",
                                 suffix: " energy to remove from your deck for this combat.")]
        }
        func moved(_ base: Int, _ actual: Int) -> CardValueChange? {
            actual == base ? nil : (actual < base ? .reduced : .increased)
        }
        var parts: [CardTextPart] = []
        if damage > 0 {
            let actual = status.damageDealt(damage)
            parts.append(CardTextPart(prefix: "Deal ", value: "\(actual)",
                                      suffix: hitsAllEnemies ? " damage to ALL enemies." : " damage.",
                                      change: moved(damage, actual)))
        }
        if vulnerableApply > 0 { parts.append(CardTextPart(prefix: "Apply ", value: "\(vulnerableApply)", suffix: " Vulnerable.")) }
        if poisonApply > 0 { parts.append(CardTextPart(prefix: "Apply ", value: "\(poisonApply)", suffix: " Poison.")) }
        if frailApply > 0 { parts.append(CardTextPart(prefix: "Apply ", value: "\(frailApply)", suffix: " Frail (it gains 25% less Block).")) }
        if thornsGain > 0 { parts.append(CardTextPart(prefix: "Gain ", value: "\(thornsGain)", suffix: " Thorns — attackers take \(thornsGain) damage.")) }
        if doublesPoison { parts.append(CardTextPart(suffix: "Double the enemy's Poison.")) }
        if block > 0 {
            let actual = status.blockGained(block)
            parts.append(CardTextPart(prefix: "Gain ", value: "\(actual)", suffix: " block.",
                                      change: moved(block, actual)))
        }
        if doublesBlock { parts.append(CardTextPart(suffix: "Double your current Block.")) }
        if energyNextTurn > 0 { parts.append(CardTextPart(prefix: "Gain ", value: "\(energyNextTurn)", suffix: " energy next turn.")) }
        if blockNextTurn > 0 { parts.append(CardTextPart(prefix: "Gain ", value: "\(blockNextTurn)", suffix: " block next turn.")) }
        if permanentBlock { parts.append(CardTextPart(suffix: "Block no longer resets at the start of your turn.")) }
        if isExhaustible { parts.append(CardTextPart(suffix: "Exhaust (leaves your deck until the next stage).")) }
        return parts
    }

    /// Plain, unmodified rules text (shop, draft — nowhere the player has statuses).
    var description: String {
        descriptionParts().map(\.plain).joined(separator: " ")
    }

    static func slime() -> Card {
        Card(name: "Slime", type: .status, energyCost: 1, damage: 0, block: 0,
             imageName: "card_slimed_status", isExhaustible: true)
    }

    /// The starter attack, also offered by the draft/shop (Strike and Defend are not).
    static func bash() -> Card {
        Card(name: "Bash", type: .attack, energyCost: 2, damage: 8, block: 0,
             imageName: "card_bash_attack", vulnerableApply: 1, rarity: .common)
    }

    // Individual card factories (fresh id each call).
    static func cleave() -> Card {
        Card(name: "Cleave", type: .attack, energyCost: 2, damage: 8, block: 0,
             imageName: "card_cleave_attack", hitsAllEnemies: true, rarity: .common)
    }
    static func thunder() -> Card {
        Card(name: "Thunder", type: .attack, energyCost: 2, damage: 15, block: 0,
             imageName: "card_thunder_attack", energyNextTurn: 1, rarity: .uncommon)
    }
    static func barricade() -> Card {
        Card(name: "Barricade", type: .skill, energyCost: 3, damage: 0, block: 8,
             imageName: "card_barricade_skill", permanentBlock: true, rarity: .rare)
    }
    static func poison() -> Card {
        Card(name: "Poison", type: .attack, energyCost: 1, damage: 5, block: 0,
             imageName: "card_posion_attack", poisonApply: 3, rarity: .common)
    }
    static func fortify() -> Card {
        Card(name: "Fortify", type: .skill, energyCost: 2, damage: 0, block: 15,
             imageName: "card_fortify_skill", rarity: .common)
    }
    static func turtle() -> Card {
        Card(name: "Turtle", type: .skill, energyCost: 2, damage: 0, block: 0,
             imageName: "card_turtle_skill", doublesBlock: true, rarity: .uncommon)
    }
    static func catalyst() -> Card {
        Card(name: "Catalyst", type: .skill, energyCost: 2, damage: 0, block: 0,
             imageName: "card_catalyst_skill", isExhaustible: true, doublesPoison: true, rarity: .rare)
    }

    /// Corrode — the player's access to Frail (the Acid Slime's signature).
    static func corrode() -> Card {
        Card(name: "Corrode", type: .skill, energyCost: 0, damage: 0, block: 0,
             imageName: "card_corrode_skill", frailApply: 2, rarity: .common)
    }
    /// Spikes — the player's access to Thorns (the Spiked Slime's signature).
    static func spikes() -> Card {
        Card(name: "Spikes", type: .skill, energyCost: 0, damage: 0, block: 0,
             imageName: "card_spikes_skill", thornsGain: 3, rarity: .uncommon)
    }

    /// Rebuild a card from its name — a saved deck stores names, not whole cards, so
    /// tuning a card's numbers automatically applies to loaded runs too.
    static func named(_ name: String) -> Card? {
        switch name {
        case "Strike":    return Card(name: "Strike", type: .attack, energyCost: 1, damage: 6, block: 0,
                                      imageName: "card_strike_attack")
        case "Defend":    return Card(name: "Defend", type: .skill, energyCost: 1, damage: 0, block: 5,
                                      imageName: "card_defend_skill")
        case "Bash":      return Card(name: "Bash", type: .attack, energyCost: 2, damage: 8, block: 0,
                                      imageName: "card_bash_attack", vulnerableApply: 1)
        case "Cleave":    return cleave()
        case "Thunder":   return thunder()
        case "Barricade": return barricade()
        case "Poison":    return poison()
        case "Fortify":   return fortify()
        case "Turtle":    return turtle()
        case "Catalyst":  return catalyst()
        case "Corrode":   return corrode()
        case "Spikes":    return spikes()
        case "Slime":     return slime()
        default:          return nil
        }
    }

    /// Every card the player can be offered — the Rest draft and the Shop both draw from
    /// here. Strike and Defend are starter-only; Slime is an unplayable status card.
    static var obtainableCards: [Card] {
        [bash(), cleave(), thunder(), barricade(), poison(),
         fortify(), turtle(), catalyst(), corrode(), spikes()]
    }

    /// Three random picks for the Rest Site draft (a fresh roll each visit).
    static var availableDraftCards: [Card] { Array(obtainableCards.shuffled().prefix(3)) }

    /// The Shop stocks from the same pool as the draft.
    static var shopCardPool: [Card] { obtainableCards }
}

// MARK: - Enemy Intent

enum EnemyIntent {
    case tackle(baseDamage: Int)
    case gooSpit(slimeCount: Int, weakTurns: Int)
    case harden(block: Int, strengthGain: Int, clearsDebuffs: Bool)
    case defend(block: Int)
    case attackDefend(damage: Int, block: Int)   // deals damage AND gains block
    case corrode(damage: Int, frailTurns: Int)   // acid — damages and eats away at Block

    var displayName: String {
        switch self {
        case .tackle: return "Tackle"
        case .gooSpit: return "Goo Spit"
        case .harden: return "Harden"
        case .defend: return "Defend"
        case .attackDefend: return "Spike"
        case .corrode: return "Corrode"
        }
    }

    /// What the player is told is coming. Deliberately COARSE — the icon and blurb say
    /// "a debuff is coming", never which one. Only the damage number is exact.
    enum Category {
        case attack, defend, debuff, attackDefend, attackDebuff, defendBuff

        var iconName: String {
            switch self {
            case .attack:        return "intent_attack"
            case .defend:        return "intent_defend"
            case .debuff:        return "intent_debuff"
            case .attackDefend:  return "intent_attack_defend"
            case .attackDebuff:  return "intent_attack_debuff"
            case .defendBuff:    return "intent_defend_buff"
            }
        }

        /// Where the art sits inside its 64px canvas, so every icon renders the same size.
        var iconContent: (w: CGFloat, h: CGFloat) {
            switch self {
            case .attack:       return (0.266, 0.281)
            case .defend:       return (0.234, 0.297)
            case .debuff:       return (0.250, 0.203)
            case .attackDefend: return (0.266, 0.297)
            case .attackDebuff: return (0.359, 0.297)
            case .defendBuff:   return (0.266, 0.344)
            }
        }

        var title: String {
            switch self {
            case .attack:       return "Attack"
            case .defend:       return "Defend"
            case .debuff:       return "Debuff"
            case .attackDefend: return "Attack & Defend"
            case .attackDebuff: return "Attack & Debuff"
            case .defendBuff:   return "Defend & Buff"
            }
        }

        var blurb: String {
            switch self {
            case .attack:       return "It's going to attack you."
            case .defend:       return "It's going to brace itself and gain Block."
            case .debuff:       return "It's going to inflict a debuff on you."
            case .attackDefend: return "It's going to attack you and gain Block."
            case .attackDebuff: return "It's going to attack you and inflict a debuff."
            case .defendBuff:   return "It's going to gain Block and buff itself."
            }
        }

        /// Only attacks put a number on screen — everything else stays vague on purpose.
        var showsValue: Bool {
            switch self {
            case .attack, .attackDefend, .attackDebuff: return true
            case .defend, .debuff, .defendBuff:         return false
            }
        }
    }

    var category: Category {
        switch self {
        case .tackle:       return .attack
        case .defend:       return .defend
        case .gooSpit:      return .debuff
        case .harden:       return .defendBuff
        case .attackDefend: return .attackDefend
        case .corrode:      return .attackDebuff
        }
    }

    /// The incoming damage, after this enemy's own Strength and Weak — so the telegraph
    /// matches what will actually land. Nil for non-attacks, which show no number.
    func displayValue(for status: StatusEffects) -> String? {
        guard category.showsValue else { return nil }
        switch self {
        case .tackle(let base):         return "\(status.damageDealt(base))"
        case .attackDefend(let dmg, _): return "\(status.damageDealt(dmg))"
        case .corrode(let dmg, _):      return "\(status.damageDealt(dmg))"
        default:                        return nil
        }
    }
}

// MARK: - Stats

enum StatKind: String, CaseIterable, Identifiable {
    case str, dex, con, int, fth, lck, cha
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

/// Combat + economy values derived from stat allocations. Every stat has a clear identity
/// so each is worth investing in:
///   STR → Guard chance + crit damage       DEX → Dodge + crit chance
///   CON → Max HP + Guard reduction          INT → +1 Max Energy per 15 (+ energy trickle)
///   FTH → healing (stronger heals/lifesteal + a heal after every combat)
///   LCK → loot (gear drops + more gold)      CHA → merchant (cheaper shops + extra cards)
struct DerivedStats {
    var critChance: Double       // 0…1
    var critDamage: Double       // multiplier, e.g. 1.30 = 130%
    var guardChance: Double      // 0…1 chance to reduce an incoming hit
    var guardDR: Double          // 0…1 fraction reduced when a hit is guarded
    var dodgeChance: Double      // 0…1 chance to negate an incoming hit
    var energyGainChance: Double // 0…1 chance for +1 energy at turn start (INT trickle)
    var bonusEnergy: Int         // INT breakpoints → extra Max Energy
    var incomingHeal: Double     // multiplier on heals the player receives (FTH)
    var combatEndHeal: Int       // HP healed after each combat (FTH)
    var lifestealChance: Double  // added to Vampire Tooth's base 50%
    var lifestealAmount: Int     // added to Vampire Tooth's base 2 HP (FTH)
    var luckyDrop: Double        // LCK bonus to the equipment drop chance
    var goldFind: Double         // LCK bonus multiplier on gold from enemies
    var shopDiscount: Double     // CHA fraction off shop prices
    var shopExtraCards: Int      // CHA extra shop card offers

    static let base = DerivedStats(
        critChance: 0.05, critDamage: 1.30, guardChance: 0.0, guardDR: 0.50,
        dodgeChance: 0.05, energyGainChance: 0.0, bonusEnergy: 0,
        incomingHeal: 1.0, combatEndHeal: 0, lifestealChance: 0.0, lifestealAmount: 0,
        luckyDrop: 0.0, goldFind: 0.0, shopDiscount: 0.0, shopExtraCards: 0)

    /// Pure derivation from the 7 stat allocations. Guard/Dodge use the reference game's
    /// diminishing formulas; crit/energy/healing are linear-per-point (crit clamps at 100%).
    static func derive(_ a: [StatKind: Int]) -> DerivedStats {
        let str = Double(a[.str] ?? 0), dex = Double(a[.dex] ?? 0)
        let con = Double(a[.con] ?? 0), int = Double(a[.int] ?? 0)
        let fth = Double(a[.fth] ?? 0), cha = Double(a[.cha] ?? 0)
        let lck = Double(a[.lck] ?? 0)

        // Crit — STR/DEX lead; INT/LCK chip in.
        let critChance = min(1.0, base.critChance
            + str * 0.00125 + dex * 0.0015 + int * 0.00075 + lck * 0.003)
        let critDamage = base.critDamage
            + str * 0.002 + dex * 0.0025 + int * 0.0015 + lck * 0.004
        // Guard Chance (STR), Guard DR (CON), Dodge (DEX) — diminishing returns.
        let guardChance = (str * 0.1)/(str + 50) + (str * 0.2)/(str + 200) + (str * 0.5)/(str + 500)
        let guardDR = base.guardDR + (con * 0.1)/(con + 100) + (con * 0.3)/(con + 250)
        let dodge = base.dodgeChance + (dex * 0.05)/(dex + 50) + (dex * 0.2)/(dex + 200)

        // INT → +1 Max Energy every 15 points, plus a small energy-gain trickle so points
        // between breakpoints aren't wasted.
        let bonusEnergy = (a[.int] ?? 0) / 15
        let energyGain = min(0.5, int * 0.0015)

        // FTH → healing: heals received, a post-combat heal, and stronger lifesteal.
        let incomingHeal = base.incomingHeal + fth * 0.01      // +1% healing received per FTH
        let combatEndHeal = (a[.fth] ?? 0) / 5                  // heal (FTH/5) HP after each combat
        let lifestealAmount = (a[.fth] ?? 0) / 10              // +1 lifesteal HP per 10 FTH

        // LCK → loot: gear-drop chance + gold from enemies.
        let luckyDrop = min(0.75, lck * 0.01)                  // +1% gear-drop chance per LCK
        let goldFind = lck * 0.01                              // +1% enemy gold per LCK

        // CHA → merchant: cheaper shop prices + extra card offers.
        let shopDiscount = min(0.5, cha * 0.006)               // up to 50% off
        let shopExtraCards = (a[.cha] ?? 0) / 20               // +1 shop card per 20 CHA

        return DerivedStats(
            critChance: critChance, critDamage: critDamage,
            guardChance: guardChance, guardDR: guardDR, dodgeChance: dodge,
            energyGainChance: energyGain, bonusEnergy: bonusEnergy,
            incomingHeal: incomingHeal, combatEndHeal: combatEndHeal,
            lifestealChance: 0.0, lifestealAmount: lifestealAmount,
            luckyDrop: luckyDrop, goldFind: goldFind,
            shopDiscount: shopDiscount, shopExtraCards: shopExtraCards)
    }
}

// MARK: - Combat Flash (floating text over a combatant)

enum FlashKind { case damage, crit, dodge, guarded, heal, poison }

struct CombatFlash: Equatable {
    let id = UUID()
    let text: String
    let kind: FlashKind
    static func == (a: CombatFlash, b: CombatFlash) -> Bool { a.id == b.id }
}

// MARK: - Equipment

enum EquipmentSlot: String, CaseIterable, Identifiable {
    case helmet, chest, legs, feet, weapon
    var id: String { rawValue }
    var label: String {
        switch self {
        case .helmet: return "Helmet"
        case .chest:  return "Chest"
        case .legs:   return "Legs"
        case .feet:   return "Feet"
        case .weapon: return "Weapon"
        }
    }
}

/// A piece of gear. Unlike relics (passives/abilities), equipment grants flat stat boosts.
/// One item per slot; extras live in the inventory.
struct Equipment: Identifiable {
    let id = UUID()
    let name: String
    let slot: EquipmentSlot
    let statBonuses: [StatKind: Int]
    let sellValue: Int
    var iconName: String? = nil

    /// "+2 CON, +1 STR"
    var bonusSummary: String {
        StatKind.allCases.compactMap { k in
            guard let v = statBonuses[k], v != 0 else { return nil }
            return "+\(v) \(k.label)"
        }.joined(separator: ", ")
    }

    /// A random droppable piece (fresh id each call, so duplicates are distinct).
    static func randomDrop() -> Equipment {
        let templates: [(String, EquipmentSlot, [StatKind: Int], Int)] = [
            ("Leather Cap",       .helmet, [.con: 2],           8),
            ("Iron Helm",         .helmet, [.con: 3, .str: 1], 16),
            ("Focus Hood",        .helmet, [.int: 3],          14),
            ("Padded Vest",       .chest,  [.con: 3],          10),
            ("Iron Chestplate",   .chest,  [.con: 4, .str: 2], 22),
            ("Silk Robe",         .chest,  [.int: 4, .fth: 1], 20),
            ("Leather Greaves",   .legs,   [.dex: 2, .con: 1], 10),
            ("Iron Leggings",     .legs,   [.con: 3, .str: 1], 16),
            ("Swift Boots",       .feet,   [.dex: 3],          12),
            ("Iron Boots",        .feet,   [.con: 2, .str: 1], 12),
            ("Rusty Sword",       .weapon, [.str: 3],          12),
            ("Keen Dagger",       .weapon, [.dex: 3, .lck: 1], 18),
            ("Oak Staff",         .weapon, [.int: 4],          18),
            ("Gambler's Blade",   .weapon, [.lck: 3],          20),
        ]
        let t = templates.randomElement()!
        return Equipment(name: t.0, slot: t.1, statBonuses: t.2, sellValue: t.3)
    }
}

// MARK: - Player

@Observable
class Player {
    let baseMaxHp = 80
    var currentHp = 80
    var maxEnergy = 3
    var currentEnergy = 3
    var gold = 0
    var currentBlock = 0
    var status = StatusEffects()

    // Stats — allocated points, plus bonuses from equipped gear.
    var statAllocations: [StatKind: Int] = [:]
    var unspentStatPoints = 0

    // Equipment — one item per slot; extras live in the inventory.
    var equippedItems: [EquipmentSlot: Equipment] = [:]
    var equipmentInventory: [Equipment] = []

    /// Allocated points + all equipped gear bonuses — what actually drives combat.
    var effectiveStats: [StatKind: Int] {
        var s = statAllocations
        for item in equippedItems.values {
            for (k, v) in item.statBonuses { s[k, default: 0] += v }
        }
        return s
    }

    var derived: DerivedStats { DerivedStats.derive(effectiveStats) }
    // Max HP is base + effective CON (allocations + gear), so it tracks gear automatically.
    var maxHp: Int { baseMaxHp + (effectiveStats[.con] ?? 0) }

    var combatFlash: CombatFlash? = nil
}

// MARK: - Enemy

@Observable
class Enemy: Identifiable {
    let id = UUID()
    var name: String
    var maxHp: Int
    var currentHp: Int
    var currentBlock = 0
    var status = StatusEffects()
    /// Enemies run the SAME stat system as the player — they crit, dodge and guard by the
    /// identical formulas. Each enemy's spread expresses its identity.
    var stats: [StatKind: Int]
    var derived: DerivedStats { DerivedStats.derive(stats) }
    var vfx: SpriteVFX = .none
    var combatFlash: CombatFlash? = nil

    // Hidden Poison-combo tracking (per combat): Poison + Catalyst cards played on this enemy.
    var poisonCardsThisTurn = 0
    var catalystCardsThisTurn = 0
    var poisonCardsTotal = 0
    var catalystCardsTotal = 0

    // Sprite art + crop bounds (fraction of the 64px canvas).
    var spriteName: String
    var spriteContentW: CGFloat
    var spriteContentH: CGFloat
    /// Art centre vs canvas centre (+ve = below), so every sprite stands on the same
    /// ground line however tall its art is. Measured from the asset.
    var spriteContentOffsetY: CGFloat = 0
    var spriteScale: CGFloat   // display size relative to the boss sprite height

    // Repeating list of moves; advanceIntent walks through it by turn number.
    var rotation: [EnemyIntent]
    var nextMove: EnemyIntent

    // Relic awarded to the player when this enemy dies (Elites drop relics).
    let dropsRelic: Relic?
    var relicRolled = false   // guards against re-rolling the drop each frame

    // Gold this enemy contributes to the combat reward (Normal 15 / Elite 30 / Boss 100).
    let goldReward: Int
    // Guaranteed equipment pieces dropped on death (mini-boss = 2). 0 = roll the normal chance.
    let guaranteedEquipmentDrops: Int

    init(name: String, maxHp: Int, spriteName: String,
         spriteContentW: CGFloat, spriteContentH: CGFloat, rotation: [EnemyIntent],
         spriteScale: CGFloat = 1.0, dropsRelic: Relic? = nil, goldReward: Int = 15,
         guaranteedEquipmentDrops: Int = 0, spriteContentOffsetY: CGFloat = 0,
         stats: [StatKind: Int] = [:]) {
        self.stats = stats
        self.spriteContentOffsetY = spriteContentOffsetY
        self.name = name
        self.maxHp = maxHp
        self.currentHp = maxHp
        self.spriteName = spriteName
        self.spriteContentW = spriteContentW
        self.spriteContentH = spriteContentH
        self.spriteScale = spriteScale
        self.rotation = rotation
        self.nextMove = rotation.first ?? .tackle(baseDamage: 0)
        self.dropsRelic = dropsRelic
        self.goldReward = goldReward
        self.guaranteedEquipmentDrops = guaranteedEquipmentDrops
    }

    var isAlive: Bool { currentHp > 0 }

    /// Normal-tier enemy: not an elite (no relic drop) and not the boss. Only these can
    /// drop equipment; elites drop relics instead.
    var isNormalTier: Bool { dropsRelic == nil && goldReward < 100 }

    // Queued-move classification (for the view's per-enemy turn animation).
    var moveAttacksPlayer: Bool {
        switch nextMove { case .tackle, .attackDefend, .corrode: return true; default: return false }
    }
    var moveGainsBlock: Bool {
        switch nextMove { case .defend, .harden, .attackDefend: return true; default: return false }
    }
    var moveGooSpits: Bool {
        if case .gooSpit = nextMove { return true }; return false
    }

    func clearDebuffs() { status.clearDebuffs() }

    func advanceIntent(forTurn turn: Int) {
        guard !rotation.isEmpty else { return }
        nextMove = rotation[(turn - 1) % rotation.count]
    }

    // MARK: - Enemy factories (Act 1 — Slime Biome)

    /// Normal — a plain slime. Attacks for 5 (fully blocked by one Defend).
    static func slime() -> Enemy {
        Enemy(name: "Slime", maxHp: 30, spriteName: "enemy_slime_basic",
              spriteContentW: 0.453, spriteContentH: 0.375,
              rotation: [.tackle(baseDamage: 5)],
              spriteScale: 0.5, spriteContentOffsetY: 0.0156,
              stats: [:])   // the tutorial enemy: baseline reflexes only
    }

    /// Normal — glass-cannon slime: hits for 8, then blocks 3.
    static func redSlime() -> Enemy {
        Enemy(name: "Red Slime", maxHp: 20, spriteName: "enemy_red_slime_basic",
              spriteContentW: 0.453, spriteContentH: 0.375,
              rotation: [.tackle(baseDamage: 8), .defend(block: 3)],
              spriteScale: 0.5, spriteContentOffsetY: 0.0156,
              stats: [.dex: 20, .lck: 10])   // quick and reckless: slips hits, crits often
    }

    /// Elite (Floor 5) — corrodes (9 damage + 2 Frail, so your Block is worth less), then
    /// blocks 15. Drops Vampire Tooth. First enemy in the run to inflict a status.
    static func acidSlime() -> Enemy {
        Enemy(name: "Acid Slime", maxHp: 55, spriteName: "enemy_acid_slime_elite",
              spriteContentW: 0.453, spriteContentH: 0.375,
              rotation: [.corrode(damage: 9, frailTurns: 2), .defend(block: 15)],
              spriteScale: 0.78, dropsRelic: .vampireTooth, goldReward: 30,
              spriteContentOffsetY: 0.0156,
              stats: [.str: 18, .con: 20, .dex: 8])   // elite: sturdier all round
    }

    /// Elite (Floor 13) — attacks for 8, then hits 5 while gaining 10 block.
    /// Drops the Mysterious Amber relic.
    static func spikedSlime() -> Enemy {
        let e = Enemy(name: "Spiked Slime", maxHp: 72, spriteName: "enemy_spiked_slime_elite",
                      spriteContentW: 0.453, spriteContentH: 0.438,
                      rotation: [.tackle(baseDamage: 8), .attackDefend(damage: 5, block: 10)],
                      spriteScale: 0.65, dropsRelic: .mysteriousAmber, goldReward: 30,
                      spriteContentOffsetY: -0.0156,
                      stats: [.str: 45, .con: 30, .dex: 4])   // armoured: guards a lot, rarely dodges
        e.status.thorns = 3   // its spikes bite anything that hits it
        return e
    }

    /// Mini-boss (Floor 9) — a bruiser: hits hard, then hardens (block + a little Strength),
    /// so its tackles ramp slowly if you stall. Guarantees 2 equipment drops.
    /// (Placeholder art: the basic slime sprite scaled up — needs its own sprite later.)
    static func giantSlime() -> Enemy {
        Enemy(name: "Giant Slime", maxHp: 100, spriteName: "enemy_slime_basic",
              spriteContentW: 0.453, spriteContentH: 0.375,
              rotation: [.tackle(baseDamage: 12), .harden(block: 10, strengthGain: 1, clearsDebuffs: false)],
              spriteScale: 0.95, goldReward: 50, guaranteedEquipmentDrops: 2,
              spriteContentOffsetY: 0.0156,
              stats: [.str: 30, .con: 55, .dex: 0])   // a wall: soaks hits, too big to dodge
    }

    /// Boss (Floor 18) — the Act boss.
    static func slimeKing() -> Enemy {
        Enemy(name: "Slime King", maxHp: 160, spriteName: "boss_slime",
              spriteContentW: 0.61, spriteContentH: 0.578,
              rotation: [.tackle(baseDamage: 12),
                         .gooSpit(slimeCount: 2, weakTurns: 2),
                         .harden(block: 15, strengthGain: 2, clearsDebuffs: true)],
              goldReward: 100, spriteContentOffsetY: -0.0078,
              stats: [.str: 45, .dex: 22, .con: 45, .lck: 20])   // boss: strong at everything
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

// MARK: - Shop Offers

struct ShopCardOffer: Identifiable {
    let id = UUID()
    let card: Card
    let price: Int
    var sold = false
}

struct ShopRelicOffer: Identifiable {
    let id = UUID()
    let relic: Relic
    let price: Int
    var sold = false
}

// MARK: - Game Engine

@Observable
class GameEngine {
    var player = Player()
    var enemies: [Enemy] = []
    var targetIndex: Int = 0
    var deck = DeckManager()
    var selectedCardIds: Set<UUID> = []
    var currentTurn = 1
    var gameState: GameState = .playing

    // Roguelike progression
    var currentAct = 1
    var currentFloor = 1

    // Gold rewards. `lastGoldEarned` / `lastBonusGold` feed the victory screen's reward
    // breakdown. `clearedFloors` records which floors have been won.
    var clearedFloors: Set<Int> = []
    var lastGoldEarned = 0
    /// The "Clean Fight" bonus from the floor just won (0 if it wasn't earned).
    var lastBonusGold = 0
    /// Whether the last floor's bonus was earned — the victory screen labels the chip.
    var lastBonusEarned = false
    /// HP lost during the current combat, for the Clean Fight bonus.
    var damageTakenThisCombat = 0

    /// Damage you can take and still earn the Clean Fight bonus: a quarter of max HP
    /// (20 at the base 80). Scales with CON, so it stays reachable as the run goes on.
    var cleanFightThreshold: Int { max(1, player.maxHp / 4) }
    var lastStatPoints = 0   // stat points from the just-won floor (victory screen)

    // Next-turn buffs (applied at the start of the player's turn)
    var extraEnergyNextTurn: Int = 0
    var extraBlockNextTurn: Int = 0

    // When true (Barricade played this combat), block stops resetting each turn.
    var blockPersists = false

    // Hidden combos (per combat). Shield combo tracks which of its 4 cards have been played.
    var shieldComboCards: Set<String> = []
    var justTriggeredCombo: String? = nil   // set when a combo fires, for the view's banner

    // Relics — every relic the player owns is active (there is no equip/unequip).
    var playerRelics: [Relic] = []
    var justEarnedRelic: Relic? = nil        // set when a relic is awarded, for the UI banner

    // Equipment dropped on the just-cleared floor (queued for the reveal notification).
    var justEarnedEquipment: [Equipment] = []

    func hasRelic(named name: String) -> Bool {
        playerRelics.contains { $0.name == name }
    }

    /// How many copies of a relic the player owns (duplicates stack their effects).
    func relicCount(named name: String) -> Int {
        playerRelics.filter { $0.name == name }.count
    }

    /// Base max energy plus +1 per Slime Core relic and INT's breakpoint bonus.
    var effectiveMaxEnergy: Int {
        player.maxEnergy + relicCount(named: "Slime Core") + player.derived.bonusEnergy
    }

    /// Grant the relics carried by this floor's elites. Called once the whole floor is
    /// cleared (not the instant an elite dies), so the reward lands with the victory.
    /// All relics currently drop at 100%, are added active, and duplicates are kept.
    private func grantFloorRelics() {
        for enemy in enemies {
            guard let relic = enemy.dropsRelic, !enemy.relicRolled else { continue }
            enemy.relicRolled = true
            playerRelics.append(relic)
            justEarnedRelic = relic
        }
    }

    /// Roll equipment drops: each defeated NORMAL enemy has a chance (base 25% + Lucky Drop)
    /// to drop a random piece. Elites/bosses don't drop equipment. Dropped gear goes to the
    /// inventory and is queued for the reveal notification.
    private func grantFloorEquipment() {
        justEarnedEquipment = []
        let chance = 0.25 + player.derived.luckyDrop
        for enemy in enemies where !enemy.isAlive {
            if enemy.guaranteedEquipmentDrops > 0 {
                // Mini-boss: guaranteed pieces (skips the chance roll).
                for _ in 0..<enemy.guaranteedEquipmentDrops { dropEquipment() }
            } else if enemy.isNormalTier, Double.random(in: 0..<1) < chance {
                dropEquipment()
            }
        }
    }

    private func dropEquipment() {
        let item = Equipment.randomDrop()
        player.equipmentInventory.append(item)
        justEarnedEquipment.append(item)
    }

    /// Equip an inventory item into its slot (any current occupant returns to the inventory).
    func equip(_ item: Equipment) {
        guard let idx = player.equipmentInventory.firstIndex(where: { $0.id == item.id }) else { return }
        player.equipmentInventory.remove(at: idx)
        if let current = player.equippedItems[item.slot] {
            player.equipmentInventory.append(current)
        }
        player.equippedItems[item.slot] = item
        player.currentHp = min(player.currentHp, player.maxHp)   // clamp if max HP changed
    }

    /// Unequip the item in `slot` back to the inventory.
    func unequip(_ slot: EquipmentSlot) {
        guard let item = player.equippedItems[slot] else { return }
        player.equippedItems[slot] = nil
        player.equipmentInventory.append(item)
        player.currentHp = min(player.currentHp, player.maxHp)
    }

    // Turn-flow + VFX presentation state (driven by the view's orchestrator)
    var turnBanner: TurnBanner = .none
    var playerVFX: SpriteVFX = .none
    var isResolvingTurn = false

    // The enemy the player's single-target cards will hit.
    var currentTarget: Enemy? {
        guard enemies.indices.contains(targetIndex) else { return nil }
        return enemies[targetIndex]
    }

    var allEnemiesDead: Bool {
        !enemies.isEmpty && enemies.allSatisfy { $0.currentHp <= 0 }
    }

    /// If the current target is dead, move the reticle to the first living enemy.
    private func retargetIfNeeded() {
        guard let t = currentTarget, t.isAlive else {
            if let firstAlive = enemies.firstIndex(where: { $0.isAlive }) {
                targetIndex = firstAlive
            }
            return
        }
    }

    // Selected (highlighted, not-yet-played) cards "reserve" their energy so the HUD
    // previews the cost — the counter drops the moment you select a card, before it's
    // played. Playing a card spends real energy but also drops it from the selection,
    // so the displayed remainder stays consistent.
    var usedEnergy: Int {
        deck.hand
            .filter { selectedCardIds.contains($0.id) }
            .reduce(0) { $0 + $1.energyCost }
    }

    var remainingEnergy: Int { player.currentEnergy - usedEnergy }
    var displayPlayerBlock: Int { player.currentBlock }

    /// Bumped by every `startGame()` — launch and each Try Again. The view watches this to
    /// replay the run's opening scene.
    private(set) var runId = 0

    init() {
        startGame()
    }

    func canAfford(_ card: Card) -> Bool {
        if selectedCardIds.contains(card.id) { return true }   // already reserved
        return remainingEnergy >= card.energyCost
    }

    /// Tap a card to toggle its selection. Multiple cards can be selected at once —
    /// selection is only a visual highlight (energy is spent when a card is played,
    /// one at a time, by dragging it).
    func toggleSelect(_ cardId: UUID) {
        guard gameState == .playing else { return }
        if selectedCardIds.contains(cardId) {
            selectedCardIds.remove(cardId)
        } else {
            guard let card = deck.hand.first(where: { $0.id == cardId }), canAfford(card) else { return }
            selectedCardIds.insert(cardId)
        }
    }

    /// Ensure a card is highlighted (used when a drag begins on it).
    func selectCard(_ cardId: UUID) {
        guard gameState == .playing else { return }
        selectedCardIds.insert(cardId)
    }

    /// Clear every selected card.
    func clearSelection() {
        selectedCardIds.removeAll()
    }

    // MARK: - Combat Resolution

    /// Set once the run's single revive has been spent. Per RUN, not per combat, and it
    /// rides along in the save so quitting and continuing can't hand it back.
    private(set) var reviveUsed = false

    /// Fraction of max HP restored by a revive.
    private static let reviveHpFraction = 0.40

    /// Spend the run's revive: back to 40% HP with a clean slate, combat resumed. The view
    /// then starts a fresh player turn — the enemies that were still to act do not get to.
    func revive() {
        guard gameState == .reviveOffer else { return }
        reviveUsed = true
        player.currentHp = max(1, Int((Double(player.maxHp) * Self.reviveHpFraction).rounded()))
        player.status.clearDebuffs()   // coming back Frail'd and Poisoned is just a slower death
        player.currentBlock = 0
        player.combatFlash = CombatFlash(text: "+\(player.currentHp)", kind: .heal)
        gameState = .playing
    }

    /// Restore the flag when loading a run (it's `private(set)` so nothing else can grant
    /// a revive back mid-run).
    func restoreReviveUsed(_ used: Bool) { reviveUsed = used }

    /// Turn the offer down (or the ad failed) — fall through to the normal defeat.
    func declineRevive() {
        guard gameState == .reviveOffer else { return }
        gameState = .defeat
    }

    private func checkCombatResolution() {
        guard gameState == .playing else { return }   // resolve only once per combat
        // A combat is "won" once every enemy is at 0 HP. The floor logic (auto-
        // advance vs. terminal victory) is decided by the turn orchestrator.
        if allEnemiesDead {
            awardCombatRewards()
            gameState = .victory
        } else if player.currentHp <= 0 {
            player.currentHp = 0
            // Offer the revive first, unless this run has already spent it.
            gameState = reviveUsed ? .defeat : .reviveOffer
        }
    }

    /// Stat points awarded for clearing a floor: Elite +4, Mini-boss +5, Boss +6, Normal +2.
    private func statPointsForFloor(_ floor: Int) -> Int {
        switch floor {
        case 5, 13: return 4   // Elites
        case 9:     return 5   // Mini-boss
        case 18:    return 6   // Boss
        default:    return 2   // Normal
        }
    }

    /// Grant the rewards for the just-won floor: gold (15/30/100 per Normal/Elite/Boss,
    /// plus a one-time +15 first-clear bonus), stat points, and any relics the elites carry.
    /// Records the gold + stat-point breakdown for the victory screen.
    private func awardCombatRewards() {
        // LCK increases the gold enemies drop.
        let rawGold = enemies.reduce(0) { $0 + $1.goldReward }
        let base = Int((Double(rawGold) * (1.0 + player.derived.goldFind)).rounded())
        // "Clean Fight" — clear the floor having lost at most a quarter of your max HP.
        let clean = damageTakenThisCombat <= cleanFightThreshold
        let bonus = clean ? 15 : 0
        clearedFloors.insert(currentFloor)
        player.gold += base + bonus
        lastGoldEarned = base
        lastBonusGold = bonus
        lastBonusEarned = clean

        lastStatPoints = statPointsForFloor(currentFloor)
        player.unspentStatPoints += lastStatPoints

        // FTH heals a little after every combat.
        let heal = player.derived.combatEndHeal
        if heal > 0 {
            player.currentHp = min(player.maxHp, player.currentHp + heal)
            AudioManager.shared.play(.heal)
        }

        grantFloorRelics()
        grantFloorEquipment()
    }

    /// Commit a pending stat allocation (from the Invest Points screen). Allocating CON
    /// raises max HP (via `effectiveStats`); we heal the added amount so you stay as "full".
    func commitAllocations(_ pending: [StatKind: Int]) {
        let total = pending.values.reduce(0, +)
        guard total > 0, total <= player.unspentStatPoints else { return }
        for (stat, n) in pending where n > 0 {
            player.statAllocations[stat, default: 0] += n
            if stat == .con { player.currentHp += n }   // maxHp is computed; heal the gain
        }
        player.unspentStatPoints -= total
    }

    /// Deal a card's damage to one enemy: roll the player's crit, apply the player's own
    /// Strength/Weak, then the enemy's Vulnerable, absorb with its block, clamp HP.
    /// Flashes the damage (gold + "CRIT!" on a crit). Thorns bite back afterwards.
    private func dealDamage(_ base: Int, to enemy: Enemy) {
        let d = player.derived
        let crit = Double.random(in: 0..<1) < d.critChance
        var hit = crit ? Int((Double(base) * d.critDamage).rounded()) : base
        // The attacker's own statuses shape what it deals…
        hit = player.status.damageDealt(hit)
        // The defender's own reflexes: Dodge negates outright, Guard softens.
        let ed = enemy.derived
        if Double.random(in: 0..<1) < ed.dodgeChance {
            enemy.combatFlash = CombatFlash(text: "DODGE", kind: .dodge)
            return                                    // nothing landed — no Thorns either
        }
        var guarded = false
        if Double.random(in: 0..<1) < ed.guardChance {
            hit = Int((Double(hit) * (1.0 - ed.guardDR)).rounded())
            guarded = true
        }

        // …and the defender's statuses shape what it takes.
        let raw = max(0, Int(floor(Double(hit) * enemy.status.vulnerableMultiplier)))
        let absorbed = min(raw, enemy.currentBlock)
        enemy.currentBlock -= absorbed
        enemy.currentHp = max(0, enemy.currentHp - (raw - absorbed))
        enemy.combatFlash = CombatFlash(
            text: crit ? "\(raw) CRIT!" : (guarded ? "\(raw) GUARD" : "\(raw)"),
            kind: crit ? .crit : (guarded ? .guarded : .damage))
        AudioManager.shared.play(.attack)

        // Thorns — hitting a spiked enemy costs you. Bypasses Block, like Poison.
        if enemy.status.thorns > 0 {
            takeUnblockableDamage(enemy.status.thorns)
        }
    }

    /// Damage that ignores Block, Dodge and Guard entirely (Thorns, Poison on the player).
    private func takeUnblockableDamage(_ amount: Int) {
        guard amount > 0 else { return }
        player.currentHp = max(0, player.currentHp - amount)
        damageTakenThisCombat += amount
        player.combatFlash = CombatFlash(text: "\(amount)", kind: .damage)
        AudioManager.shared.play(.damage)
        checkCombatResolution()
    }

    // MARK: - Play Cards
    //
    // Playing is two-phase so plays can be queued: COMMIT happens the instant a card is
    // dragged out (it leaves the hand and its energy is spent), while its EFFECT resolves
    // later (in order), letting the player fire off several cards without waiting.

    /// Commit a played card: spend its energy and move it out of the hand immediately.
    /// The effect is applied later by `resolveCardEffect`.
    func commitCardPlay(_ card: Card) {
        guard gameState == .playing, canAfford(card) else { return }
        player.currentEnergy -= card.energyCost
        selectedCardIds.remove(card.id)
        deck.hand.removeAll { $0.id == card.id }
        if card.isExhaustible {
            deck.exhaustPile.append(card)
        } else {
            deck.discardPile.append(card)
        }
    }

    /// Apply a committed card's effect to `targetIndex` (captured when it was played, so a
    /// queued card still hits the enemy the player aimed at), or to all enemies for AOE.
    func resolveCardEffect(_ card: Card, targetIndex: Int) {
        guard gameState == .playing else { return }
        let target: Enemy? = enemies.indices.contains(targetIndex) ? enemies[targetIndex] : nil

        if card.damage > 0 {
            if card.hitsAllEnemies {
                for enemy in enemies where enemy.isAlive {
                    dealDamage(card.damage, to: enemy)
                }
            } else if let target, target.isAlive {
                dealDamage(card.damage, to: target)
            }
        }
        if let target, target.isAlive, card.vulnerableApply > 0 {
            target.status.vulnerable += card.vulnerableApply
        }
        if let target, target.isAlive, card.poisonApply > 0 {
            target.status.poison += card.poisonApply
        }
        if let target, target.isAlive, card.frailApply > 0 {
            target.status.frail += card.frailApply       // Corrode
        }
        if card.doublesPoison, let target, target.isAlive {
            target.status.poison *= 2   // Catalyst
        }
        if card.thornsGain > 0 {
            player.status.thorns += card.thornsGain      // Spikes — a buff on yourself
            AudioManager.shared.play(.heal)
        }
        if card.block > 0 {
            player.currentBlock += player.status.blockGained(card.block)
            AudioManager.shared.play(.heal)
        }
        if card.doublesBlock {
            player.currentBlock *= 2   // Turtle
            AudioManager.shared.play(.heal)
        }
        if card.energyNextTurn > 0 {
            extraEnergyNextTurn += card.energyNextTurn
        }
        if card.blockNextTurn > 0 {
            extraBlockNextTurn += card.blockNextTurn
        }
        if card.permanentBlock {
            blockPersists = true   // Barricade — block stops resetting for the rest of combat
        }

        // Relic: Vampire Tooth — lifesteal on an Attack card. Each owned copy rolls its own
        // 50% (+ Lifesteal) chance to heal 2 (+ Lifesteal) HP (so duplicates roll twice).
        if card.type == .attack {
            let d = player.derived
            var healed = 0
            for _ in 0..<relicCount(named: "Vampire Tooth") {
                if Double.random(in: 0..<1) < (0.5 + d.lifestealChance) {
                    healed += 2 + d.lifestealAmount
                }
            }
            if healed > 0 {
                player.currentHp = min(player.maxHp, player.currentHp + healed)
                player.combatFlash = CombatFlash(text: "+\(healed)", kind: .heal)
                AudioManager.shared.play(.heal)
            }
        }

        // Hidden combos.
        trackAndCheckCombos(card, target: target)

        retargetIfNeeded()          // keep the reticle on a living enemy if the target died
        checkCombatResolution()     // grants relics once the whole floor is cleared
    }

    // MARK: - Hidden Combos

    /// Tally combo-relevant cards and fire either hidden combo if its conditions are met.
    private func trackAndCheckCombos(_ card: Card, target: Enemy?) {
        // Poison combo — Poison + Catalyst on the same enemy (same turn), or 2 Poison + 1
        // Catalyst on the same enemy over the fight.
        if let target, target.isAlive {
            if card.poisonApply > 0 {
                target.poisonCardsThisTurn += 1
                target.poisonCardsTotal += 1
            }
            if card.doublesPoison {
                target.catalystCardsThisTurn += 1
                target.catalystCardsTotal += 1
            }
            do {
                let sameTurn = target.poisonCardsThisTurn >= 1 && target.catalystCardsThisTurn >= 1
                let cumulative = target.poisonCardsTotal >= 2 && target.catalystCardsTotal >= 1
                if sameTurn || cumulative {
                    // Spend the tally rather than latching the combo off: it can fire as
                    // often as you like, but each time you have to build it up again.
                    // (Leaving the counters standing would re-fire it on every later card.)
                    target.poisonCardsThisTurn = 0
                    target.catalystCardsThisTurn = 0
                    target.poisonCardsTotal = 0
                    target.catalystCardsTotal = 0
                    let dmg = target.status.poison
                    target.currentHp = max(0, target.currentHp - dmg)   // direct
                    target.status.weak += 1                             // -25% next turn
                    target.combatFlash = CombatFlash(text: "\(dmg)", kind: .poison)
                    AudioManager.shared.play(.attack)
                    justTriggeredCombo = "POISON COMBO"
                }
            }
        }

        // Shield combo — play Fortify + Turtle + Barricade + Defend during the fight.
        let comboCards: Set<String> = ["Fortify", "Turtle", "Barricade", "Defend"]
        if comboCards.contains(card.name) {
            shieldComboCards.insert(card.name)
            if comboCards.isSubset(of: shieldComboCards) {
                // Same rule: the four cards are consumed, so playing them again re-arms it.
                shieldComboCards.removeAll()
                // Hit the lowest-HP living enemy for the player's current Block, Stun it,
                // and refund 8 Block.
                if let victim = enemies.filter({ $0.isAlive }).min(by: { $0.currentHp < $1.currentHp }) {
                    let dmg = player.currentBlock
                    victim.currentHp = max(0, victim.currentHp - dmg)   // direct
                    victim.status.stun += 1
                    victim.combatFlash = CombatFlash(text: "\(dmg)", kind: .crit)
                    AudioManager.shared.play(.attack)
                }
                player.currentBlock += player.status.blockGained(8)
                justTriggeredCombo = "SHIELD COMBO"
            }
        }
    }

    // MARK: - Enemy Turn

    /// Apply an incoming `raw` hit to the player: first roll Dodge (negates the whole hit),
    /// then Guard (a chance to reduce it by Guard DR), then the Block shield absorbs, then
    /// HP. Flashes DODGE / GUARD / the damage number.
    ///
    /// `attacker` is whoever swung, so the player's Thorns can bite back — the mirror of
    /// the retaliation in `dealDamage`. A fully dodged hit never made contact, so it
    /// doesn't trigger Thorns.
    private func dealDamageToPlayer(_ raw: Int, from attacker: Enemy? = nil) {
        let d = player.derived

        // Dodge — negate the entire hit (and any status it would carry).
        if Double.random(in: 0..<1) < d.dodgeChance {
            player.combatFlash = CombatFlash(text: "DODGE", kind: .dodge)
            return
        }

        // The attacker's Crit, rolled on its own stats — the mirror of the player's.
        var incoming = raw
        var attackerCrit = false
        if let attacker {
            let ad = attacker.derived
            if Double.random(in: 0..<1) < ad.critChance {
                incoming = Int((Double(incoming) * ad.critDamage).rounded())
                attackerCrit = true
            }
        }

        // Guard — a chance to soften this hit by Guard DR.
        var guarded = false
        if Double.random(in: 0..<1) < d.guardChance {
            incoming = Int((Double(incoming) * (1.0 - d.guardDR)).rounded())
            guarded = true
        }

        // The player's own Vulnerable amplifies the hit before Block soaks it.
        incoming = max(0, Int(floor(Double(incoming) * player.status.vulnerableMultiplier)))

        let remaining = incoming - player.currentBlock
        let absorbedByBlock = min(incoming, player.currentBlock)
        player.currentBlock = max(0, player.currentBlock - incoming)
        if remaining > 0 {
            player.currentHp = max(0, player.currentHp - remaining)
            damageTakenThisCombat += remaining     // Clean Fight bonus tracking
        }
        player.combatFlash = CombatFlash(
            text: guarded ? "\(incoming) GUARD" : (attackerCrit ? "\(incoming) CRIT!" : "\(incoming)"),
            kind: guarded ? .guarded : (attackerCrit ? .crit : .damage))
        // Guarding or soaking a hit on the shield reads as a block; only HP loss hurts.
        if guarded || absorbedByBlock > 0 { AudioManager.shared.play(.block) }
        if remaining > 0 { AudioManager.shared.play(.damage) }

        // Thorns — whatever struck the player takes the hit back, bypassing its Block
        // (same rule as the enemy-side retaliation and as Poison).
        if player.status.thorns > 0, let attacker, attacker.isAlive {
            let bite = player.status.thorns
            attacker.currentHp = max(0, attacker.currentHp - bite)
            attacker.combatFlash = CombatFlash(text: "\(bite)", kind: .damage)
            AudioManager.shared.play(.attack)
            checkCombatResolution()
        }
    }

    /// Execute ONE enemy's queued move. The view calls this per enemy (in order) so a
    /// multi-enemy turn reads as separate hits — each incoming attack is its own hit and
    /// rolls Dodge/Guard independently.
    func runEnemyMove(at index: Int) {
        guard gameState == .playing, enemies.indices.contains(index) else { return }
        let enemy = enemies[index]
        guard enemy.isAlive else { return }

        // Poison ticks at the start of this enemy's turn: 3 damage (bypasses block), then
        // 1 stack falls off. It can kill the enemy before it acts.
        if enemy.status.poison > 0 {
            enemy.currentHp = max(0, enemy.currentHp - 3)
            enemy.status.poison -= 1
            enemy.combatFlash = CombatFlash(text: "3", kind: .poison)
            AudioManager.shared.play(.attack)
            checkCombatResolution()
            if !enemy.isAlive || gameState != .playing { return }
        }

        // Stun — skip the move entirely (poison still ticked above).
        if enemy.status.stun > 0 {
            enemy.status.tickDurations()   // the skipped turn still counts down Weak/Frail
            enemy.combatFlash = CombatFlash(text: "STUNNED", kind: .dodge)
            return
        }

        // Block earned last turn expires at the start of this enemy's turn (it already
        // absorbed the player's attacks). Mirrors the player's reset.
        enemy.currentBlock = 0

        // Weak — reduce this enemy's attack damage by 25% for the turn.
        func atk(_ base: Int) -> Int {
            return enemy.status.damageDealt(base)
        }

        switch enemy.nextMove {
        case .tackle(let baseDamage):
            dealDamageToPlayer(atk(baseDamage), from: enemy)

        case .gooSpit(let count, let weakTurns):
            var slimeCards: [Card] = []
            for _ in 0..<count {
                slimeCards.append(.slime())
            }
            deck.injectIntoDiscard(slimeCards)
            // Energy-drain debuff — reduces next turn's energy (can go negative).
            extraEnergyNextTurn -= 1
            // …and the slime saps your strength.
            if weakTurns > 0 { player.status.weak += weakTurns }

        case .harden(let block, let strengthGain, let clearsDebuffs):
            enemy.currentBlock += enemy.status.blockGained(block)
            enemy.status.strength += strengthGain
            if clearsDebuffs { enemy.clearDebuffs() }
            AudioManager.shared.play(.heal)

        case .defend(let block):
            enemy.currentBlock += enemy.status.blockGained(block)
            AudioManager.shared.play(.heal)

        case .attackDefend(let damage, let block):
            dealDamageToPlayer(atk(damage), from: enemy)
            enemy.currentBlock += enemy.status.blockGained(block)
            AudioManager.shared.play(.heal)

        case .corrode(let damage, let frailTurns):
            dealDamageToPlayer(atk(damage), from: enemy)
            if frailTurns > 0 { player.status.frail += frailTurns }
        }

        enemy.status.tickDurations()   // Weak / Frail / Stun count down after acting

        checkCombatResolution()
    }

    // MARK: - Turn Steps (driven by the view's animated orchestration)

    /// Move any remaining cards in hand to the discard pile.
    func discardHand() {
        while !deck.hand.isEmpty {
            deck.discardPile.append(deck.hand.removeLast())
        }
    }

    /// Refresh energy, apply next-turn buffs, advance the intents, and draw.
    func beginNextTurn() {
        guard gameState == .playing else { return }
        // New player turn resets the Poison-combo "same turn" window.
        for enemy in enemies {
            enemy.poisonCardsThisTurn = 0
            enemy.catalystCardsThisTurn = 0
        }
        // The player's own statuses resolve at the start of their turn, exactly as an
        // enemy's do at the start of theirs: Poison bites, then durations count down.
        if player.status.poison > 0 {
            let tick = 3
            player.currentHp = max(0, player.currentHp - tick)
            damageTakenThisCombat += tick
            player.status.poison -= 1
            player.combatFlash = CombatFlash(text: "\(tick)", kind: .poison)
            checkCombatResolution()
            if gameState != .playing { return }
        }
        player.status.tickDurations()

        // Block resets at the start of the player's turn, unless made permanent (Barricade).
        // (It survived the enemy turn, so incoming attacks were already absorbed.)
        if !blockPersists {
            player.currentBlock = 0
        }
        // Start-of-turn buffs/debuffs (energy clamped so it never goes below 0).
        player.currentBlock += player.status.blockGained(extraBlockNextTurn)
        player.currentEnergy = max(0, effectiveMaxEnergy + extraEnergyNextTurn)
        extraEnergyNextTurn = 0
        extraBlockNextTurn = 0

        // Stat: Energy Gain — a chance for +1 energy this turn.
        if Double.random(in: 0..<1) < player.derived.energyGainChance {
            player.currentEnergy += 1
        }

        currentTurn += 1
        for enemy in enemies { enemy.advanceIntent(forTurn: currentTurn) }

        // Relic: Mysterious Amber — gain 5 Block at the start of every 3rd turn, per copy.
        if currentTurn % 3 == 0 {
            player.currentBlock += player.status.blockGained(5 * relicCount(named: "Mysterious Amber"))
        }

        deck.drawCards(5)
    }

    // MARK: - Progression (18-floor Act 1)

    func nodeForFloor(_ floor: Int) -> FloorNode {
        switch floor {
        case 4, 10, 16: return .rest
        case 5, 13:     return .elite
        case 9:         return .elite   // mini-boss (no dedicated node type yet)
        case 18:        return .boss
        default:        return .combat
        }
    }

    var isBossFloor: Bool { currentFloor == 18 }

    /// True for elite, mini-boss and boss encounters — they get the boss track instead of
    /// the normal fight track. Derived from the enemies themselves (relic carriers,
    /// guaranteed-drop mini-bosses, and the 100-gold boss) rather than hard-coded floors.
    var isEliteOrBossEncounter: Bool {
        enemies.contains {
            $0.dropsRelic != nil || $0.guaranteedEquipmentDrops > 0 || $0.goldReward >= 100
        }
    }

    /// Rest floors allow drafting except the final one (Floor 16, heal only).
    var restDraftAllowed: Bool { currentFloor != 16 }

    /// Spawn a combat encounter and reset per-fight state (player HP carries over).
    private func startCombat(with newEnemies: [Enemy]) {
        enemies = newEnemies
        targetIndex = 0
        for enemy in enemies { enemy.advanceIntent(forTurn: 1) }

        damageTakenThisCombat = 0     // fresh slate for the Clean Fight bonus
        player.status = StatusEffects()   // statuses never carry between fights
        player.currentBlock = 0
        player.currentEnergy = effectiveMaxEnergy
        extraEnergyNextTurn = 0
        extraBlockNextTurn = 0
        blockPersists = false
        shieldComboCards = []
        justTriggeredCombo = nil

        // Relic: Mysterious Amber — gain 6 Block at the start of combat, per owned copy.
        player.currentBlock += 6 * relicCount(named: "Mysterious Amber")

        deck.startCombat()   // reshuffle masterDeck into drawPile, clear temp piles
        // Relic: Slime Core — start each combat with a Slime card mixed into the deck (one
        // per copy). It's not in the master deck, so it's gone next combat.
        for _ in 0..<relicCount(named: "Slime Core") { deck.drawPile.append(.slime()) }
        if relicCount(named: "Slime Core") > 0 { deck.drawPile.shuffle() }
        deck.drawCards(5)

        selectedCardIds.removeAll()
        currentTurn = 1
        turnBanner = .none
        playerVFX = .none
        isResolvingTurn = false
        gameState = .playing
    }

    /// Configure whatever the current floor is. Encounters are FIXED per floor and
    /// hand-tuned into a fair difficulty curve for a fresh run:
    ///   • Floors 1–3 use only the starter deck — kept gentle, one teaching idea each.
    ///   • Rests (4/10/16) + Shop (after 10) space out the power spikes.
    ///   • Mini-boss on 9; Elites on 5/13; Boss on 18.
    /// (Slime = tanky/40 HP/6 dmg; Red Slime = fragile/20 HP/10 dmg burst.)
    private func setupCurrentFloor() {
        switch currentFloor {
        // Pre-draft: gentle introduction.
        case 1:  startCombat(with: [.slime()])                          // basics: one target
        case 2:  startCombat(with: [.slime(), .slime()])               // multi-target basics
        case 3:  startCombat(with: [.slime(), .redSlime()])            // focus the dangerous target

        case 4, 10, 16:   // Rest Sites
            enemies = []
            gameState = .restSite

        case 5:  startCombat(with: [.acidSlime(), .slime()])           // Elite 1

        // After the first draft: real threats.
        case 6:  startCombat(with: [.redSlime(), .redSlime()])         // burst check
        case 7:  startCombat(with: [.slime(), .slime(), .slime()])     // endurance wall (rewards AOE)
        case 8:  startCombat(with: [.slime(), .slime(), .redSlime()])  // mixed, sustained

        case 9:  startCombat(with: [.giantSlime()])                    // Mini-boss

        // After the second rest + Shop: high threat.
        case 11: startCombat(with: [.slime(), .redSlime(), .redSlime()]) // high burst
        case 12: startCombat(with: [.redSlime(), .redSlime(), .redSlime()]) // burst race

        case 13: startCombat(with: [.spikedSlime(), .slime(), .slime()]) // Elite 2

        case 14: startCombat(with: [.slime(), .slime(), .slime()])     // grind
        case 15: startCombat(with: [.slime(), .slime(), .redSlime()])  // mixed

        case 17: startCombat(with: [.redSlime(), .redSlime(), .redSlime()]) // final gauntlet

        case 18: startCombat(with: [.slimeKing()])                     // Boss

        case 19:         // Run complete
            enemies = []
            gameState = .actComplete

        default: startCombat(with: [.slime()])   // safety fallback (unreached)
        }
    }

    /// Advance to the next floor and configure it.
    func advanceFloor() {
        currentFloor += 1
        // A Shop sits after the Floor-10 rest — visit it before Floor 11's combat.
        if currentFloor == 11 {
            enemies = []
            stockShop()
            gameState = .shop
            saveRun()
            return
        }
        setupCurrentFloor()
        saveRun()   // checkpoint each floor, so quitting mid-run doesn't lose it
    }

    /// Leave the shop and start Floor 11's combat.
    func leaveShop() {
        setupCurrentFloor()   // currentFloor is already 11
    }

    // MARK: - Dev tools

    /// Re-enter the current floor from its start (used when loading a run that wasn't
    /// saved on a result screen — combat is rebuilt rather than resumed mid-fight).
    func restoreCurrentFloor() {
        setupCurrentFloor()
    }

    /// Dev-only: jump straight to any floor and configure its encounter/rest/boss,
    /// bypassing normal progression (no rewards granted). Used by the DEV floor picker.
    func devJumpToFloor(_ floor: Int) {
        currentFloor = max(1, min(floor, 19))
        setupCurrentFloor()
    }

    /// Dev-only: jump straight into the Shop (normally reached after the Floor-10 rest).
    func devJumpToShop() {
        currentFloor = 11
        enemies = []
        stockShop()
        gameState = .shop
    }

    // MARK: - Shop

    var shopCards: [ShopCardOffer] = []
    var shopRelics: [ShopRelicOffer] = []

    private func cardPrice(_ rarity: CardRarity) -> Int {
        switch rarity { case .common: return 50; case .uncommon: return 60; case .rare: return 75 }
    }

    /// Apply CHA's shop discount to a price.
    private func discounted(_ price: Int) -> Int {
        Int((Double(price) * (1.0 - player.derived.shopDiscount)).rounded())
    }

    /// Roll the shop's stock: 5 cards (2 Common / 2 Uncommon / 1 Rare) + CHA extras, and
    /// 2–3 relics. CHA also discounts every price.
    func stockShop() {
        let pool = Card.shopCardPool
        var cards: [Card] = []
        cards += pool.filter { $0.rarity == .common }.shuffled().prefix(2)
        cards += pool.filter { $0.rarity == .uncommon }.shuffled().prefix(2)
        cards += pool.filter { $0.rarity == .rare }.shuffled().prefix(1)
        // CHA: extra card offers (any rarity).
        let extra = player.derived.shopExtraCards
        if extra > 0 { cards += pool.shuffled().prefix(extra) }
        shopCards = cards.map { ShopCardOffer(card: $0, price: discounted(cardPrice($0.rarity))) }

        let relicCount = Int.random(in: 2...3)
        shopRelics = Relic.shopPool.shuffled().prefix(relicCount).map { relic in
            ShopRelicOffer(relic: relic, price: discounted(Int.random(in: 6...12) * 25))   // 150…300
        }
    }

    func buyCard(_ offer: ShopCardOffer) {
        guard let i = shopCards.firstIndex(where: { $0.id == offer.id }),
              !shopCards[i].sold, player.gold >= shopCards[i].price else { return }
        player.gold -= shopCards[i].price
        deck.masterDeck.append(shopCards[i].card)
        shopCards[i].sold = true
    }

    func buyRelic(_ offer: ShopRelicOffer) {
        guard let i = shopRelics.firstIndex(where: { $0.id == offer.id }),
              !shopRelics[i].sold, player.gold >= shopRelics[i].price else { return }
        player.gold -= shopRelics[i].price
        playerRelics.append(shopRelics[i].relic)   // duplicates allowed (effects stack)
        shopRelics[i].sold = true
    }

    /// Sell a spare piece of gear from the inventory for its sell value.
    func sellEquipment(_ item: Equipment) {
        guard let i = player.equipmentInventory.firstIndex(where: { $0.id == item.id }) else { return }
        player.gold += item.sellValue
        player.equipmentInventory.remove(at: i)
    }

    /// Start a brand-new run from Act 1, Floor 1 (Slay-the-Spire style): full HP,
    /// gold and relics wiped, deck back to the 10-card starter, first-win history
    /// cleared. Used at launch and by the "Try Again" button.
    func startGame() {
        runId += 1
        reviveUsed = false        // one revive per run, refreshed only by a brand-new run
        player.currentBlock = 0
        player.gold = 0
        player.statAllocations = [:]      // maxHp is computed → clears any CON bonus too
        player.unspentStatPoints = 0
        player.equippedItems = [:]
        player.equipmentInventory = []
        player.combatFlash = nil
        player.currentHp = player.maxHp   // full (base 80 now that stats/gear are cleared)

        playerRelics = []
        justEarnedRelic = nil
        justEarnedEquipment = []
        clearedFloors = []
        lastGoldEarned = 0
        lastBonusGold = 0
        lastBonusEarned = false
        damageTakenThisCombat = 0
        lastStatPoints = 0
        shopCards = []
        shopRelics = []

        deck.initializeDeck()   // drop drafted cards, back to the starter deck

        currentAct = 1
        currentFloor = 1
        setupCurrentFloor()
    }

    // MARK: - Rest Site

    /// "Rest" — heal 30% of max HP (scaled by Incoming Healing), then advance.
    func restHealAndAdvance() {
        let base = Double(player.maxHp) * 0.30
        let healAmount = Int((base * player.derived.incomingHeal).rounded())
        player.currentHp = min(player.maxHp, player.currentHp + healAmount)
        AudioManager.shared.play(.heal)
        advanceFloor()
    }

    /// "Train" — open the card draft.
    func chooseTrainDraft() {
        gameState = .drafting
    }

    /// Draft — add one copy of `card` to the master deck (duplicates allowed), then advance.
    func draftCard(_ card: Card) {
        guard gameState == .drafting else { return }
        deck.masterDeck.append(card)
        advanceFloor()
    }

    /// Draft — skip the reward and advance.
    func skipDraft() {
        guard gameState == .drafting else { return }
        advanceFloor()
    }

    /// DEV ONLY — drop the player to 0 HP so the death flow (revive offer, then defeat)
    /// can be tested without losing a fight for real.
    func devKillPlayer() {
        guard gameState == .playing else { return }
        player.currentHp = 0
        checkCombatResolution()
    }

    /// DEV ONLY — instantly kill every enemy so the round resolves as a normal win.
    func devWinCombat() {
        for enemy in enemies { enemy.currentHp = 0; enemy.vfx = .none }
        turnBanner = .none
        playerVFX = .none
        isResolvingTurn = true   // suppress the overlay until the win sequence finishes
        awardCombatRewards()     // gold + relics for the skipped floor
        gameState = .victory
    }
}
