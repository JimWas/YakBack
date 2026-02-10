//
//  AudioEngine.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/1/26.
//

import AVFoundation

// MARK: - Single Track Player

@Observable
final class TrackPlayer {
    let id: UUID
    private var engine: AVAudioEngine
    private var playerNode = AVAudioPlayerNode()
    private var eqNode = AVAudioUnitEQ(numberOfBands: 3)
    private var timePitchNode = AVAudioUnitTimePitch()

    private var audioFile: AVAudioFile?
    private var currentBuffer: AVAudioPCMBuffer?

    var isPlaying = false
    var currentLoopIteration = 0
    var totalLoops = 1

    var volume: Float = 1.0 {
        didSet { playerNode.volume = min(volume * volumeBoost, 2.0) }
    }

    var volumeBoost: Float = 1.0 {
        didSet { playerNode.volume = min(volume * volumeBoost, 2.0) }
    }

    var speed: Float = 1.0 {
        didSet { timePitchNode.rate = speed }
    }

    var bassGain: Float = 0.0 {
        didSet { eqNode.bands[0].gain = bassGain }
    }

    var midGain: Float = 0.0 {
        didSet { eqNode.bands[1].gain = midGain }
    }

    var trebleGain: Float = 0.0 {
        didSet { eqNode.bands[2].gain = trebleGain }
    }

    init(id: UUID, engine: AVAudioEngine) {
        self.id = id
        self.engine = engine
        configureEQ()
        attachNodes()
    }

    private func configureEQ() {
        let bassParams = eqNode.bands[0]
        bassParams.filterType = .lowShelf
        bassParams.frequency = 100
        bassParams.bandwidth = 1.0
        bassParams.gain = 0
        bassParams.bypass = false

        let midParams = eqNode.bands[1]
        midParams.filterType = .parametric
        midParams.frequency = 1000
        midParams.bandwidth = 1.0
        midParams.gain = 0
        midParams.bypass = false

        let trebleParams = eqNode.bands[2]
        trebleParams.filterType = .highShelf
        trebleParams.frequency = 6000
        trebleParams.bandwidth = 1.0
        trebleParams.gain = 0
        trebleParams.bypass = false
    }

    private func attachNodes() {
        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.attach(timePitchNode)
    }

    private func connectNodes(format: AVAudioFormat) {
        engine.connect(playerNode, to: eqNode, format: format)
        engine.connect(eqNode, to: timePitchNode, format: format)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: format)
    }

    func loadFile(url: URL) throws {
        stop()
        audioFile = try AVAudioFile(forReading: url)
        guard let file = audioFile else { return }
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        try file.read(into: buffer)
        currentBuffer = buffer
        connectNodes(format: format)
    }

    func play(loops: Int = 1) {
        guard let buffer = currentBuffer else { return }
        totalLoops = loops
        currentLoopIteration = 0

        playerNode.volume = min(volume * volumeBoost, 2.0)
        timePitchNode.rate = speed

        isPlaying = true
        scheduleBuffer(buffer)
    }

    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer) {
        playerNode.scheduleBuffer(buffer) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.currentLoopIteration += 1
                if self.totalLoops == -1 || self.currentLoopIteration < self.totalLoops {
                    if self.isPlaying {
                        self.scheduleBuffer(buffer)
                    }
                } else {
                    self.isPlaying = false
                    self.playerNode.stop()
                }
            }
        }
        playerNode.play()
    }

    func stop() {
        isPlaying = false
        playerNode.stop()
    }

    func pause() {
        isPlaying = false
        playerNode.pause()
    }

    func resume() {
        isPlaying = true
        playerNode.play()
    }

    func detach() {
        stop()
        engine.detach(playerNode)
        engine.detach(eqNode)
        engine.detach(timePitchNode)
    }
}

// MARK: - Multi-Track Audio Engine

@Observable
final class AudioEngine {
    private var engine = AVAudioEngine()
    private var tracks: [UUID: TrackPlayer] = [:]
    var playingSoundIDs: Set<UUID> = []

    init() {
        configureSession()
    }

    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func ensureEngineRunning() {
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("Engine start error: \(error)")
            }
        }
    }

    func play(sound: SoundItem) {
        // If already playing this sound, stop it first
        if let existing = tracks[sound.id] {
            existing.stop()
            existing.detach()
            tracks.removeValue(forKey: sound.id)
            playingSoundIDs.remove(sound.id)
        }

        let track = TrackPlayer(id: sound.id, engine: engine)
        do {
            try track.loadFile(url: sound.fileURL)
            track.volume = sound.volume
            track.speed = sound.speed
            track.bassGain = sound.eqBass
            track.midGain = sound.eqMid
            track.trebleGain = sound.eqTreble
            track.volumeBoost = sound.effectiveVolumeBoost
            ensureEngineRunning()
            track.play(loops: sound.loopCount)
            tracks[sound.id] = track
            playingSoundIDs.insert(sound.id)

            // Monitor for completion
            monitorTrack(sound.id)
        } catch {
            track.detach()
            print("Play error: \(error)")
        }
    }

    private func monitorTrack(_ id: UUID) {
        Task { @MainActor in
            while let track = tracks[id], track.isPlaying {
                try? await Task.sleep(for: .milliseconds(200))
            }
            playingSoundIDs.remove(id)
            if let track = tracks.removeValue(forKey: id) {
                track.detach()
            }
            // Stop engine if no tracks are playing
            if tracks.isEmpty && engine.isRunning {
                engine.stop()
            }
        }
    }

    func stop(soundID: UUID) {
        if let track = tracks.removeValue(forKey: soundID) {
            track.stop()
            track.detach()
            playingSoundIDs.remove(soundID)
        }
        if tracks.isEmpty && engine.isRunning {
            engine.stop()
        }
    }

    func stopAll() {
        for (_, track) in tracks {
            track.stop()
            track.detach()
        }
        tracks.removeAll()
        playingSoundIDs.removeAll()
        if engine.isRunning {
            engine.stop()
        }
    }

    func isPlaying(soundID: UUID) -> Bool {
        playingSoundIDs.contains(soundID)
    }

    func getTrack(for soundID: UUID) -> TrackPlayer? {
        tracks[soundID]
    }

    // MARK: - Single-track interface for SoundControlsView

    func playForControls(sound: SoundItem) -> TrackPlayer {
        stop(soundID: sound.id)

        let track = TrackPlayer(id: sound.id, engine: engine)
        do {
            try track.loadFile(url: sound.fileURL)
            track.volume = sound.volume
            track.speed = sound.speed
            track.bassGain = sound.eqBass
            track.midGain = sound.eqMid
            track.trebleGain = sound.eqTreble
            track.volumeBoost = sound.effectiveVolumeBoost
            ensureEngineRunning()
        } catch {
            print("Load error: \(error)")
        }

        tracks[sound.id] = track
        playingSoundIDs.insert(sound.id)
        monitorTrack(sound.id)
        return track
    }

    // MARK: - Conversion

    static func convertVideoToM4A(inputURL: URL, outputFileName: String) async throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = documentsURL.appendingPathComponent(outputFileName)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let asset = AVURLAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ConversionError.exportSessionFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw exportSession.error ?? ConversionError.unknown
        case .cancelled:
            throw ConversionError.cancelled
        default:
            throw ConversionError.unknown
        }
    }

    static func copyAudioFile(inputURL: URL, outputFileName: String) throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = documentsURL.appendingPathComponent(outputFileName)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        try FileManager.default.copyItem(at: inputURL, to: outputURL)
        return outputURL
    }

    enum ConversionError: LocalizedError {
        case exportSessionFailed
        case cancelled
        case unknown

        var errorDescription: String? {
            switch self {
            case .exportSessionFailed: return "Failed to create export session"
            case .cancelled: return "Export was cancelled"
            case .unknown: return "Unknown export error"
            }
        }
    }
}
