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

// MARK: - Content View

struct ContentView: View {
    @State private var engine = GameEngine()
    @State private var enemyPulsing = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                statusBar
                    .frame(height: geo.size.height * 0.10)

                goldDivider

                arena
                    .frame(maxHeight: .infinity)

                goldDivider

                controlDeck
                    .frame(height: geo.size.height * 0.40)
            }
        }
        .background(Color.bgDeep)
        .ignoresSafeArea()
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            HStack(spacing: 16) {
                hpBar
                Text("\u{1F4B0} \(engine.player.gold)")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundColor(.textGold)
            }

            Spacer()

            Text("Act 1 \u{2014} Floor 4")
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundColor(.textMuted)
                .tracking(1)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.bgPanelDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color(hex: 0x3A2A5A).opacity(0.5), lineWidth: 1)
                        )
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .background(
            LinearGradient(
                colors: [Color.bgPanel, Color(hex: 0x120E20), Color.bgPanelDark],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var hpBar: some View {
        HStack(spacing: 6) {
            Text("\u{2665}")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: 0xBF2040))
                .shadow(color: Color(hex: 0xBF2040).opacity(0.5), radius: 4)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.bgDeep)

                    let fraction = CGFloat(engine.player.currentHp) / CGFloat(engine.player.maxHp)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.hpRuby, Color(hex: 0x9B1B30), .hpRubyDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: geo.size.width * fraction)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(hex: 0x4A2030), lineWidth: 1)
                )
            }
            .frame(width: 100, height: 12)

            Text("\(engine.player.currentHp)/\(engine.player.maxHp)")
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: 0xD4A0A8))
        }
    }

    // MARK: - Arena

    private var arena: some View {
        ZStack {
            LinearGradient(
                colors: [Color.bgDeep, Color(hex: 0x0C0A14), Color(hex: 0x14101E)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack {
                Spacer()

                // Player
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x8A6A40), Color(hex: 0x5A3A20), Color(hex: 0x2A1808)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 65, height: 95)
                    .shadow(color: Color(hex: 0xA07830).opacity(0.25), radius: 12)

                Spacer()
                Spacer()

                // Enemy
                VStack(spacing: 12) {
                    Text("\u{2694}\u{FE0F} 12")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundColor(Color(hex: 0xD4A0A8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x5A1923).opacity(0.7), Color(hex: 0x320F16).opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color(hex: 0xC85064).opacity(0.3), lineWidth: 1)
                        )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: 0x40C068),
                                    Color(hex: 0x228A42),
                                    Color(hex: 0x186A32),
                                    Color(hex: 0x0A3818)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 55
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color(hex: 0x32B45A).opacity(0.3), radius: 16)
                        .scaleEffect(enemyPulsing ? 1.04 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.75).repeatForever(autoreverses: true),
                            value: enemyPulsing
                        )
                        .onAppear { enemyPulsing = true }
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Control Deck

    private var controlDeck: some View {
        HStack(alignment: .center, spacing: 12) {
            // Energy + Draw Pile
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: 0xF0D860),
                                    Color(hex: 0xD4A520),
                                    Color(hex: 0xA87818),
                                    Color(hex: 0x7A5510)
                                ],
                                center: UnitPoint(x: 0.38, y: 0.32),
                                startRadius: 0,
                                endRadius: 26
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: .goldAccent.opacity(0.35), radius: 8)

                    Text("\(engine.player.currentEnergy)/\(engine.player.maxEnergy)")
                        .font(.system(size: 13, weight: .heavy, design: .serif))
                        .foregroundColor(Color(hex: 0x1A1008))
                }

                VStack(spacing: 2) {
                    Text("Draw")
                        .font(.system(size: 8, weight: .bold, design: .serif))
                        .foregroundColor(.textMuted)
                        .tracking(1)
                    Text("\(engine.deck.drawPile.count)")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(Color(hex: 0xB0A080))
                }
            }
            .frame(width: 56)

            // Hand
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(engine.deck.hand) { card in
                        CardView(card: card)
                            .onTapGesture {
                                if let index = engine.deck.hand.firstIndex(where: { $0.id == card.id }) {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        engine.playCard(at: index)
                                    }
                                }
                            }
                    }
                }
                .padding(.vertical, 8)
            }

            // End Turn + Discard
            VStack(spacing: 10) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        engine.endTurn()
                    }
                } label: {
                    Text("END TURN")
                        .font(.system(size: 10, weight: .heavy, design: .serif))
                        .tracking(1)
                        .foregroundColor(.textParchment)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x6A2028), Color(hex: 0x4A1520), Color(hex: 0x2A0A10)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color(hex: 0x6A3020), lineWidth: 1.5)
                        )
                        .shadow(color: Color(hex: 0x501414).opacity(0.5), radius: 6)
                }

                VStack(spacing: 2) {
                    Text("Discard")
                        .font(.system(size: 8, weight: .bold, design: .serif))
                        .foregroundColor(.textMuted)
                        .tracking(1)
                    Text("\(engine.deck.discardPile.count)")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(Color(hex: 0xB0A080))
                }
            }
            .frame(width: 80)
        }
        .padding(.horizontal, 12)
        .background(
            LinearGradient(
                colors: [Color.bgPanelDark, Color(hex: 0x140F22), Color.bgPanel],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Gold Divider

    private var goldDivider: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .goldDark, location: 0.15),
                .init(color: .goldAccent, location: 0.35),
                .init(color: .goldBright, location: 0.5),
                .init(color: .goldAccent, location: 0.65),
                .init(color: .goldDark, location: 0.85),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 2)
        .padding(.horizontal, 16)
        .background(Color.bgDeep)
    }
}

// MARK: - Card View

struct CardView: View {
    let card: Card

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(card.name)
                    .font(.system(size: 9, weight: .bold, design: .serif))
                    .foregroundColor(.textParchment)
                    .lineLimit(1)

                Spacer()

                ZStack {
                    Rectangle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: 0xF0D860), Color(hex: 0xC5961A), Color(hex: 0x7A5510)],
                                center: UnitPoint(x: 0.4, y: 0.35),
                                startRadius: 0,
                                endRadius: 10
                            )
                        )
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(45))

                    Text("\(card.energyCost)")
                        .font(.system(size: 9, weight: .heavy, design: .serif))
                        .foregroundColor(Color(hex: 0x1A1008))
                }
                .frame(width: 18, height: 18)
            }
            .padding(.horizontal, 7)
            .padding(.top, 6)
            .padding(.bottom, 4)

            // Header divider
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .goldBorder.opacity(0.4), location: 0.2),
                    .init(color: .goldBorder.opacity(0.4), location: 0.8),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .padding(.horizontal, 6)

            // Art area
            RoundedRectangle(cornerRadius: 2)
                .fill(cardArtGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(cardArtBorder, lineWidth: 0.5)
                )
                .padding(.horizontal, 5)
                .padding(.vertical, 4)

            // Ornate divider
            Text("\u{2014} \u{2726} \u{2014}")
                .font(.system(size: 5))
                .foregroundColor(Color(hex: 0xA08240).opacity(0.45))
                .padding(.bottom, 2)

            // Description
            Text(card.description)
                .font(.system(size: 7, weight: .regular, design: .serif))
                .foregroundColor(Color(hex: 0xA09880))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .padding(.horizontal, 7)

            Spacer(minLength: 2)

            // Type label
            Text(card.type.rawValue.uppercased())
                .font(.system(size: 5, weight: .bold, design: .serif))
                .tracking(2)
                .foregroundColor(Color(hex: 0x5A4A30))
                .padding(.bottom, 4)
        }
        .frame(width: 88, height: 134)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x1E1828), Color(hex: 0x18122A), Color(hex: 0x100A1A)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.goldBorder, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
    }

    private var cardArtGradient: LinearGradient {
        switch card.type {
        case .attack:
            LinearGradient(
                colors: [Color(hex: 0x3A1510), Color(hex: 0x2A0E08), Color(hex: 0x1A0804)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .skill:
            LinearGradient(
                colors: [Color(hex: 0x10203A), Color(hex: 0x0A1828), Color(hex: 0x060E1A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var cardArtBorder: Color {
        switch card.type {
        case .attack: Color(hex: 0x5A2518)
        case .skill: Color(hex: 0x1A3A5A)
        }
    }
}

#Preview {
    ContentView()
}
