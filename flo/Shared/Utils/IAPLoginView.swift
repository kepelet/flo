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
  @State private var showAdvancedSettings = false
  @State private var customHeaderName: String = ""
  @State private var customCookieName: String = ""
  @State private var customUsernameCookie: String = ""
  
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
        customHeaderName: customHeaderName.isEmpty ? nil : customHeaderName,
        customCookieName: customCookieName.isEmpty ? nil : customCookieName,
        customUsernameCookie: customUsernameCookie.isEmpty ? nil : customUsernameCookie,
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
      
      advancedSettingsSection
      
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
  
  private var advancedSettingsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      DisclosureGroup("Advanced Settings", isExpanded: $showAdvancedSettings) {
        VStack(alignment: .leading, spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Authentication Token Header Name")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("The HTTP header containing your JWT token (leave empty for auto-detection)")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextField("e.g., x-auth-request-access-token", text: $customHeaderName)
              .padding()
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(.accent, lineWidth: 1)
              )
              .autocapitalization(.none)
              .disableAutocorrection(true)
              .disabled(isLoading)
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Authentication Token Cookie Name")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("The cookie containing your session token (leave empty for auto-detection)")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextField("e.g., _oauth2_proxy, KEYCLOAK_IDENTITY", text: $customCookieName)
              .padding()
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(.accent, lineWidth: 1)
              )
              .autocapitalization(.none)
              .disableAutocorrection(true)
              .disabled(isLoading)
          }
          
          VStack(alignment: .leading, spacing: 4) {
            Text("Username Cookie Name")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("The cookie containing your username (defaults to 'username')")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextField("e.g., username, user, preferred_username", text: $customUsernameCookie)
              .padding()
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(.accent, lineWidth: 1)
              )
              .autocapitalization(.none)
              .disableAutocorrection(true)
              .disabled(isLoading)
          }
        }
        .padding(.top, 8)
      }
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
