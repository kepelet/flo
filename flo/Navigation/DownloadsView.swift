//
//  DownloadsView.swift
//  flo
//
//  Created by rizaldy on 08/06/24.
//

import SwiftUI

struct DownloadsView: View {
  var body: some View {
    VStack(alignment: .leading) {
      Image("Downloads").resizable().aspectRatio(contentMode: .fit).frame(width: 300).padding()
        .padding(.bottom, 10)
      Group {
        Text("Going off the grid?")
          .customFont(.title1)
          .fontWeight(.bold)
          .multilineTextAlignment(.leading)
          .padding(.bottom, 10)
        Text(
          "Bring your music anywhere, even when you're offline. Your downloaded music will be here."
        )
        .customFont(.subheadline)

      }.padding(.horizontal, 20).foregroundColor(.accent)
    }
  }
}

#Preview {
  DownloadsView()
}
