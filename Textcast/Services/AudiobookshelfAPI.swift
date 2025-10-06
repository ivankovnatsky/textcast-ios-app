import Foundation
@preconcurrency import UIKit

/// API client for Audiobookshelf server
/// Documentation: See AUDIOBOOKSHELF_API.md
actor AudiobookshelfAPI {
    private let baseURL: String
    private var accessToken: String?

    init(baseURL: String) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    // MARK: - Authentication

    /// Login with username and password
    /// POST /login
    func login(username: String, password: String) async throws -> LoginResponse {
        guard let url = URL(string: "\(baseURL)/login") else {
            throw AudiobookshelfError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-return-tokens") // Get token in response

        let body: [String: String] = [
            "username": username,
            "password": password,
        ]

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudiobookshelfError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw AudiobookshelfError.unauthorized
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AudiobookshelfError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        // Store the access token for subsequent requests
        accessToken = loginResponse.user.token
        return loginResponse
    }

    /// Set access token manually (e.g., from storage)
    func setAccessToken(_ token: String) {
        accessToken = token
    }

    /// Clear access token (logout)
    func clearAccessToken() {
        accessToken = nil
    }

    /// Get current access token
    func getAccessToken() -> String? {
        accessToken
    }

    // MARK: - User Endpoints

    /// Get current user details with media progress
    /// GET /api/me
    func getCurrentUser() async throws -> UserDetailsResponse {
        guard let token = accessToken else {
            throw AudiobookshelfError.unauthorized
        }

        guard let url = URL(string: "\(baseURL)/api/me") else {
            throw AudiobookshelfError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudiobookshelfError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw AudiobookshelfError.unauthorized
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AudiobookshelfError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        let userDetails = try JSONDecoder().decode(UserDetailsResponse.self, from: data)
        await AppLogger.shared.log("Fetched user details: \(userDetails.mediaProgress?.count ?? 0) progress items", level: .info)
        return userDetails
    }

    /// Get items in progress for the current user
    /// GET /api/me/items-in-progress
    func getItemsInProgress(limit: Int = 25) async throws -> [LibraryItem] {
        guard let token = accessToken else {
            throw AudiobookshelfError.unauthorized
        }

        var urlComponents = URLComponents(string: "\(baseURL)/api/me/items-in-progress")
        urlComponents?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = urlComponents?.url else {
            throw AudiobookshelfError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudiobookshelfError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw AudiobookshelfError.unauthorized
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AudiobookshelfError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        let itemsResponse = try JSONDecoder().decode(ItemsInProgressResponse.self, from: data)
        return itemsResponse.libraryItems
    }

    // MARK: - Library Endpoints

    /// Get all libraries
    /// GET /api/libraries
    func getLibraries() async throws -> [Library] {
        guard let token = accessToken else {
            throw AudiobookshelfError.unauthorized
        }

        guard let url = URL(string: "\(baseURL)/api/libraries") else {
            throw AudiobookshelfError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudiobookshelfError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw AudiobookshelfError.unauthorized
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AudiobookshelfError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        let librariesResponse = try JSONDecoder().decode(LibrariesResponse.self, from: data)
        return librariesResponse.libraries
    }

    /// Get recent episodes from a podcast library
    /// GET /api/libraries/:id/recent-episodes
    func getRecentEpisodes(libraryId: String, limit: Int = 25) async throws -> [PodcastEpisodeExpanded] {
        guard let token = accessToken else {
            throw AudiobookshelfError.unauthorized
        }

        var urlComponents = URLComponents(string: "\(baseURL)/api/libraries/\(libraryId)/recent-episodes")
        urlComponents?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = urlComponents?.url else {
            throw AudiobookshelfError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudiobookshelfError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw AudiobookshelfError.unauthorized
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AudiobookshelfError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        // Log the raw JSON response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            await AppLogger.shared.log("Recent episodes raw response: \(jsonString.prefix(500))", level: .debug)
        }

        let episodesResponse = try JSONDecoder().decode(RecentEpisodesResponse.self, from: data)

        // Log progress info for first episode
        if let firstEpisode = episodesResponse.episodes.first {
            await AppLogger.shared.log("First episode: id=\(firstEpisode.id), title=\(firstEpisode.title ?? "nil"), progress=\(firstEpisode.mediaProgress?.progress ?? -1), currentTime=\(firstEpisode.mediaProgress?.currentTime ?? -1)", level: .debug)
        }

        return episodesResponse.episodes
    }

    // MARK: - Item Endpoints

    /// Get stream URL for a library item by starting a playback session
    /// POST /api/items/:id/play (for books/audiobooks)
    /// POST /api/items/:id/play/:episodeId (for podcast episodes)
    func getStreamURL(itemId: String) async -> URL? {
        guard let token = accessToken else {
            await AppLogger.shared.log("No access token available", level: .error)
            return nil
        }

        // Check if this is a composite ID for podcast episode (format: "libraryItemId/episodeId")
        let (libraryItemId, episodeId) = await parseItemId(itemId)

        // Build the endpoint (baseURL already has trailing slash trimmed)
        let endpoint = if let episodeId {
            "\(baseURL)/api/items/\(libraryItemId)/play/\(episodeId)"
        } else {
            "\(baseURL)/api/items/\(libraryItemId)/play"
        }

        await AppLogger.shared.log("Parsed libraryItemId: \(libraryItemId), episodeId: \(episodeId ?? "nil")", level: .info)

        await AppLogger.shared.log("Starting playback session: POST \(endpoint)", level: .info)

        guard let url = URL(string: endpoint) else {
            await AppLogger.shared.log("Invalid playback URL", level: .error)
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Send device info matching the official app structure
            let (deviceId, deviceModel) = await MainActor.run {
                (UIDevice.current.identifierForVendor?.uuidString ?? "unknown", UIDevice.current.model)
            }
            let deviceInfo: [String: Any] = [
                "deviceInfo": [
                    "deviceId": deviceId,
                    "clientName": "TextCast iOS",
                    "manufacturer": "Apple",
                    "model": deviceModel,
                ],
                "forceDirectPlay": true,
                "forceTranscode": false,
                "mediaPlayer": "AVPlayer",
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: deviceInfo)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                await AppLogger.shared.log("Invalid response", level: .error)
                return nil
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                await AppLogger.shared.log("Playback session failed (\(httpResponse.statusCode)): \(message)", level: .error)
                return nil
            }

            // Parse the playback session response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Store session ID for progress syncing
                if let sessionId = json["id"] as? String {
                    await AppLogger.shared.log("Playback session ID: \(sessionId)", level: .info)
                    // Store session ID globally for progress syncing
                    await MainActor.run {
                        PlaybackSessionManager.shared.currentSessionId = sessionId
                    }
                }

                // Extract audio track URL from the session response
                if let audioTracks = json["audioTracks"] as? [[String: Any]],
                   let firstTrack = audioTracks.first,
                   let contentUrl = firstTrack["contentUrl"] as? String
                {
                    await AppLogger.shared.log("Got stream URL from playback session: \(contentUrl)", level: .info)
                    return URL(string: "\(baseURL)\(contentUrl)?token=\(token)")
                }

                await AppLogger.shared.log("No contentUrl found in playback session response", level: .error)
                await AppLogger.shared.log("Session response: \(String(data: data, encoding: .utf8) ?? "nil")", level: .debug)
            }
        } catch {
            await AppLogger.shared.log("Error starting playback session: \(error.localizedDescription)", level: .error)
        }

        return nil
    }

    /// Parse item ID which can be either "id" or "libraryItemId/episodeId"
    private func parseItemId(_ itemId: String) async -> (libraryItemId: String, episodeId: String?) {
        await AppLogger.shared.log("parseItemId called with: \(itemId)", level: .debug)

        if itemId.contains("/") {
            let components = itemId.split(separator: "/", maxSplits: 1)
            if components.count == 2 {
                let result = (String(components[0]), String(components[1]))
                await AppLogger.shared.log("parseItemId result: libraryItemId=\(result.0), episodeId=\(result.1)", level: .debug)
                return result
            }
        }

        await AppLogger.shared.log("parseItemId: no '/' found, returning libraryItemId=\(itemId), episodeId=nil", level: .debug)
        return (itemId, nil)
    }

    /// Get cover image URL for a library item
    /// GET /api/items/:id/cover (public endpoint, no auth needed)
    func getCoverURL(itemId: String) -> URL? {
        URL(string: "\(baseURL)/api/items/\(itemId)/cover")
    }

    // MARK: - Helper Methods

    /// Test connection to server
    func testConnection() async throws -> Bool {
        guard let url = URL(string: baseURL) else {
            throw AudiobookshelfError.invalidURL
        }

        let (_, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudiobookshelfError.invalidResponse
        }

        return (200 ... 299).contains(httpResponse.statusCode)
    }

    /// Get base URL
    func getBaseURL() -> String {
        baseURL
    }

    // MARK: - Playback Progress

    /// Sync playback progress with server
    /// POST /api/session/:sessionId/sync
    func syncPlaybackProgress(sessionId: String, currentTime: Double, duration: Double, timeListened: Double) async throws {
        guard let token = accessToken else {
            throw AudiobookshelfError.unauthorized
        }

        let endpoint = "\(baseURL)/api/session/\(sessionId)/sync"
        guard let url = URL(string: endpoint) else {
            throw AudiobookshelfError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "currentTime": currentTime,
            "duration": duration,
            "timeListened": timeListened,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudiobookshelfError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw AudiobookshelfError.serverError(statusCode: httpResponse.statusCode, message: "Failed to sync progress")
        }

        await AppLogger.shared.log("Synced progress: \(currentTime)s / \(duration)s", level: .info)
    }

    // MARK: - User Progress Management

    /// Delete podcast episode from library (permanent deletion)
    /// DELETE /api/podcasts/:id/episode/:episodeId
    func deleteEpisode(libraryItemId: String, episodeId: String) async throws {
        guard let token = accessToken else {
            throw AudiobookshelfError.unauthorized
        }

        let endpoint = "\(baseURL)/api/podcasts/\(libraryItemId)/episode/\(episodeId)"
        guard let url = URL(string: endpoint) else {
            throw AudiobookshelfError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudiobookshelfError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw AudiobookshelfError.serverError(statusCode: httpResponse.statusCode, message: "Failed to delete episode")
        }

        await MainActor.run {
            AppLogger.shared.log("Deleted episode \(episodeId) from library", level: .info)
        }
    }

    /// Update media progress (can mark as finished or reset progress)
    /// PATCH /api/me/progress/:libraryItemId/:episodeId?
    func updateMediaProgress(libraryItemId: String, episodeId: String?, isFinished: Bool, currentTime: Double = 0, duration: Double? = nil) async throws {
        guard let token = accessToken else {
            throw AudiobookshelfError.unauthorized
        }

        var endpoint = "\(baseURL)/api/me/progress/\(libraryItemId)"
        if let episodeId = episodeId {
            endpoint += "/\(episodeId)"
        }

        guard let url = URL(string: endpoint) else {
            throw AudiobookshelfError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "isFinished": isFinished,
            "currentTime": currentTime,
        ]

        if let duration = duration {
            payload["duration"] = duration
            payload["progress"] = duration > 0 ? currentTime / duration : 0
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AudiobookshelfError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw AudiobookshelfError.serverError(statusCode: httpResponse.statusCode, message: "Failed to update media progress")
        }

        await MainActor.run {
            AppLogger.shared.log("Updated progress for \(libraryItemId)\(episodeId != nil ? "/\(episodeId!)" : ""): isFinished=\(isFinished), currentTime=\(currentTime)", level: .info)
        }
    }

    /// Mark episode as finished
    func markAsFinished(libraryItemId: String, episodeId: String, duration: Double) async throws {
        try await updateMediaProgress(libraryItemId: libraryItemId, episodeId: episodeId, isFinished: true, currentTime: duration, duration: duration)
    }

    /// Reset episode progress to beginning
    func resetProgress(libraryItemId: String, episodeId: String, duration: Double) async throws {
        try await updateMediaProgress(libraryItemId: libraryItemId, episodeId: episodeId, isFinished: false, currentTime: 0, duration: duration)
    }
}
