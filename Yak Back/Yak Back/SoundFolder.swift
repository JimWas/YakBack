//
//  SoundFolder.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/2/26.
//

import Foundation
import SwiftData

@Model
final class SoundFolder {
    var id: UUID
    var name: String
    var colorHue: Double
    var sortOrder: Int
    var dateCreated: Date

    init(name: String, colorHue: Double = 0.33) {
        self.id = UUID()
        self.name = name
        self.colorHue = colorHue
        self.sortOrder = 0
        self.dateCreated = Date()
    }
}
