import AVFoundation

// MARK: - Audio
//
// One place for every sound in the game. Two kinds:
//   • one-shot SFX  — fire and forget (attack, block, damage, heal, win, lose, start)
//   • looping music — exactly one at a time (fight / boss / rest), crossfaded on change
//
// Nothing here touches game logic; callers just announce that something happened.

final class AudioManager {
    static let shared = AudioManager()

    /// One-shot effects.
    enum SFX: String, CaseIterable {
        case attack   = "sfx_attack"
        case block    = "sfx_block"
        case cardFlip = "sfx_cardflip"
        case damage   = "sfx_damage"
        case heal     = "sfx_heal"
        case lose     = "sfx_lose"
        case start    = "sfx_start"
        case win      = "sfx_win"
    }

    /// Background tracks. Only one plays at a time.
    enum Music: String {
        case intro   = "sfx_introloop"     // title page
        case opening = "sfx_openingloop"   // the opening story scene
        case fight   = "sfx_fightloop"
        case boss    = "sfx_bossloop"
        case rest    = "sfx_restloop"

        /// Level for this track relative to the player's music slider, so one track can sit
        /// lower than another without the slider lying about what it controls. The opening
        /// plays *under* narration — it has to stay beneath the dialogue rather than compete
        /// with it, unlike a combat loop that has the screen to itself.
        var gain: Float {
            switch self {
            case .opening: return 0.60
            default:       return 1.0
            }
        }
    }

    var sfxVolume: Float = 0.85

    /// Background-music level, 0…1. Applies live to whatever is playing and is remembered
    /// between launches. At 0 the track keeps running silently, so raising the slider
    /// brings it straight back rather than waiting for the next track change.
    var musicVolume: Float {
        didSet {
            UserDefaults.standard.set(musicVolume, forKey: Self.musicVolumeKey)
            // Through the current track's own gain, so dragging the slider doesn't undo a
            // deliberately quieter track.
            musicPlayer?.volume = musicVolume * (currentMusic?.gain ?? 1)
        }
    }

    /// Whether one-shot effects play at all (the settings toggle).
    var sfxEnabled: Bool {
        didSet {
            UserDefaults.standard.set(sfxEnabled, forKey: Self.sfxEnabledKey)
            if !sfxEnabled { pools.values.forEach { $0.forEach { $0.stop() } } }
        }
    }

    private static let musicVolumeKey = "musicVolume"
    private static let sfxEnabledKey = "sfxEnabled"

    /// Pre-built, pre-prepared voices per sound. Building an AVAudioPlayer at fire time
    /// costs file I/O + decoder setup — enough to be *heard* as lag against a short
    /// animation — so every player is ready before it's needed. Several voices per sound
    /// let copies overlap (a dealt hand flips 5 cards inside one flip's duration).
    private var pools: [String: [AVAudioPlayer]] = [:]
    private var musicPlayer: AVAudioPlayer?
    private var currentMusic: Music?
    /// Last time each sound started, so a burst (e.g. Cleave hitting three enemies)
    /// reads as one hit instead of three stacked copies.
    private var lastPlayed: [String: TimeInterval] = [:]
    private let retriggerGap: TimeInterval = 0.07
    private let fade: TimeInterval = 0.45

    private init() {
        let defaults = UserDefaults.standard
        musicVolume = defaults.object(forKey: Self.musicVolumeKey) as? Float ?? 0.30
        sfxEnabled = defaults.object(forKey: Self.sfxEnabledKey) as? Bool ?? true

        #if os(iOS)
        // .ambient keeps the player's own music going if they have some on.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    // MARK: One-shots

    /// Build every one-shot's voices up front. Call once at launch: doing it lazily would
    /// put the cost on the first play of each sound, which is exactly when timing matters.
    func preloadSFX() {
        for sfx in SFX.allCases { _ = pool(for: sfx) }
    }

    /// How many copies of a sound can overlap.
    private func voices(for sfx: SFX) -> Int {
        sfx == .cardFlip ? 6 : 3   // a dealt hand overlaps up to 5 flips
    }

    private func pool(for sfx: SFX) -> [AVAudioPlayer] {
        if let existing = pools[sfx.rawValue] { return existing }
        var players: [AVAudioPlayer] = []
        // Load the file once, then spin the voices off the in-memory copy.
        if let url = Self.url(for: sfx.rawValue), let data = try? Data(contentsOf: url) {
            for _ in 0..<voices(for: sfx) {
                if let p = try? AVAudioPlayer(data: data) {
                    p.volume = sfxVolume
                    p.prepareToPlay()      // decoder warm and buffers filled
                    players.append(p)
                }
            }
        }
        pools[sfx.rawValue] = players
        return players
    }

    /// `debounced: false` guarantees a sound for every call, however close together — used
    /// where each play maps to its own on-screen event (one flip per card dealt).
    func play(_ sfx: SFX, debounced: Bool = true) {
        guard sfxEnabled else { return }
        let now = Date().timeIntervalSinceReferenceDate
        if debounced {
            if let last = lastPlayed[sfx.rawValue], now - last < retriggerGap { return }
            lastPlayed[sfx.rawValue] = now
        }

        let players = pool(for: sfx)
        guard !players.isEmpty else { return }
        // Take a free voice; if they're all busy, restart the first so nothing is dropped.
        let player = players.first { !$0.isPlaying } ?? players[0]
        player.volume = sfxVolume
        player.currentTime = 0
        player.play()
    }

    // MARK: Music

    /// Switch the looping track. Passing `nil` fades the current one out.
    ///
    /// Re-requesting the track that's already playing is a no-op so it never restarts
    /// mid-fight — but only while it is *genuinely still playing*. `currentMusic` alone
    /// can be a stale claim (a torn-down view can stop the player behind our back), and
    /// trusting it would leave the track permanently silent.
    func playMusic(_ music: Music?) {
        if currentMusic == music, music == nil || musicPlayer?.isPlaying == true { return }
        currentMusic = music

        // Fade out whatever is playing and let it release itself.
        if let old = musicPlayer {
            old.setVolume(0, fadeDuration: fade)
            DispatchQueue.main.asyncAfter(deadline: .now() + fade) { old.stop() }
        }
        musicPlayer = nil

        guard let music,
              let url = Self.url(for: music.rawValue),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1          // loop until told otherwise
        player.volume = 0
        player.prepareToPlay()
        player.play()
        player.setVolume(musicVolume * music.gain, fadeDuration: fade)
        musicPlayer = player
    }

    func stopMusic() { playMusic(nil) }

    /// Identifies the view instance that currently owns playback. Xcode's Canvas can tear
    /// an old view down *after* its replacement has appeared, so teardown must prove it is
    /// the current owner before silencing anything.
    private var sessionToken = 0

    /// Claim playback for a newly-appeared view; keep the token for `shutdown(token:)`.
    func beginSession() -> Int {
        sessionToken += 1
        return sessionToken
    }

    /// Hard stop with no fade — for teardown (the window closing, a preview being torn
    /// down), where a fade's delayed stop would never run and the track would play on.
    /// Ignored if a newer view has already taken over.
    func shutdown(token: Int) {
        guard token == sessionToken else { return }
        currentMusic = nil
        musicPlayer?.stop()
        musicPlayer = nil
        pools.values.forEach { $0.forEach { $0.stop() } }
    }

    // MARK: Lookup

    /// Files are mixed .wav/.mp3/.flac and may sit at the bundle root or in Sounds/,
    /// depending on how Xcode copies them — try every combination.
    private static let extensions = ["wav", "mp3", "flac", "m4a", "aiff", "caf"]

    private static func url(for name: String) -> URL? {
        for ext in extensions {
            if let u = Bundle.main.url(forResource: name, withExtension: ext) { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Sounds") { return u }
        }
        return nil
    }
}
