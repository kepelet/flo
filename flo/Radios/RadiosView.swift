
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
}
