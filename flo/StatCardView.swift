//
//  StatCardView.swift
//  flo
//
//  Created by rizaldy on 22/11/24.
//

import SwiftUI

struct StatCard: View {
  let title: String
  let value: String
  let subtitle: String?
  let icon: String
  let color: Color
  let isWide: Bool
  let showArrow: Bool

  init(
    title: String,
    value: String,
    subtitle: String? = nil,
    icon: String,
    color: Color,
    isWide: Bool = false,
    showArrow: Bool = false
  ) {
    self.title = title
    self.value = value
    self.subtitle = subtitle
    self.icon = icon
    self.color = color
    self.isWide = isWide
    self.showArrow = false  // FIXME: use `showArrow` after implement deeplinks
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: icon)
          .foregroundColor(color)
        Text(title)
          .foregroundColor(.secondary)
          .customFont(.body)

        Spacer()

        if showArrow {
          Image(systemName: "chevron.right")
            .foregroundColor(.secondary)
            .font(.system(size: 14))
        }
      }
      .customFont(.subheadline)

      VStack(alignment: .leading, spacing: 4) {
        Text(value)
          .customFont(.title2)
          .lineSpacing(2)
          .fontWeight(.bold)
          .lineLimit(2)

        if let subtitle = subtitle {
          Text(subtitle)
            .foregroundColor(.secondary)
            .customFont(.subheadline)
            .lineSpacing(2)
            .lineLimit(2)
        }
      }
    }
    .padding()
    .frame(maxWidth: isWide ? .infinity : nil)
    .background(Color(UIColor.systemBackground))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color(UIColor.separator), lineWidth: 0.8)
    )
  }
}
