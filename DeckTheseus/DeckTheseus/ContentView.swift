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

// MARK: - Health Hearts (Pixel Art)

struct HealthHeartsView: View {
    let currentHp: Int
    let maxHp: Int
    let heartSize: CGFloat

    private func heartImage(at index: Int) -> String {
        let hpPerHeart = Double(maxHp) / 5.0
        let heartHp = Double(currentHp) - Double(index) * hpPerHeart
        if heartHp >= hpPerHeart {
            return "health_heart_full"
        } else if heartHp > 0 {
            return "health_heart_half"
        } else {
            return "health_heart_none"
        }
    }

    var body: some View {
        HStack(spacing: -heartSize * 0.28) {
            ForEach(0..<5, id: \.self) { index in
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

// MARK: - Stat Block (Name + Hearts + Shield, compact)

struct StatBlockView: View {
    let name: String
    let currentHp: Int
    let maxHp: Int
    let block: Int
    let heartSize: CGFloat
    let nameFont: CGFloat
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(name)
                .font(.pixel(nameFont))
                .foregroundColor(.textParchment)

            HealthHeartsView(
                currentHp: currentHp,
                maxHp: maxHp,
                heartSize: heartSize
            )
            .padding(.top, -heartSize * 0.08)

            ShieldView(block: block, size: heartSize * 0.35)
                .padding(.top, -heartSize * 0.10)
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

// MARK: - Content View

struct ContentView: View {
    @State private var engine = GameEngine()
    @State private var enemyPulsing = false
    @State private var playerPulsing = false
    @State private var tooltipCardId: UUID? = nil
    @State private var dealtCardIds: Set<UUID> = []
    @State private var revealedCardIds: Set<UUID> = []

    var body: some View {
        GeometryReader { geo in
            let unit = min(geo.size.width, geo.size.height)
            let cardH = min(unit * 0.30, 260.0)
            let cardW = cardH * 0.72
            let bossH = min(unit * 0.38, 320.0)
            let playerH = bossH * 0.75
            let heartSize = min(unit * 0.12, 80.0)
            let nameFont = min(unit * 0.028, 18.0)
            let titleFont = min(unit * 0.030, 20.0)
            let bodyFont = min(unit * 0.026, 18.0)
            let smallFont = min(unit * 0.022, 16.0)
            let orbSize = max(unit * 0.09, 50.0)
            let handWidth = geo.size.width * 0.52

            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(hex: 0x0A0816), Color(hex: 0x0C0A14), Color(hex: 0x14101E)],
                    startPoint: .top,
                    endPoint: .bottom
                )

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

                // Boss (CENTER, close to middle)
                VStack(spacing: 0) {
                    PixelImage(name: "boss_slime", height: bossH)
                        .shadow(color: Color(hex: 0x32B45A).opacity(0.4), radius: 20)
                        .scaleEffect(enemyPulsing ? 1.03 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.75).repeatForever(autoreverses: true),
                            value: enemyPulsing
                        )
                        .padding(.bottom, -bossH * 0.06)

                    StatBlockView(
                        name: "Slime King",
                        currentHp: engine.enemy.currentHp,
                        maxHp: engine.enemy.maxHp,
                        block: engine.enemy.currentBlock,
                        heartSize: heartSize,
                        nameFont: nameFont
                    )
                }
                .position(x: geo.size.width * 0.50, y: geo.size.height * 0.46)

                // Player (LEFT side, LOW)
                VStack(spacing: 0) {
                    PixelImage(name: "player_sprite", height: playerH)
                        .shadow(color: Color(hex: 0xA07830).opacity(0.3), radius: 12)
                        .scaleEffect(playerPulsing ? 1.02 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: playerPulsing
                        )
                        .padding(.bottom, -playerH * 0.08)

                    StatBlockView(
                        name: "Player",
                        currentHp: engine.player.currentHp,
                        maxHp: engine.player.maxHp,
                        block: engine.displayPlayerBlock,
                        heartSize: heartSize * 0.85,
                        nameFont: nameFont,
                        alignment: .center
                    )
                }
                .position(x: geo.size.width * 0.15, y: geo.size.height * 0.55)

                // Bottom-LEFT: Draw pile
                VStack(spacing: 4) {
                    Text("\(engine.deck.drawPile.count)")
                        .font(.pixel(bodyFont))
                        .foregroundColor(.textMuted)

                    ZStack {
                        if engine.deck.drawPile.count > 0 {
                            ForEach(0..<min(3, engine.deck.drawPile.count), id: \.self) { i in
                                FaceDownCard(width: cardW * 0.65, height: cardH * 0.65)
                                    .offset(x: CGFloat(i) * 1.5, y: CGFloat(-i) * 1.5)
                            }
                        } else {
                            Image("card_facedown_empty")
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: cardW * 0.65, height: cardH * 0.65)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 20)
                .padding(.bottom, cardH * 0.15 + 10)

                // Bottom-RIGHT: Energy + End Turn
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        PixelImage(name: "hud_energy_orb", width: orbSize, height: orbSize)
                            .shadow(color: Color(hex: 0xA040D0).opacity(0.6), radius: 12)

                        Text("\(engine.remainingEnergy)/\(engine.player.maxEnergy)")
                            .font(.pixel(orbSize * 0.55))
                            .foregroundColor(Color(hex: 0xE0C0F0))
                    }

                    Button {
                        engine.endTurn()
                        tooltipCardId = nil
                        dealNewHand()
                    } label: {
                        Image("end_turn")
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(contentMode: .fit)
                            .frame(height: orbSize * 0.6)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 20)
                .padding(.bottom, cardH * 0.15 + 20)

                // Card fan (bottom center)
                ZStack {
                    let count = engine.deck.hand.count
                    let mid = count > 1 ? Double(count - 1) / 2.0 : 0

                    ForEach(Array(engine.deck.hand.enumerated()), id: \.element.id) { index, card in
                        let t = count > 1 ? (Double(index) - mid) / mid : 0
                        let fanAngle = t * 8.0
                        let fanX = t * Double(handWidth) * 0.42
                        let fanY = abs(t) * 8.0

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
                                    isAffordable: engine.canAfford(card),
                                    showTooltip: tooltipCardId == card.id,
                                    cardWidth: cardW,
                                    cardHeight: cardH
                                )
                            } else {
                                FaceDownCard(width: cardW, height: cardH)
                            }
                        }
                        .offset(x: currentX, y: currentY)
                        .rotationEffect(.degrees(currentAngle), anchor: .bottom)
                        .zIndex(
                            tooltipCardId == card.id ? 200 :
                            isSelected ? 100 + Double(index) :
                            Double(index)
                        )
                        .allowsHitTesting(isRevealed)
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
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: cardH * 0.12)
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
        ZStack(alignment: .top) {
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
                    .offset(y: -cardHeight * 0.25)
                    .zIndex(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

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
