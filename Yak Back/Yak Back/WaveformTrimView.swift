//
//  WaveformTrimView.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/2/26.
//

import SwiftUI
import AVFoundation

struct WaveformTrimView: View {
    @Bindable var sound: SoundItem
    @Environment(\.dismiss) private var dismiss

    @State private var samples: [Float] = []
    @State private var trimStart: Double = 0.0
    @State private var trimEnd: Double = 1.0
    @State private var duration: Double = 0.0
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .fill(MatrixTheme.dimGreen)
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                MatrixText(text: "TRIM SOUND", size: 20)

                if samples.isEmpty {
                    ProgressView()
                        .tint(MatrixTheme.green)
                        .padding(40)
                } else {
                    waveformView
                        .padding(.horizontal)

                    timeLabels
                        .padding(.horizontal)

                    trimControls

                    if let errorMessage {
                        MatrixText(text: errorMessage, size: 11, color: .red)
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        MatrixText(text: "CANCEL", size: 13, color: MatrixTheme.dimGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MatrixTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .glowingBorder(color: MatrixTheme.dimGreen)
                    }

                    Button {
                        applyTrim()
                    } label: {
                        MatrixText(text: isProcessing ? "TRIMMING..." : "APPLY TRIM", size: 13)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(MatrixTheme.green.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .glowingBorder()
                    }
                    .disabled(isProcessing)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            loadWaveform()
        }
    }

    private var waveformView: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(MatrixTheme.cardBackground)

                // Waveform bars
                HStack(spacing: 1) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                        let normalizedIndex = Double(index) / Double(max(samples.count - 1, 1))
                        let isInRange = normalizedIndex >= trimStart && normalizedIndex <= trimEnd

                        RoundedRectangle(cornerRadius: 1)
                            .fill(isInRange ? MatrixTheme.green : MatrixTheme.dimGreen.opacity(0.3))
                            .frame(height: max(2, CGFloat(sample) * height * 0.8))
                    }
                }
                .padding(.horizontal, 4)

                // Trim handles
                let startX = trimStart * width
                let endX = trimEnd * width

                // Dimmed areas outside trim
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: max(0, startX))
                    Spacer()
                }

                HStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: max(0, width - endX))
                }

                // Start handle
                Rectangle()
                    .fill(MatrixTheme.green)
                    .frame(width: 3)
                    .position(x: startX, y: height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newStart = max(0, min(value.location.x / width, trimEnd - 0.02))
                                trimStart = newStart
                            }
                    )

                // End handle
                Rectangle()
                    .fill(MatrixTheme.green)
                    .frame(width: 3)
                    .position(x: endX, y: height / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newEnd = min(1, max(value.location.x / width, trimStart + 0.02))
                                trimEnd = newEnd
                            }
                    )
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .glowingBorder()
    }

    private var timeLabels: some View {
        HStack {
            MatrixText(text: formatTime(trimStart * duration), size: 11, color: MatrixTheme.green)
            Spacer()
            MatrixText(
                text: "Duration: \(formatTime((trimEnd - trimStart) * duration))",
                size: 11,
                color: MatrixTheme.dimGreen
            )
            Spacer()
            MatrixText(text: formatTime(trimEnd * duration), size: 11, color: MatrixTheme.green)
        }
    }

    private var trimControls: some View {
        VStack(spacing: 12) {
            HStack {
                MatrixText(text: "START", size: 11, color: MatrixTheme.dimGreen)
                    .frame(width: 50, alignment: .leading)
                MatrixSlider(
                    value: Binding(
                        get: { Float(trimStart) },
                        set: { trimStart = min(Double($0), trimEnd - 0.02) }
                    ),
                    range: 0...1
                )
            }
            .padding(.horizontal)

            HStack {
                MatrixText(text: "END", size: 11, color: MatrixTheme.dimGreen)
                    .frame(width: 50, alignment: .leading)
                MatrixSlider(
                    value: Binding(
                        get: { Float(trimEnd) },
                        set: { trimEnd = max(Double($0), trimStart + 0.02) }
                    ),
                    range: 0...1
                )
            }
            .padding(.horizontal)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", mins, secs, ms)
    }

    private func loadWaveform() {
        Task {
            do {
                let file = try AVAudioFile(forReading: sound.fileURL)
                duration = Double(file.length) / file.processingFormat.sampleRate

                // Load existing trim points
                if let ts = sound.trimStart, let te = sound.trimEnd, te > ts {
                    trimStart = ts / duration
                    trimEnd = te / duration
                }

                let format = file.processingFormat
                let frameCount = AVAudioFrameCount(file.length)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
                try file.read(into: buffer)

                guard let channelData = buffer.floatChannelData?[0] else { return }
                let totalFrames = Int(buffer.frameLength)
                let barCount = 100
                let framesPerBar = max(1, totalFrames / barCount)

                var result: [Float] = []
                for i in 0..<barCount {
                    let start = i * framesPerBar
                    let end = min(start + framesPerBar, totalFrames)
                    var sum: Float = 0
                    for j in start..<end {
                        sum += abs(channelData[j])
                    }
                    result.append(sum / Float(end - start))
                }

                // Normalize
                let maxVal = result.max() ?? 1.0
                if maxVal > 0 {
                    result = result.map { $0 / maxVal }
                }

                await MainActor.run {
                    samples = result
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load audio: \(error.localizedDescription)"
                }
            }
        }
    }

    private func applyTrim() {
        isProcessing = true
        errorMessage = nil

        let startTime = trimStart * duration
        let endTime = trimEnd * duration

        Task {
            do {
                let inputURL = sound.fileURL
                let file = try AVAudioFile(forReading: inputURL)
                let format = file.processingFormat
                let sampleRate = format.sampleRate

                let startFrame = AVAudioFramePosition(startTime * sampleRate)
                let endFrame = AVAudioFramePosition(endTime * sampleRate)
                let frameCount = AVAudioFrameCount(endFrame - startFrame)

                guard frameCount > 0 else {
                    await MainActor.run {
                        errorMessage = "Selected range is too short."
                        isProcessing = false
                    }
                    return
                }

                file.framePosition = startFrame
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    throw NSError(domain: "WaveformTrim", code: 1, userInfo: [NSLocalizedDescriptionKey: "Buffer allocation failed"])
                }
                try file.read(into: buffer, frameCount: frameCount)

                // Write trimmed audio to a new file
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let ext = inputURL.pathExtension
                let baseName = inputURL.deletingPathExtension().lastPathComponent
                let trimmedFileName = "\(baseName)_trimmed_\(UUID().uuidString.prefix(4)).\(ext)"
                let outputURL = docs.appendingPathComponent(trimmedFileName)

                let outputFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
                try outputFile.write(from: buffer)

                // Remove old file
                try? FileManager.default.removeItem(at: inputURL)

                await MainActor.run {
                    sound.fileName = trimmedFileName
                    sound.trimStart = nil
                    sound.trimEnd = nil
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Trim failed: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
}
