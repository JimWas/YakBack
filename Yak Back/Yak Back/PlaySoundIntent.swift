//
//  PlaySoundIntent.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/4/26.
//

import AppIntents
import SwiftData
import AVFoundation

// MARK: - Sound Entity

struct SoundEntity: AppEntity {
    static var defaultQuery = SoundEntityQuery()
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sound")

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Sound Entity Query

struct SoundEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SoundEntity] {
        let sounds = try fetchAllSounds()
        return sounds.filter { identifiers.contains($0.id.uuidString) }
            .map { SoundEntity(id: $0.id.uuidString, name: $0.name) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<SoundEntity> {
        let sounds = try fetchAllSounds()
        let filtered = sounds.filter { $0.name.localizedCaseInsensitiveContains(string) }
        return IntentItemCollection(items: filtered.map { SoundEntity(id: $0.id.uuidString, name: $0.name) })
    }

    func suggestedEntities() async throws -> IntentItemCollection<SoundEntity> {
        let sounds = try fetchAllSounds()
        return IntentItemCollection(items: sounds.map { SoundEntity(id: $0.id.uuidString, name: $0.name) })
    }

    private func fetchAllSounds() throws -> [SoundItem] {
        let schema = Schema([SoundItem.self, SoundFolder.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SoundItem>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor)
    }
}

// MARK: - Play Sound Intent

struct PlaySoundIntent: AppIntent {
    static var title: LocalizedStringResource = "Play Sound"
    static var description = IntentDescription("Play a sound from your Yak Back soundboard")
    static var openAppWhenRun = false

    @Parameter(title: "Sound")
    var sound: SoundEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let schema = Schema([SoundItem.self, SoundFolder.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let targetID = UUID(uuidString: sound.id)
        var descriptor = FetchDescriptor<SoundItem>()
        descriptor.predicate = #Predicate { $0.id == targetID! }
        descriptor.fetchLimit = 1

        guard let soundItem = try context.fetch(descriptor).first else {
            return .result(dialog: "Could not find \"\(sound.name)\" in your soundboard.")
        }

        let url = soundItem.fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .result(dialog: "The audio file for \"\(sound.name)\" is missing.")
        }

        // Configure audio session and play
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try AVAudioSession.sharedInstance().setActive(true)

        let player = try AVAudioPlayer(contentsOf: url)
        player.volume = soundItem.volume * soundItem.effectiveVolumeBoost
        player.enableRate = true
        player.rate = soundItem.speed
        player.play()

        // Keep alive until playback finishes
        while player.isPlaying {
            try await Task.sleep(for: .milliseconds(200))
        }

        return .result(dialog: "Played \"\(sound.name)\"")
    }
}
