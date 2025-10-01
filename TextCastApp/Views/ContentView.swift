import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authState: AuthenticationState

    var body: some View {
        if authState.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @ObservedObject var logger = AppLogger.shared
    @StateObject private var playerState = PlayerState()
    @EnvironmentObject var authState: AuthenticationState

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                LatestView()
                    .environmentObject(playerState)
                    .tabItem {
                        Label("Latest", systemImage: "list.bullet")
                    }

                if logger.isEnabled {
                    LogsView()
                        .tabItem {
                            Label("Logs", systemImage: "doc.text")
                        }
                }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }

            // Mini player floating above tab bar
            // FIXME: Hardcoded padding value - find better way to dynamically position above tab bar
            // Consider using safeAreaInset with safeAreaPadding on each tab view (see SO: 79364059)
            if playerState.currentItem != nil, !playerState.isPlayerExpanded {
                VStack {
                    Spacer()
                    NowPlayingBar(playerState: playerState)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 90)
                }
                .ignoresSafeArea()
            }

            // Full-screen player overlay
            if playerState.isPlayerExpanded {
                PlayerView(playerState: playerState)
                    .environmentObject(authState)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut, value: playerState.isPlayerExpanded)
        .animation(.easeInOut, value: playerState.currentItem != nil)
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var authState: AuthenticationState
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Configuration") {
                    TextField("Server URL", text: $serverURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                }

                Section("Credentials") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await login()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Login")
                        }
                    }
                    .disabled(serverURL.isEmpty || username.isEmpty || password.isEmpty || isLoading)
                }
            }
            .navigationTitle("TextCast")
        }
    }

    private func login() async {
        await authState.login(
            serverURL: serverURL.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username,
            password: password
        )

        // Update local state from auth state
        isLoading = authState.isLoading
        errorMessage = authState.errorMessage
    }
}

#Preview("Login") {
    LoginView()
        .environmentObject(AuthenticationState())
}

#Preview("Main Tabs") {
    MainTabView()
        .environmentObject(AuthenticationState())
}
