//
//  ConfettiView.swift
//  flo
//
//  Created by rizaldy on 21/08/26.
//

import SwiftUI

/// A lightweight confetti burst that falls across the screen once.
/// Used to celebrate a successful tip.
struct ConfettiView: View {
  let count: Int
  let colors: [Color]

  init(
    count: Int = 80,
    colors: [Color] = [
      .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink,
    ]
  ) {
    self.count = count
    self.colors = colors
  }

  var body: some View {
    GeometryReader { geo in
      ZStack {
        ForEach(0..<count, id: \.self) { index in
          ConfettiPiece(
            color: colors[index % colors.count],
            startX: CGFloat.random(in: 0...geo.size.width),
            travelY: geo.size.height + 40,
            duration: Double.random(in: 1.6...2.8),
            spin: Double.random(in: 180...720),
            size: CGFloat.random(in: 6...12)
          )
        }
      }
    }
    .allowsHitTesting(false)
    .ignoresSafeArea()
  }
}

private struct ConfettiPiece: View {
  let color: Color
  let startX: CGFloat
  let travelY: CGFloat
  let duration: Double
  let spin: Double
  let size: CGFloat

  @State private var isFalling = false

  var body: some View {
    RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
      .fill(color)
      .frame(width: size, height: size * (Bool.random() ? 0.6 : 1.7))
      .rotationEffect(.degrees(isFalling ? spin : 0))
      .offset(x: 0, y: isFalling ? travelY : 0)
      .position(x: startX, y: 0)
      .onAppear {
        isFalling = true
      }
      .animation(.easeIn(duration: duration), value: isFalling)
  }
}
