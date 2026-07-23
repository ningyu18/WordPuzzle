import AVFoundation

/// Synthesized sound cues for game events — no bundled audio files (ADR-0001:
/// self-contained, asset-light). Every tone is a runtime-generated PCM buffer
/// played through a single AVAudioEngine.
///
/// Design: one coherent voice family. Soft triangle timbre with a fast attack /
/// exponential decay, pitched on the C-major pentatonic scale (C D E G A) so any
/// combination — including the escalating word-found ladder — stays consonant.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    /// Whether cues play. Persisted in UserDefaults; mirrored to a speaker toggle.
    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.muteKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.muteKey) }
    }
    private static let muteKey = "soundMuted"

    /// Optional per-cell tick during a Trace. Off by default (continuous ticking
    /// can grate); persisted so a preference sticks.
    var cellTickEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.cellTickKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.cellTickKey) }
    }
    private static let cellTickKey = "soundCellTick"

    private let engine = AVAudioEngine()
    private let sampleRate = 44_100.0
    private let format: AVAudioFormat
    /// A pool of player nodes so overlapping cues (e.g. an arpeggio) don't cut
    /// each other off.
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var started = false

    // C-major pentatonic frequencies (Hz), low to high, spanning C4..D6.
    // Index by "combo step" for the escalating word-found ladder.
    private static let ladder: [Double] = [
        523.25, // C5
        587.33, // D5
        659.25, // E5
        783.99, // G5
        880.00, // A5
        1046.50, // C6
        1174.66, // D6
    ]

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        // Eight voices is plenty for our densest cue (a 4-note arpeggio).
        for _ in 0..<8 {
            let node = AVAudioPlayerNode()
            players.append(node)
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }

    // MARK: - Lifecycle

    /// Start the audio engine and configure an ambient session (respects the
    /// hardware silent switch; never interrupts other audio). Safe to call twice.
    func activate() {
        guard !started else { return }
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
            #endif
            try engine.start()
            started = true
        } catch {
            // Audio is non-essential; a failure here must never break gameplay.
            started = false
        }
    }

    // MARK: - Public cues

    /// A found word. `comboIndex` (0-based, reset each puzzle) climbs the
    /// pentatonic ladder so consecutive finds build a little melody.
    func playWordFound(comboIndex: Int) {
        let freq = Self.ladder[min(comboIndex, Self.ladder.count - 1)]
        play(Tone(frequency: freq, duration: 0.16, amplitude: 0.5,
                  wave: .triangle, decay: 12))
    }

    /// All words found: a bright ascending arpeggio flourish.
    func playPuzzleComplete() {
        let notes = [523.25, 659.25, 783.99, 1046.50] // C5 E5 G5 C6
        for (i, f) in notes.enumerated() {
            play(Tone(frequency: f, duration: 0.5, amplitude: 0.45,
                      wave: .triangle, decay: 6),
                 afterDelay: Double(i) * 0.09)
        }
    }

    /// A drag that matched nothing: a soft, low "nothing here" — deliberately
    /// gentle, not a punishing error buzz (misfires are constant in a word hunt).
    func playNoMatch() {
        play(Tone(frequency: 146.83, duration: 0.14, amplitude: 0.28,
                  wave: .sine, decay: 18)) // D3
    }

    /// A hint reveal: an airy ascending shimmer.
    func playHint() {
        let notes = [392.00, 523.25, 659.25] // G4 C5 E5
        for (i, f) in notes.enumerated() {
            play(Tone(frequency: f, duration: 0.22, amplitude: 0.3,
                      wave: .sine, decay: 10),
                 afterDelay: Double(i) * 0.06)
        }
    }

    /// Optional, off by default: a quiet per-cell tick as a Trace grows. Pitch
    /// rises one pentatonic-ish step per cell so a long drag "climbs."
    func playCellTick(step: Int) {
        let freq = 440.0 * pow(2.0, Double(step) / 24.0) // ~quarter-tone per cell
        play(Tone(frequency: freq, duration: 0.04, amplitude: 0.12,
                  wave: .sine, decay: 30))
    }

    // MARK: - Synthesis

    private enum Wave { case sine, triangle }

    private struct Tone {
        let frequency: Double
        let duration: Double
        let amplitude: Double
        let wave: Wave
        /// Exponential decay rate; higher = pluckier/shorter tail.
        let decay: Double
    }

    private func play(_ tone: Tone, afterDelay delay: Double = 0) {
        guard started, !isMuted else { return }
        guard let buffer = makeBuffer(for: tone) else { return }
        let node = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count

        if delay > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                Self.emit(node, buffer)
            }
        } else {
            Self.emit(node, buffer)
        }
    }

    private static func emit(_ node: AVAudioPlayerNode, _ buffer: AVAudioPCMBuffer) {
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    private func makeBuffer(for tone: Tone) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(tone.duration * sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)
        else { return nil }
        buffer.frameLength = frames
        guard let samples = buffer.floatChannelData?[0] else { return nil }

        let twoPi = 2.0 * Double.pi
        let attackFrames = max(1.0, 0.005 * sampleRate) // ~5 ms attack
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let phase = twoPi * tone.frequency * t
            let raw: Double
            switch tone.wave {
            case .sine:
                raw = sin(phase)
            case .triangle:
                // Triangle from asin(sin) — soft, few harmonics.
                raw = (2.0 / Double.pi) * asin(sin(phase))
            }
            // Fast linear attack, then exponential decay envelope.
            let attack = min(1.0, Double(i) / attackFrames)
            let env = attack * exp(-tone.decay * t)
            samples[i] = Float(raw * env * tone.amplitude)
        }
        return buffer
    }
}
