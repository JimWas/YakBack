//
//  RecordingView.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/2/26.
//

import SwiftUI
import AVFoundation
import SwiftData

@Observable
final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    var isRecording = false
    var recordingTime: TimeInterval = 0
    var meterLevel: Float = -160
    var permissionDenied = false
    var errorMessage: String?
    private var timer: Timer?
    private(set) var outputURL: URL?

    func checkPermission() async -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted {
            return true
        }
        let granted = await AVAudioApplication.requestRecordPermission()
        await MainActor.run {
            permissionDenied = !granted
        }
        return granted
    }

    func startRecording() async {
        let granted = await checkPermission()
        guard granted else { return }

        await MainActor.run {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true)
            } catch {
                errorMessage = "Could not configure audio session."
                return
            }

            // Check available disk space
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: docs.path),
               let freeSpace = attrs[.systemFreeSize] as? Int64,
               freeSpace < 10_000_000 {
                errorMessage = "Not enough storage space to record. Free up at least 10 MB."
                return
            }

            let fileName = "recording_\(UUID().uuidString.prefix(8)).m4a"
            let url = docs.appendingPathComponent(fileName)
            outputURL = url

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            do {
                recorder = try AVAudioRecorder(url: url, settings: settings)
                recorder?.isMeteringEnabled = true
                recorder?.record()
                isRecording = true
                recordingTime = 0
                errorMessage = nil
                startTimer()
            } catch {
                errorMessage = "Could not start recording: \(error.localizedDescription)"
            }
        }
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        isRecording = false
        stopTimer()
        return outputURL
    }

    func cancelRecording() {
        recorder?.stop()
        recorder?.deleteRecording()
        isRecording = false
        outputURL = nil
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder, recorder.isRecording else { return }
            self.recordingTime = recorder.currentTime
            recorder.updateMeters()
            self.meterLevel = recorder.averagePower(forChannel: 0)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var recorder = AudioRecorder()
    @State private var soundName = ""
    @State private var showNameField = false
    let showAds: Bool

    var body: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 30) {
                    Capsule()
                        .fill(MatrixTheme.dimGreen)
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)

                    MatrixText(text: "RECORD AUDIO", size: 22)

                    Spacer()

                    if recorder.permissionDenied {
                        permissionDeniedView
                    } else if showNameField {
                        nameInputSection
                    } else {
                        recordingSection
                    }

                    Spacer()
                }
                .padding()

                AdBannerView(showAd: showAds && !recorder.isRecording)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red.opacity(0.7))

            MatrixText(text: "MICROPHONE ACCESS DENIED", size: 14)

            Text("Yak Back needs microphone access to record audio. Please enable it in Settings.")
                .font(MatrixTheme.font(12))
                .foregroundStyle(MatrixTheme.dimGreen)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                MatrixText(text: "OPEN SETTINGS", size: 13, color: .black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(MatrixTheme.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: MatrixTheme.glowColor, radius: 8)
            }
            .accessibilityLabel("Open device settings to enable microphone")

            Button {
                dismiss()
            } label: {
                MatrixText(text: "CANCEL", size: 12, color: MatrixTheme.dimGreen)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(MatrixTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .glowingBorder(color: .red)
        .padding(.horizontal)
    }

    private var recordingSection: some View {
        VStack(spacing: 24) {
            // Error banner
            if let error = recorder.errorMessage {
                Text(error)
                    .font(MatrixTheme.font(11))
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3)))
            }

            // Meter visualization
            HStack(spacing: 3) {
                ForEach(0..<20, id: \.self) { i in
                    let threshold = Float(-50 + i * 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: i, active: recorder.meterLevel > threshold))
                        .frame(width: 10, height: CGFloat(20 + i * 2))
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 60)
            .animation(.easeOut(duration: 0.05), value: recorder.meterLevel)
            .accessibilityLabel("Audio level meter")

            // Timer display
            Text(formatTime(recorder.recordingTime))
                .font(MatrixTheme.font(40))
                .foregroundStyle(recorder.isRecording ? MatrixTheme.green : MatrixTheme.dimGreen)
                .monospacedDigit()
                .accessibilityLabel("Recording time: \(Int(recorder.recordingTime)) seconds")

            // Record button
            Button {
                if recorder.isRecording {
                    let url = recorder.stopRecording()
                    if url != nil {
                        showNameField = true
                    }
                } else {
                    Task {
                        await recorder.startRecording()
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(MatrixTheme.green, lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .shadow(color: MatrixTheme.glowColor, radius: recorder.isRecording ? 12 : 4)

                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.red)
                            .frame(width: 30, height: 30)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 60, height: 60)
                    }
                }
            }
            .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")

            MatrixText(
                text: recorder.isRecording ? "TAP TO STOP" : "TAP TO RECORD",
                size: 12,
                color: MatrixTheme.dimGreen
            )

            if recorder.isRecording {
                Button {
                    recorder.cancelRecording()
                } label: {
                    MatrixText(text: "CANCEL", size: 12, color: .red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.4)))
                }
                .accessibilityLabel("Cancel recording and discard")
            }
        }
    }

    private var nameInputSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(MatrixTheme.green)
                .accessibilityHidden(true)

            MatrixText(text: "RECORDING SAVED", size: 16)

            Text(formatTime(recorder.recordingTime))
                .font(MatrixTheme.font(18))
                .foregroundStyle(MatrixTheme.dimGreen)

            VStack(alignment: .leading, spacing: 6) {
                MatrixText(text: "SOUND NAME", size: 11, color: MatrixTheme.dimGreen)
                TextField("", text: $soundName, prompt: Text("Enter name...").foregroundStyle(MatrixTheme.dimGreen.opacity(0.5)))
                    .font(MatrixTheme.font(16))
                    .foregroundStyle(MatrixTheme.green)
                    .padding(12)
                    .background(MatrixTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(MatrixTheme.cardBorder))
                    .autocorrectionDisabled()
                    .accessibilityLabel("Sound name input")
            }

            HStack(spacing: 16) {
                Button {
                    recorder.cancelRecording()
                    dismiss()
                } label: {
                    MatrixText(text: "DISCARD", size: 13, color: .red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.4)))
                }
                .accessibilityLabel("Discard recording")

                Button {
                    saveRecording()
                } label: {
                    MatrixText(text: "SAVE", size: 13, color: .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(soundName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? MatrixTheme.dimGreen : MatrixTheme.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: MatrixTheme.glowColor, radius: 8)
                }
                .disabled(soundName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Save recording")
            }
        }
        .padding()
        .background(MatrixTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .glowingBorder()
        .padding(.horizontal)
    }

    private func saveRecording() {
        let name = soundName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let url = recorder.outputURL else { return }

        let sound = SoundItem(name: name, fileName: url.lastPathComponent)
        modelContext.insert(sound)
        dismiss()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    private func barColor(for index: Int, active: Bool) -> Color {
        if !active { return MatrixTheme.cardBackground }
        if index < 14 { return MatrixTheme.green }
        if index < 17 { return .yellow }
        return .red
    }
}
