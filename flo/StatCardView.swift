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
    if #available(iOS 26.0, *) {
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
      .glassEffect(in: .rect(cornerRadius: 16))
      .frame(maxWidth: isWide ? .infinity : nil)
    } else {
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
}

private struct MaxHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct EqualHeightValueKey: EnvironmentKey {
  static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
  fileprivate var equalHeightValue: CGFloat {
    get { self[EqualHeightValueKey.self] }
    set { self[EqualHeightValueKey.self] = newValue }
  }
}

struct EqualHeightItem<Content: View>: View {
  @State private var ownHeight: CGFloat = 0
  @Environment(\.equalHeightValue) private var equalHeightValue
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .frame(minHeight: shouldExpand ? equalHeightValue : nil, alignment: .top)
      .background(
        GeometryReader { proxy in
          Color.clear
            .preference(key: MaxHeightPreferenceKey.self, value: proxy.size.height)
            .onAppear {
              ownHeight = proxy.size.height
            }
            .onChange(of: proxy.size.height) { newValue in
              ownHeight = newValue
            }
        }
      )
  }

  private var shouldExpand: Bool {
    equalHeightValue > 0 && ownHeight > 0 && ownHeight < equalHeightValue
  }
}

struct EqualHeightHStack<Content: View>: View {
  let alignment: VerticalAlignment
  let spacing: CGFloat?

  @ViewBuilder let content: () -> Content
  @State private var maxHeight: CGFloat = 0

  init(
    alignment: VerticalAlignment = .center,
    spacing: CGFloat? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.alignment = alignment
    self.spacing = spacing
    self.content = content
  }

  var body: some View {
    HStack(alignment: alignment, spacing: spacing) {
      content()
    }
    .frame(height: maxHeight == 0 ? nil : maxHeight, alignment: alignment == .top ? .top : .center)
    .environment(\.equalHeightValue, maxHeight)
    .onPreferenceChange(MaxHeightPreferenceKey.self) { newValue in
      if maxHeight != newValue {
        maxHeight = newValue
      }
    }
  }
}
