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
  
  @State private var showIAPLogin = false

  var isSubmitButtonDisabled: Bool {
    viewModel.serverUrl.isEmpty || viewModel.username.isEmpty || viewModel.password.isEmpty
      || viewModel.isSubmitting
  }

  var body: some View {
    ScrollView {
      if !viewModel.extraMessage.isEmpty {
        extraMessage
      }
      headerSection
      formSection
    }
    .overlay(alignment: .topTrailing) {
      if UIDevice.current.userInterfaceIdiom == .pad {
        Button(action: { showLoginSheet = false }) {
          Image(systemName: "xmark")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(Color("PlayerColor"))
            .clipShape(Circle())
        }
        .padding()
      }
    }
    .alert(isPresented: $viewModel.showAlert) {
      Alert(
        title: Text("Login Failed"),
        message: Text(viewModel.alertMessage),
        dismissButton: .default(Text("OK"))
      )
    }
    .sheet(isPresented: $showIAPLogin) {
      IAPLoginView(authViewModel: viewModel)
    }
    .onChange(of: viewModel.isLoggedIn) { isLoggedIn in
      if isLoggedIn {
        showLoginSheet = false
        showIAPLogin = false
      }
    }
    .background(Color(.systemBackground))
    .foregroundColor(.accent)
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  private var extraMessage: some View {
    VStack {
      Text(viewModel.extraMessage)
        .customFont(.caption1)
        .lineSpacing(2)
        .multilineTextAlignment(.center)
        .padding()
    }
    .overlay(
      Rectangle().stroke(.accent, lineWidth: 1)
    )
  }

  private var headerSection: some View {
    VStack {
      Image("logo_alt")
        .resizable()
        .scaledToFit()
        .frame(width: 100)
        .padding(.vertical, 20)

      if viewModel.experimentalSaveLoginInfo {
        Text("Login to your Navidrome server to continue")
          .customFont(.title1)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .padding(.bottom, 10)

        Text("The password is stored securely in Keychain")
          .customFont(.body)
          .multilineTextAlignment(.center)
      } else {
        Text("Thanks for choosing flo!")
          .customFont(.title1)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .padding(.bottom, 10)

        Text("Login to your Navidrome server to continue")
          .customFont(.body)
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 30)
  }

  private var formSection: some View {
    VStack {
      formField(
        title: "Server URL", text: $viewModel.serverUrl,
        placeholder: "https://navidrome․your-server․net", keyboardType: .URL)
      formField(title: "Username", text: $viewModel.username, placeholder: "sigma")
      secureFormField(title: "Password", text: $viewModel.password, placeholder: "*************")
      submitButton
      iapLoginButton
    }
    .padding(.bottom, 30)
    .padding(.horizontal, 10)
  }

  private func formField(
    title: String, text: Binding<String>, placeholder: String,
    keyboardType: UIKeyboardType = .default
  ) -> some View {
    VStack(alignment: .leading) {
      Text(title)
        .font(.headline)
      TextField(placeholder, text: text)
        .padding()
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(.accent, lineWidth: 1)
        )
        .keyboardType(keyboardType)
        .autocapitalization(.none)
        .disableAutocorrection(true)
        .textContentType(.none)
    }
    .padding(.horizontal, 15)
    .padding(.bottom, 10)
  }

  private func secureFormField(title: String, text: Binding<String>, placeholder: String)
    -> some View
  {
    VStack(alignment: .leading) {
      Text(title)
        .font(.headline)
      SecureField(placeholder, text: text)
        .padding()
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(.accent, lineWidth: 1)
        )
    }
    .padding(.horizontal, 15)
    .padding(.bottom, 10)
  }

  private var submitButton: some View {
    VStack(alignment: .leading) {
      Button(action: viewModel.login) {
        Text(viewModel.experimentalSaveLoginInfo ? "Save" : "Login")
          .foregroundColor(.white)
          .fontWeight(.bold)
          .customFont(.headline)
          .textCase(.uppercase)
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color("PlayerColor"))
          .cornerRadius(5)
          .opacity(isSubmitButtonDisabled ? 0.5 : 1)
          .shadow(radius: isSubmitButtonDisabled ? 0 : 10)
      }
      .padding(.top, 10)
      .padding()
      .disabled(isSubmitButtonDisabled)
    }
  }
  
  private var iapLoginButton: some View {
    VStack(spacing: 12) {
      HStack {
        VStack { Divider() }
        Text("OR")
          .customFont(.caption1)
          .foregroundColor(.secondary)
          .padding(.horizontal, 8)
        VStack { Divider() }
      }
      .padding(.horizontal, 15)
      .padding(.vertical, 10)
      
      Button(action: { showIAPLogin = true }) {
        HStack {
          Image(systemName: "lock.shield.fill")
            .font(.system(size: 16))
          Text("Login with IAP")
            .fontWeight(.semibold)
            .customFont(.headline)
        }
        .foregroundColor(Color("PlayerColor"))
        .padding()
        .frame(maxWidth: .infinity)
        .overlay(
          RoundedRectangle(cornerRadius: 5)
            .stroke(Color("PlayerColor"), lineWidth: 2)
        )
      }
      .padding(.horizontal, 15)
      
      Text("Use this if your server is behind OAuth2-Proxy or Identity-Aware Proxy")
        .customFont(.caption1)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }
  }
}

struct LoginView_Previews: PreviewProvider {
  @StateObject static var viewModel: AuthViewModel = AuthViewModel()
  @State static var showLoginSheet: Bool = true

  static var previews: some View {
    Login(viewModel: viewModel, showLoginSheet: $showLoginSheet)
  }
}
