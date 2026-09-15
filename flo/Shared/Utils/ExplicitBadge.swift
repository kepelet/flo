//
//  ExplicitBadge.swift
//  flo
//

import SwiftUI

struct ExplicitBadge: View {
  enum Size {
    case compact
    case regular

    var fontSize: CGFloat {
      switch self {
      case .compact:
        return 9
      case .regular:
        return 11
      }
    }

    var horizontalPadding: CGFloat {
      switch self {
      case .compact:
        return 4
      case .regular:
        return 5
      }
    }

    var verticalPadding: CGFloat {
      switch self {
      case .compact:
        return 1
      case .regular:
        return 2
      }
    }

    var cornerRadius: CGFloat {
      switch self {
      case .compact:
        return 3
      case .regular:
        return 4
      }
    }
  }

  var tint: Color = .secondary
  var size: Size = .regular

  var body: some View {
    Text("E")
      .font(.system(size: size.fontSize, weight: .bold))
      .foregroundColor(tint)
      .padding(.horizontal, size.horizontalPadding)
      .padding(.vertical, size.verticalPadding)
      .background(
        RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
          .fill(tint.opacity(0.18))
      )
      .accessibilityLabel("Explicit")
  }
}
