import SwiftUI

// MARK: - Credits
//
// Attribution for third-party assets. Creative Commons asks for four things — Title, Author,
// Source, License (the "TASL" form) — plus an indication of any changes made to the work, so
// each entry carries all five rather than a single pre-formatted line. Freesound hands you a
// ready-made string; this splits it so the screen can lay it out and make the links tappable,
// and so the licence itself can be linked, which the Freesound string doesn't do.
//
// ONLY list assets that actually ship. Crediting something the game doesn't contain is
// confusing, and a missing entry is the failure that matters.

struct CreditEntry: Identifiable {
    let id = UUID()
    /// The work's title exactly as published.
    let title: String
    let author: String
    /// Where it came from — the page, not the file.
    let source: String
    let license: String
    let licenseURL: String
    /// CC BY asks you to say so when you've altered the work.
    var modification: String? = nil
}

enum Credits {
    /// Licence URLs, spelled once. Note that CC BY **3.0** and **4.0** are different licences
    /// with different deeds — `sfx_lose` is 3.0 and must not be lumped in with the rest.
    private static let cc0     = "https://creativecommons.org/publicdomain/zero/1.0/"
    private static let ccBy3   = "https://creativecommons.org/licenses/by/3.0/"
    private static let ccBy4   = "https://creativecommons.org/licenses/by/4.0/"
    private static let ccByNc4 = "https://creativecommons.org/licenses/by-nc/4.0/"

    /// Sound and music, each mapping to a file in `DeckTheseus/Sounds/`.
    ///
    /// Every one of the 12 files in `Sounds/` is accounted for here. The CC0 entries carry no
    /// attribution requirement — they're listed as a courtesy, which costs nothing and is never
    /// wrong. Keep it that way: a sound with no traced licence can't be complied with at all.
    static let audio: [CreditEntry] = [
        // ---- music loops ----
        CreditEntry(                                            // sfx_introloop — title page
            title: "8 Bit Game Intro Loop.wav",
            author: "Mrthenoronha",
            source: "https://freesound.org/s/520937/",
            license: "CC BY-NC 4.0",
            licenseURL: ccByNc4),
        CreditEntry(                                            // sfx_bossloop
            title: "Boss Battle Loop #3",
            author: "Sirkoto51",
            source: "https://freesound.org/s/443128/",
            license: "CC BY 4.0",
            licenseURL: ccBy4,
            modification: "converted to .m4a"),
        CreditEntry(                                            // sfx_openingloop — opening scene
            title: "Castle Music Loop #1",
            author: "Sirkoto51",
            source: "https://freesound.org/s/416632/",
            license: "CC BY 4.0",
            licenseURL: ccBy4,
            modification: "converted to .m4a"),
        CreditEntry(                                            // sfx_fightloop — normal combat
            title: "Boss fight",
            author: "Victor_Natas",
            source: "https://freesound.org/s/721472/",
            license: "CC BY 4.0",
            licenseURL: ccBy4,
            modification: "converted to .m4a"),
        CreditEntry(                                            // sfx_restloop — rest sites
            title: "Medieval/Fantasy RPG Loop (mix at 32 secs to extend/repeat)",
            author: "sonically_sound",
            source: "https://freesound.org/s/649132/",
            license: "CC BY-NC 4.0",
            licenseURL: ccByNc4),

        // ---- sound effects ----
        CreditEntry(                                            // sfx_attack
            title: "SFX_ATTACK_SWORD_001.wav",
            author: "JoelAudio",
            source: "https://freesound.org/s/77611/",
            license: "CC BY 4.0",
            licenseURL: ccBy4),
        CreditEntry(                                            // sfx_cardflip
            title: "Card Flip",
            author: "f4ngy",
            source: "https://freesound.org/s/240776/",
            license: "CC BY 4.0",
            licenseURL: ccBy4),
        CreditEntry(                                            // sfx_damage
            title: "Damage",
            author: "qubodup",
            source: "https://freesound.org/s/211634/",
            license: "CC BY 4.0",
            licenseURL: ccBy4),
        CreditEntry(                                            // sfx_lose — 3.0, not 4.0
            title: "Video Game - Die or Lose Life",
            author: "AdamWeeden",
            source: "https://freesound.org/s/157218/",
            license: "CC BY 3.0",
            licenseURL: ccBy3),
        CreditEntry(                                            // sfx_block — no credit required
            title: "Block.mp3",
            author: "FlameEagle",
            source: "https://freesound.org/s/131142/",
            license: "CC0 1.0",
            licenseURL: cc0),
        CreditEntry(                                            // sfx_heal — no credit required
            title: "Heal - Rpg",
            author: "colorsCrimsonTears",
            source: "https://freesound.org/s/562292/",
            license: "CC0 1.0",
            licenseURL: cc0),
        CreditEntry(                                            // sfx_win — no credit required
            title: "Success Fanfare Trumpets.mp3",
            author: "FunWithSound",
            source: "https://freesound.org/s/456966/",
            license: "CC0 1.0",
            licenseURL: cc0),
        CreditEntry(                                            // sfx_start — no credit required
            title: "8-Bit Arcade Video Game Start Sound Effect, Gun Reload and Jump !!",
            author: "FartBiscuit1700",
            source: "https://freesound.org/s/368691/",
            license: "CC0 1.0",
            licenseURL: cc0),
    ]

    /// The typeface, registered at launch from the bundled .ttf. Redistributing an OFL font
    /// inside an app means carrying its notice — VERIFY this line against the copy you bundled
    /// before submitting.
    static let fonts: [CreditEntry] = [
        CreditEntry(
            title: "VT323",
            author: "Peter Hunt",
            source: "https://fonts.google.com/specimen/VT323",
            license: "SIL Open Font License 1.1",
            licenseURL: "https://openfontlicense.org"),
    ]
}

// MARK: - Credits screen

struct CreditsView: View {
    let unit: CGFloat
    let size: CGSize
    let onClose: () -> Void

    var body: some View {
        let titleFont = min(unit * 0.052, 38)
        let headFont = min(unit * 0.030, 20)
        let bodyFont = min(unit * 0.024, 16)

        ZStack {
            Color(hex: 0x08060E).opacity(0.97)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            VStack(spacing: unit * 0.02) {
                Text("CREDITS")
                    .font(.pixel(titleFont))
                    .foregroundColor(.goldBright)
                    .shadow(color: Color.goldBright.opacity(0.4), radius: 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: unit * 0.026) {
                        section("SOUND & MUSIC", Credits.audio,
                                headFont: headFont, bodyFont: bodyFont)
                        section("FONT", Credits.fonts,
                                headFont: headFont, bodyFont: bodyFont)

                        Text("Thank you to everyone who shared their work.")
                            .font(.pixel(bodyFont))
                            .foregroundColor(.textMuted)
                            .padding(.top, unit * 0.01)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, unit * 0.01)
                }

                Button(action: onClose) {
                    Text("Back")
                        .font(.pixel(headFont))
                        .foregroundColor(.textParchment)
                        .padding(.horizontal, unit * 0.05)
                        .padding(.vertical, unit * 0.012)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x2E2340)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.goldBorder, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(unit * 0.04)
            .frame(width: min(size.width * 0.86, 720),
                   height: min(size.height * 0.86, 620))
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func section(_ heading: String, _ entries: [CreditEntry],
                         headFont: CGFloat, bodyFont: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: bodyFont * 0.9) {
            Text(heading)
                .font(.pixel(headFont))
                .foregroundColor(.goldBorder)

            ForEach(entries) { e in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(e.title) — by \(e.author)")
                        .font(.pixel(bodyFont))
                        .foregroundColor(.textParchment)
                        .fixedSize(horizontal: false, vertical: true)

                    Link(e.source, destination: URL(string: e.source)!)
                        .font(.pixel(bodyFont * 0.9))
                        .foregroundColor(Color(hex: 0x7FC5FF))

                    HStack(spacing: 6) {
                        Link(e.license, destination: URL(string: e.licenseURL)!)
                            .foregroundColor(Color(hex: 0x7FC5FF))
                        if let modification = e.modification {
                            Text("\u{2014} \(modification)")
                                .foregroundColor(.textMuted)
                        }
                    }
                    .font(.pixel(bodyFont * 0.9))
                }
            }
        }
    }
}
