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

struct HealthHeartsView: View {
    let currentHp: Int
    let maxHp: Int
    let heartSize: CGFloat
    var depleteFromLeft: Bool = false

    private let hpPerHeart = 20

    private var heartCount: Int { maxHp / hpPerHeart }

    private func heartImage(at index: Int) -> String {
        // Which "logical" slot this display position maps to. When depleting
        // from the left, the leftmost icon empties first (full hearts stay right).
        let slot = depleteFromLeft ? (heartCount - 1 - index) : index
        let heartHp = currentHp - slot * hpPerHeart
        if heartHp >= 11 {
            return "health_heart_full"
        } else if heartHp >= 1 {
            return "health_heart_half"
        } else {
            return "health_heart_none"
        }
    }

    var body: some View {
        HStack(spacing: -heartSize * 0.55) {
            ForEach(Array(0..<heartCount), id: \.self) { index in
                Image(heartImage(at: index))
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: heartSize, height: heartSize)
            }
        }
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

                // Top-left: Floor-Act + Turn
                HStack(spacing: 12) {
                    Text("1-4")
                        .font(.pixel(titleFont * 1.2))
                        .foregroundColor(.textParchment)

                    Text("Turn \(engine.currentTurn)")
                        .font(.pixel(titleFont))
                        .foregroundColor(.textMuted)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

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
                        .frame(height: bossSpriteH, alignment: .bottom)   // stand on the same ground as the boss

                    HStack(spacing: 2) {
                        HealthHeartsView(
                            currentHp: engine.player.currentHp,
                            maxHp: engine.player.maxHp,
                            heartSize: heartSize
                        )

                        ShieldView(block: engine.displayPlayerBlock, size: heartSize * 0.30)
                    }
                }
                .padding(.top, spriteTopPad)
                .padding(.leading, sideMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // Boss (RIGHT) — compact, right-aligned; hearts deplete from the left; status under hearts
                VStack(alignment: .trailing, spacing: statGap) {
                    Text("Slime King")
                        .font(.pixel(nameFont))
                        .foregroundColor(.textParchment)
                        .frame(width: bossSpriteH * 1.055, height: nameFont * 1.3, alignment: .trailing)
                        .padding(.bottom, statGap)

                    CroppedSprite(name: "boss_slime", contentW: 0.61, contentH: 0.578, targetH: bossSpriteH)
                        .shadow(color: Color(hex: 0x32B45A).opacity(0.4), radius: 20)
                        .scaleEffect(enemyPulsing ? 1.03 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.75).repeatForever(autoreverses: true),
                            value: enemyPulsing
                        )
                        .overlay {
                            SpriteVFXView(vfx: engine.enemyVFX, size: bossSpriteH * 0.9)
                        }
                        .frame(height: bossSpriteH, alignment: .bottom)   // shared ground line

                    // Hearts+shield, then status directly underneath (aligned to the bar's left edge)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 2) {
                            HealthHeartsView(
                                currentHp: engine.enemy.currentHp,
                                maxHp: engine.enemy.maxHp,
                                heartSize: heartSize,
                                depleteFromLeft: true
                            )

                            ShieldView(block: engine.enemy.currentBlock, size: heartSize * 0.30)
                        }

                        if engine.enemy.vulnerableTurns > 0 {
                            HStack(spacing: heartSize * 0.04) {
                                ForEach(Array(0..<engine.enemy.vulnerableTurns), id: \.self) { _ in
                                    CroppedSprite(name: "status_vulnerable", contentW: 0.234, contentH: 0.297, targetH: heartSize * 0.34)
                                }
                            }
                            .padding(.top, -heartSize * 0.42)
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

                // Bottom-RIGHT: Energy directly above End Turn (compact)
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 6) {
                        PixelImage(name: "hud_energy_orb", width: orbSize * 0.7, height: orbSize * 0.7)
                            .shadow(color: Color(hex: 0xA040D0).opacity(0.6), radius: 10)

                        Text("\(engine.remainingEnergy)/\(engine.player.maxEnergy)")
                            .font(.pixel(orbSize * 0.45))
                            .foregroundColor(Color(hex: 0xE0C0F0))
                    }

                    Button {
                        resolveTurn()
                    } label: {
                        CroppedSprite(name: "end_turn", contentW: 0.67, contentH: 0.1875, targetH: orbSize * 0.55)
                    }
                    .buttonStyle(.plain)
                    .disabled(engine.isResolvingTurn)
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

                    ForEach(Array(engine.deck.hand.enumerated()), id: \.element.id) { index, card in
                        let t = count > 1 ? (Double(index) - mid) / mid : 0
                        let fanAngle = t * 8.0 * spreadScale
                        let fanX = t * Double(handWidth) * 0.42 * spreadScale
                        let fanY = abs(t) * 8.0 * spreadScale

                        let isDealt = dealtCardIds.contains(card.id)
                        let isRevealed = revealedCardIds.contains(card.id)
                        let isSelected = engine.selectedCardIds.contains(card.id)

                        let startX = Double(-handWidth) * 0.55
                        let currentX = isDealt ? fanX : startX
                        let currentY = (isDealt ? fanY : 0) + (isSelected ? -cardH * 0.15 : 0)
                        let currentAngle = isDealt ? fanAngle : 0

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
                        .offset(x: currentX, y: currentY)
                        .rotationEffect(.degrees(currentAngle), anchor: .bottom)
                        .zIndex(
                            tooltipCardId == card.id ? 200 :
                            isSelected ? 100 + Double(index) :
                            Double(index)
                        )
                        .allowsHitTesting(isRevealed && !engine.isResolvingTurn)
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.15)) {
                                engine.toggleSelection(card.id)
                            }
                        }
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

                // Win/Loss overlay
                if engine.gameState != .playing {
                    Color.black.opacity(0.75)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Text(engine.gameState == .victory ? "VICTORY" : "DEFEAT")
                            .font(.pixel(min(unit * 0.12, 80)))
                            .foregroundColor(engine.gameState == .victory ? .goldBright : Color(hex: 0xCC2244))
                            .shadow(
                                color: engine.gameState == .victory
                                    ? Color.goldBright.opacity(0.6)
                                    : Color(hex: 0xCC2244).opacity(0.6),
                                radius: 16
                            )

                        Button {
                            engine.restartCombat()
                            dealNewHand()
                        } label: {
                            Text("RESTART")
                                .font(.pixel(min(unit * 0.05, 32)))
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
                    .zIndex(999)
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

    // MARK: - Turn Resolution Orchestrator

    // Frame sequence durations (frameCount steps * 0.08s + lingering buffer).
    private let attackAnimDuration = 0.72   // 9 frames
    private let healAnimDuration = 0.8      // 10 frames
    private let comprehendPause = 0.8       // beat so the user can read the board

    private func resolveTurn() {
        guard !engine.isResolvingTurn, engine.gameState == .playing else { return }
        engine.isResolvingTurn = true
        tooltipCardId = nil

        // Snapshot what the player's selection will do before it's consumed.
        let playerWillAttack = engine.selectedDealsDamage
        let playerWillShield = engine.selectedGivesBlock

        Task { @MainActor in
            // 1. Short beat after pressing End Turn — the player's hand stays on screen.
            try? await Task.sleep(for: .seconds(0.35))

            // 2. Resolve the player's cards, then play their animation.
            engine.playSelectedCards()
            if playerWillAttack { triggerVFX(.attack, on: \.enemyVFX) }
            if playerWillShield { triggerVFX(.healDebuff, on: \.playerVFX) }
            let playerAnim = max(playerWillAttack ? attackAnimDuration : 0,
                                 playerWillShield ? healAnimDuration : 0)
            if playerAnim > 0 {
                try? await Task.sleep(for: .seconds(playerAnim))
                clearVFX()
            }

            if engine.gameState != .playing { engine.isResolvingTurn = false; return }

            // 3. Let the result sink in before the enemy acts.
            try? await Task.sleep(for: .seconds(comprehendPause))

            // 4. Enemy turn notification — dim the hand so cards read as unplayable.
            withAnimation(.easeInOut(duration: 0.25)) { isEnemyTurn = true }
            await showBanner(.enemyTurn, hold: 0.9)
            try? await Task.sleep(for: .seconds(0.3))

            // 5. Resolve the enemy's queued move, then play its animation.
            let enemyWillAttack = engine.enemyIntentAttacks
            let enemyWillBuffSelf = engine.enemyIntentBuffsSelf
            engine.runEnemyTurn()
            if enemyWillAttack { triggerVFX(.attack, on: \.playerVFX) }
            if enemyWillBuffSelf { triggerVFX(.healDebuff, on: \.enemyVFX) }
            let enemyAnim = max(enemyWillAttack ? attackAnimDuration : 0,
                                enemyWillBuffSelf ? healAnimDuration : 0)
            if enemyAnim > 0 {
                try? await Task.sleep(for: .seconds(enemyAnim))
                clearVFX()
            }

            if engine.gameState != .playing { isEnemyTurn = false; engine.isResolvingTurn = false; return }

            // 6. Let the enemy's result sink in.
            try? await Task.sleep(for: .seconds(comprehendPause))

            // 7. Player turn notification — restore the hand's brightness.
            withAnimation(.easeInOut(duration: 0.25)) { isEnemyTurn = false }
            await showBanner(.playerTurn, hold: 0.9)
            try? await Task.sleep(for: .seconds(0.3))

            // 8. Now swap out the old hand and deal fresh cards.
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
    private func triggerVFX(_ vfx: SpriteVFX, on keyPath: ReferenceWritableKeyPath<GameEngine, SpriteVFX>) {
        withAnimation(.easeOut(duration: 0.15)) {
            engine[keyPath: keyPath] = vfx
        }
    }

    @MainActor
    private func clearVFX() {
        withAnimation(.easeOut(duration: 0.2)) {
            engine.playerVFX = .none
            engine.enemyVFX = .none
        }
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
            Color(hex: 0x18122A)
        }
    }
}

#Preview {
    ContentView()
}
