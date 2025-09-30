import Foundation

// MARK: - Login Response

struct LoginResponse: Codable {
    let user: User
    let userDefaultLibraryId: String?

    struct User: Codable {
        let id: String
        let username: String
        let email: String?
        let type: String
        let token: String
        let isActive: Bool
        let lastSeen: Int64?
        let createdAt: Int64
        let permissions: Permissions

        struct Permissions: Codable {
            let download: Bool
            let update: Bool
            let delete: Bool
            let upload: Bool
            let accessAllLibraries: Bool
            let accessAllTags: Bool
            let accessExplicitContent: Bool
        }
    }
}

// MARK: - User Details Response (GET /api/me)

struct UserDetailsResponse: Codable {
    let id: String
    let username: String
    let type: String
    let mediaProgress: [UserMediaProgress]?
    let bookmarks: [UserBookmark]?

    struct UserMediaProgress: Codable {
        let id: String
        let libraryItemId: String
        let episodeId: String?
        let duration: Double?
        let progress: Double? // 0-1
        let currentTime: Double?
        let isFinished: Bool?
        let hideFromContinueListening: Bool?
        let lastUpdate: Int64?
        let updatedAt: Int64?
    }

    struct UserBookmark: Codable {
        let id: String
        let libraryItemId: String
        let title: String?
        let time: Double?
        let createdAt: Int64?
    }
}

// MARK: - Libraries Response

struct LibrariesResponse: Codable {
    let libraries: [Library]
}

struct Library: Codable, Identifiable {
    let id: String
    let name: String
    let mediaType: String // "book" or "podcast"
    let displayOrder: Int?
    let icon: String?
}

// MARK: - Media Progress

struct MediaProgress: Codable {
    let id: String?
    let currentTime: Double?
    let isFinished: Bool?
    let progress: Double? // 0-1
    let duration: Double?
    let updatedAt: Int64?
}

// MARK: - Recent Episodes Response

struct RecentEpisodesResponse: Codable {
    let episodes: [PodcastEpisodeExpanded]
    let limit: Int?
    let page: Int?
}

struct PodcastEpisodeExpanded: Codable, Identifiable {
    let id: String
    let libraryItemId: String? // Top-level field, not nested
    let title: String?
    let subtitle: String?
    let description: String?
    let publishedAt: Int64?
    let duration: Double?
    let podcast: PodcastMinimal?
    let libraryId: String?
    let audioFile: AudioFile?
    let mediaProgress: MediaProgress? // Progress information

    struct PodcastMinimal: Codable {
        let metadata: PodcastMetadata?

        struct PodcastMetadata: Codable {
            let title: String?
            let author: String?
        }
    }

    struct AudioFile: Codable {
        let ino: String
        let metadata: AudioMetadata?

        struct AudioMetadata: Codable {
            let filename: String?
            let ext: String?
            let path: String?
            let relPath: String?
            let size: Int64?
            let mtimeMs: Int64?
            let ctimeMs: Int64?
            let birthtimeMs: Int64?
        }
    }
}

// MARK: - Items In Progress Response

struct ItemsInProgressResponse: Codable {
    let libraryItems: [LibraryItem]
}

struct LibraryItem: Codable, Identifiable {
    let id: String
    let libraryId: String
    let folderId: String?
    let path: String?
    let relPath: String?
    let isFile: Bool?
    let mtimeMs: Int64?
    let ctimeMs: Int64?
    let birthtimeMs: Int64?
    let addedAt: Int64?
    let updatedAt: Int64?
    let media: Media
    let progressLastUpdate: Int64?
    let recentEpisode: PodcastEpisode?

    struct Media: Codable {
        let metadata: Metadata
        let coverPath: String?
        let tags: [String]?
        let duration: Double?
        let size: Int64?

        struct Metadata: Codable {
            let title: String?
            let author: String?
            let authorName: String?
            let description: String?
            let publisher: String?
            let publishedYear: String?
            let genres: [String]?
            let tags: [String]?
            let narrators: [String]?
            let series: [Series]?
            let coverPath: String?

            struct Series: Codable {
                let id: String
                let name: String
                let sequence: String?
            }
        }
    }

    struct PodcastEpisode: Codable {
        let id: String
        let title: String?
        let subtitle: String?
        let description: String?
        let publishedAt: Int64?
        let duration: Double?
    }
}

// MARK: - Conversion to App Models

extension PodcastEpisodeExpanded {
    func toQueueItem(baseURL: String, progressMap: [String: UserDetailsResponse.UserMediaProgress] = [:]) -> QueueItem {
        let title = title ?? "Unknown Episode"
        let author = podcast?.metadata?.author ?? podcast?.metadata?.title ?? "Unknown Podcast"
        let coverURL = coverImageURL(baseURL: baseURL)

        // For podcast episodes, store both libraryItemId and episodeId in a special format
        // Format: "libraryItemId/episodeId"
        // This is used for the playback endpoint: POST /api/items/:libraryItemId/play/:episodeId
        let compositeId: String
        if let libraryItemId {
            compositeId = "\(libraryItemId)/\(id)"
        } else {
            compositeId = id
            Task { @MainActor in
                await AppLogger.shared.log("Creating QueueItem: no libraryItemId, using episodeId=\(id) as compositeId", level: .warning)
            }
        }

        // Look up progress from the progressMap using the composite ID
        let userProgress = progressMap[compositeId]
        let totalDuration = duration ?? 0
        let currentTime: TimeInterval = userProgress?.currentTime ?? 0
        let progress: Double = userProgress?.progress ?? 0

        Task { @MainActor in
            if let userProgress {
                await AppLogger.shared.log("Episode \(compositeId): found progress \(progress), currentTime \(currentTime)", level: .debug)
            } else {
                await AppLogger.shared.log("Episode \(compositeId): no progress found in map", level: .debug)
            }
        }

        return QueueItem(
            id: compositeId,
            title: title,
            author: author,
            coverURL: coverURL,
            progress: progress,
            currentTime: currentTime,
            totalDuration: totalDuration
        )
    }

    private func coverImageURL(baseURL: String) -> URL? {
        guard let libraryItemId else { return nil }
        // Cover art endpoint: GET /api/items/:id/cover
        let urlString = "\(baseURL)/api/items/\(libraryItemId)/cover"
        return URL(string: urlString)
    }
}

extension LibraryItem {
    func toQueueItem(baseURL: String) -> QueueItem {
        let title = media.metadata.title ?? "Unknown Title"
        let author = media.metadata.authorName ?? media.metadata.author ?? "Unknown Author"
        let coverURL = coverImageURL(baseURL: baseURL)

        // Calculate progress
        let totalDuration = media.duration ?? 0
        let currentTime: TimeInterval = 0 // TODO: Get from mediaProgress API
        let progress: Double = totalDuration > 0 ? currentTime / totalDuration : 0

        return QueueItem(
            id: id,
            title: title,
            author: author,
            coverURL: coverURL,
            progress: progress,
            currentTime: currentTime,
            totalDuration: totalDuration
        )
    }

    private func coverImageURL(baseURL: String) -> URL? {
        // Cover art endpoint: GET /api/items/:id/cover
        let urlString = "\(baseURL)/api/items/\(id)/cover"
        return URL(string: urlString)
    }
}

// MARK: - API Error

enum AudiobookshelfError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case networkError(Error)
    case decodingError(Error)
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid server URL"
        case .invalidResponse:
            "Invalid response from server"
        case .unauthorized:
            "Unauthorized - please log in again"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case let .decodingError(error):
            "Failed to decode response: \(error.localizedDescription)"
        case let .serverError(statusCode, message):
            "Server error (\(statusCode)): \(message)"
        }
    }
}
