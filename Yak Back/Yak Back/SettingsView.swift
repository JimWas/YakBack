//
//  SettingsView.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/2/26.
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    var storeManager: StoreManager
    @State private var isPurchasing = false

    private let appVersion: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }()

    var body: some View {
        ZStack {
            MatrixTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        Capsule()
                            .fill(MatrixTheme.dimGreen)
                            .frame(width: 40, height: 4)
                            .padding(.top, 12)
                            .accessibilityHidden(true)

                        MatrixText(text: "SETTINGS", size: 22)

                        // Pro section
                        settingsSection(title: "PRO") {
                            if storeManager.isPro {
                                HStack {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.yellow)
                                        .frame(width: 28)
                                    MatrixText(text: "PRO UNLOCKED", size: 13)
                                    Spacer()
                                    MatrixText(text: "Unlimited • No Ads", size: 12, color: MatrixTheme.dimGreen)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            } else {
                                Button {
                                    isPurchasing = true
                                    Task {
                                        await storeManager.purchase()
                                        isPurchasing = false
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.yellow)
                                            .frame(width: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                        MatrixText(text: "SUBSCRIBE TO PRO", size: 13)
                                        MatrixText(text: "Unlimited sounds • No ads", size: 10, color: MatrixTheme.dimGreen)
                                        }
                                        Spacer()
                                        if isPurchasing {
                                            ProgressView()
                                                .tint(MatrixTheme.green)
                                        } else {
                                        MatrixText(
                                            text: storeManager.proProduct?.displayPrice ?? "$2.99/mo",
                                            size: 13,
                                            color: .black
                                        )
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(MatrixTheme.green)
                                        .clipShape(Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                }
                                .disabled(isPurchasing)

                                Button {
                                    Task { await storeManager.restorePurchases() }
                                } label: {
                                    settingsRow(icon: "arrow.clockwise", label: "Restore Purchases", value: nil, showChevron: true)
                                }
                            }
                        }

                        // About section
                        settingsSection(title: "ABOUT") {
                            settingsRow(icon: "info.circle", label: "Version", value: appVersion)
                            settingsRow(icon: "person.fill", label: "Developer", value: "Jim Washkau")
                        }

                        // Legal section
                        settingsSection(title: "LEGAL") {
                            Button {
                                if let url = URL(string: "https://jimwas.com/yakback/privacy") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                settingsRow(icon: "hand.raised.fill", label: "Privacy Policy", value: nil, showChevron: true)
                            }

                            Button {
                                if let url = URL(string: "https://jimwas.com/yakback/terms") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                settingsRow(icon: "doc.text.fill", label: "Terms of Use", value: nil, showChevron: true)
                            }
                        }

                        // Preferences
                        settingsSection(title: "PREFERENCES") {
                            HStack {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .font(.system(size: 16))
                                    .foregroundStyle(MatrixTheme.green)
                                    .frame(width: 28)

                                MatrixText(text: "Haptic Feedback", size: 13)

                                Spacer()

                                Toggle("", isOn: $hapticEnabled)
                                    .tint(MatrixTheme.green)
                                    .labelsHidden()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Haptic Feedback")
                            .accessibilityValue(hapticEnabled ? "On" : "Off")
                        }

                        // Actions
                        settingsSection(title: "ACTIONS") {
                            Button {
                                hasCompletedOnboarding = false
                                dismiss()
                            } label: {
                                settingsRow(icon: "arrow.counterclockwise", label: "Replay Onboarding", value: nil, showChevron: true)
                            }
                        }

                        // Storage info
                        settingsSection(title: "STORAGE") {
                            let used = calculateStorageUsed()
                            settingsRow(icon: "internaldrive.fill", label: "Sounds Storage", value: used)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }

                AdBannerView(showAd: !storeManager.isPro)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MatrixText(text: title, size: 11, color: MatrixTheme.dimGreen)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(MatrixTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .glowingBorder()
        }
    }

    private func settingsRow(icon: String, label: String, value: String?, showChevron: Bool = false) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(MatrixTheme.green)
                .frame(width: 28)

            MatrixText(text: label, size: 13)

            Spacer()

            if let value {
                MatrixText(text: value, size: 12, color: MatrixTheme.dimGreen)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(MatrixTheme.dimGreen)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func calculateStorageUsed() -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var totalSize: Int64 = 0
        if let files = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in files {
                if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]),
                   let size = attrs.fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}
