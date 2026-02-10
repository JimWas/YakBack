//
//  Theme.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/1/26.
//

import SwiftUI

enum MatrixTheme {
    static let fontName = "Nasalization"

    static let green = Color(red: 0, green: 1, blue: 0.255)
    static let darkGreen = Color(red: 0, green: 0.4, blue: 0.1)
    static let dimGreen = Color(red: 0, green: 0.6, blue: 0.15)
    static let background = Color(red: 0.02, green: 0.02, blue: 0.03)
    static let cardBackground = Color(red: 0.05, green: 0.08, blue: 0.05)
    static let cardBorder = Color(red: 0, green: 0.7, blue: 0.2).opacity(0.5)
    static let glowColor = Color(red: 0, green: 1, blue: 0.255).opacity(0.6)

    static func font(_ size: CGFloat) -> Font {
        .custom(fontName, size: size)
    }
}

struct MatrixText: View {
    let text: String
    let size: CGFloat
    var color: Color = MatrixTheme.green

    var body: some View {
        Text(text)
            .font(MatrixTheme.font(size))
            .foregroundStyle(color)
    }
}

struct GlowingBorder: ViewModifier {
    var color: Color = MatrixTheme.green
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.6), lineWidth: lineWidth)
            )
            .shadow(color: color.opacity(0.3), radius: 8)
    }
}

extension View {
    func glowingBorder(color: Color = MatrixTheme.green, lineWidth: CGFloat = 1) -> some View {
        modifier(GlowingBorder(color: color, lineWidth: lineWidth))
    }
}
