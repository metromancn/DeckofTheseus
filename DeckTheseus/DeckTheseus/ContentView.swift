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

    var body: some View {
        let full = targetH / contentH   // scale the whole canvas so content == targetH
        Image(name)
            .resizable()
            .interpolation(.none)
            .frame(width: full, height: full)
            .frame(width: full * contentW, height: targetH)  // clip layout to content
            .clipped()
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

    // Which status badge is being hovered/held (shows its description bubble).
    @State private var hoveredStatus: String? = nil

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
                if enemy.vulnerableTurns > 0 || enemy.poison > 0 || enemy.weak > 0 || enemy.stun > 0 {
                    HStack(spacing: heartSize * 0.06) {
                        // Placeholder status badges (no sprites yet).
                        if enemy.vulnerableTurns > 0 { statusBadge("VULN \(enemy.vulnerableTurns)", key: "vuln", color: Color(hex: 0xC0455E)) }
                        if enemy.poison > 0 { statusBadge("PSN \(enemy.poison)", key: "psn", color: Color(hex: 0x8A3EB0)) }
                        if enemy.weak > 0   { statusBadge("WEAK \(enemy.weak)", key: "weak", color: Color(hex: 0xC06A2E)) }
                        if enemy.stun > 0   { statusBadge("STUN \(enemy.stun)", key: "stun", color: Color(hex: 0x3E7AC0)) }
                    }
                    .overlay(alignment: .bottom) {
                        if let key = hoveredStatus, let info = statusInfo(key) {
                            statusTooltip(info)
                                .offset(y: -(heartSize * 0.55))
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }

    private func statusBadge(_ text: String, key: String, color: Color) -> some View {
        Text(text)
            .font(.pixel(heartSize * 0.28))
            .foregroundColor(.white)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(color))
            // Hover (pointer) or hold (touch) reveals the description bubble.
            .onHover { hovering in
                if hovering { hoveredStatus = key }
                else if hoveredStatus == key { hoveredStatus = nil }
            }
            .onLongPressGesture(minimumDuration: 0.2) {
                hoveredStatus = (hoveredStatus == key) ? nil : key
            }
    }

    /// Title + description for a status badge, with its number's meaning spelled out.
    private func statusInfo(_ key: String) -> (title: String, desc: String)? {
        switch key {
        case "vuln":
            return ("VULNERABLE \(enemy.vulnerableTurns)",
                    "Takes +50% damage from your attacks per stack — now +\(enemy.vulnerableTurns * 50)%. Stacks add up and last the whole fight.")
        case "psn":
            return ("POISON \(enemy.poison)",
                    "Loses 3 HP at the start of its turn, then 1 stack falls off. The number is how many turns of poison remain.")
        case "weak":
            return ("WEAK \(enemy.weak)",
                    "Its attacks deal 25% less damage. The number is how many of its turns this lasts (−1 each turn).")
        case "stun":
            return ("STUN \(enemy.stun)",
                    "Skips its turn entirely (poison still hurts it). The number is how many turns it stays stunned (−1 each turn).")
        default:
            return nil
        }
    }

    private func statusTooltip(_ info: (title: String, desc: String)) -> some View {
        VStack(spacing: 3) {
            Text(info.title)
                .font(.pixel(heartSize * 0.26))
                .foregroundColor(.goldBright)
            Text(info.desc)
                .font(.pixel(heartSize * 0.22))
                .foregroundColor(.textParchment)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .frame(width: max(barWidth * 1.5, heartSize * 3.0))
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

                    HStack(spacing: 4) {
                        HealthBarView(currentHp: engine.player.currentHp, maxHp: engine.player.maxHp,
                                      width: heartSize * 1.9, height: heartSize * 0.42)

                        ShieldView(block: engine.displayPlayerBlock, size: heartSize * 0.30)
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
                            barWidth: enemyBarW
                        )
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
                                    cardHeight: cardH
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

                            CroppedSprite(name: relic.iconName, contentW: 0.578, contentH: 0.266,
                                          targetH: min(unit * 0.09, 72))
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
                                overlayTitle("ACT \(engine.currentAct) COMPLETE", size: titleFontSize * 0.6, color: .goldBright)
                                Text("You conquered the Slime Biome!")
                                    .font(.pixel(btnFontSize * 1.2))
                                    .foregroundColor(.textParchment)

                            case .victory, .defeat, .shop, .drafting, .playing:
                                EmptyView()
                            }
                        }
                        .zIndex(999)
                    }
                }

                // DEV tools (top-right) — floor picker (always) + instant-win SKIP (in combat).
                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        showDevPanel = true
                    } label: {
                        Text("DEV \u{25BC}")
                            .font(.pixel(titleFont * 0.85))
                            .foregroundColor(Color(hex: 0xE0C0F0))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x2A1E3A).opacity(0.85)))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: 0x6A4A8A), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)

                    if engine.gameState == .playing {
                        Button {
                            guard engine.gameState == .playing, !engine.isResolvingTurn, !isProcessingPlays else { return }
                            isEnemyTurn = false
                            engine.devWinCombat()          // kills all enemies, awards relic, marks .victory
                            Task { @MainActor in await handleCombatWon() }
                        } label: {
                            Text("SKIP \u{25B6}")
                                .font(.pixel(titleFont * 0.85))
                                .foregroundColor(Color(hex: 0xE0C0F0))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x2A1E3A).opacity(0.85)))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: 0x6A4A8A), lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 20)
                .padding(.top, 52)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(1500)

                if showDevPanel {
                    devPanel(unit: unit)
                        .zIndex(1600)
                }
            }
        }
        .background(Color.bgDeep)
        .ignoresSafeArea()
        .onAppear {
            playerPulsing = true
            enemyPulsing = true
            dealNewHand()
        }
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
        CroppedSprite(name: relic.iconName, contentW: 0.578, contentH: 0.266, targetH: size)
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
                // No-op for now — returns to the Map once the mapping system exists.
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
                dealNewHand()
            }
            victoryButton("Exit", fontSize: btnFontSize, tint: Color(hex: 0x4A90C2)) {
                // No-op for now — returns to the Map once the mapping system exists.
            }
        }
    }

    /// The bar below the hero. On victory it holds the reward chips (first-win bonus in
    /// front of the normal gold); on defeat it's an empty bar of the same size.
    private func rewardsBar(unit: CGFloat, showRewards: Bool) -> some View {
        let chip = min(unit * 0.10, 76)
        return HStack(spacing: unit * 0.018) {
            if showRewards {
                if engine.lastFirstWinBonus > 0 {
                    rewardChip(amount: engine.lastFirstWinBonus, size: chip, firstWin: true)
                }
                rewardChip(amount: engine.lastGoldEarned, size: chip, firstWin: false)
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

    private func rewardChip(amount: Int, size: CGFloat, firstWin: Bool) -> some View {
        VStack(spacing: 5) {
            // "First Win" bubble — fixed-height row so chips with/without it align.
            // (Uses an empty ZStack, not Color.clear, so it never stretches width.)
            ZStack {
                if firstWin {
                    Text("First Win")
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
                                CroppedSprite(name: offer.relic.iconName, contentW: 0.578, contentH: 0.266,
                                              targetH: bodyFont * 1.5)
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

            if engine.gameState != .playing { isEnemyTurn = false; engine.isResolvingTurn = false; return }

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
                withAnimation(.easeInOut(duration: 0.08)) {
                    revealedCardIds.insert(card.id)
                }
            }
        }
    }
}

// MARK: - Card View

struct CardView: View {
    let card: Card
    let isSelected: Bool
    let isAffordable: Bool
    let showTooltip: Bool
    let cardWidth: CGFloat
    let cardHeight: CGFloat

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
                    Text(card.description)
                        .font(.pixel(max(cardWidth * 0.12, 14)))
                        .foregroundColor(.textParchment)
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
