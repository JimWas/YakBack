//
//  SoundControlsView.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/1/26.
//

import SwiftUI
import SwiftData

struct SoundControlsView: View {
    @Bindable var sound: SoundItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let audioEngine: AudioEngine
    let showAds: Bool
    @State private var track: TrackPlayer?

    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var showDeleteConfirm = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showTrimView = false

    // Timer playback
    @State private var selectedDelay: Int = 5 // seconds
    @State private var timerRemaining: Int = 0
    @State private var timerActive = false
    @State private var countdownTimer: Timer?

    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let timerPresets: [(label: String, seconds: Int)] = [
        ("5s", 5), ("10s", 10), ("30s", 30), ("1m", 60), ("5m", 300)
    ]

    private var isPlaying: Bool {
        track?.isPlaying ?? false
    }

    var body: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        playbackControls
                        volumeSection
                        speedSection
                        loopSection
                        timerSection
                        equalizerSection
                        colorSection
                        trimSection
                        actionButtons
                    }
                    .padding()
                }

                AdBannerView(showAd: showAds)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                MatrixText(text: sound.name, size: 16)
            }
        }
        .onAppear {
            track = audioEngine.getTrack(for: sound.id)
            if track == nil {
                startPlayback()
            }
        }
        .onDisappear {
            cancelTimer()
        }
        .alert("Delete Sound", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSound()
            }
        } message: {
            Text("This will permanently remove this sound from your board.")
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showTrimView) {
            WaveformTrimView(sound: sound)
                .presentationDetents([.medium, .large])
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hue: sound.colorHue, saturation: 0.8, brightness: 0.3),
                                MatrixTheme.background
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: isPlaying ? "waveform" : "music.note")
                    .font(.system(size: 36))
                    .foregroundStyle(MatrixTheme.green)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
            }

            Text(sound.name)
                .font(MatrixTheme.font(20))
                .foregroundStyle(MatrixTheme.green)

            Text("Added \(sound.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                .font(MatrixTheme.font(11))
                .foregroundStyle(MatrixTheme.dimGreen)
        }
        .padding(.top, 8)
    }

    private var playbackControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Button {
                    stopTrack()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(MatrixTheme.green)
                        .frame(width: 50, height: 50)
                        .background(MatrixTheme.cardBackground)
                        .clipShape(Circle())
                        .glowingBorder(color: MatrixTheme.green, lineWidth: 1)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Stop")

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.black)
                        .frame(width: 70, height: 70)
                        .background(MatrixTheme.green)
                        .clipShape(Circle())
                        .shadow(color: MatrixTheme.glowColor, radius: 12)
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button {
                    stopTrack()
                    startPlayback()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20))
                        .foregroundStyle(MatrixTheme.green)
                        .frame(width: 50, height: 50)
                        .background(MatrixTheme.cardBackground)
                        .clipShape(Circle())
                        .glowingBorder(color: MatrixTheme.green, lineWidth: 1)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Restart")
            }

            Button {
                stopTrack()
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    MatrixText(text: "STOP & GO BACK", size: 13)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.5), lineWidth: 1))
            }
            .accessibilityLabel("Stop playback and return to soundboard")
        }
    }

    private var volumeSection: some View {
        controlCard(title: "VOLUME") {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(MatrixTheme.dimGreen)
                    MatrixSlider(value: Binding(
                        get: { sound.volume },
                        set: { sound.volume = $0; track?.volume = $0 }
                    ), range: 0...1)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(MatrixTheme.green)
                }

                HStack {
                    MatrixText(text: "BOOST", size: 11, color: MatrixTheme.dimGreen)
                    Spacer()
                    MatrixSlider(value: Binding(
                        get: { sound.effectiveVolumeBoost },
                        set: { sound.effectiveVolumeBoost = $0; track?.volumeBoost = $0 }
                    ), range: 1...2)
                    MatrixText(text: "\(String(format: "%.1f", sound.effectiveVolumeBoost))x", size: 12)
                }
            }
        }
    }

    private var speedSection: some View {
        controlCard(title: "SPEED") {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "tortoise.fill")
                        .foregroundStyle(MatrixTheme.dimGreen)
                    MatrixSlider(value: Binding(
                        get: { sound.speed },
                        set: { sound.speed = $0; track?.speed = $0 }
                    ), range: 0.25...2.0)
                    Image(systemName: "hare.fill")
                        .foregroundStyle(MatrixTheme.green)
                }

                MatrixText(text: "\(String(format: "%.2f", sound.speed))x", size: 14)

                HStack(spacing: 8) {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { preset in
                        Button {
                            sound.speed = Float(preset)
                            track?.speed = Float(preset)
                        } label: {
                            Text("\(String(format: "%g", preset))x")
                                .font(MatrixTheme.font(10))
                                .foregroundStyle(sound.speed == Float(preset) ? .black : MatrixTheme.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(sound.speed == Float(preset) ? MatrixTheme.green : MatrixTheme.cardBackground)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(MatrixTheme.cardBorder, lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
        }
    }

    private var loopSection: some View {
        controlCard(title: "LOOP") {
            VStack(spacing: 12) {
                HStack {
                    MatrixText(text: loopDisplayText, size: 28)
                    Spacer()
                    VStack(spacing: 4) {
                        Button {
                            if sound.loopCount == -1 { return }
                            if sound.loopCount >= 99 {
                                sound.loopCount = -1
                            } else {
                                sound.loopCount += 1
                            }
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(MatrixTheme.green)
                                .frame(width: 44, height: 34)
                                .background(MatrixTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(MatrixTheme.cardBorder))
                        }
                        Button {
                            if sound.loopCount == -1 {
                                sound.loopCount = 99
                            } else if sound.loopCount > 1 {
                                sound.loopCount -= 1
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(MatrixTheme.green)
                                .frame(width: 44, height: 34)
                                .background(MatrixTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(MatrixTheme.cardBorder))
                        }
                    }
                }

                HStack(spacing: 8) {
                    ForEach([1, 3, 5, 10, -1], id: \.self) { preset in
                        Button {
                            sound.loopCount = preset
                        } label: {
                            Text(preset == -1 ? "\u{221E}" : "\(preset)")
                                .font(MatrixTheme.font(12))
                                .foregroundStyle(sound.loopCount == preset ? .black : MatrixTheme.green)
                                .frame(width: 44, height: 32)
                                .background(sound.loopCount == preset ? MatrixTheme.green : MatrixTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(MatrixTheme.cardBorder, lineWidth: 0.5))
                        }
                    }
                }
            }
        }
    }

    private var loopDisplayText: String {
        if sound.loopCount == -1 {
            return "\u{221E}"
        }
        return "\(sound.loopCount)"
    }

    private var equalizerSection: some View {
        controlCard(title: "EQUALIZER") {
            VStack(spacing: 16) {
                eqBand(label: "BASS", value: Binding(
                    get: { sound.eqBass },
                    set: { sound.eqBass = $0; track?.bassGain = $0 }
                ))
                eqBand(label: "MID", value: Binding(
                    get: { sound.eqMid },
                    set: { sound.eqMid = $0; track?.midGain = $0 }
                ))
                eqBand(label: "TREBLE", value: Binding(
                    get: { sound.eqTreble },
                    set: { sound.eqTreble = $0; track?.trebleGain = $0 }
                ))

                Button {
                    sound.eqBass = 0
                    sound.eqMid = 0
                    sound.eqTreble = 0
                    track?.bassGain = 0
                    track?.midGain = 0
                    track?.trebleGain = 0
                } label: {
                    MatrixText(text: "RESET EQ", size: 11, color: MatrixTheme.dimGreen)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(MatrixTheme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(MatrixTheme.cardBorder, lineWidth: 0.5))
                }
            }
        }
    }

    private func eqBand(label: String, value: Binding<Float>) -> some View {
        HStack {
            MatrixText(text: label, size: 11, color: MatrixTheme.dimGreen)
                .frame(width: 55, alignment: .leading)
            MatrixSlider(value: value, range: -12...12)
            MatrixText(text: "\(String(format: "%+.0f", value.wrappedValue))dB", size: 11)
                .frame(width: 45, alignment: .trailing)
        }
    }

    private var colorSection: some View {
        controlCard(title: "PAD COLOR") {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    ForEach(0..<20, id: \.self) { i in
                        let hue = Double(i) / 20.0
                        Rectangle()
                            .fill(Color(hue: hue, saturation: 0.8, brightness: 0.6))
                            .frame(height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(
                                        abs(sound.colorHue - hue) < 0.03 ? Color.white : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .onTapGesture {
                                sound.colorHue = hue
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))

                HStack {
                    MatrixText(text: "HUE", size: 11, color: MatrixTheme.dimGreen)
                    MatrixSlider(value: Binding(
                        get: { Float(sound.colorHue) },
                        set: { sound.colorHue = Double($0) }
                    ), range: 0...1)
                    Circle()
                        .fill(Color(hue: sound.colorHue, saturation: 0.8, brightness: 0.6))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(MatrixTheme.cardBorder))
                }
            }
        }
    }

    private var trimSection: some View {
        Button {
            stopTrack()
            showTrimView = true
        } label: {
            HStack {
                Image(systemName: "scissors")
                    .foregroundStyle(MatrixTheme.green)
                MatrixText(text: "TRIM SOUND", size: 13)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(MatrixTheme.dimGreen)
            }
            .padding(16)
            .background(MatrixTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .glowingBorder()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                exportURL = sound.fileURL
                showExportSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    MatrixText(text: "SAVE TO FILES", size: 13)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(MatrixTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .glowingBorder()
            }

            Button {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    MatrixText(text: "DELETE SOUND", size: 13, color: .red)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.4)))
            }
        }
        .padding(.bottom, 30)
    }

    private var timerSection: some View {
        controlCard(title: "TIMER") {
            VStack(spacing: 12) {
                if timerActive {
                    VStack(spacing: 8) {
                        MatrixText(text: timerDisplayText, size: 36)
                            .monospacedDigit()

                        MatrixText(text: "PLAYING IN...", size: 11, color: MatrixTheme.dimGreen)

                        Button {
                            cancelTimer()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                MatrixText(text: "CANCEL", size: 12, color: .red)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.red.opacity(0.4), lineWidth: 1))
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        ForEach(timerPresets, id: \.seconds) { preset in
                            Button {
                                selectedDelay = preset.seconds
                            } label: {
                                Text(preset.label)
                                    .font(MatrixTheme.font(11))
                                    .foregroundStyle(selectedDelay == preset.seconds ? .black : MatrixTheme.green)
                                    .frame(width: 44, height: 32)
                                    .background(selectedDelay == preset.seconds ? MatrixTheme.green : MatrixTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(MatrixTheme.cardBorder, lineWidth: 0.5))
                            }
                        }
                    }

                    Button {
                        startTimer()
                    } label: {
                        HStack {
                            Image(systemName: "timer")
                            MatrixText(text: "START TIMER", size: 13)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(MatrixTheme.green.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MatrixTheme.green.opacity(0.5), lineWidth: 1))
                    }
                    .accessibilityLabel("Start timer for \(selectedDelay) seconds")
                }
            }
        }
    }

    private var timerDisplayText: String {
        let minutes = timerRemaining / 60
        let seconds = timerRemaining % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return "\(seconds)"
    }

    private func startTimer() {
        fireHaptic()
        stopTrack()
        timerRemaining = selectedDelay
        timerActive = true
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if timerRemaining > 1 {
                    timerRemaining -= 1
                } else {
                    cancelTimer()
                    startPlayback()
                    fireHaptic()
                }
            }
        }
    }

    private func cancelTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        timerActive = false
        timerRemaining = 0
    }

    private func controlCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MatrixText(text: title, size: 12, color: MatrixTheme.dimGreen)
            content()
        }
        .padding(16)
        .background(MatrixTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .glowingBorder()
    }

    private func fireHaptic() {
        if hapticEnabled { haptic.impactOccurred() }
    }

    private func togglePlayback() {
        fireHaptic()
        if isPlaying {
            track?.pause()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        let t = audioEngine.playForControls(sound: sound)
        t.play(loops: sound.loopCount)
        track = t
    }

    private func stopTrack() {
        fireHaptic()
        audioEngine.stop(soundID: sound.id)
        track = nil
    }

    private func deleteSound() {
        audioEngine.stop(soundID: sound.id)
        try? FileManager.default.removeItem(at: sound.fileURL)
        modelContext.delete(sound)
        dismiss()
    }
}

struct MatrixSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>

    var body: some View {
        GeometryReader { geo in
            let fraction = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbX = fraction * geo.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MatrixTheme.cardBackground)
                    .frame(height: 6)
                    .overlay(Capsule().stroke(MatrixTheme.cardBorder, lineWidth: 0.5))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [MatrixTheme.darkGreen, MatrixTheme.green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, thumbX), height: 6)

                Circle()
                    .fill(MatrixTheme.green)
                    .frame(width: 18, height: 18)
                    .shadow(color: MatrixTheme.glowColor, radius: 6)
                    .offset(x: max(0, min(thumbX - 9, geo.size.width - 18)))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let fraction = Float(gesture.location.x / geo.size.width)
                        let clamped = max(0, min(1, fraction))
                        value = range.lowerBound + clamped * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 24)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
