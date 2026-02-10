//
//  OnboardingView.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/2/26.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentPage = 0
    @State private var showContent = false

    private let pages: [(icon: String, title: String, subtitle: String, description: String)] = [
        (
            "waveform.badge.plus",
            "WELCOME TO\nYAK BACK",
            "DIGITAL SOUNDBOARD",
            "Import videos, record audio, and build\nyour ultimate custom soundboard."
        ),
        (
            "film.fill",
            "IMPORT & CONVERT",
            "VIDEO + AUDIO FILES",
            "Import video files and automatically\nextract the audio. Or import audio\nfiles directly - MP3, WAV, M4A, AIF."
        ),
        (
            "mic.fill",
            "RECORD LIVE",
            "BUILT-IN RECORDER",
            "Record audio directly from your\nmicrophone and add it straight\nto your soundboard."
        ),
        (
            "slider.horizontal.3",
            "FINE TUNE",
            "EQUALIZER + EFFECTS",
            "Adjust EQ, volume boost, playback\nspeed, and loop count for every\nsound on your board."
        ),
        (
            "square.grid.3x3.fill",
            "MULTI-TRACK",
            "PLAY SIMULTANEOUSLY",
            "Tap multiple pads to layer sounds\ntogether. Long-press any pad to\naccess its full controls."
        )
    ]

    var body: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()

            MatrixRainView()
                .opacity(0.1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        onboardingPage(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Custom page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? MatrixTheme.green : MatrixTheme.dimGreen.opacity(0.3))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 20)

                // Buttons
                HStack {
                    if currentPage > 0 {
                        Button {
                            currentPage -= 1
                        } label: {
                            MatrixText(text: "BACK", size: 14, color: MatrixTheme.dimGreen)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                    }

                    Spacer()

                    if currentPage < pages.count - 1 {
                        Button {
                            currentPage += 1
                        } label: {
                            HStack(spacing: 6) {
                                MatrixText(text: "NEXT", size: 14)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(MatrixTheme.green)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(MatrixTheme.cardBackground)
                            .clipShape(Capsule())
                            .glowingBorder()
                        }
                    } else {
                        Button {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isComplete = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                MatrixText(text: "START", size: 14, color: .black)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.black)
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(MatrixTheme.green)
                            .clipShape(Capsule())
                            .shadow(color: MatrixTheme.glowColor, radius: 12)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }
    }

    private func onboardingPage(_ page: (icon: String, title: String, subtitle: String, description: String)) -> some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MatrixTheme.green.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: page.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(MatrixTheme.green)
                    .shadow(color: MatrixTheme.glowColor, radius: 12)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Text(page.title)
                .font(MatrixTheme.font(26))
                .foregroundStyle(MatrixTheme.green)
                .multilineTextAlignment(.center)
                .shadow(color: MatrixTheme.glowColor, radius: 8)

            Text(page.subtitle)
                .font(MatrixTheme.font(11))
                .foregroundStyle(MatrixTheme.dimGreen)
                .tracking(4)

            Text(page.description)
                .font(MatrixTheme.font(13))
                .foregroundStyle(MatrixTheme.dimGreen.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)

            Spacer()
            Spacer()
        }
    }
}
