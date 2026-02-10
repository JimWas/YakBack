//
//  MatrixRainView.swift
//  Yak Back
//
//  Created by Jim Washkau on 2/1/26.
//

import SwiftUI

struct MatrixRainView: View {
    let columnCount = 20

    var body: some View {
        GeometryReader { geo in
            let colWidth = geo.size.width / CGFloat(columnCount)
            ZStack {
                MatrixTheme.background
                ForEach(0..<columnCount, id: \.self) { col in
                    MatrixColumn(
                        columnWidth: colWidth,
                        height: geo.size.height,
                        xOffset: CGFloat(col) * colWidth
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct MatrixColumn: View {
    let columnWidth: CGFloat
    let height: CGFloat
    let xOffset: CGFloat

    @State private var offset: CGFloat = 0
    @State private var characters: [String] = []
    @State private var speed: Double = 0

    private let matrixChars = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789")

    var body: some View {
        Canvas { context, size in
            for (index, char) in characters.enumerated() {
                let y = (CGFloat(index) * 18 + offset).truncatingRemainder(dividingBy: height + 200) - 100
                let alpha = max(0, 1.0 - Double(index) / Double(characters.count))
                let color = Color(red: 0, green: alpha, blue: alpha * 0.25)

                var text = Text(char)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(color)

                if index == 0 {
                    text = Text(char)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white)
                }

                context.draw(text, at: CGPoint(x: xOffset + columnWidth / 2, y: y))
            }
        }
        .onAppear {
            speed = Double.random(in: 30...80)
            let count = Int.random(in: 8...20)
            characters = (0..<count).map { _ in
                String(matrixChars.randomElement()!)
            }
            withAnimation(.linear(duration: speed / 10).repeatForever(autoreverses: false)) {
                offset = height + 200
            }
        }
    }
}
