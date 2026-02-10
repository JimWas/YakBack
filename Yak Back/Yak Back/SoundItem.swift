//
//  SoundItem.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/1/26.
//

import Foundation
import SwiftData

@Model
final class SoundItem {
    var id: UUID
    var name: String
    var fileName: String
    var dateAdded: Date
    var volume: Float
    var speed: Float
    var loopCount: Int // -1 = infinite
    var eqBass: Float
    var eqMid: Float
    var eqTreble: Float
    var volumeBoost: Float?
    var colorHue: Double

    // New optional properties (safe for migration)
    var isFavorite: Bool?
    var sortOrder: Int?
    var folderName: String?
    var trimStart: Double?
    var trimEnd: Double?

    init(name: String, fileName: String) {
        self.id = UUID()
        self.name = name
        self.fileName = fileName
        self.dateAdded = Date()
        self.volume = 1.0
        self.speed = 1.0
        self.loopCount = 1
        self.eqBass = 0.0
        self.eqMid = 0.0
        self.eqTreble = 0.0
        self.volumeBoost = 1.0
        self.colorHue = Double.random(in: 0.25...0.45)
        self.isFavorite = false
        self.sortOrder = nil
        self.folderName = nil
        self.trimStart = nil
        self.trimEnd = nil
    }

    var effectiveVolumeBoost: Float {
        get { volumeBoost ?? 1.0 }
        set { volumeBoost = newValue }
    }

    var effectiveFavorite: Bool {
        get { isFavorite ?? false }
        set { isFavorite = newValue }
    }

    var effectiveSortOrder: Int {
        get { sortOrder ?? Int.max }
        set { sortOrder = newValue }
    }

    var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(fileName)
    }
}
