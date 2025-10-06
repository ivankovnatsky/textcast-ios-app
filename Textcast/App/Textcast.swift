import Combine
import SwiftUI

@main
struct Textcast: App {
    @StateObject private var authState = AuthenticationState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authState)
        }
    }
}

// MARK: - Authentication State

@MainActor
class AuthenticationState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var serverURL: String = ""
    @Published var authToken: String?
    @Published var username: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Store user's media progress for quick lookup
    @Published var mediaProgressMap: [String: UserDetailsResponse.UserMediaProgress] = [:]

    private var apiClient: AudiobookshelfAPI?

    init() {
        // Load saved credentials if any
        loadCredentials()
    }

    /// Fetch user details and populate mediaProgressMap
    func refreshUserProgress() async {
        guard let api = apiClient else { return }

        do {
            let userDetails = try await api.getCurrentUser()

            // Build a map for quick lookups: "libraryItemId/episodeId" or just "libraryItemId"
            var progressMap: [String: UserDetailsResponse.UserMediaProgress] = [:]

            for progress in userDetails.mediaProgress ?? [] {
                let key: String = if let episodeId = progress.episodeId {
                    // For podcast episodes: "libraryItemId/episodeId"
                    "\(progress.libraryItemId)/\(episodeId)"
                } else {
                    // For audiobooks: just "libraryItemId"
                    progress.libraryItemId
                }
                progressMap[key] = progress
            }

            self.mediaProgressMap = progressMap

            AppLogger.shared.log("Refreshed user progress: \(progressMap.count) items", level: .info)
        } catch {
            AppLogger.shared.log("Failed to refresh user progress: \(error)", level: .error)
        }
    }

    func loadCredentials() {
        if let savedURL = UserDefaults.standard.string(forKey: "serverURL"),
           let savedToken = UserDefaults.standard.string(forKey: "authToken"),
           let savedUsername = UserDefaults.standard.string(forKey: "username")
        {
            serverURL = savedURL
            authToken = savedToken
            username = savedUsername
            isAuthenticated = true

            // Initialize API client with saved credentials
            apiClient = AudiobookshelfAPI(baseURL: savedURL)
            Task {
                await self.apiClient?.setAccessToken(savedToken)
                // Fetch user progress on app launch
                await refreshUserProgress()
            }
        }
    }

    func login(serverURL: String, username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Normalize server URL (add https:// if no scheme provided)
            let normalizedURL = normalizeServerURL(serverURL)

            // Try to login, with fallback to http if https fails
            let (api, finalURL) = try await loginWithFallback(
                baseURL: normalizedURL,
                username: username,
                password: password
            )

            // Save credentials (save final working URL)
            self.serverURL = finalURL
            authToken = await api.getAccessToken()
            self.username = username
            apiClient = api

            // Persist to UserDefaults
            UserDefaults.standard.set(finalURL, forKey: "serverURL")
            UserDefaults.standard.set(authToken, forKey: "authToken")
            UserDefaults.standard.set(username, forKey: "username")

            isAuthenticated = true

            // Fetch user progress after successful login
            await refreshUserProgress()

            isLoading = false
        } catch let error as AudiobookshelfError {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        } catch {
            errorMessage = "Login failed: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: "serverURL")
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "username")

        Task {
            await self.apiClient?.clearAccessToken()
        }

        serverURL = ""
        authToken = nil
        username = nil
        apiClient = nil
        isAuthenticated = false
        errorMessage = nil
    }

    func getAPIClient() -> AudiobookshelfAPI? {
        apiClient
    }

    private func normalizeServerURL(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespaces)

        // If it already has a scheme, return as-is
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return trimmed
        }

        // Otherwise, add https:// by default
        return "https://\(trimmed)"
    }

    private func loginWithFallback(
        baseURL: String,
        username: String,
        password: String
    ) async throws -> (api: AudiobookshelfAPI, url: String) {
        // First, try with the provided URL (likely https)
        let api = AudiobookshelfAPI(baseURL: baseURL)

        do {
            _ = try await api.login(username: username, password: password)
            // Success - return the API client with this URL
            return (api, baseURL)
        } catch {
            // If https fails and URL starts with https://, try http://
            if baseURL.lowercased().hasPrefix("https://") {
                let httpURL = baseURL.replacingOccurrences(
                    of: "https://",
                    with: "http://",
                    options: [.caseInsensitive],
                    range: baseURL.startIndex ..< baseURL.index(baseURL.startIndex, offsetBy: 8)
                )

                let httpAPI = AudiobookshelfAPI(baseURL: httpURL)
                _ = try await httpAPI.login(username: username, password: password)
                // Success with http - return this API client
                return (httpAPI, httpURL)
            } else {
                // Not https, or fallback also failed - rethrow original error
                throw error
            }
        }
    }
}
