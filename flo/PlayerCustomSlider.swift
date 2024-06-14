//
//  CustomSlider.swift
//  flo
//
//  Created by rizaldy on 05/06/24.
//

import SwiftUI

struct PlayerCustomSlider: View {
  @Binding var isSeeking: Bool
  @Binding var value: Double

  @State private var tempValue: Double = 0.0

  var range: ClosedRange<Double>
  var onEnded: (Double) -> Void

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Rectangle()
          .foregroundColor(Color.gray.opacity(0.8))
          .frame(height: 5)
          .cornerRadius(5)

        Rectangle()
          .foregroundColor(Color.white)
          .frame(
            width: CGFloat(
              (self.value - self.range.lowerBound) / (self.range.upperBound - self.range.lowerBound)
            ) * geometry.size.width, height: 4
          )
          .cornerRadius(2)

        if self.isSeeking {
          Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .opacity(0.8)
            .offset(
              x: CGFloat(
                (self.tempValue - self.range.lowerBound)
                  / (self.range.upperBound - self.range.lowerBound)) * geometry.size.width - 6)
        }

        Circle()
          .fill(Color.white)
          .frame(width: 12, height: 12)
          .offset(
            x: CGFloat(
              (self.value - self.range.lowerBound) / (self.range.upperBound - self.range.lowerBound)
            ) * geometry.size.width - 6
          )
          .animation(.easeInOut(duration: 0.3), value: self.value)
          .gesture(
            DragGesture()
              .onChanged { gesture in
                self.isSeeking = true

                let newValue =
                  self.range.lowerBound + Double(gesture.location.x / geometry.size.width)
                  * (self.range.upperBound - self.range.lowerBound)

                self.tempValue = newValue
              }.onEnded { gesture in
                let newValue =
                  self.range.lowerBound + Double(gesture.location.x / geometry.size.width)
                  * (self.range.upperBound - self.range.lowerBound)

                onEnded(newValue)

                self.isSeeking = false
              }
          )
      }
    }
    .frame(height: 20)
  }
}

struct CustomSliders_Previews: PreviewProvider {
  static var previews: some View {
    PreviewWrapper()
  }

  struct PreviewWrapper: View {
    @State private var value: Double = 0.30
    @State private var isSeeking: Bool = false

    var body: some View {
      ZStack {
        Color.accent
        HStack {
          PlayerCustomSlider(isSeeking: $isSeeking, value: $value, range: 0...1) { value in
            self.value = value
          }
        }.padding()
      }.ignoresSafeArea()
    }
  }
}
