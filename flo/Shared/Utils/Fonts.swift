//
//  Fonts.swift
//  flo
//
//  Created by rizaldy on 06/06/24.
//

import SwiftUI

enum TextStyle {
  case largeTitle
  case title
  case title1
  case title2
  case title3
  case headline
  case subheadline
  case body
  case callout
  case footnote
  case caption1
  case caption2
}

struct CustomFont: ViewModifier {
  var textStyle: TextStyle
  @AppStorage(UserDefaultsKeys.uiFontScale) private var uiFontScale: Double = 1.0

  func body(content: Content) -> some View {
    let scale = CGFloat(min(max(uiFontScale, 0.8), 1.4))
    let font: Font

    switch textStyle {
    case .largeTitle:
      font = .custom("Plus Jakarta Sans", size: 34 * scale)
    case .title:
      font = .custom("Plus Jakarta Sans", size: 28 * scale)
    case .title1:
      font = .custom("Plus Jakarta Sans", size: 28 * scale)
    case .title2:
      font = .custom("Plus Jakarta Sans", size: 22 * scale)
    case .title3:
      font = .custom("Plus Jakarta Sans", size: 20 * scale)
    case .headline:
      font = .custom("Plus Jakarta Sans", size: 17 * scale).weight(.bold)
    case .body:
      font = .custom("Plus Jakarta Sans", size: 17 * scale)
    case .callout:
      font = .custom("Plus Jakarta Sans", size: 16 * scale)
    case .subheadline:
      font = .custom("Plus Jakarta Sans", size: 15 * scale)
    case .footnote:
      font = .custom("Plus Jakarta Sans", size: 13 * scale)
    case .caption1:
      font = .custom("Plus Jakarta Sans", size: 12 * scale)
    case .caption2:
      font = .custom("Plus Jakarta Sans", size: 11 * scale)
    }

    return content.font(font)
  }
}

extension View {
  func customFont(_ textStyle: TextStyle) -> some View {
    // FIXME: this is fishy
    self.modifier(CustomFont(textStyle: textStyle)).foregroundColor(.accent)
  }
}

#Preview {
  VStack {
    Text("Large Title")
      .customFont(.largeTitle)
    Text("Title 1")
      .customFont(.title1)
    Text("Title 2")
      .customFont(.title2)
    Text("Title 3")
      .customFont(.title3)
    Text("Headline")
      .customFont(.headline)
    Text("Subhead")
      .customFont(.subheadline)
    Text("Body")
      .customFont(.body)
    Text("Callout")
      .customFont(.callout)
    Text("Footnote")
      .customFont(.footnote)
    Text("Caption 1")
      .customFont(.caption1)
    Text("Caption 2")
      .customFont(.caption2)
  }
}
