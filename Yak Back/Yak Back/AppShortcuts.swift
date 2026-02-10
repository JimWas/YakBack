//
//  AppShortcuts.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/4/26.
//

import AppIntents

struct YakBackShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlaySoundIntent(),
            phrases: [
                "Play \(\.$sound) in \(.applicationName)",
                "Play \(\.$sound) on \(.applicationName)",
                "Play \(\.$sound) with \(.applicationName)",
                "\(.applicationName) play \(\.$sound)"
            ],
            shortTitle: "Play Sound",
            systemImageName: "play.circle.fill"
        )
    }
}
