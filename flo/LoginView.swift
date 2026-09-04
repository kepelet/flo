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

  // Login form fields are kept as local state so that every keystroke does
  // not mutate the shared AuthViewModel. On Mac Catalyst the login form is
  // presented via fullScreenCover from HomeView/PreferencesView, which both
  // observe the same AuthViewModel; re-rendering the presenter on every
  // keystroke while the cover is up triggers a re-presentation loop and
  // crashes the app. Fields are pushed into the view model once on submit.
  @State private var serverField: String
  @State private var usernameField: String
  @State private var passwordField: String

  init(viewModel: AuthViewModel, showLoginSheet: Binding<Bool>) {
    self.viewModel = viewModel
    self._showLoginSheet = showLoginSheet
    self._serverField = State(initialValue: viewModel.serverUrl)
    self._usernameField = State(initialValue: viewModel.username)
    self._passwordField = State(initialValue: viewModel.password)
  }

  var isSubmitButtonDisabled: Bool {
    serverField.isEmpty || usernameField.isEmpty || passwordField.isEmpty
      || viewModel.isSubmitting
  }

  var body: some View {
    ScrollView {
      if !httpWarning.isEmpty {
        extraMessage(httpWarning)
      }
      headerSection
      formSection
    }
    .overlay(alignment: .topTrailing) {
      if UIDevice.current.userInterfaceIdiom == .pad {
        Button(action: { showLoginSheet = false }) {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.primary)
            .frame(width: 34, height: 34)
            .glassedEffect(in: Circle(), interactive: true)
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
    .iapModal(isPresented: $showIAPLogin) {
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

  private var httpWarning: String {
    serverField.lowercased().hasPrefix("http://")
      ? "http:// is only supported within private IP ranges: 192.168.0.0/16, 10.0.0.0/8, and 172.16.0.0/12 — learn more at https://dub.sh/flo-ats"
      : ""
  }

  private func extraMessage(_ message: String) -> some View {
    VStack {
      Text(message)
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
        title: "Server URL", text: $serverField,
        placeholder: "https://navidrome․your-server․net", keyboardType: .URL)
      formField(title: "Username", text: $usernameField, placeholder: "sigma")
      secureFormField(title: "Password", text: $passwordField, placeholder: "*************")
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
      Button(action: submitLogin) {
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
  
  private func submitLogin() {
    viewModel.serverUrl = serverField
    viewModel.username = usernameField
    viewModel.password = passwordField
    viewModel.login()
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

extension View {
  @ViewBuilder
  func iapModal<Modal: View>(
    isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Modal
  ) -> some View {
    #if targetEnvironment(macCatalyst)
      fullScreenCover(isPresented: isPresented, content: content)
    #else
      sheet(isPresented: isPresented, content: content)
    #endif
  }
}

struct LoginView_Previews: PreviewProvider {
  @StateObject static var viewModel: AuthViewModel = AuthViewModel()
  @State static var showLoginSheet: Bool = true

  static var previews: some View {
    Login(viewModel: viewModel, showLoginSheet: $showLoginSheet)
  }
}
