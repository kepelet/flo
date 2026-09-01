//
//  CustomSlider.swift
//  flo
//
//  Created by rizaldy on 05/06/24.
//

import SwiftUI

struct PlayerCustomSlider: View {
  var isMediaLoading: Bool = false

  @Binding var isSeeking: Bool
  @Binding var value: Double

  @State private var tempValue: Double = 0.0

  var range: ClosedRange<Double>
  var onEnded: (Double) -> Void

  var body: some View {
    GeometryReader { geometry in
      let clampedValue = min(max(self.value, self.range.lowerBound), self.range.upperBound)
      let clampedTemp = min(max(self.tempValue, self.range.lowerBound), self.range.upperBound)
      let span = self.range.upperBound - self.range.lowerBound
      let normalized: CGFloat = {
        guard span.isFinite, span != 0 else { return 0 }
        let v = (clampedValue - self.range.lowerBound) / span
        guard v.isFinite else { return 0 }
        return CGFloat(min(max(v, 0), 1))
      }()
      let normalizedTemp: CGFloat = {
        guard span.isFinite, span != 0 else { return 0 }
        let v = (clampedTemp - self.range.lowerBound) / span
        guard v.isFinite else { return 0 }
        return CGFloat(min(max(v, 0), 1))
      }()
      let safeWidth: CGFloat = (geometry.size.width.isFinite && geometry.size.width > 0) ? geometry.size.width : 0
      ZStack(alignment: .leading) {
        Rectangle()
          .foregroundColor(Color.gray.opacity(0.8))
          .frame(height: 5)
          .cornerRadius(5)

        Rectangle()
          .foregroundColor(Color.white)
          .frame(
            width: normalized * safeWidth, height: 4
          )
          .opacity(isMediaLoading ? 0 : 1)
          .cornerRadius(2)

        if self.isSeeking {
          Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .opacity(0.8)
            .offset(
              x: normalizedTemp * safeWidth - 6)
        }

        Circle()
          .fill(Color.white)
          .frame(width: 12, height: 12)
          .offset(
            x: normalized * safeWidth - 6
          )
          .opacity(isMediaLoading ? 0 : 1)
          .animation(.easeInOut(duration: 0.3), value: self.value)
          .gesture(
            DragGesture()
              .onChanged { gesture in
                self.isSeeking = true
                guard safeWidth > 0 else { return }
                let raw = Double(gesture.location.x / safeWidth)
                guard raw.isFinite else { return }
                let newValue = self.range.lowerBound + raw * span
                let clamped = min(max(newValue, self.range.lowerBound), self.range.upperBound)
                guard clamped.isFinite else { return }
                self.tempValue = clamped
              }.onEnded { gesture in
                guard safeWidth > 0 else { self.isSeeking = false; return }
                let raw = Double(gesture.location.x / safeWidth)
                guard raw.isFinite else { self.isSeeking = false; return }
                var newValue = self.range.lowerBound + raw * span
                newValue = min(max(newValue, self.range.lowerBound), self.range.upperBound)
                guard newValue.isFinite else { self.isSeeking = false; return }
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
