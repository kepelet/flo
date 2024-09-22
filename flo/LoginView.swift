//
//  LoginView.swift
//  flo
//
//  Created by rizaldy on 01/06/24.
//

import SwiftUI

struct Login: View {
  @ObservedObject var viewModel: AuthViewModel
  @Binding var showLoginSheet: Bool

  var body: some View {
    VStack {
      VStack {
        Image("logo")
          .resizable()
          .scaledToFit()
          .frame(width: 130)
          .padding(.bottom, 20)

        Text("Thanks for choosing flo!")
          .foregroundColor(.white)
          .customFont(.title1)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .padding(.bottom, 10)

        Text("Login to your Navidrome server to continue")
          .foregroundColor(.white)
          .customFont(.body)
          .multilineTextAlignment(.center)
      }.padding(.horizontal, 20).padding(.vertical, 50)

      VStack {
        VStack(alignment: .leading) {
          Text("Server URL")
            .font(.headline)
          TextField("http://localhost:4533", text: $viewModel.serverUrl)
            .padding()
            .background(.white)
            .foregroundColor(.accent)
            .keyboardType(.URL)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .cornerRadius(10)
        }.padding(.horizontal, 15).padding(.bottom, 10)
        VStack(alignment: .leading) {
          Text("Username")
            .font(.headline)
          TextField("sigma", text: $viewModel.username)
            .padding()
            .background(.white)
            .foregroundColor(.accent)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .cornerRadius(10)
        }.padding(.horizontal, 15).padding(.bottom, 10)

        VStack(alignment: .leading) {
          Text("Password")
            .font(.headline)
          SecureField("*************", text: $viewModel.password)
            .padding()
            .background(.white)
            .foregroundColor(.accent)
            .cornerRadius(10)
        }.padding(.horizontal, 15).padding(.bottom, 10)
        VStack(alignment: .leading) {
          Button(action: {
            viewModel.login()
          }) {
            Text("Login")
              .foregroundColor(.white)
              .fontWeight(.bold)
              .customFont(.headline)
              .textCase(.uppercase)
              .padding()
              .frame(maxWidth: .infinity)
              .background(Color("PlayerColor"))
              .cornerRadius(5)
              .shadow(radius: 10)
          }.padding(.top, 10).padding()
        }

      }.padding(.vertical, 30).padding(.horizontal, 10)
        .background(Color(red: 34.4 / 255, green: 33.6 / 255, blue: 75.2 / 255))
        .cornerRadius(20)
        .foregroundColor(.white)
    }
    .alert(isPresented: $viewModel.showAlert) {
      Alert(
        title: Text("Login Failed"), message: Text(viewModel.alertMessage),
        dismissButton: .default(Text("OK")))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundColor(Color.white)
    .background(Color(red: 43 / 255, green: 42 / 255, blue: 94 / 255))
    .edgesIgnoringSafeArea(.all)
  }
}

struct LoginView_Previews: PreviewProvider {
  @StateObject static var viewModel: AuthViewModel = AuthViewModel()
  @State static var showLoginSheet: Bool = true

  static var previews: some View {
    Login(viewModel: viewModel, showLoginSheet: $showLoginSheet)
  }
}
