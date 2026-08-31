import SwiftUI

// MARK: - Dialogue System (narrative scenes, Cookie-Run-Kingdom style)
//
// Fully data-driven: a scene is an ordered array of lines, and scenes are looked up by
// trigger in `DialogueScript.scenes`. Adding new story beats means adding entries to that
// table — the renderer in ContentView never changes.
//
// Every scene is MANDATORY: it plays each time its trigger fires, on every run, with no
// seen-once tracking anywhere. SKIP covers repeat viewings.

/// Who is speaking. A line with no speaker is a plain caption (no portrait, no name pill).
enum DialogueSpeaker: String, Hashable {
    case knight, acidSlime, spikedSlime, slimeKing

    var displayName: String {
        switch self {
        case .knight:      return "Knight"
        case .acidSlime:   return "Acid Slime"
        case .spikedSlime: return "Spiked Slime"
        case .slimeKing:   return "Slime King"
        }
    }

    /// PLACEHOLDER PORTRAITS — these reuse the existing combat sprites (and their measured
    /// crop fractions) so no new art is needed yet. Swap these for real portrait assets
    /// later; nothing else has to change.
    var portrait: (name: String, contentW: CGFloat, contentH: CGFloat) {
        switch self {
        case .knight:      return ("player_sprite", 0.33, 0.4375)
        case .acidSlime:   return ("enemy_acid_slime_elite", 0.453, 0.375)
        case .spikedSlime: return ("enemy_spiked_slime_elite", 0.453, 0.438)
        case .slimeKing:   return ("boss_slime", 0.61, 0.578)
        }
    }

    /// The knight stands on the left; everyone else faces them from the right.
    var isPlayerSide: Bool { self == .knight }
}

/// One line of a scene. `speaker == nil` renders as a caption.
///
/// A line may also change the backdrop. The change **sticks** for the following lines until
/// another one changes it, so a scene can cut between images mid-dialogue.
struct DialogueLine: Identifiable {
    let id = UUID()
    let speaker: DialogueSpeaker?
    let text: String
    var backdrop: DialogueBackdrop? = nil

    static func caption(_ text: String, backdrop: DialogueBackdrop? = nil) -> DialogueLine {
        DialogueLine(speaker: nil, text: text, backdrop: backdrop)
    }
    static func says(_ speaker: DialogueSpeaker, _ text: String,
                     backdrop: DialogueBackdrop? = nil) -> DialogueLine {
        DialogueLine(speaker: speaker, text: text, backdrop: backdrop)
    }
}

/// How a scene advances.
enum DialoguePresentation {
    /// Player taps (or clicks) to move to the next line. Used by the story scenes.
    case tapToAdvance
    /// Lines fade through on a timer with no input needed; a tap skips the whole scene.
    /// For caption-only cards; nothing uses it at present.
    case autoTimed(perLine: Double)
}

/// What sits behind a scene.
enum DialogueBackdrop: Hashable {
    /// Keep the game arena visible behind the scene, dimmed. Default — used by the
    /// pre/post-fight banter, which should read as happening on the battlefield.
    case arena
    /// Full-screen story art that replaces the arena entirely. Until the named asset
    /// exists in the catalog it renders as a black placeholder, so dropping the artwork
    /// in later needs no code change.
    case art(String)
}

struct DialogueScene: Identifiable {
    let id: String
    let lines: [DialogueLine]
    var presentation: DialoguePresentation = .tapToAdvance
    /// The scene's opening backdrop; individual lines can cut away from it.
    var backdrop: DialogueBackdrop = .arena

    /// The backdrop showing at `index`: the most recent line that set one, or the
    /// scene's own if no line has.
    func resolvedBackdrop(at index: Int) -> DialogueBackdrop {
        guard !lines.isEmpty else { return backdrop }
        for i in stride(from: min(index, lines.count - 1), through: 0, by: -1) {
            if let b = lines[i].backdrop { return b }
        }
        return backdrop
    }
}

/// Where a scene fires. Floors are the game's only progression axis (Act 1 is linear),
/// so before/after-floor covers every story beat we currently need.
enum DialogueTrigger: Hashable {
    case runStart          // before the very first fight (there is no map yet)
    case beforeFloor(Int)  // when that floor's encounter begins
    case afterFloor(Int)   // the moment its last enemy dies, before the rewards/victory screen
}

// MARK: - The script

enum DialogueScript {

    static let scenes: [DialogueTrigger: DialogueScene] = [

        // Runs over full-screen story art instead of the Floor 1 arena, cutting from the
        // standing castle to its ruin on the second line; the ruin then stays up for the
        // knight's lines.
        .runStart: DialogueScene(id: "opening", lines: [
            .caption("The kingdom stood for a thousand years. It took the slimes about a week."),
            .caption("No throne left. No banners. Just... slime.",
                     backdrop: .art("art_destroyedcastle")),
            .says(.knight, "There's nothing left to defend. So I guess I'm done defending."),
            .says(.knight, "Time to take it back. One slime at a time."),
        ], backdrop: .art("art_castle")),

        // Elite 1 — Acid Slime (Floor 5)
        .beforeFloor(5): DialogueScene(id: "acid_pre", lines: [
            .says(.acidSlime, "Oooh, shiny armor. Bet it dissolves nicely."),
            .says(.knight, "Try me."),
        ]),
        .afterFloor(5): DialogueScene(id: "acid_post", lines: [
            .says(.acidSlime, "Ugh— fine. Tell the King... he's not gonna like this."),
        ]),

        // Elite 2 — Spiked Slime (Floor 13)
        .beforeFloor(13): DialogueScene(id: "spiked_pre", lines: [
            .says(.spikedSlime, "You're the one poking around the King's halls?"),
            .says(.knight, "Just here to take back what's mine."),
            .says(.spikedSlime, "Rude. Guess I'll poke back, then."),
        ]),
        .afterFloor(13): DialogueScene(id: "spiked_post", lines: [
            .says(.spikedSlime, "...Okay. Maybe the King should be worried."),
        ]),

        // Boss — Slime King (Floor 18)
        .beforeFloor(18): DialogueScene(id: "king_pre", lines: [
            .says(.slimeKing, "So. The little knight finally oozed its way to me."),
            .says(.knight, "Give back the kingdom. I'll make this quick."),
            .says(.slimeKing, "Quick? Sweet knight, I've been forming for a hundred years. I am the kingdom now."),
            .says(.knight, "Then I guess I'm doing some remodeling."),
        ]),
        // The epilogue plays as one scene right after the King dies, before the VICTORY screen.
        // (The long caption is split at its sentence break so it fits the box — 5 lines total.)
        .afterFloor(18): DialogueScene(id: "king_victory", lines: [
            .says(.slimeKing, "Impossible— I was the strongest slime in the—"),
            .says(.knight, "You were a slime. Singular. That was kind of the problem."),
            .caption("The Slime King dissolved, and with him, his hold on the kingdom."),
            .caption("Rebuilding would take time. But for once, the kingdom was quiet. And dry."),
            .says(.knight, "...Someone's still gonna have to clean this up, though."),
        ]),
    ]

    static func scene(for trigger: DialogueTrigger) -> DialogueScene? { scenes[trigger] }

    // (There is deliberately no defeat scene — death drops straight to the DEFEAT screen.
    // `DialoguePresentation.autoTimed` remains available for future caption cards.)

    /// Is this image actually in the asset catalog yet? Lets a scene declare its artwork
    /// before the art exists and fall back to a placeholder in the meantime.
    static func assetExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #elseif canImport(AppKit)
        return NSImage(named: name) != nil
        #else
        return false
        #endif
    }
}

// MARK: - Backdrop view

/// Full-screen story art behind a dialogue scene. Renders the asset once it exists;
/// until then, a black screen labelled with the asset name it's waiting for.
struct DialogueBackdropView: View {
    let assetName: String

    var body: some View {
        ZStack {
            Color.black
            if DialogueScript.assetExists(assetName) {
                Image(assetName)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fill)
            } else {
                // PLACEHOLDER — drop `\(assetName)` into the asset catalog to replace this.
                VStack(spacing: 6) {
                    Text("[ story background ]")
                    Text(assetName)
                }
                .font(.pixel(15))
                .foregroundColor(Color.white.opacity(0.16))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
