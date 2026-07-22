//
//  IAPLoginView.swift
//  flo
//
//  Created by piekay on 08/03/26.
//

import SwiftUI

struct IAPLoginView: View {
  @ObservedObject var authViewModel: AuthViewModel
  @Environment(\.dismiss) private var dismiss
  
  @State private var serverUrl: String = ""
  @State private var showWebAuth = false
  @State private var isLoading = false
  @State private var errorMessage: String?
  
  var isSubmitButtonDisabled: Bool {
    serverUrl.isEmpty || isLoading
  }
  
  init(authViewModel: AuthViewModel) {
    self.authViewModel = authViewModel
    _serverUrl = State(initialValue: authViewModel.serverUrl)
  }
  
  var body: some View {
    ScrollView {
      headerSection
      formSection
    }
    .background(Color(.systemBackground))
    .foregroundColor(.accent)
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .alert(isPresented: Binding<Bool>(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )) {
      Alert(
        title: Text("Authentication Failed"),
        message: Text(errorMessage ?? "Unknown error"),
        dismissButton: .default(Text("OK"))
      )
    }
    .sheet(isPresented: $showWebAuth) {
      IAPWebAuthView(
        serverURL: serverUrl,
        authViewModel: authViewModel,
        onSuccess: {
          dismiss()
        },
        onError: { error in
          errorMessage = error
          isLoading = false
        }
      )
    }
  }
    
  private var headerSection: some View {
    VStack {
      Image("logo_alt")
        .resizable()
        .scaledToFit()
        .frame(width: 100)
        .padding(.vertical, 20)

      Text("Login with IAP")
        .customFont(.title1)
        .fontWeight(.bold)
        .multilineTextAlignment(.center)
        .padding(.bottom, 10)

      Text("Authenticate using OAuth2-Proxy or Identity-Aware Proxy")
        .customFont(.body)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 30)
  }
  
  private var formSection: some View {
    VStack {
      formField(
        title: "Server URL",
        text: $serverUrl,
        placeholder: "https://your-iap-server.com",
        keyboardType: .URL
      )

      submitButton
      
      cancelButton
    }
    .padding(.bottom, 30)
    .padding(.horizontal, 10)
  }
  
  private func formField(
    title: String,
    text: Binding<String>,
    placeholder: String,
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
        .disabled(isLoading)
    }
    .padding(.horizontal, 15)
    .padding(.bottom, 10)
  }
  
  private var submitButton: some View {
    VStack(alignment: .leading) {
      Button(action: authenticateWithIAP) {
        HStack {
          if isLoading {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(.white)
          }
          
          Text(isLoading ? "Authenticating..." : "Authenticate")
            .foregroundColor(.white)
            .fontWeight(.bold)
            .customFont(.headline)
            .textCase(.uppercase)
        }
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
  
  private var cancelButton: some View {
    Button(action: { dismiss() }) {
      Text("Cancel")
        .foregroundColor(Color("PlayerColor"))
        .fontWeight(.semibold)
        .customFont(.headline)
        .padding()
        .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, 15)
  }
  
  private func authenticateWithIAP() {
    errorMessage = nil
    isLoading = true
    authViewModel.serverUrl = serverUrl
    showWebAuth = true
  }
}

#Preview {
  IAPLoginView(authViewModel: AuthViewModel())
}
