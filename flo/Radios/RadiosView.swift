//
//  SongsView.swift
//  flo
//
//

import NukeUI
import SwiftUI

struct RadiosView: View {
  @EnvironmentObject private var playerViewModel: PlayerViewModel

  @StateObject var viewModel = RadiosViewModel()
  @State private var searchRadio = ""

  var filteredRadios: [Radio] {
    if searchRadio.isEmpty {
      return viewModel.radios
    } else {
      return viewModel.radios.filter { radio in
        radio.name.localizedCaseInsensitiveContains(searchRadio)
      }
    }
  }

  var body: some View {
    ScrollView {
      if filteredRadios.isEmpty {
        emptyStateView
      } else {
        LazyVStack {
          ForEach(filteredRadios, id: \.id) { radio in
            Group {
              HStack {
                Color("PlayerColor").frame(width: 40, height: 40)
                  .cornerRadius(5)
                  .overlay {
                    Image(systemName: "dot.radiowaves.up.forward")
                      .resizable()
                      .scaledToFit()
                      .foregroundStyle(.white)
                      .padding(8)
                  }

                VStack(alignment: .leading) {
                  Text(radio.name)
                    .customFont(.headline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.bottom, 3)
                }
                .padding(.horizontal, 10)

                Spacer()
              }
              .padding(.horizontal)
              .background(Color(UIColor.systemBackground))

              Divider()
            }
            .onTapGesture {
              playerViewModel.playRadioItem(radio: radio)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(.top, 10)
      }
    }
    .navigationTitle("Radios")
    .navigationBarTitleDisplayMode(.large)
    .searchable(
      text: $searchRadio,
      placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Search"
    )
    .onAppear {
      viewModel.fetchAllRadios()
    }
  }

  private var emptyStateView: some View {
    VStack(spacing: 12) {
      Image(systemName: "dot.radiowaves.up.forward")
        .font(.system(size: 36, weight: .semibold))
        .foregroundStyle(Color.gray.opacity(0.7))

      Text(searchRadio.isEmpty ? "No radios available" : "No radios match your search")
        .customFont(.headline)
        .multilineTextAlignment(.center)

      Text(
        searchRadio.isEmpty
          ? "Add radios in your Navidrome server."
          : "Try a different keyword."
      )
      .customFont(.subheadline)
      .foregroundColor(.secondary)
      .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 300)
    .padding(.horizontal, 24)
  }
}
