import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authState: AuthenticationState
    @ObservedObject var logger = AppLogger.shared
    @State private var showingLogoutAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    LabeledContent("URL", value: authState.serverURL)
                }

                Section("Account") {
                    if let username = authState.username {
                        LabeledContent("Username", value: username)
                    }

                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Text("Logout")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")

                    Toggle("Logs", isOn: $logger.isEnabled)
                }
            }
            .navigationTitle("Settings")
            .alert("Logout", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    authState.logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationState())
}
