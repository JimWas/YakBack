//
//  SoundPadView.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/1/26.
//

import SwiftUI

struct SoundPadView: View {
    let sound: SoundItem
    let isPlaying: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onSettingsTap: () -> Void
    let onStopTap: () -> Void
    let showSettingsTip: Bool

    @State private var isPressed = false
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: sound.colorHue, saturation: 0.8, brightness: isPlaying ? 0.3 : 0.12),
                                Color(hue: sound.colorHue, saturation: 0.9, brightness: isPlaying ? 0.15 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color(hue: sound.colorHue, saturation: 0.8, brightness: 0.8).opacity(isPlaying ? 0.8 : 0.4),
                        lineWidth: isPlaying ? 2 : 1
                    )

                if isPlaying {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            Color(hue: sound.colorHue, saturation: 0.6, brightness: 1.0).opacity(glowPulse ? 0.6 : 0.2),
                            lineWidth: 3
                        )
                        .blur(radius: 4)
                }

                VStack(spacing: 4) {
                    Image(systemName: isPlaying ? "waveform" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            Color(hue: sound.colorHue, saturation: 0.6, brightness: isPlaying ? 1.0 : 0.7)
                        )
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)

                    Text(sound.name)
                        .font(MatrixTheme.font(11))
                        .foregroundStyle(MatrixTheme.green)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }

                // Favorite indicator
                if sound.effectiveFavorite {
                    VStack {
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.yellow)
                                .padding(4)
                            Spacer()
                        }
                        Spacer()
                    }
                }

                // Status badges (bottom-left)
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        if isPlaying {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red.opacity(0.9))
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                        }

                        if sound.loopCount != 1 {
                            Text(loopBadgeText)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(MatrixTheme.green.opacity(0.9))
                                .clipShape(Capsule())
                                .accessibilityLabel(loopBadgeAccessibility)
                        }

                        Spacer()
                    }
                    .padding(6)
                }

                // Stop control (bottom-right)
                if isPlaying {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                onStopTap()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.9))
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 28, height: 28)
                                .shadow(color: Color.red.opacity(0.6), radius: 6)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Stop \(sound.name)")
                            .accessibilityHint("Stops playback")
                            .padding(6)
                        }
                    }
                }

                VStack {
                    HStack {
                        Spacer()
                        ZStack(alignment: .topTrailing) {
                            Button {
                                onSettingsTap()
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(MatrixTheme.green)
                                    .padding(6)
                                    .background(Color.black.opacity(0.35))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Sound settings")
                            .accessibilityHint("Open controls for \(sound.name)")

                            if showSettingsTip {
                                Text("Settings")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(MatrixTheme.green)
                                    .clipShape(Capsule())
                                    .offset(x: -6, y: -14)
                                    .shadow(color: MatrixTheme.glowColor.opacity(0.6), radius: 6)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    Spacer()
                }
            }
            .frame(height: 100)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .shadow(color: isPlaying ?
                Color(hue: sound.colorHue, saturation: 0.8, brightness: 1.0).opacity(0.4) :
                    .clear, radius: 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sound.name), \(isPlaying ? "playing" : "stopped")")
        .accessibilityHint("Tap to play. Long press for controls.")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var loopBadgeText: String {
        if sound.loopCount == -1 { return "LOOP" }
        return "x\(sound.loopCount)"
    }

    private var loopBadgeAccessibility: String {
        if sound.loopCount == -1 { return "Looping" }
        return "Plays \(sound.loopCount) times"
    }
}
