import SwiftUI

// MARK: - Color Palette

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let bgDeep = Color(hex: 0x08060E)
    static let bgPanel = Color(hex: 0x18122A)
    static let bgPanelDark = Color(hex: 0x0E0A18)
    static let goldAccent = Color(hex: 0xC5961A)
    static let goldBright = Color(hex: 0xE8C850)
    static let goldDark = Color(hex: 0x6B5A28)
    static let goldBorder = Color(hex: 0x4A3A20)
    static let hpRuby = Color(hex: 0xCC2244)
    static let hpRubyDark = Color(hex: 0x5A1020)
    static let textParchment = Color(hex: 0xD4C5A0)
    static let textMuted = Color(hex: 0x8A7A60)
    static let textGold = Color(hex: 0xD4A520)
}

// MARK: - Pixel Font

extension Font {
    static func pixel(_ size: CGFloat) -> Font {
        .custom("VT323-Regular", size: size)
    }
}

// MARK: - Crisp Pixel Image

struct PixelImage: View {
    let name: String
    var width: CGFloat? = nil
    var height: CGFloat? = nil

    var body: some View {
        Image(name)
            .resizable()
            .interpolation(.none)
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
    }
}

// MARK: - Cropped Sprite (trims transparent canvas padding from layout)

struct CroppedSprite: View {
    let name: String
    let contentW: CGFloat   // visible content width as a fraction of the 64px canvas
    let contentH: CGFloat   // visible content height as a fraction of the 64px canvas
    let targetH: CGFloat    // desired on-screen height of the visible content
    /// The crop box is exactly content-sized and centred on the canvas, so art that sits
    /// even a pixel or two off-centre gets shaved. Pass `false` where the whole glyph must
    /// show (relic icons): layout still measures the content, but nothing is cut — the
    /// overspill is only the canvas's transparent padding.
    var clipToContent: Bool = true

    var body: some View {
        let full = targetH / contentH   // scale the whole canvas so content == targetH
        let image = Image(name)
            .resizable()
            .interpolation(.none)
            .frame(width: full, height: full)

        if clipToContent {
            image
                .frame(width: full * contentW, height: targetH)  // clip layout to content
                .clipped()
        } else {
            image
                .frame(width: full * contentW, height: targetH)  // same layout box, no clip
        }
    }
}

// MARK: - Health Hearts (Pixel Art)

/// A numeric HP bar: a fill proportional to current/max, with "cur/max" centered on top.
struct HealthBarView: View {
    let currentHp: Int
    let maxHp: Int
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let cur = max(0, currentHp)
        let frac = maxHp > 0 ? CGFloat(cur) / CGFloat(maxHp) : 0
        let radius = height * 0.28
        ZStack {
            RoundedRectangle(cornerRadius: radius).fill(Color.black.opacity(0.55))
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: radius)
                    .fill(LinearGradient(colors: [Color(hex: 0xE24A5C), Color(hex: 0xA81E36)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: geo.size.width * min(1, max(0, frac)))
            }
            Text("\(cur)/\(maxHp)")
                .font(.pixel(height * 0.72))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.85), radius: 1)
        }
        .frame(width: width, height: height)
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.black.opacity(0.6), lineWidth: 1.5))
    }
}

/// Floating combat text (damage / CRIT / DODGE / GUARD / heal) that rises and fades over
/// a combatant. Re-fires whenever the flash's id changes.
struct CombatFlashView: View {
    let flash: CombatFlash?
    let fontSize: CGFloat
    @State private var rise: CGFloat = 0
    @State private var opacity: Double = 0

    private func color(_ kind: FlashKind) -> Color {
        switch kind {
        case .damage:  return .white
        case .crit:    return Color(hex: 0xFFD84A)
        case .dodge:   return Color(hex: 0x7FD6FF)
        case .guarded: return Color(hex: 0x9BE38B)
        case .heal:    return Color(hex: 0x76E06A)
        case .poison:  return Color(hex: 0xB84AE0)
        }
    }

    var body: some View {
        Group {
            if let flash {
                Text(flash.text)
                    .font(.pixel(flash.kind == .crit ? fontSize * 1.3 : fontSize))
                    .foregroundColor(color(flash.kind))
                    .shadow(color: .black.opacity(0.9), radius: 2)
                    .fixedSize()
                    .offset(y: rise)
                    .opacity(opacity)
                    .task(id: flash.id) {
                        rise = 0
                        opacity = 1
                        withAnimation(.easeOut(duration: 0.9)) {
                            rise = -fontSize * 3
                            opacity = 0
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Shield / Block

struct ShieldView: View {
    let block: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Image(systemName: "shield.fill")
                .font(.system(size: size))
                .foregroundColor(block > 0 ? Color(hex: 0x4499DD) : Color(hex: 0x1A2838))
                .shadow(
                    color: block > 0 ? Color(hex: 0x44AAEE).opacity(0.5) : .clear,
                    radius: block > 0 ? 5 : 0
                )

            Text("\(block)")
                .font(.pixel(size * 0.55))
                .foregroundColor(block > 0 ? .white : Color(hex: 0x2A3848))
        }
    }
}

// MARK: - Face Down Card

struct FaceDownCard: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Image("card_facedown")
            .resizable()
            .interpolation(.none)
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
    }
}

// MARK: - Enemy View (one enemy: name, sprite, hearts, shield, status, target reticle)

struct EnemyView: View {
    let enemy: Enemy
    let isTarget: Bool
    let spriteH: CGFloat      // visible sprite height
    let groundH: CGFloat      // shared ground-zone height (aligns with the player)
    let heartSize: CGFloat
    let nameFont: CGFloat
    let statGap: CGFloat
    let pulsing: Bool
    let barWidth: CGFloat     // narrower when many enemies, to clear the player's stats
    var onStatusTooltip: ((Bool) -> Void)? = nil

    // Which status badge is being hovered/held (shows its description bubble).

    var body: some View {
        VStack(spacing: statGap) {
            Text(enemy.name)
                .font(.pixel(nameFont))
                .foregroundColor(isTarget ? .goldBright : .textParchment)
                .frame(height: nameFont * 1.3, alignment: .center)
                .padding(.bottom, statGap)

            ZStack(alignment: .top) {
                CroppedSprite(name: enemy.spriteName,
                              contentW: enemy.spriteContentW,
                              contentH: enemy.spriteContentH,
                              targetH: spriteH)
                    .shadow(color: Color(hex: 0x32B45A).opacity(0.4), radius: 16)
                    .scaleEffect(pulsing ? 1.03 : 1.0)
                    .animation(.easeInOut(duration: 1.75).repeatForever(autoreverses: true), value: pulsing)
                    .overlay { SpriteVFXView(vfx: enemy.vfx, size: spriteH * 0.9) }
                    .opacity(enemy.isAlive ? 1.0 : 0.25)
                    .frame(height: groundH, alignment: .bottom)

                // Target reticle above the sprite.
                if isTarget {
                    Text("\u{25BC}")
                        .font(.system(size: heartSize * 0.55))
                        .foregroundColor(.goldBright)
                        .shadow(color: Color.goldBright.opacity(0.8), radius: 6)
                        .offset(y: -heartSize * 0.35)
                }

                // Floating combat text (damage / CRIT).
                CombatFlashView(flash: enemy.combatFlash, fontSize: heartSize * 0.42)
                    .offset(y: -spriteH * 0.35)
            }

            VStack(spacing: heartSize * 0.06) {
                HStack(spacing: 4) {
                    HealthBarView(currentHp: enemy.currentHp, maxHp: enemy.maxHp,
                                  width: barWidth, height: heartSize * 0.42)
                    ShieldView(block: enemy.currentBlock, size: heartSize * 0.30)
                }

                // Status row below the bar (no overlap with the numeric bar).
                // Hover / hold a badge to see what it does (and what its number means).
                StatusRowView(status: enemy.status, isPlayer: false,
                              scale: heartSize, tooltipWidth: max(barWidth * 1.5, heartSize * 3.0),
                              rowWidth: barWidth,
                              // Bars narrow when 3+ enemies share the arena — one badge
                              // per line then, so nothing overhangs its own column.
                              maxPerRow: barWidth < heartSize * 1.7 ? 1 : 2,
                              onTooltipChange: { onStatusTooltip?($0) })
            }
        }
    }
}

// MARK: - Status Row
//
// The same badges and explanations for the player and for every enemy — statuses are
// universal, so one view renders both. Wording flips person ("You take" / "Takes").

struct StatusRowView: View {
    let status: StatusEffects
    let isPlayer: Bool
    let scale: CGFloat          // sized off the health-bar metric of whoever owns it
    let tooltipWidth: CGFloat
    /// Pinned to the owner's health-bar width so a long list of statuses can never widen
    /// the column and nudge the sprite sideways. Extra badges wrap onto further rows.
    var rowWidth: CGFloat? = nil
    var maxPerRow: Int = 2
    /// Fires when the description bubble opens or closes. A tooltip drawn inside one
    /// combatant's column is painted over by the next one, so whoever owns it has to be
    /// raised above its siblings while it shows.
    var onTooltipChange: ((Bool) -> Void)? = nil

    @State private var hovered: String? = nil

    private struct Badge: Identifiable {
        let id: String
        let label: String
        let color: Color
    }

    private var badges: [Badge] {
        var out: [Badge] = []
        if status.vulnerable > 0 { out.append(.init(id: "vuln", label: "VULN \(status.vulnerable)", color: Color(hex: 0xC0455E))) }
        if status.poison > 0     { out.append(.init(id: "psn",  label: "PSN \(status.poison)",      color: Color(hex: 0x8A3EB0))) }
        if status.weak > 0       { out.append(.init(id: "weak", label: "WEAK \(status.weak)",       color: Color(hex: 0xC06A2E))) }
        if status.frail > 0      { out.append(.init(id: "frail",label: "FRAIL \(status.frail)",     color: Color(hex: 0x4A8C8C))) }
        if status.stun > 0       { out.append(.init(id: "stun", label: "STUN \(status.stun)",       color: Color(hex: 0x3E7AC0))) }
        if status.thorns > 0     { out.append(.init(id: "thorn",label: "THORN \(status.thorns)",    color: Color(hex: 0x8C6A3E))) }
        return out
    }

    /// Badges split into rows, so a fourth status stacks underneath instead of stretching
    /// the row out sideways.
    private var rows: [[Badge]] {
        stride(from: 0, to: badges.count, by: maxPerRow).map {
            Array(badges[$0 ..< min($0 + maxPerRow, badges.count)])
        }
    }

    var body: some View {
        if !badges.isEmpty {
            VStack(spacing: scale * 0.05) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: scale * 0.06) {
                        ForEach(row) { badge in
                            Text(badge.label)
                                .font(.pixel(scale * 0.28))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(badge.color))
                                // Hover (pointer) or hold (touch) shows the description.
                                .onHover { hovering in
                                    if hovering { hovered = badge.id }
                                    else if hovered == badge.id { hovered = nil }
                                }
                                .onLongPressGesture(minimumDuration: 0.2) {
                                    hovered = (hovered == badge.id) ? nil : badge.id
                                }
                        }
                    }
                }
            }
            .frame(width: rowWidth)   // nil = size to content
            .onChange(of: hovered) { _, new in onTooltipChange?(new != nil) }
            .overlay(alignment: .bottom) {
                if let key = hovered, let info = info(key) {
                    tooltip(info)
                        .offset(y: -(scale * 0.55))
                        .allowsHitTesting(false)
                }
            }
        }
    }

    /// Title + description, with the number's meaning spelled out (they differ per status:
    /// Vulnerable stacks add up, the rest are turn counters).
    private func info(_ key: String) -> (title: String, desc: String)? {
        let subject = isPlayer ? "You take" : "Takes"
        let deals   = isPlayer ? "Your attacks deal" : "Its attacks deal"
        let gains   = isPlayer ? "You gain" : "It gains"
        let skips   = isPlayer ? "You skip your turn" : "Skips its turn"
        switch key {
        case "vuln":
            return ("VULNERABLE \(status.vulnerable)",
                    "\(subject) +50% damage per stack — now +\(status.vulnerable * 50)%. Stacks add up and last the whole fight.")
        case "psn":
            return ("POISON \(status.poison)",
                    "3 HP lost at the start of the turn, bypassing Block, then 1 stack falls off. The number is how many turns of poison remain.")
        case "weak":
            return ("WEAK \(status.weak)",
                    "\(deals) 25% less damage. The number is how many turns this lasts (−1 each turn).")
        case "frail":
            return ("FRAIL \(status.frail)",
                    "\(gains) 25% less Block from every source. The number is how many turns this lasts (−1 each turn).")
        case "stun":
            return ("STUN \(status.stun)",
                    "\(skips) entirely (poison still bites). The number is how many turns it lasts (−1 each turn).")
        case "thorn":
            return ("THORNS \(status.thorns)",
                    "Anything that attacks it takes \(status.thorns) damage, bypassing Block. Lasts the whole fight.")
        default:
            return nil
        }
    }

    private func tooltip(_ info: (title: String, desc: String)) -> some View {
        VStack(spacing: 3) {
            Text(info.title)
                .font(.pixel(scale * 0.26))
                .foregroundColor(.goldBright)
            Text(info.desc)
                .font(.pixel(scale * 0.22))
                .foregroundColor(.textParchment)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .frame(width: tooltipWidth)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x140E20)))   // fully opaque
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.goldBorder, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.5), radius: 8)
    }
}

// MARK: - Combat VFX Overlay

struct SpriteVFXView: View {
    let vfx: SpriteVFX
    let size: CGFloat

    @State private var frame = 0

    private static let frameDuration = 0.08

    private var prefix: String? {
        switch vfx {
        case .attack: return "basic_attack_animation"
        case .healDebuff: return "heal_debuff_animation2"
        case .none: return nil
        }
    }

    private var frameCount: Int {
        switch vfx {
        case .attack: return 9
        case .healDebuff: return 10
        case .none: return 0
        }
    }

    var body: some View {
        if let prefix {
            let index = min(frame, frameCount - 1) + 1
            let frameName = String(format: "%@_%04d", prefix, index)
            Image(frameName)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .allowsHitTesting(false)
                .task(id: vfx) {
                    frame = 0
                    while frame < frameCount - 1 {
                        try? await Task.sleep(for: .seconds(Self.frameDuration))
                        if Task.isCancelled { return }
                        frame += 1
                    }
                }
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var engine = GameEngine()
    @State private var enemyPulsing = false
    @State private var playerPulsing = false
    @State private var tooltipCardId: UUID? = nil
    @State private var dealtCardIds: Set<UUID> = []
    @State private var revealedCardIds: Set<UUID> = []
    @State private var isEnemyTurn = false

    // DEV floor picker: jump to any floor for testing.
    @State private var showDevPanel = false

    // Which stat's explanation bubble is showing in the character screen.
    @State private var statTooltip: StatKind? = nil

    // Narrative dialogue: the scene currently playing, which line it's on, and the
    // continuation that lets a caller `await` the whole scene before continuing.
    @State private var activeScene: DialogueScene? = nil
    @State private var dialogueLineIndex = 0
    @State private var dialogueContinuation: CheckedContinuation<Void, Never>? = nil
    @State private var dialogueAutoTask: Task<Void, Never>? = nil
    @State private var dialogueArrowPulse = false
    // The floor whose post-fight scene already played this combat. Both win paths ask for
    // it (card kill and the victory handler), so this keeps it to one showing per floor.
    @State private var floorEndScenePlayed: Int? = nil
    // True while the opening scene owns the screen: the run — cards, music — hasn't started.
    @State private var openingActive = false

    // Title page. It owns the screen at launch and whenever the player exits a run; the
    // engine keeps the run's state untouched behind it, so "Continue" resumes exactly
    // where they left off (floor, HP, deck, relics, stats, equipment).
    @State private var showTitle = true
    @State private var hasSave = false
    @State private var hoveredMenuItem: String? = nil
    // Loading a run moves floor/state, which would otherwise re-fire stingers and scenes
    // for events the player already lived through.
    @State private var isRestoringRun = false
    // The enemy whose status description is open — drawn above the others while it shows.
    @State private var statusTooltipEnemyId: UUID? = nil

    // This view instance's claim on audio playback (see `AudioManager.beginSession`).
    @State private var audioSession = 0

    // Settings panel (music level, SFX on/off, save & quit).
    @State private var showSettings = false
    @State private var musicVolume: Float = 0.30
    @State private var sfxOn = true

    // Drag-to-play: which hand card is being dragged, and its live drag offset.
    @State private var draggingCardId: UUID? = nil
    @State private var cardDragOffset: CGSize = .zero
    // Queued plays: a played card leaves the hand instantly and its effect resolves later
    // (in order, each with its center-hold), so the player can fire off cards without waiting.
    @State private var pendingPlays: [QueuedPlay] = []
    @State private var isProcessingPlays = false
    // The card currently parked in the center (held, then faded) before its effect fires.
    @State private var resolvingCard: Card? = nil
    @State private var resolvingCardOpacity: Double = 1.0

    struct QueuedPlay {
        let card: Card
        let targetIndex: Int
    }

    // Character / stats screen (view stats, invest points)
    @State private var showCharacter = false
    @State private var pendingAlloc: [StatKind: Int] = [:]
    // .review = opened mid-run (Confirm just commits); .postVictory = the step after a win
    // (Confirm commits AND advances to the next stage).
    enum CharacterMode { case review, postVictory }
    @State private var characterMode: CharacterMode = .review

    // Goo-spit projectile (boss → player)
    @State private var gooSpitActive = false
    @State private var gooSpitFrame = 0
    @State private var gooSpitProgress: CGFloat = 0

    // Floor 3 card draft
    @State private var draftCards: [Card] = []
    @State private var draftDealtIds: Set<UUID> = []
    @State private var draftRevealedIds: Set<UUID> = []
    @State private var draftSelectedId: UUID? = nil

    // Relics
    @State private var relicTooltipId: UUID? = nil
    @State private var earnedRelicBanner: Relic? = nil
    @State private var relicBannerContinuation: CheckedContinuation<Void, Never>? = nil
    @State private var earnedEquipmentBanner: Equipment? = nil
    @State private var equipmentBannerContinuation: CheckedContinuation<Void, Never>? = nil
    @State private var comboBanner: String? = nil   // hidden-combo notification

    var body: some View {
        GeometryReader { geo in
            let unit = min(geo.size.width, geo.size.height)
            let cardH = min(unit * 0.30, 260.0)
            let cardW = cardH * 0.72
            let bossH = min(unit * 0.38, 320.0)
            let heartSize = min(unit * 0.12, 80.0)
            let nameFont = min(unit * 0.028, 18.0)
            let titleFont = min(unit * 0.030, 20.0)
            let bodyFont = min(unit * 0.026, 18.0)
            let orbSize = max(unit * 0.09, 50.0)
            let handWidth = geo.size.width * 0.52

            // Sprite layout (equal margins from each screen edge, both on same level)
            let sideMargin = geo.size.width * 0.10         // more inward from the edges
            let bossSpriteH = min(unit * 0.20, 175.0)      // boss a bit bigger
            let playerSpriteH = bossSpriteH * 0.78         // player smaller than boss
            let spriteTopPad = geo.size.height * 0.25      // sit low in the arena
            let statGap = heartSize * 0.14   // sprite→hearts (compact)

            ZStack {
                // Background — fill screen, slight crop OK
                Image("battle_background")
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                // Top bar: Floor-Act + Turn + Gold (left), dev SKIP (right)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text("\(engine.currentAct)-\(engine.currentFloor)")
                            .font(.pixel(titleFont * 1.2))
                            .foregroundColor(.textParchment)

                        Text("Turn \(engine.currentTurn)")
                            .font(.pixel(titleFont))
                            .foregroundColor(.textMuted)
                    }

                    goldDisplay(size: titleFont * 1.1)

                    Button {
                        pendingAlloc = [:]
                        characterMode = .review
                        showCharacter = true
                    } label: {
                        let n = engine.player.unspentStatPoints
                        Text(n > 0 ? "STATS (\(n))" : "STATS")
                            .font(.pixel(titleFont * 0.85))
                            .foregroundColor(n > 0 ? .goldBright : .textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.4)))
                            .overlay(RoundedRectangle(cornerRadius: 4)
                                .stroke((n > 0 ? Color.goldBright : Color.goldBorder).opacity(0.7), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(700)   // keep the HUD (and relic tooltips) above the arena

                // Player (LEFT) — compact: name, sprite, hearts+shield all adjacent, left-aligned
                VStack(alignment: .leading, spacing: statGap) {
                    Text("Player")
                        .font(.pixel(nameFont))
                        .foregroundColor(.textParchment)
                        .frame(height: nameFont * 1.3, alignment: .center)
                        .padding(.bottom, statGap)

                    CroppedSprite(name: "player_sprite", contentW: 0.33, contentH: 0.4375, targetH: playerSpriteH)
                        .shadow(color: Color(hex: 0xA07830).opacity(0.3), radius: 12)
                        .scaleEffect(playerPulsing ? 1.02 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: playerPulsing
                        )
                        .overlay {
                            SpriteVFXView(vfx: engine.playerVFX, size: playerSpriteH * 0.9)
                        }
                        .overlay(alignment: .top) {
                            CombatFlashView(flash: engine.player.combatFlash, fontSize: heartSize * 0.42)
                                .offset(y: -playerSpriteH * 0.2)
                        }
                        .frame(height: bossSpriteH, alignment: .bottom)   // stand on the same ground as the boss

                    VStack(alignment: .leading, spacing: heartSize * 0.06) {
                        HStack(spacing: 4) {
                            HealthBarView(currentHp: engine.player.currentHp, maxHp: engine.player.maxHp,
                                          width: heartSize * 1.9, height: heartSize * 0.42)

                            ShieldView(block: engine.displayPlayerBlock, size: heartSize * 0.30)
                        }

                        // Statuses are universal — the player shows the same badges as enemies.
                        StatusRowView(status: engine.player.status, isPlayer: true,
                                      scale: heartSize, tooltipWidth: heartSize * 3.0,
                                      rowWidth: heartSize * 1.9)
                    }
                }
                .padding(.top, spriteTopPad)
                .padding(.leading, sideMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(5)   // player stats draw above the enemy cluster if they ever meet

                // Enemies (RIGHT) — one or more; tap a sprite to target it.
                // Each enemy's display size comes from its own spriteScale so it's
                // consistent across every floor it appears on. Tight spacing keeps the
                // group clustered on the right, out of the player's side of the arena.
                // Dragging or resolving an AOE card (Cleave) marks every living enemy;
                // otherwise only the single current target is reticled.
                let draggedCardIsAOE: Bool = {
                    if let rc = resolvingCard, rc.hitsAllEnemies, rc.damage > 0 { return true }
                    guard let id = draggingCardId,
                          let c = engine.deck.hand.first(where: { $0.id == id }) else { return false }
                    return c.hitsAllEnemies && c.damage > 0
                }()
                // Narrow the enemy bars when the cluster is crowded so it stays on the
                // right and doesn't reach into the player's health/shield.
                let enemyBarW = heartSize * (engine.enemies.count >= 3 ? 1.45 : 1.9)
                HStack(alignment: .top, spacing: heartSize * 0.1) {
                    ForEach(Array(engine.enemies.enumerated()), id: \.element.id) { index, enemy in
                        EnemyView(
                            enemy: enemy,
                            isTarget: draggedCardIsAOE ? enemy.isAlive : index == engine.targetIndex,
                            spriteH: bossSpriteH * enemy.spriteScale,
                            groundH: bossSpriteH,
                            heartSize: heartSize,
                            nameFont: nameFont,
                            statGap: statGap,
                            pulsing: enemyPulsing,
                            barWidth: enemyBarW,
                            onStatusTooltip: { showing in
                                statusTooltipEnemyId = showing ? enemy.id : nil
                            }
                        )
                        .zIndex(statusTooltipEnemyId == enemy.id ? 50 : 0)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard enemy.isAlive, !engine.isResolvingTurn else { return }
                            withAnimation(.easeOut(duration: 0.15)) {
                                engine.targetIndex = index
                            }
                        }
                    }
                }
                .padding(.top, spriteTopPad)
                .padding(.trailing, sideMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                // Lift the whole cluster over the player's column (zIndex 5) while a
                // status description is open, so the bubble is never painted under it.
                .zIndex(statusTooltipEnemyId != nil ? 20 : 0)

                // Bottom-LEFT: Draw pile with count right above
                VStack(spacing: 1) {
                    Text("\(engine.deck.drawPile.count)")
                        .font(.pixel(bodyFont))
                        .foregroundColor(.textMuted)
                        .padding(.bottom, -cardH * 0.09)   // sit adjacent above the visible pile

                    ZStack {
                        if engine.deck.drawPile.count > 0 {
                            ForEach(0..<min(3, engine.deck.drawPile.count), id: \.self) { i in
                                FaceDownCard(width: cardW, height: cardH)
                                    .offset(x: CGFloat(i) * 2, y: CGFloat(-i) * 2)
                            }
                        } else {
                            Image("card_facedown_empty")
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: cardW, height: cardH)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 16)
                .padding(.bottom, 8)

                // Bottom-RIGHT: Energy, then End Turn (compact)
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 6) {
                        PixelImage(name: "hud_energy_orb", width: orbSize * 0.7, height: orbSize * 0.7)
                            .shadow(color: Color(hex: 0xA040D0).opacity(0.6), radius: 10)

                        Text("\(engine.remainingEnergy)/\(engine.effectiveMaxEnergy)")
                            .font(.pixel(orbSize * 0.45))
                            .foregroundColor(Color(hex: 0xE0C0F0))
                    }

                    Button {
                        endPlayerTurn(size: geo.size)
                    } label: {
                        CroppedSprite(name: "end_turn", contentW: 0.67, contentH: 0.1875, targetH: orbSize * 0.55)
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.isResolvingTurn || isProcessingPlays)   // wait for queued plays
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .padding(.bottom, 8)

                // Card fan (bottom center)
                ZStack {
                    let count = engine.deck.hand.count
                    let mid = count > 1 ? Double(count - 1) / 2.0 : 0
                    // Fewer cards → tighter, smaller semi-circle.
                    let spreadScale = min(1.0, Double(count) / 5.0)
                    // Drag a card up past this much to release it into the "play zone".
                    let playThreshold = geo.size.height * 0.16

                    ForEach(Array(engine.deck.hand.enumerated()), id: \.element.id) { index, card in
                        let t = count > 1 ? (Double(index) - mid) / mid : 0
                        let fanAngle = t * 8.0 * spreadScale
                        let fanX = t * Double(handWidth) * 0.42 * spreadScale
                        let fanY = abs(t) * 8.0 * spreadScale

                        let isDealt = dealtCardIds.contains(card.id)
                        let isRevealed = revealedCardIds.contains(card.id)
                        let isSelected = engine.selectedCardIds.contains(card.id)
                        let isDragging = draggingCardId == card.id
                        // Card is lifted high enough that releasing will play it.
                        let inPlayZone = isDragging && cardDragOffset.height < -playThreshold

                        let startX = Double(-handWidth) * 0.55
                        let dragX = isDragging ? Double(cardDragOffset.width) : 0
                        let dragY = isDragging ? Double(cardDragOffset.height) : 0
                        let currentX = (isDealt ? fanX : startX) + dragX
                        let currentY = (isDealt ? fanY : 0) + (isSelected ? -cardH * 0.15 : 0) + dragY
                        // Straighten the card while it's being dragged.
                        let currentAngle = isDragging ? 0 : (isDealt ? fanAngle : 0)

                        Group {
                            if isRevealed {
                                CardView(
                                    card: card,
                                    isSelected: isSelected,
                                    // During the enemy's turn, dim every card exactly like
                                    // an unplayable (not enough energy) card.
                                    isAffordable: engine.canAfford(card) && !isEnemyTurn,
                                    showTooltip: tooltipCardId == card.id,
                                    cardWidth: cardW,
                                    cardHeight: cardH,
                                    ownerStatus: engine.player.status
                                )
                            } else {
                                FaceDownCard(width: cardW, height: cardH)
                            }
                        }
                        .contentShape(Rectangle())
                        .scaleEffect(inPlayZone ? 1.06 : 1.0)   // "ready to play" cue
                        .offset(x: currentX, y: currentY)
                        .rotationEffect(.degrees(currentAngle), anchor: .bottom)
                        .zIndex(
                            isDragging ? 500 :
                            tooltipCardId == card.id ? 200 :
                            isSelected ? 100 + Double(index) :
                            Double(index)
                        )
                        .allowsHitTesting(isRevealed && !engine.isResolvingTurn && !isEnemyTurn)
                        // Tap toggles selection (multi-select — floats the card up).
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) { engine.toggleSelect(card.id) }
                        }
                        // Drag it up into the middle and release to play it (one at a time).
                        .gesture(
                            DragGesture(minimumDistance: 6)
                                .onChanged { value in
                                    guard !engine.isResolvingTurn, !isEnemyTurn,
                                          engine.gameState == .playing, engine.canAfford(card) else { return }
                                    if draggingCardId != card.id {
                                        draggingCardId = card.id
                                        engine.selectCard(card.id)   // highlight while dragging
                                        tooltipCardId = nil
                                    }
                                    cardDragOffset = value.translation
                                }
                                .onEnded { value in
                                    guard draggingCardId == card.id else { return }
                                    let releasedInPlayZone = value.translation.height < -playThreshold
                                    draggingCardId = nil
                                    cardDragOffset = .zero
                                    if releasedInPlayZone && engine.canAfford(card) {
                                        // Commit + queue instantly — the card leaves the hand
                                        // now; its effect resolves in the play queue.
                                        playCardNow(card)
                                    } else {
                                        // Not far enough — snap back to the hand.
                                        withAnimation(.easeOut(duration: 0.2)) { cardDragOffset = .zero }
                                    }
                                }
                        )
                        .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                tooltipCardId = pressing ? card.id : nil
                            }
                        }, perform: {})
                        .animation(.easeOut(duration: 0.15), value: isSelected)
                        .animation(.easeInOut(duration: 0.3), value: count)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: cardH * 0.12)

                // The card currently resolving from the play queue — parked in the center,
                // held so the player can read it, then faded before its effect fires.
                if let rc = resolvingCard {
                    CardView(card: rc, isSelected: true, isAffordable: true,
                             showTooltip: false, cardWidth: cardW, cardHeight: cardH)
                        .scaleEffect(1.15)
                        .opacity(resolvingCardOpacity)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                        .allowsHitTesting(false)
                        .zIndex(600)
                }

                // Goo-spit projectile flying in a straight, level line boss → player
                if gooSpitActive {
                    let lineY = geo.size.height * 0.38
                    let start = CGPoint(x: geo.size.width * 0.78, y: lineY)
                    let end = CGPoint(x: geo.size.width * 0.18, y: lineY)
                    let pos = CGPoint(
                        x: start.x + (end.x - start.x) * gooSpitProgress,
                        y: lineY
                    )
                    Image(String(format: "goo_spit_animation_%04d", gooSpitFrame + 1))
                        .resizable()
                        .interpolation(.none)
                        .frame(width: heartSize * 1.4, height: heartSize * 1.4)
                        .position(pos)
                        .allowsHitTesting(false)
                        .zIndex(750)
                }

                // New-relic reveal — a prominent centered modal.
                if let relic = earnedRelicBanner {
                    ZStack {
                        Color.black.opacity(0.65)
                            .ignoresSafeArea()

                        VStack(spacing: unit * 0.03) {
                            Text("NEW RELIC!")
                                .font(.pixel(min(unit * 0.075, 52)))
                                .foregroundColor(.goldBright)
                                .shadow(color: Color.goldBright.opacity(0.8), radius: 16)

                            CroppedSprite(name: relic.iconName, contentW: relic.iconContentW, contentH: relic.iconContentH,
                                          targetH: min(unit * 0.09, 72), clipToContent: false)
                                .shadow(color: Color.goldBright.opacity(0.5), radius: 12)

                            Text(relic.name)
                                .font(.pixel(min(unit * 0.055, 38)))
                                .foregroundColor(.textParchment)

                            Text(relic.description)
                                .font(.pixel(min(unit * 0.034, 22)))
                                .foregroundColor(.textMuted)
                                .multilineTextAlignment(.center)

                            Text("Tap anywhere to close")
                                .font(.pixel(min(unit * 0.028, 18)))
                                .foregroundColor(Color(hex: 0x6A5A78))
                                .padding(.top, unit * 0.02)
                        }
                        .padding(.horizontal, unit * 0.06)
                        .padding(.vertical, unit * 0.05)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: 0x1A1428).opacity(0.96))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.goldBright.opacity(0.75), lineWidth: 3)
                        )
                        .shadow(color: Color.goldBright.opacity(0.4), radius: 24)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        relicBannerContinuation?.resume()
                        relicBannerContinuation = nil
                    }
                    .transition(.opacity)
                    .zIndex(950)
                }

                // Equipment-drop reveal.
                if let item = earnedEquipmentBanner {
                    ZStack {
                        Color.black.opacity(0.65).ignoresSafeArea()

                        VStack(spacing: unit * 0.025) {
                            Text("EQUIPMENT FOUND!")
                                .font(.pixel(min(unit * 0.07, 48)))
                                .foregroundColor(Color(hex: 0x8FD0FF))
                                .shadow(color: Color(hex: 0x8FD0FF).opacity(0.7), radius: 14)

                            Text(item.name)
                                .font(.pixel(min(unit * 0.055, 38)))
                                .foregroundColor(.textParchment)

                            Text(item.slot.label)
                                .font(.pixel(min(unit * 0.03, 20)))
                                .foregroundColor(.textMuted)

                            Text(item.bonusSummary)
                                .font(.pixel(min(unit * 0.038, 26)))
                                .foregroundColor(.goldBright)

                            Text("Tap anywhere to close")
                                .font(.pixel(min(unit * 0.028, 18)))
                                .foregroundColor(Color(hex: 0x6A5A78))
                                .padding(.top, unit * 0.015)
                        }
                        .padding(.horizontal, unit * 0.06)
                        .padding(.vertical, unit * 0.05)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x141C2A).opacity(0.96)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0x5FA8E0), lineWidth: 3))
                        .shadow(color: Color(hex: 0x5FA8E0).opacity(0.4), radius: 24)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        equipmentBannerContinuation?.resume()
                        equipmentBannerContinuation = nil
                    }
                    .transition(.opacity)
                    .zIndex(950)
                }

                // Character / stats screen — above everything (incl. the victory overlay).
                if showCharacter {
                    characterOverlay(unit: unit)
                        .zIndex(1200)
                }

                // Hidden-combo notification.
                if let combo = comboBanner {
                    VStack(spacing: 2) {
                        Text("\u{2726} COMBO! \u{2726}")
                            .font(.pixel(min(unit * 0.055, 38)))
                            .foregroundColor(Color(hex: 0xFFD84A))
                        Text(combo)
                            .font(.pixel(min(unit * 0.08, 54)))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, unit * 0.05)
                    .padding(.vertical, unit * 0.025)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.72)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xFFD84A), lineWidth: 3))
                    .shadow(color: Color(hex: 0xFFD84A).opacity(0.6), radius: 18)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.34)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .zIndex(860)
                }

                // Turn-state notifier banner
                if engine.turnBanner != .none {
                    let isPlayer = engine.turnBanner == .playerTurn
                    Text(isPlayer ? "PLAYER TURN" : "ENEMY TURN")
                        .font(.pixel(min(unit * 0.085, 60)))
                        .foregroundColor(isPlayer ? .goldBright : Color(hex: 0xCC2244))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.55))
                        )
                        .shadow(
                            color: isPlayer ? Color.goldBright.opacity(0.5) : Color(hex: 0xCC2244).opacity(0.5),
                            radius: 14
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        .allowsHitTesting(false)
                        .zIndex(800)
                }

                // Non-combat overlays (hidden while the turn orchestrator is mid-resolve,
                // so a Floor 1/2 win doesn't briefly flash the VICTORY screen before it
                // auto-advances to the next floor).
                if engine.gameState != .playing && !engine.isResolvingTurn {
                    let titleFontSize = min(unit * 0.12, 80)
                    let btnFontSize = min(unit * 0.045, 30)

                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                        .zIndex(990)

                    if engine.gameState == .drafting {
                        draftOverlay(unit: unit, btnFontSize: btnFontSize)
                            .zIndex(999)
                    } else if engine.gameState == .victory {
                        victoryOverlay(unit: unit, btnFontSize: btnFontSize)
                            .zIndex(999)
                    } else if engine.gameState == .defeat {
                        defeatOverlay(unit: unit, btnFontSize: btnFontSize)
                            .zIndex(999)
                    } else if engine.gameState == .shop {
                        shopOverlay(unit: unit, btnFontSize: btnFontSize)
                            .zIndex(999)
                    } else {
                        VStack(spacing: 20) {
                            switch engine.gameState {
                            case .restSite:
                                overlayTitle("REST SITE", size: titleFontSize * 0.75, color: .goldBright)
                                Text("Recover your strength, or train a new technique.")
                                    .font(.pixel(btnFontSize))
                                    .foregroundColor(.textParchment)
                                HStack(spacing: unit * 0.05) {
                                    overlayButton("Rest\n(Heal 30%)", fontSize: btnFontSize) {
                                        isEnemyTurn = false
                                        engine.restHealAndAdvance()
                                        if engine.gameState == .playing { dealNewHand() }
                                    }
                                    if engine.restDraftAllowed {
                                        overlayButton("Train\n(Draft a Card)", fontSize: btnFontSize) {
                                            engine.chooseTrainDraft()
                                        }
                                    }
                                }

                            case .actComplete:
                                // The story ends here — the kingdom is avenged.
                                overlayTitle("YOUR KINGDOM IS AVENGED", size: titleFontSize * 0.5, color: .goldBright)
                                VStack(spacing: unit * 0.012) {
                                    Text("The Slime King is gone, and the halls are quiet again.")
                                    Text("What's left of the kingdom is yours to rebuild.")
                                }
                                .font(.pixel(btnFontSize))
                                .foregroundColor(.textParchment)
                                .multilineTextAlignment(.center)
                                Text("\u{2756} THE END \u{2756}")
                                    .font(.pixel(btnFontSize * 1.1))
                                    .foregroundColor(.goldBorder)
                                    .padding(.top, unit * 0.01)
                                overlayButton("Play Again", fontSize: btnFontSize) {
                                    exitToTitle(runFinished: true)   // back to the title page
                                }

                            case .victory, .defeat, .shop, .drafting, .playing:
                                EmptyView()
                            }
                        }
                        .zIndex(999)
                    }
                }

                // Settings (top-right). Hidden on the title page and during a dialogue
                // scene, so it never collides with their own controls.
                if !showTitle && activeScene == nil {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: titleFont * 1.05))
                            .foregroundColor(.textParchment)
                            .padding(9)
                            .background(Circle().fill(Color(hex: 0x1A1228).opacity(0.85)))
                            .overlay(Circle().stroke(Color.goldBorder, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 32)   // sits level with the gold / STATS block
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .zIndex(1500)
                }

                if showSettings {
                    settingsPanel(unit: unit, size: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .zIndex(2600)
                }

                if showDevPanel {
                    devPanel(unit: unit)
                        .zIndex(1600)
                }

                // Narrative dialogue — above everything, including the dev buttons.
                // Pinned to the exact geometry rect so it centers on the window even if a
                // sibling in this ZStack overflows it.
                if let scene = activeScene {
                    dialogueOverlay(scene, unit: unit, size: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .zIndex(2000)
                }

                // Curtain: a run has begun but its opening scene hasn't rendered yet.
                // Without this the arena shows for a frame between the two.
                if openingActive && activeScene == nil {
                    Color.black
                        .ignoresSafeArea()
                        .zIndex(2500)
                }

                // Title page — owns the whole screen; nothing of the run shows through.
                if showTitle {
                    titleScreen(unit: unit, size: geo.size)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .zIndex(3000)
                }
            }
        }
        .background(Color.bgDeep)
        .ignoresSafeArea()
        .onAppear {
            playerPulsing = true
            enemyPulsing = true
            AudioManager.shared.preloadSFX()   // warm the voices before anything fires
            // Claim playback before starting any, so a previous instance's teardown can't
            // silence this one (Canvas tears views down out of order).
            audioSession = AudioManager.shared.beginSession()
            // The title page owns the screen at launch — the run begins on "Start Game".
            hasSave = SaveStore.hasSave
            musicVolume = AudioManager.shared.musicVolume
            sfxOn = AudioManager.shared.sfxEnabled
            if showTitle { AudioManager.shared.playMusic(.intro) }
        }
        // The view going away (window closed, or an Xcode preview torn down) must not leave
        // a track playing — a fade's delayed stop would never run. Only the current owner
        // may shut playback down.
        .onDisappear { AudioManager.shared.shutdown(token: audioSession) }
        // A brand-new run started (Try Again) — the opening frames every run, so replay it.
        .onChange(of: engine.runId) { _, _ in
            openingActive = true
            AudioManager.shared.stopMusic()
            Task { @MainActor in await startRun() }
        }
        // A new floor began — clear the post-fight guard and play its pre-fight scene
        // (also covers dev floor jumps).
        .onChange(of: engine.currentFloor) { _, floor in
            floorEndScenePlayed = nil
            syncMusic()          // normal ↔ elite/boss track
            guard !isRestoringRun else { return }
            Task { @MainActor in await playScene(for: .beforeFloor(floor)) }
        }
        // Win / loss stingers, the defeat caption card, and the track for the new state.
        .onChange(of: engine.gameState) { _, state in
            guard !isRestoringRun else { syncMusic(); return }
            switch state {
            case .victory: AudioManager.shared.play(.win)
            case .defeat:
                AudioManager.shared.play(.lose)
                // The run is over — drop the save so a floor checkpoint can't revive it,
                // however the player leaves this screen.
                SaveStore.clear()
                hasSave = false
                Task { @MainActor in await playScene(DialogueScript.defeatScene) }
            default: break
            }
            syncMusic()
        }
        // Entering/leaving the stats screen swaps to (and back from) the rest track.
        .onChange(of: showCharacter) { _, _ in syncMusic() }
    }

    // MARK: - DEV floor picker

    /// Short label for each floor so the picker is easy to scan.
    private static let devFloors: [(Int, String)] = [
        (1, "1"), (2, "2"), (3, "3"), (4, "4 · Rest"), (5, "5 · Elite"),
        (6, "6"), (7, "7"), (8, "8"), (9, "9 · Mini"), (10, "10 · Rest"),
        (11, "11"), (12, "12"), (13, "13 · Elite"), (14, "14"), (15, "15"),
        (16, "16 · Rest"), (17, "17"), (18, "18 · Boss"), (19, "19 · Done")
    ]

    /// Reset transient view/animation state after a dev jump, then deal a fresh hand
    /// if we landed in combat.
    private func resetForDevJump() {
        isEnemyTurn = false
        isProcessingPlays = false
        pendingPlays.removeAll()
        resolvingCard = nil
        resolvingCardOpacity = 1.0
        draggingCardId = nil
        cardDragOffset = .zero
        engine.isResolvingTurn = false
        engine.selectedCardIds.removeAll()
        showCharacter = false
        showDevPanel = false
        if engine.gameState == .playing { dealNewHand() }
    }

    @ViewBuilder
    private func devPanel(unit: CGFloat) -> some View {
        let f = min(unit * 0.030, 20.0)
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { showDevPanel = false }

            VStack(spacing: 14) {
                HStack {
                    Text("DEV — GO TO STAGE")
                        .font(.pixel(f * 1.1))
                        .foregroundColor(.goldBright)
                    Spacer()
                    Button { showDevPanel = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: f * 1.3))
                            .foregroundColor(.textMuted)
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: unit * 0.14), spacing: 8)], spacing: 8) {
                    devJumpButton("Shop", font: f) { engine.devJumpToShop(); resetForDevJump() }
                    ForEach(Self.devFloors, id: \.0) { floor, label in
                        devJumpButton(label, font: f) { engine.devJumpToFloor(floor); resetForDevJump() }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: min(unit * 0.9, 560))
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x1A1420).opacity(0.97)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.goldBorder, lineWidth: 2))
            .padding(24)
        }
    }

    private func devJumpButton(_ label: String, font: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.pixel(font * 0.85))
                .foregroundColor(.textParchment)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.45)))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.goldBorder.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dialogue

    /// Play a scene and suspend until it finishes, so callers can sequence it inside an
    /// existing flow (e.g. before the victory screen).
    @MainActor
    private func playScene(_ scene: DialogueScene) async {
        // If a scene is somehow still up, close it out first so its awaiting caller
        // resumes instead of hanging on an orphaned continuation.
        if dialogueContinuation != nil { finishDialogue() }
        dialogueAutoTask?.cancel()
        dialogueLineIndex = 0
        withAnimation(.easeOut(duration: 0.28)) { activeScene = scene }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            dialogueContinuation = cont
            // Auto-timed scenes walk themselves through their lines, then finish.
            if case .autoTimed(let perLine) = scene.presentation {
                dialogueAutoTask = Task { @MainActor in
                    for index in scene.lines.indices {
                        if Task.isCancelled { return }
                        withAnimation(.easeInOut(duration: 0.3)) { dialogueLineIndex = index }
                        try? await Task.sleep(for: .seconds(perLine))
                    }
                    if !Task.isCancelled { finishDialogue() }
                }
            }
        }
        try? await Task.sleep(for: .seconds(0.2))
    }

    // MARK: - Music
    //
    // One looping track at a time, chosen from the current game state. Called whenever
    // anything that could change it moves; `playMusic` ignores a repeat request, so the
    // track never restarts mid-fight.
    private func syncMusic() {
        // The title page or the opening owns the screen — the run's music hasn't started.
        guard !openingActive, !showTitle else { return }
        let track: AudioManager.Music?
        if showCharacter {
            track = .rest                     // stats screen — out of the fight
        } else {
            switch engine.gameState {
            case .playing:
                track = engine.isEliteOrBossEncounter ? .boss : .fight
            case .restSite, .drafting, .shop, .actComplete, .victory:
                track = .rest                 // resting, drafting, shopping, after a win
            case .defeat:
                track = nil                   // silence under the defeat stinger
            }
        }
        AudioManager.shared.playMusic(track)
    }

    // MARK: - Settings

    /// Speaker glyph matching the level: three waves at full, fewer as it drops, a slash
    /// at zero (no music at all, whatever the device volume is doing).
    private var speakerIcon: String {
        switch musicVolume {
        case ..<0.01: return "speaker.slash.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default:      return "speaker.wave.3.fill"
        }
    }

    @ViewBuilder
    private func settingsPanel(unit: CGFloat, size: CGSize) -> some View {
        let f = min(unit * 0.032, 21)
        let barW = min(unit * 0.34, 240)

        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { showSettings = false }

            VStack(alignment: .leading, spacing: unit * 0.026) {
                HStack {
                    Text("SETTINGS").font(.pixel(f * 1.25)).foregroundColor(.goldBright)
                    Spacer()
                    Button { showSettings = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: f, weight: .bold))
                            .foregroundColor(.textMuted)
                    }.buttonStyle(.plain)
                }

                // Music volume — affects the looping background track only.
                VStack(alignment: .leading, spacing: 8) {
                    Text("MUSIC").font(.pixel(f * 0.95)).foregroundColor(.textMuted)
                    HStack(spacing: 12) {
                        Button {
                            // Tapping the speaker mutes, or restores a sensible level.
                            musicVolume = musicVolume > 0 ? 0 : 0.30
                            AudioManager.shared.musicVolume = musicVolume
                        } label: {
                            Image(systemName: speakerIcon)
                                .font(.system(size: f * 1.1))
                                .foregroundColor(musicVolume > 0 ? .goldBright : Color(hex: 0xC0455E))
                                .frame(width: f * 1.8, alignment: .leading)
                        }.buttonStyle(.plain)

                        volumeBar(width: barW, height: f * 0.62)

                        Text("\(Int(musicVolume * 100))%")
                            .font(.pixel(f * 0.85))
                            .foregroundColor(.textParchment)
                            .frame(width: f * 2.6, alignment: .trailing)
                    }
                }

                // Sound effects — a plain on/off.
                VStack(alignment: .leading, spacing: 8) {
                    Text("SOUND EFFECTS").font(.pixel(f * 0.95)).foregroundColor(.textMuted)
                    Button {
                        sfxOn.toggle()
                        AudioManager.shared.sfxEnabled = sfxOn
                        if sfxOn { AudioManager.shared.play(.cardFlip, debounced: false) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: sfxOn ? "waveform" : "speaker.slash.fill")
                                .font(.system(size: f))
                            Text(sfxOn ? "ON" : "OFF").font(.pixel(f))
                        }
                        .foregroundColor(sfxOn ? .goldBright : Color(hex: 0xC0455E))
                        .padding(.horizontal, 18).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.45)))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .stroke(sfxOn ? Color.goldBorder : Color(hex: 0xC0455E).opacity(0.7), lineWidth: 1.5))
                    }.buttonStyle(.plain)
                }

                Rectangle().fill(Color.goldBorder.opacity(0.5)).frame(height: 1)

                // Developer tools — testing shortcuts, not player settings.
                VStack(alignment: .leading, spacing: 8) {
                    Text("DEVELOPER").font(.pixel(f * 0.95)).foregroundColor(.textMuted)
                    HStack(spacing: unit * 0.014) {
                        settingsButton("Go to Stage", font: f * 0.9, tint: Color(hex: 0x2A1E3A)) {
                            showSettings = false
                            showDevPanel = true
                        }
                        settingsButton("Win Fight", font: f * 0.9, tint: Color(hex: 0x2A1E3A)) {
                            guard engine.gameState == .playing,
                                  !engine.isResolvingTurn, !isProcessingPlays else { return }
                            showSettings = false
                            isEnemyTurn = false
                            engine.devWinCombat()
                            Task { @MainActor in await handleCombatWon() }
                        }
                        .opacity(engine.gameState == .playing ? 1 : 0.45)
                    }
                }

                Rectangle().fill(Color.goldBorder.opacity(0.5)).frame(height: 1)

                VStack(spacing: unit * 0.014) {
                    settingsButton("Save & Quit to Title", font: f, tint: Color(hex: 0x2C6E3C)) {
                        showSettings = false
                        exitToTitle()
                    }
                    settingsButton("Resume", font: f, tint: Color(hex: 0x2E2340)) {
                        showSettings = false
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(unit * 0.035)
            .frame(width: min(unit * 0.78, 520))
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x18122A)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.goldBorder, lineWidth: 2))
            .shadow(color: .black.opacity(0.6), radius: 24)
        }
        .frame(width: size.width, height: size.height)
    }

    /// Pixel-styled drag bar for the music level.
    private func volumeBar(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.55))
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.goldBright)
                .frame(width: max(0, width * CGFloat(musicVolume)))
        }
        .frame(width: width, height: height)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.goldBorder, lineWidth: 1.5))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0).onChanged { value in
                let pct = min(max(0, value.location.x / width), 1)
                musicVolume = Float(pct)
                AudioManager.shared.musicVolume = musicVolume
            }
        )
    }

    private func settingsButton(_ title: String, font: CGFloat, tint: Color,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.pixel(font))
                .foregroundColor(.textParchment)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 6).fill(tint))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.goldBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Title page

    /// Begin a fresh run: wipes progress and any save, then the opening plays.
    /// `openingActive` is raised *before* the title drops so the arena never flashes
    /// in the frame between the two.
    private func beginNewRun() {
        AudioManager.shared.play(.start)
        openingActive = true
        SaveStore.clear()
        hasSave = false
        engine.startGame()      // bumps runId → startRun() plays the opening
        showTitle = false
    }

    /// Resume the saved run — from disk, so it works after quitting the app entirely.
    private func resumeRun() {
        AudioManager.shared.play(.start)
        isRestoringRun = true
        if let save = SaveStore.read() { engine.loadSave(save) }
        showTitle = false
        if engine.gameState == .playing { dealNewHand() }
        syncMusic()
        // Clear once the restore's state changes have been observed, so the next real
        // transition announces itself normally.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            isRestoringRun = false
        }
    }

    /// Hand the screen back to the title page, saving the run so it can be resumed later
    /// — including after the app is quit. A run that has *ended* (defeat, or the finished
    /// story) is cleared instead: there's nothing left to continue.
    private func exitToTitle(runFinished: Bool = false) {
        if runFinished || engine.gameState == .defeat {
            SaveStore.clear()
            hasSave = false
        } else {
            engine.saveRun()
            hasSave = true
        }
        showTitle = true
        AudioManager.shared.playMusic(.intro)
    }

    /// PLACEHOLDER title page — the background is `art_title_background`, which renders as a
    /// labelled black screen until that asset exists. Nothing of the run runs behind it.
    @ViewBuilder
    private func titleScreen(unit: CGFloat, size: CGSize) -> some View {
        let titleFont = min(unit * 0.105, 78)
        let menuFont = min(unit * 0.040, 28)

        ZStack {
            DialogueBackdropView(assetName: "art_title_background")
                .frame(width: size.width, height: size.height)
                .clipped()

            // Darken toward the bottom so the menu stays readable over any artwork.
            LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0.82)],
                           startPoint: .top, endPoint: .bottom)

            VStack(spacing: 0) {
                Spacer(minLength: size.height * 0.10)

                VStack(spacing: unit * 0.014) {
                    Text("DECK OF THESEUS")
                        .font(.pixel(titleFont))
                        .foregroundColor(.goldBright)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.goldBright.opacity(0.5), radius: 24)
                        .shadow(color: .black.opacity(0.9), radius: 4)
                    Text("\u{2756}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2756}")
                        .font(.pixel(menuFont))
                        .foregroundColor(.goldBorder)
                }

                Spacer(minLength: 0)

                VStack(spacing: unit * 0.020) {
                    if hasSave {
                        titleMenuItem("Continue Run", font: menuFont) { resumeRun() }
                    }
                    titleMenuItem(hasSave ? "New Run" : "Start Run", font: menuFont) {
                        beginNewRun()
                    }
                    #if os(macOS)
                    titleMenuItem("Quit Game", font: menuFont) {
                        NSApplication.shared.terminate(nil)
                    }
                    #endif
                }
                .padding(.bottom, size.height * 0.11)
            }

            Text("Act 1 \u{2022} Slime Biome \u{2014} placeholder title art")
                .font(.pixel(min(unit * 0.024, 15)))
                .foregroundColor(.textMuted)
                .padding(20)
                .frame(width: size.width, height: size.height, alignment: .bottomLeading)
        }
        .frame(width: size.width, height: size.height)
    }

    private func titleMenuItem(_ label: String, font: CGFloat, action: @escaping () -> Void) -> some View {
        let hot = hoveredMenuItem == label
        return Button(action: action) {
            HStack(spacing: 12) {
                Text("\u{273A}").opacity(hot ? 1 : 0)
                Text(label)
                Text("\u{273A}").opacity(hot ? 1 : 0)
            }
            .font(.pixel(font))
            .foregroundColor(hot ? .goldBright : .textParchment)
            .shadow(color: hot ? Color.goldBright.opacity(0.7) : .clear, radius: 12)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredMenuItem = $0 ? label : (hoveredMenuItem == label ? nil : hoveredMenuItem) }
    }

    /// Start a run. The opening plays on its own screen — no cards are dealt and no combat
    /// music starts until it's finished, so nothing of the fight leaks through it.
    @MainActor
    private func startRun() async {
        await playScene(for: .runStart)
        openingActive = false
        dealNewHand()
        syncMusic()
    }

    /// Play the scene for a trigger, if the script has one. Every scene is mandatory —
    /// it plays each time its trigger fires, on every run.
    @MainActor
    private func playScene(for trigger: DialogueTrigger) async {
        guard let scene = DialogueScript.scene(for: trigger) else { return }
        await playScene(scene)
    }

    /// The current floor's post-fight scene, shown once per combat however many win paths
    /// ask for it. Reset when the next floor begins, so it plays again on a later run.
    @MainActor
    private func playFloorEndScene() async {
        guard floorEndScenePlayed != engine.currentFloor else { return }
        floorEndScenePlayed = engine.currentFloor
        await playScene(for: .afterFloor(engine.currentFloor))
    }

    /// Tap anywhere: next line for a tap-through scene, skip entirely for an auto card.
    private func advanceDialogue() {
        guard let scene = activeScene else { return }
        guard case .tapToAdvance = scene.presentation else { finishDialogue(); return }
        if dialogueLineIndex + 1 < scene.lines.count {
            withAnimation(.easeInOut(duration: 0.18)) { dialogueLineIndex += 1 }
        } else {
            finishDialogue()
        }
    }

    /// End the scene and resume whoever is awaiting it. Safe to call twice.
    private func finishDialogue() {
        dialogueAutoTask?.cancel()
        dialogueAutoTask = nil
        withAnimation(.easeIn(duration: 0.22)) { activeScene = nil }
        let cont = dialogueContinuation
        dialogueContinuation = nil
        cont?.resume()
    }

    /// CRK-style scene: portrait to one side, name pill above a dialogue box along the
    /// bottom. Captions drop the portrait and pill and center their text.
    @ViewBuilder
    private func dialogueOverlay(_ scene: DialogueScene, unit: CGFloat, size: CGSize) -> some View {
        let line = scene.lines[min(dialogueLineIndex, scene.lines.count - 1)]
        let speaker = line.speaker
        let textFont = min(unit * 0.038, 25)
        let portraitH = min(unit * 0.34, 280)
        let isTapScene: Bool = { if case .tapToAdvance = scene.presentation { return true }; return false }()
        // Definite width so the box (and the portrait above it) centre reliably.
        let boxW = min(size.width * 0.88, 980)

        ZStack {
            // Either dim the arena behind the scene, or replace it with story art. Lines
            // can cut to a different image mid-scene, so this resolves per line and
            // crossfades between them.
            let backdrop = scene.resolvedBackdrop(at: dialogueLineIndex)
            Group {
                switch backdrop {
                case .arena:          Color.black.opacity(0.55)
                case .art(let name):  DialogueBackdropView(assetName: name)
                }
            }
            .id(backdrop)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.35), value: backdrop)
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { advanceDialogue() }

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // Portrait — knight on the left, everyone else on the right.
                if let speaker {
                    HStack(spacing: 0) {
                        if !speaker.isPlayerSide { Spacer(minLength: 0) }
                        CroppedSprite(name: speaker.portrait.name,
                                      contentW: speaker.portrait.contentW,
                                      contentH: speaker.portrait.contentH,
                                      targetH: portraitH)
                            .shadow(color: .black.opacity(0.7), radius: 18)
                            .transition(.opacity)
                        if speaker.isPlayerSide { Spacer(minLength: 0) }
                    }
                    .frame(width: boxW)
                    .padding(.bottom, unit * 0.012)
                }

                // Name pill + dialogue box.
                VStack(alignment: speaker?.isPlayerSide == false ? .trailing : .leading, spacing: -unit * 0.014) {
                    if let speaker {
                        Text(speaker.displayName)
                            .font(.pixel(textFont * 0.9))
                            .foregroundColor(Color(hex: 0x140E20))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.goldBright))
                            .overlay(Capsule().stroke(Color.goldBorder, lineWidth: 2))
                            .padding(.horizontal, unit * 0.03)
                            .zIndex(2)
                    }

                    Text(line.text)
                        .font(.pixel(textFont))
                        .foregroundColor(.textParchment)
                        .multilineTextAlignment(speaker == nil ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: speaker == nil ? .center : .leading)
                        .padding(.horizontal, unit * 0.04)
                        .padding(.vertical, unit * 0.032)
                        .frame(width: boxW, alignment: .center)
                        .frame(minHeight: unit * 0.16, alignment: .center)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x140E20).opacity(0.92)))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.goldBorder, lineWidth: 2))
                        // Advance arrow (tap-through scenes only).
                        .overlay(alignment: .bottomTrailing) {
                            if isTapScene {
                                Text("\u{25BC}")
                                    .font(.system(size: textFont * 0.7))
                                    .foregroundColor(.goldBright)
                                    .opacity(dialogueArrowPulse ? 0.3 : 1.0)
                                    .onAppear {
                                        dialogueArrowPulse = false
                                        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                                            dialogueArrowPulse = true
                                        }
                                    }
                                    .padding(.trailing, 14).padding(.bottom, 10)
                            }
                        }
                }
                .frame(width: boxW)
                .padding(.bottom, unit * 0.05)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onTapGesture { advanceDialogue() }

            // SKIP — always available, for returning players.
            Button { finishDialogue() } label: {
                Text("SKIP")
                    .font(.pixel(min(unit * 0.03, 20)))
                    .foregroundColor(.textParchment)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .overlay(Capsule().stroke(Color.goldBorder, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20).padding(.top, 16)
            .frame(width: size.width, height: size.height, alignment: .topTrailing)
        }
        .frame(width: size.width, height: size.height)
        .transition(.opacity)
    }

    // MARK: - Overlay Helpers

    private func overlayTitle(_ text: String, size: CGFloat, color: Color) -> some View {
        Text(text)
            .font(.pixel(size))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.6), radius: 16)
    }

    @ViewBuilder
    private func overlayButton(_ title: String, fontSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.pixel(fontSize))
                .multilineTextAlignment(.center)
                .foregroundColor(.textParchment)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x2A1E3A), Color(hex: 0x1A1228)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.goldBorder, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gold

    /// Placeholder gold-coin icon (swap for real art later).
    private func goldCoin(size: CGFloat) -> some View {
        ZStack {
            Circle().fill(
                LinearGradient(colors: [Color(hex: 0xFFD966), Color(hex: 0xE0A828)],
                               startPoint: .top, endPoint: .bottom))
            Circle().stroke(Color(hex: 0x9C6D12), lineWidth: max(1, size * 0.08))
            Text("G")
                .font(.pixel(size * 0.62))
                .foregroundColor(Color(hex: 0x7A5410))
        }
        .frame(width: size, height: size)
    }

    /// Top-left HUD row: gold (coin + amount), then every owned relic's icon growing
    /// rightward. Relics are all active; hover/hold an icon to read its name + description.
    private func goldDisplay(size: CGFloat) -> some View {
        HStack(spacing: 8) {
            goldCoin(size: size)
            Text("\(engine.player.gold)")
                .font(.pixel(size))
                .foregroundColor(.goldBright)

            ForEach(engine.playerRelics) { relic in
                relicHudIcon(relic, size: size)
            }
        }
    }

    /// A relic icon in the top HUD (same height as the gold coin). Hover or hold to
    /// reveal its name + description just below the icon.
    private func relicHudIcon(_ relic: Relic, size: CGFloat) -> some View {
        CroppedSprite(name: relic.iconName, contentW: relic.iconContentW, contentH: relic.iconContentH,
                      targetH: size, clipToContent: false)
            .contentShape(Rectangle())
            .overlay(alignment: .topLeading) {
                if relicTooltipId == relic.id {
                    relicTooltipBubble(relic)
                        .offset(y: size + 8)      // drop the bubble below the icon
                        .zIndex(100)
                }
            }
            .onHover { hovering in
                relicTooltipId = hovering ? relic.id : (relicTooltipId == relic.id ? nil : relicTooltipId)
            }
            .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                relicTooltipId = pressing ? relic.id : nil
            }, perform: {})
    }

    // MARK: - Character / Stats screen

    /// Effective stats (allocations + equipped gear) merged with the pending (uncommitted)
    /// allocation — the true preview of what the derived stats will be.
    private func mergedAllocations() -> [StatKind: Int] {
        var m = engine.player.effectiveStats
        for (k, v) in pendingAlloc { m[k, default: 0] += v }
        return m
    }

    private func characterOverlay(unit: CGFloat) -> some View {
        let headerFont = min(unit * 0.05, 32)
        let bodyFont = min(unit * 0.03, 20)
        let boxW = min(unit * 1.3, 860)
        let boxH = min(unit * 0.9, 700)
        let isPostVictory = characterMode == .postVictory

        let merged = mergedAllocations()
        let d = DerivedStats.derive(merged)
        let previewMaxHp = engine.player.baseMaxHp + (merged[.con] ?? 0)
        let pendingTotal = pendingAlloc.values.reduce(0, +)
        let remaining = engine.player.unspentStatPoints - pendingTotal

        return ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { pendingAlloc = [:]; showCharacter = false }

            VStack(spacing: unit * 0.014) {
                HStack {
                    Text(isPostVictory ? "ALLOCATE POINTS" : "CHARACTER")
                        .font(.pixel(headerFont)).foregroundColor(.goldBright)
                    Spacer()
                    Text("Points: \(remaining)")
                        .font(.pixel(bodyFont * 1.1))
                        .foregroundColor(remaining > 0 ? .goldBright : .textMuted)
                    Button { pendingAlloc = [:]; showCharacter = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: headerFont * 0.7, weight: .bold))
                            .foregroundColor(.textParchment).padding(6)
                    }.buttonStyle(.plain)
                }

                // Stat allocator (▲ / LABEL (value) / ▼). Lifted above the STATS grid so a
                // stat tooltip (which overflows downward) paints on top of it, not behind.
                HStack(alignment: .top, spacing: unit * 0.006) {
                    ForEach(StatKind.allCases) { stat in
                        statColumn(stat, remaining: remaining, bodyFont: bodyFont)
                    }
                }
                .zIndex(10)

                Rectangle().fill(Color.goldBorder.opacity(0.5)).frame(height: 1)

                // Two columns: derived stats (left) and equipment (right). Both size to
                // content; the inventory scroll area below has a fixed height so it's usable.
                HStack(alignment: .top, spacing: unit * 0.02) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("STATS").font(.pixel(bodyFont * 1.1)).foregroundColor(.goldBright)
                        derivedStatsGrid(d, maxHp: previewMaxHp, bodyFont: bodyFont)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    Rectangle().fill(Color.goldBorder.opacity(0.4)).frame(maxHeight: .infinity).frame(width: 1)

                    equipmentPanel(bodyFont: bodyFont, unit: unit)
                }

                Spacer(minLength: 0)

                Button {
                    engine.commitAllocations(pendingAlloc)
                    pendingAlloc = [:]
                    if isPostVictory {
                        AudioManager.shared.play(.start)   // "Next Stage"
                        showCharacter = false
                        isEnemyTurn = false
                        engine.advanceFloor()              // onto the next stage
                        if engine.gameState == .playing { dealNewHand() }
                    }
                } label: {
                    let enabled = isPostVictory || pendingTotal > 0
                    Text(isPostVictory ? "Next Stage \u{25B6}" : "Confirm")
                        .font(.pixel(bodyFont * 1.1))
                        .foregroundColor(enabled ? .white : .textMuted)
                        .padding(.horizontal, 36).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 6)
                            .fill(enabled ? Color(hex: 0x2C6E3C) : Color(hex: 0x241E36)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.goldBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(!isPostVictory && pendingTotal == 0)
            }
            .padding(unit * 0.028)
            .frame(width: boxW, height: boxH)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0x18122A)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.goldBorder, lineWidth: 2))
            .shadow(color: .black.opacity(0.6), radius: 24)
        }
    }

    private func statColumn(_ stat: StatKind, remaining: Int, bodyFont: CGFloat) -> some View {
        // Show the EFFECTIVE stat (allocated points + equipped gear), plus any pending.
        let current = engine.player.effectiveStats[stat] ?? 0
        let pending = pendingAlloc[stat] ?? 0
        let total = current + pending
        return VStack(spacing: 2) {
            Button {
                if remaining > 0 { pendingAlloc[stat, default: 0] += 1 }
            } label: {
                Image(systemName: "chevron.up.circle.fill")
                    .font(.system(size: bodyFont * 0.95))
                    .foregroundColor(remaining > 0 ? .goldBright : Color(hex: 0x4A4258))
            }
            .buttonStyle(.plain).disabled(remaining <= 0)

            // The label is the tooltip target — hover (pointer) or hold (touch) to learn
            // what the stat does. A "?" hint marks it as inspectable.
            HStack(spacing: 2) {
                Text(stat.label).font(.pixel(bodyFont)).foregroundColor(.textParchment)
                Text("?").font(.pixel(bodyFont * 0.7)).foregroundColor(.goldBorder)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering { statTooltip = stat }
                else if statTooltip == stat { statTooltip = nil }
            }
            .onLongPressGesture(minimumDuration: 0.2) {
                statTooltip = (statTooltip == stat) ? nil : stat
            }

            Text("(\(total))")
                .font(.pixel(bodyFont * 0.9))
                .foregroundColor(pending > 0 ? .goldBright : .textMuted)

            Button {
                if pending > 0 { pendingAlloc[stat, default: 0] -= 1 }
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: bodyFont * 0.95))
                    .foregroundColor(pending > 0 ? .goldBright : Color(hex: 0x4A4258))
            }
            .buttonStyle(.plain).disabled(pending <= 0)
        }
        .frame(maxWidth: .infinity)
        // Edge columns anchor their bubble inward (leading for the first stat, trailing for
        // the last) so it doesn't overflow past the panel border; middle columns center.
        .overlay(alignment: tooltipAlignment(stat)) {
            if statTooltip == stat {
                statInfoBubble(stat, total: total, bodyFont: bodyFont)
                    .offset(y: bodyFont * 4.6)   // drop the bubble just below the column
                    .zIndex(300)
            }
        }
    }

    /// Keep the first/last stat's tooltip inside the panel by anchoring it inward.
    private func tooltipAlignment(_ stat: StatKind) -> Alignment {
        switch stat {
        case .str: return .topLeading
        case .cha: return .topTrailing
        default:   return .top
        }
    }

    /// Title + plain-language description for a stat, with its live numbers/breakpoints filled in.
    private func statInfo(_ stat: StatKind, total: Int) -> (title: String, desc: String) {
        switch stat {
        case .str:
            return ("STR — Power",
                    "Raises your Guard chance (block part of an incoming hit) and your Crit damage.")
        case .dex:
            return ("DEX — Agility",
                    "Raises your Dodge chance (fully avoid a hit) and your Crit chance.")
        case .con:
            return ("CON — Toughness",
                    "+1 Max HP per point, and raises Guard reduction (how much a guarded hit is cut).")
        case .int:
            let toNext = 15 - (total % 15)
            return ("INT — Focus",
                    "+1 Max Energy every 15 INT — next in \(toNext). Plus a small chance for +1 energy at turn start.")
        case .fth:
            return ("FTH — Spirit",
                    "Heals you receive are stronger. Heal \(total / 5) HP after each combat, and lifesteal heals +\(total / 10).")
        case .lck:
            return ("LCK — Fortune",
                    "+\(min(75, total))% equipment-drop chance and +\(total)% gold from enemies.")
        case .cha:
            let extra = total / 20
            let disc = min(50, Int((Double(total) * 0.6).rounded()))
            return ("CHA — Charm",
                    "\(disc)% off shop prices" + (extra > 0 ? " and +\(extra) extra shop cards." : " (extra cards every 20 CHA)."))
        }
    }

    private func statInfoBubble(_ stat: StatKind, total: Int, bodyFont: CGFloat) -> some View {
        let info = statInfo(stat, total: total)
        return VStack(spacing: 3) {
            Text(info.title).font(.pixel(bodyFont * 0.95)).foregroundColor(.goldBright)
            Text(info.desc)
                .font(.pixel(bodyFont * 0.82)).foregroundColor(.textParchment)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(width: bodyFont * 11)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x140E20)))   // fully opaque
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.goldBorder, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.6), radius: 8)
        .allowsHitTesting(false)
    }

    private func derivedStatsGrid(_ d: DerivedStats, maxHp: Int, bodyFont: CGFloat) -> some View {
        func pct(_ v: Double) -> String { String(format: "%.1f%%", v * 100) }
        let rows: [(String, String)] = [
            ("Max HP", "\(maxHp)"),
            ("Bonus Energy", "+\(d.bonusEnergy)"),
            ("Crit Chance", pct(d.critChance)),
            ("Crit Damage", String(format: "%.0f%%", d.critDamage * 100)),
            ("Guard Chance", pct(d.guardChance)),
            ("Guard Reduction", pct(d.guardDR)),
            ("Dodge Chance", pct(d.dodgeChance)),
            ("Energy Gain", pct(d.energyGainChance)),
            ("Incoming Heal", pct(d.incomingHeal)),
            ("Combat-End Heal", "\(d.combatEndHeal) HP"),
            ("Lifesteal Bonus", "+\(d.lifestealAmount)"),
            ("Lucky Drop", pct(d.luckyDrop)),
            ("Gold Find", "+" + pct(d.goldFind)),
            ("Shop Discount", pct(d.shopDiscount)),
            ("Shop Cards", "+\(d.shopExtraCards)"),
        ]
        return LazyVGrid(
            columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
            spacing: 6
        ) {
            ForEach(rows, id: \.0) { row in
                HStack(spacing: 6) {
                    Text(row.0).font(.pixel(bodyFont)).foregroundColor(.textMuted)
                    Spacer(minLength: 4)
                    Text(row.1).font(.pixel(bodyFont)).foregroundColor(.textParchment)
                }
            }
        }
    }

    // MARK: - Equipment panel (in the character screen)

    private func equipmentPanel(bodyFont: CGFloat, unit: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EQUIPMENT").font(.pixel(bodyFont * 1.1)).foregroundColor(.goldBright)

            // One row per slot; tap an equipped item to unequip it.
            ForEach(EquipmentSlot.allCases) { slot in
                HStack(spacing: 6) {
                    Text(slot.label).font(.pixel(bodyFont * 0.95)).foregroundColor(.textMuted)
                        .frame(width: bodyFont * 3.2, alignment: .leading)
                    if let item = engine.player.equippedItems[slot] {
                        Button { engine.unequip(slot) } label: {
                            HStack(spacing: 4) {
                                Text(item.name).font(.pixel(bodyFont * 0.95)).foregroundColor(.textParchment)
                                    .lineLimit(1)
                                Spacer(minLength: 2)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: bodyFont * 0.9)).foregroundColor(Color(hex: 0xCC6677))
                            }
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.goldAccent.opacity(0.20)))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.goldBorder.opacity(0.6), lineWidth: 1))
                        }.buttonStyle(.plain)
                    } else {
                        Text("Empty").font(.pixel(bodyFont * 0.95)).foregroundColor(Color(hex: 0x5A5268))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.25)))
                    }
                }
            }

            Text("INVENTORY").font(.pixel(bodyFont * 1.1)).foregroundColor(.goldBright).padding(.top, 2)
            ScrollView {
                VStack(spacing: 4) {
                    if engine.player.equipmentInventory.isEmpty {
                        Text("No spare equipment.")
                            .font(.pixel(bodyFont * 0.9)).foregroundColor(.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                    } else {
                        ForEach(engine.player.equipmentInventory) { item in
                            Button { engine.equip(item) } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack {
                                        Text(item.name).font(.pixel(bodyFont)).foregroundColor(.textParchment)
                                        Spacer()
                                        Text(item.slot.label).font(.pixel(bodyFont * 0.85)).foregroundColor(.textMuted)
                                    }
                                    Text(item.bonusSummary).font(.pixel(bodyFont * 0.85)).foregroundColor(.goldBright)
                                }
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.3)))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.goldBorder.opacity(0.4), lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
            // Fixed height → always a usable, scrollable region regardless of item count.
            .frame(height: unit * 0.2)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Result Screens (Victory / Defeat)

    /// Shared end-of-combat scaffold: Act-Floor header + title banner, the hero in the
    /// center, a rewards bar, and a right-aligned row of buttons. Victory and Defeat use
    /// the same layout — only the title, its color, the rewards, and the buttons differ.
    @ViewBuilder
    private func resultOverlay<Buttons: View>(
        unit: CGFloat,
        title: String,
        titleColor: Color,
        showRewards: Bool,
        @ViewBuilder buttons: () -> Buttons
    ) -> some View {
        let titleSize = min(unit * 0.10, 64)
        let heroSpriteH = min(unit * 0.15, 108)   // small so the title + rewards stay the focus

        VStack(spacing: 0) {
            // Header — Act-Floor number above the title banner (kept clear of the top edge).
            VStack(spacing: 2) {
                Text("\(engine.currentAct)-\(engine.currentFloor)")
                    .font(.pixel(titleSize * 0.5))
                    .foregroundColor(titleColor)
                overlayTitle(title, size: titleSize, color: titleColor)
            }
            .padding(.top, unit * 0.11)

            Spacer()

            // Center — the hero.
            CroppedSprite(name: "player_sprite", contentW: 0.33, contentH: 0.4375, targetH: heroSpriteH)
                .shadow(color: Color(hex: 0xA07830).opacity(0.4), radius: 14)

            Spacer()

            // Rewards bar (empty on defeat).
            rewardsBar(unit: unit, showRewards: showRewards)

            if showRewards && engine.lastStatPoints > 0 {
                Text("+\(engine.lastStatPoints) Stat Points")
                    .font(.pixel(min(unit * 0.032, 22)))
                    .foregroundColor(.goldBright)
                    .padding(.top, unit * 0.012)
            }

            // Buttons — right-aligned below the bar.
            HStack(spacing: unit * 0.025) {
                Spacer()
                buttons()
            }
            .padding(.horizontal, unit * 0.06)
            .padding(.top, unit * 0.03)
            .padding(.bottom, unit * 0.05)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func victoryOverlay(unit: CGFloat, btnFontSize: CGFloat) -> some View {
        resultOverlay(unit: unit, title: "VICTORY", titleColor: .goldBright, showRewards: true) {
            victoryButton("Exit", fontSize: btnFontSize, tint: Color(hex: 0x4A90C2)) {
                exitToTitle()   // run is kept intact; "Continue" picks it back up
            }
            // "Next" opens the full stats page; confirming there advances to the next stage.
            victoryButton("Next", fontSize: btnFontSize, tint: Color(hex: 0x5BA84F)) {
                pendingAlloc = [:]
                characterMode = .postVictory
                showCharacter = true
            }
        }
    }

    @ViewBuilder
    private func defeatOverlay(unit: CGFloat, btnFontSize: CGFloat) -> some View {
        resultOverlay(unit: unit, title: "DEFEAT", titleColor: Color(hex: 0xCC2244), showRewards: false) {
            victoryButton("Try Again", fontSize: btnFontSize, tint: Color(hex: 0xD86A8C)) {
                isEnemyTurn = false
                engine.startGame()      // restart the whole run from Act 1, Floor 1
                // The hand is dealt by `startRun()` once the opening scene finishes.
            }
            victoryButton("Exit", fontSize: btnFontSize, tint: Color(hex: 0x4A90C2)) {
                exitToTitle()   // run is kept intact; "Continue" picks it back up
            }
        }
    }

    /// The bar below the hero. On victory it holds the reward chips (the Clean Fight
    /// bonus in front of the normal gold); on defeat it's an empty bar of the same size.
    private func rewardsBar(unit: CGFloat, showRewards: Bool) -> some View {
        let chip = min(unit * 0.10, 76)
        return HStack(spacing: unit * 0.018) {
            if showRewards {
                if engine.lastBonusGold > 0 {
                    rewardChip(amount: engine.lastBonusGold, size: chip, bonusLabel: "Clean Fight")
                }
                rewardChip(amount: engine.lastGoldEarned, size: chip, bonusLabel: nil)
            } else {
                // Reserve the chip height so the empty bar matches the victory bar's size.
                Color.clear.frame(width: 1, height: chip * 1.8)
            }
        }
        .frame(maxWidth: .infinity)   // full-width bar, chip group centered
        .padding(.horizontal, unit * 0.05)
        .padding(.vertical, unit * 0.02)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: 0x1A1228).opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.goldBorder, lineWidth: 2))
        )
        .padding(.horizontal, unit * 0.04)
    }

    private func rewardChip(amount: Int, size: CGFloat, bonusLabel: String?) -> some View {
        VStack(spacing: 5) {
            // Bonus bubble — fixed-height row so chips with/without it align.
            // (Uses an empty ZStack, not Color.clear, so it never stretches width.)
            ZStack {
                if let bonusLabel {
                    Text(bonusLabel)
                        .font(.pixel(size * 0.26))
                        .foregroundColor(Color(hex: 0x3A2A10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(hex: 0xFFD966)))
                        .fixedSize()
                }
            }
            .frame(height: size * 0.36)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color(hex: 0x2E2340), Color(hex: 0x1A1228)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.goldBorder, lineWidth: 1.5))
                goldCoin(size: size * 0.62)
            }
            .frame(width: size, height: size)

            Text("+\(amount)")
                .font(.pixel(size * 0.34))
                .foregroundColor(.goldBright)
        }
        .fixedSize()   // hug content width — prevents the chip from expanding the bar
    }

    @ViewBuilder
    private func victoryButton(_ title: String, fontSize: CGFloat, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.pixel(fontSize))
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.55), lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shop

    @ViewBuilder
    private func shopOverlay(unit: CGFloat, btnFontSize: CGFloat) -> some View {
        let headerFont = min(unit * 0.06, 42)
        let bodyFont = min(unit * 0.03, 20)
        let cardH = min(unit * 0.24, 175)
        let cardW = cardH * 0.72

        VStack(spacing: unit * 0.02) {
            HStack {
                Text("SHOP").font(.pixel(headerFont)).foregroundColor(.goldBright)
                Spacer()
                HStack(spacing: 6) {
                    goldCoin(size: bodyFont * 1.2)
                    Text("\(engine.player.gold)").font(.pixel(bodyFont * 1.2)).foregroundColor(.goldBright)
                }
            }
            .padding(.horizontal, unit * 0.04)
            .padding(.top, unit * 0.02)

            ScrollView {
                VStack(alignment: .leading, spacing: unit * 0.025) {
                    Text("CARDS").font(.pixel(bodyFont * 1.2)).foregroundColor(.goldBright)
                    HStack(alignment: .top, spacing: unit * 0.012) {
                        ForEach(engine.shopCards) { offer in
                            VStack(spacing: 4) {
                                CardView(card: offer.card, isSelected: false,
                                         isAffordable: !offer.sold && engine.player.gold >= offer.price,
                                         showTooltip: tooltipCardId == offer.card.id,
                                         cardWidth: cardW, cardHeight: cardH)
                                    .opacity(offer.sold ? 0.3 : 1)
                                    .onLongPressGesture(minimumDuration: 0.3, pressing: { p in
                                        tooltipCardId = p ? offer.card.id : nil
                                    }, perform: {})
                                if offer.sold {
                                    Text("SOLD").font(.pixel(bodyFont)).foregroundColor(.textMuted)
                                } else {
                                    shopBuyButton(price: offer.price, bodyFont: bodyFont) { engine.buyCard(offer) }
                                }
                            }
                        }
                    }

                    Text("RELICS").font(.pixel(bodyFont * 1.2)).foregroundColor(.goldBright)
                    HStack(alignment: .top, spacing: unit * 0.02) {
                        ForEach(engine.shopRelics) { offer in
                            VStack(spacing: 4) {
                                CroppedSprite(name: offer.relic.iconName, contentW: offer.relic.iconContentW, contentH: offer.relic.iconContentH,
                                              targetH: bodyFont * 1.5, clipToContent: false)
                                    .opacity(offer.sold ? 0.3 : 1)
                                Text(offer.relic.name).font(.pixel(bodyFont * 0.95)).foregroundColor(.textParchment)
                                Text(offer.relic.description)
                                    .font(.pixel(bodyFont * 0.78)).foregroundColor(.textMuted)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(width: unit * 0.22)
                                if offer.sold {
                                    Text("SOLD").font(.pixel(bodyFont)).foregroundColor(.textMuted)
                                } else {
                                    shopBuyButton(price: offer.price, bodyFont: bodyFont) { engine.buyRelic(offer) }
                                }
                            }
                            .frame(width: unit * 0.24)
                        }
                    }

                    Text("SELL EQUIPMENT").font(.pixel(bodyFont * 1.2)).foregroundColor(.goldBright)
                    if engine.player.equipmentInventory.isEmpty {
                        Text("No spare equipment to sell.")
                            .font(.pixel(bodyFont * 0.95)).foregroundColor(.textMuted)
                    } else {
                        VStack(spacing: 5) {
                            ForEach(engine.player.equipmentInventory) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.name).font(.pixel(bodyFont)).foregroundColor(.textParchment)
                                        Text(item.bonusSummary).font(.pixel(bodyFont * 0.85)).foregroundColor(.goldBright)
                                    }
                                    Spacer()
                                    Button { engine.sellEquipment(item) } label: {
                                        HStack(spacing: 4) {
                                            Text("Sell").font(.pixel(bodyFont * 0.9)).foregroundColor(.textParchment)
                                            goldCoin(size: bodyFont * 0.9)
                                            Text("\(item.sellValue)").font(.pixel(bodyFont * 0.9)).foregroundColor(.goldBright)
                                        }
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.35)))
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.goldBorder.opacity(0.6), lineWidth: 1))
                                    }.buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.25)))
                            }
                        }
                    }
                }
                .padding(.horizontal, unit * 0.04)
                .padding(.bottom, unit * 0.02)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)   // always fill, so the shop keeps its size when empty

            overlayButton("LEAVE SHOP", fontSize: btnFontSize) {
                isEnemyTurn = false
                engine.leaveShop()
                if engine.gameState == .playing { dealNewHand() }
            }
            .padding(.bottom, unit * 0.03)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shopBuyButton(price: Int, bodyFont: CGFloat, action: @escaping () -> Void) -> some View {
        let affordable = engine.player.gold >= price
        return Button(action: action) {
            HStack(spacing: 3) {
                goldCoin(size: bodyFont * 0.9)
                Text("\(price)").font(.pixel(bodyFont))
                    .foregroundColor(affordable ? .goldBright : Color(hex: 0xAA5555))
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.4)))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(affordable ? Color.goldBorder : Color(hex: 0x5A3A3A), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!affordable)
    }

    // MARK: - Relic Tooltip

    /// The hover/hold bubble for a HUD relic icon: its name (gold) over its description.
    /// Fixed width, but height grows to fit — the full description always wraps into view.
    private func relicTooltipBubble(_ relic: Relic) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(relic.name)
                .font(.pixel(16))
                .foregroundColor(.goldBright)
                .fixedSize(horizontal: false, vertical: true)
            Text(relic.description)
                .font(.pixel(14))
                .foregroundColor(.textParchment)
                .fixedSize(horizontal: false, vertical: true)   // wrap fully, never truncate
        }
        .frame(width: 220, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x1A1428).opacity(0.97)))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.goldBorder, lineWidth: 1))
    }

    // MARK: - Card Draft (Floor 3)

    @ViewBuilder
    private func draftOverlay(unit: CGFloat, btnFontSize: CGFloat) -> some View {
        let draftCardH = min(unit * 0.34, 300)
        let draftCardW = draftCardH * 0.72

        VStack(spacing: unit * 0.05) {
            Text("Choose a Card to Add to Your Deck")
                .font(.pixel(min(unit * 0.05, 34)))
                .foregroundColor(.goldBright)
                .shadow(color: Color.goldBright.opacity(0.5), radius: 10)

            HStack(spacing: unit * 0.04) {
                ForEach(draftCards) { card in
                    let dealt = draftDealtIds.contains(card.id)
                    let revealed = draftRevealedIds.contains(card.id)
                    let selected = draftSelectedId == card.id
                    Group {
                        if revealed {
                            CardView(card: card, isSelected: selected, isAffordable: true,
                                     showTooltip: tooltipCardId == card.id,
                                     cardWidth: draftCardW, cardHeight: draftCardH)
                        } else {
                            FaceDownCard(width: draftCardW, height: draftCardH)
                        }
                    }
                    .opacity(dealt ? 1 : 0)
                    .scaleEffect(dealt ? 1 : 0.6)
                    .offset(y: selected ? -draftCardH * 0.08 : 0)
                    .zIndex(tooltipCardId == card.id ? 10 : (selected ? 5 : 0))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard revealed else { return }
                        tooltipCardId = nil
                        withAnimation(.easeOut(duration: 0.15)) {
                            draftSelectedId = card.id
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            tooltipCardId = (pressing && revealed) ? card.id : nil
                        }
                    }, perform: {})
                }
            }

            overlayButton("SELECT CARD", fontSize: btnFontSize) {
                guard let id = draftSelectedId,
                      let card = draftCards.first(where: { $0.id == id }) else { return }
                tooltipCardId = nil
                engine.draftCard(card)
                if engine.gameState == .playing { dealNewHand() }
            }
            .opacity(draftSelectedId == nil ? 0.4 : 1.0)
            .disabled(draftSelectedId == nil)
        }
        .onAppear {
            draftSelectedId = nil
            let cards = Card.availableDraftCards
            draftCards = cards
            dealDraftCards(cards)
        }
    }

    /// Flip the given draft cards in one-by-one from left to right.
    private func dealDraftCards(_ cards: [Card]) {
        draftDealtIds.removeAll()
        draftRevealedIds.removeAll()
        for (index, card) in cards.enumerated() {
            let delay = Double(index) * 0.18
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.easeOut(duration: 0.28)) {
                    draftDealtIds.insert(card.id)
                }
                try? await Task.sleep(for: .seconds(0.28))
                withAnimation(.easeInOut(duration: 0.08)) {
                    draftRevealedIds.insert(card.id)
                }
            }
        }
    }

    // MARK: - Turn Resolution Orchestrator

    // Frame sequence durations (frameCount steps * 0.08s + lingering buffer).
    private let attackAnimDuration = 0.72   // 9 frames
    private let healAnimDuration = 0.8      // 10 frames
    private let comprehendPause = 0.8       // beat so the user can read the board

    /// Show the prominent relic reveal if one was just earned. Stays up until the
    /// player taps anywhere to close it. No-op if nothing was earned.
    @MainActor
    private func revealEarnedRelicIfAny() async {
        guard let relic = engine.justEarnedRelic else { return }
        engine.justEarnedRelic = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            earnedRelicBanner = relic
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            relicBannerContinuation = cont
        }
        withAnimation(.easeOut(duration: 0.3)) { earnedRelicBanner = nil }
        try? await Task.sleep(for: .seconds(0.35))
    }

    /// Flash a hidden-combo notification for a beat (no tap needed — it's mid-combat).
    @MainActor
    private func showComboBanner(_ name: String) async {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { comboBanner = name }
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.easeOut(duration: 0.3)) { comboBanner = nil }
        try? await Task.sleep(for: .seconds(0.25))
    }

    /// Reveal each equipment piece dropped this floor, one at a time (tap to continue).
    @MainActor
    private func revealEarnedEquipmentIfAny() async {
        while !engine.justEarnedEquipment.isEmpty {
            let item = engine.justEarnedEquipment.removeFirst()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                earnedEquipmentBanner = item
            }
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                equipmentBannerContinuation = cont
            }
            withAnimation(.easeOut(duration: 0.3)) { earnedEquipmentBanner = nil }
            try? await Task.sleep(for: .seconds(0.3))
        }
    }

    /// Combat won: reveal any relic + equipment not yet shown, then the VICTORY screen.
    @MainActor
    private func handleCombatWon() async {
        isEnemyTurn = false
        try? await Task.sleep(for: .seconds(0.55))
        // Post-fight scene before any reward UI. Already-played scenes no-op, so the
        // enemy-turn kill path and this one can both ask safely.
        await playFloorEndScene()
        await revealEarnedRelicIfAny()       // covers the dev-SKIP path
        await revealEarnedEquipmentIfAny()   // equipment drops
        // gameState stays .victory → the victory overlay (Next Stage / Restart) shows.
        engine.isResolvingTurn = false
    }

    /// Commit a dragged card immediately (it leaves the hand + spends energy) and queue
    /// its effect. The queue resolves plays one at a time, so the player can keep firing
    /// off cards without waiting for the previous one's animation to finish.
    private func playCardNow(_ card: Card) {
        guard engine.gameState == .playing, engine.canAfford(card) else { return }
        tooltipCardId = nil
        let target = engine.targetIndex                 // capture the aim at play time
        engine.commitCardPlay(card)                     // leave hand + spend energy now
        pendingPlays.append(QueuedPlay(card: card, targetIndex: target))
        processPendingPlays()                           // no-op if already running
    }

    /// Drain the play queue: park each card in the center (hold, fade), then apply its
    /// effect + hit/shield animation, one after another.
    private func processPendingPlays() {
        guard !isProcessingPlays else { return }
        isProcessingPlays = true

        Task { @MainActor in
            while !pendingPlays.isEmpty {
                let play = pendingPlays.removeFirst()
                let card = play.card

                // 1. Park the card in the center so the player registers what they played.
                resolvingCard = card
                resolvingCardOpacity = 1.0
                try? await Task.sleep(for: .seconds(0.6))

                // 2. Fade it away.
                withAnimation(.easeIn(duration: 0.28)) { resolvingCardOpacity = 0.0 }
                try? await Task.sleep(for: .seconds(0.28))
                resolvingCard = nil

                // 3. Apply the effect + VFX. Cleave hits every enemy still alive right now;
                // a normal attack hits the target the player aimed at when they played it.
                let willAttack = card.damage > 0
                let willShield = card.block > 0
                let attackedIndices: [Int] = card.hitsAllEnemies
                    ? engine.enemies.indices.filter { engine.enemies[$0].isAlive }
                    : [play.targetIndex]
                engine.resolveCardEffect(card, targetIndex: play.targetIndex)

                if willAttack { for idx in attackedIndices { setEnemyVFX(.attack, at: idx) } }
                if willShield { setPlayerVFX(.healDebuff) }
                let anim = max(willAttack ? attackAnimDuration : 0, willShield ? healAnimDuration : 0)
                if anim > 0 {
                    try? await Task.sleep(for: .seconds(anim))
                    clearVFX()
                }

                // A hidden combo may have fired — announce it.
                if let combo = engine.justTriggeredCombo {
                    engine.justTriggeredCombo = nil
                    await showComboBanner(combo)
                }

                // The floor's post-fight scene lands first — a dying taunt reads wrong
                // after a rewards screen. Claim the turn first: resolving a card sets
                // .victory immediately, and without this the VICTORY screen would draw
                // underneath the scene and the reward banners instead of waiting for them.
                // (`handleCombatWon` clears it once every reveal has been dismissed.)
                if engine.gameState == .victory {
                    engine.isResolvingTurn = true
                    await playFloorEndScene()
                }

                // Reveal a relic (only if the floor was cleared) and run the victory flow.
                await revealEarnedRelicIfAny()
                if engine.gameState != .playing {
                    pendingPlays.removeAll()   // combat ended — drop any remaining queued cards
                    if engine.gameState == .victory { await handleCombatWon() }
                    isProcessingPlays = false
                    return
                }
            }
            isProcessingPlays = false
        }
    }

    /// End the player's turn: run the enemies' moves, then deal a fresh hand. Card play
    /// happens live during the turn now, so this no longer plays any of the player's cards.
    private func endPlayerTurn(size: CGSize) {
        guard !engine.isResolvingTurn, !isProcessingPlays, engine.gameState == .playing else { return }
        engine.isResolvingTurn = true
        tooltipCardId = nil
        engine.clearSelection()   // drop any selected-but-unplayed cards

        Task { @MainActor in
            // 1. Short beat after End Turn.
            try? await Task.sleep(for: .seconds(0.3))

            // 2. Enemy turn notification — dim the hand so cards read as unplayable.
            withAnimation(.easeInOut(duration: 0.25)) { isEnemyTurn = true }
            await showBanner(.enemyTurn, hold: 0.9)
            try? await Task.sleep(for: .seconds(0.3))

            // 3. Resolve each enemy's move ONE AT A TIME, so a multi-enemy turn reads as
            //    separate hits (each rolls Dodge/Guard on its own, with its own number).
            for index in engine.enemies.indices {
                guard engine.gameState == .playing else { break }
                let enemy = engine.enemies[index]
                guard enemy.isAlive else { continue }

                let attacks = enemy.moveAttacksPlayer
                let buffs = enemy.moveGainsBlock
                let gooSpit = enemy.moveGooSpits

                if attacks { setPlayerVFX(.attack) }
                if buffs { setEnemyVFX(.healDebuff, at: index) }
                engine.runEnemyMove(at: index)   // applies this one hit + sets its flash

                if gooSpit {
                    await playGooSpit(size: size)
                }
                let anim = max(attacks ? attackAnimDuration : 0, buffs ? healAnimDuration : 0)
                if anim > 0 {
                    try? await Task.sleep(for: .seconds(anim))
                    clearVFX()
                }
                if engine.gameState != .playing { break }
                // Brief beat between enemies so the hits read separately.
                try? await Task.sleep(for: .seconds(0.22))
            }

            // Combat can also END during the enemy turn — most often a Poison tick killing
            // the last enemy at the start of its turn. Route that through the same victory
            // flow as a card kill, or the post-fight scene and reward reveals are skipped.
            if engine.gameState != .playing {
                isEnemyTurn = false
                if engine.gameState == .victory {
                    await handleCombatWon()      // scene → relic → equipment → VICTORY
                } else {
                    engine.isResolvingTurn = false
                }
                return
            }

            // 4. Let the enemy's result sink in.
            try? await Task.sleep(for: .seconds(comprehendPause))

            // 5. Player turn notification — restore the hand's brightness.
            withAnimation(.easeInOut(duration: 0.25)) { isEnemyTurn = false }
            await showBanner(.playerTurn, hold: 0.9)
            try? await Task.sleep(for: .seconds(0.3))

            // 6. Swap out the old hand and deal fresh cards.
            engine.discardHand()
            engine.beginNextTurn()
            engine.isResolvingTurn = false
            dealNewHand()
        }
    }

    @MainActor
    private func showBanner(_ banner: TurnBanner, hold: Double) async {
        withAnimation(.easeInOut(duration: 0.2)) { engine.turnBanner = banner }
        try? await Task.sleep(for: .seconds(hold))
        withAnimation(.easeInOut(duration: 0.2)) { engine.turnBanner = .none }
        try? await Task.sleep(for: .seconds(0.1))
    }

    @MainActor
    private func setPlayerVFX(_ vfx: SpriteVFX) {
        withAnimation(.easeOut(duration: 0.15)) {
            engine.playerVFX = vfx
        }
    }

    @MainActor
    private func setEnemyVFX(_ vfx: SpriteVFX, at index: Int) {
        guard engine.enemies.indices.contains(index) else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            engine.enemies[index].vfx = vfx
        }
    }

    @MainActor
    private func clearVFX() {
        withAnimation(.easeOut(duration: 0.2)) {
            engine.playerVFX = .none
            for enemy in engine.enemies { enemy.vfx = .none }
        }
    }

    /// Fly the goo-spit projectile from the boss toward the player, cycling frames.
    @MainActor
    private func playGooSpit(size: CGSize) async {
        gooSpitFrame = 0
        gooSpitProgress = 0
        gooSpitActive = true

        // Travel across the screen at constant speed (straight line)…
        withAnimation(.linear(duration: 0.72)) { gooSpitProgress = 1.0 }
        // …while stepping through the 8 sprite frames.
        for i in 0..<8 {
            gooSpitFrame = i
            try? await Task.sleep(for: .seconds(0.09))
        }

        gooSpitActive = false
        gooSpitProgress = 0
        gooSpitFrame = 0
    }

    // MARK: - Deal Animation

    private func dealNewHand() {
        dealtCardIds.removeAll()
        revealedCardIds.removeAll()

        let hand = engine.deck.hand
        for (index, card) in hand.enumerated() {
            let slideDelay = Double(index) * 0.10

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(slideDelay))
                withAnimation(.easeOut(duration: 0.28)) {
                    dealtCardIds.insert(card.id)
                }
                try? await Task.sleep(for: .seconds(0.28))
                // Fire the flip a hair before the animation: audio goes through an output
                // buffer, the frame doesn't. One per card, never debounced away.
                AudioManager.shared.play(.cardFlip, debounced: false)
                withAnimation(.easeInOut(duration: 0.08)) {
                    revealedCardIds.insert(card.id)
                }
            }
        }
    }
}

// MARK: - Card View

/// A card's rules text with any number a status has moved picked out in colour —
/// red when a debuff shrank it (Frail on Block, Weak on damage), green when a buff grew it.
func cardRulesText(_ card: Card, status: StatusEffects, base: Color = .textParchment) -> Text {
    var out = Text("")
    for (index, part) in card.descriptionParts(for: status).enumerated() {
        if index > 0 { out = out + Text(" ").foregroundColor(base) }
        out = out + Text(part.prefix).foregroundColor(base)
        if let value = part.value {
            let tint: Color = part.change == nil
                ? base
                : (part.change == .reduced ? Color(hex: 0xE2564F) : Color(hex: 0x76E06A))
            out = out + Text(value).foregroundColor(tint).bold()
        }
        out = out + Text(part.suffix).foregroundColor(base)
    }
    return out
}

struct CardView: View {
    let card: Card
    let isSelected: Bool
    let isAffordable: Bool
    let showTooltip: Bool
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    /// Statuses of whoever holds the card, so the tooltip shows the numbers you'll
    /// actually get. Defaults to none for out-of-combat screens (shop, draft).
    var ownerStatus: StatusEffects = StatusEffects()

    var body: some View {
        cardContent
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .brightness(isSelected ? 0.08 : (isAffordable ? 0 : -0.15))
            .saturation(isAffordable ? 1.0 : 0.3)
            .shadow(
                color: isSelected
                    ? Color.goldBright.opacity(0.7)
                    : .clear,
                radius: isSelected ? 14 : 0
            )
            .shadow(
                color: isSelected ? Color.goldBright.opacity(0.35) : .clear,
                radius: isSelected ? 24 : 0
            )
            .overlay(alignment: .top) {
                if showTooltip {
                    cardRulesText(card, status: ownerStatus)
                        .font(.pixel(max(cardWidth * 0.12, 14)))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: 0x1A1428).opacity(0.95))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.goldBorder, lineWidth: 1)
                        )
                        .fixedSize()
                        .offset(y: -cardHeight * 0.30)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
    }

    @ViewBuilder
    private var cardContent: some View {
        if let imageName = card.imageName {
            Image(imageName)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fill)
        } else {
            fallbackCard
        }
    }

    // Text-based card face for cards without pixel art (draft cards).
    private var fallbackCard: some View {
        let attack = card.type == .attack
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                Text(card.name)
                    .font(.pixel(cardWidth * 0.15))
                    .foregroundColor(.textParchment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(Color(hex: 0x8A3FD0))
                        .frame(width: cardWidth * 0.22, height: cardWidth * 0.22)
                    Text("\(card.energyCost)")
                        .font(.pixel(cardWidth * 0.15))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, cardWidth * 0.08)
            .padding(.top, cardWidth * 0.06)

            Rectangle()
                .fill(Color.goldBorder.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, cardWidth * 0.08)
                .padding(.vertical, cardHeight * 0.03)

            Spacer(minLength: 0)

            Text(card.description)
                .font(.pixel(cardWidth * 0.125))
                .foregroundColor(Color(hex: 0xC8BCA0))
                .multilineTextAlignment(.center)
                .padding(.horizontal, cardWidth * 0.09)

            Spacer(minLength: 0)

            Text(card.type.rawValue.uppercased())
                .font(.pixel(cardWidth * 0.09))
                .foregroundColor(.textMuted)
                .padding(.bottom, cardHeight * 0.05)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            LinearGradient(
                colors: attack
                    ? [Color(hex: 0x3A1520), Color(hex: 0x240E14)]
                    : [Color(hex: 0x172A3C), Color(hex: 0x0E1A28)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.goldBorder, lineWidth: 1.5)
        )
    }
}

#Preview {
    ContentView()
}
