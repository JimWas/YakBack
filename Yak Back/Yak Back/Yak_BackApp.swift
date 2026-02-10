//
//  Yak_BackApp.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/1/26.
//

import SwiftUI
import SwiftData
import StoreKit
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport

@main
struct Yak_BackApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("launchCount") private var launchCount = 0
    @AppStorage("hasRequestedTracking") private var hasRequestedTracking = false
    @Environment(\.requestReview) private var requestReview

    init() {
        MobileAds.shared.start()
#if DEBUG
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "SIMULATOR",
            "5f668b4d0da72469f7f51d9ca21e6c78"
        ]
#endif
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SoundItem.self,
            SoundFolder.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .onAppear {
                        launchCount += 1
                        if launchCount == 5 || launchCount == 15 || launchCount == 50 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                requestReview()
                            }
                        }
                    }
                    .task {
                        await requestTrackingIfNeeded()
                    }
            } else {
                OnboardingView(isComplete: $hasCompletedOnboarding)
                    .task {
                        await requestTrackingIfNeeded()
                    }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func requestTrackingIfNeeded() async {
        guard #available(iOS 14, *) else { return }
        guard !hasRequestedTracking else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }

        // Give the first frame time to render; iOS can ignore the prompt if requested too early.
        try? await Task.sleep(nanoseconds: 800_000_000)
        hasRequestedTracking = true
        ATTrackingManager.requestTrackingAuthorization { _ in }
    }
}
