import Combine
import Foundation
import SwiftUI

@MainActor
class QueueViewModel: ObservableObject {
    @Published var items: [QueueItem] = []
    @Published var isLoading = false
    @Published var selectedItem: QueueItem?
    @Published var errorMessage: String?

    private var apiClient: AudiobookshelfAPI?

    func setAPIClient(_ client: AudiobookshelfAPI?) {
        apiClient = client
    }

    func loadQueue(progressMap: [String: UserDetailsResponse.UserMediaProgress] = [:]) async {
        guard !isLoading else {
            AppLogger.shared.log("Already loading, skipping duplicate request", level: .debug)
            return
        }
        guard let apiClient else {
            errorMessage = "Not authenticated"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let baseURL = await apiClient.getBaseURL()

            // Get libraries
            let libraries = try await apiClient.getLibraries()

            // Find podcast library
            guard let podcastLibrary = libraries.first(where: { $0.mediaType == "podcast" }) else {
                // Fallback to items in progress if no podcast library
                let libraryItems = try await apiClient.getItemsInProgress(limit: 25)
                items = libraryItems.map { $0.toQueueItem(baseURL: baseURL) }
                return
            }

            // Get recent episodes from podcast library
            let episodes = try await apiClient.getRecentEpisodes(libraryId: podcastLibrary.id, limit: 25)
            items = episodes.map { $0.toQueueItem(baseURL: baseURL, progressMap: progressMap) }

            // Debug: Log the IDs and progress
            AppLogger.shared.log("Loaded \(items.count) episodes", level: .info)
            if let firstItem = items.first {
                AppLogger.shared.log("First item ID: \(firstItem.id), title: \(firstItem.title), progress: \(firstItem.progress)", level: .info)
            }

        } catch let error as AudiobookshelfError {
            errorMessage = error.localizedDescription
            AppLogger.shared.log("Failed to load latest (AudiobookshelfError): \(error)", level: .error)
        } catch {
            // Ignore cancellation errors (happens when refreshing while already loading)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                AppLogger.shared.log("Load cancelled (user refreshed)", level: .info)
                return
            }

            errorMessage = "Failed to load latest: \(error.localizedDescription)"
            AppLogger.shared.log("Failed to load latest: \(error)", level: .error)
        }
    }

    func refresh() async {
        await loadQueue()
    }

    func selectItem(_ item: QueueItem) {
        AppLogger.shared.log("selectItem called with id: \(item.id), title: \(item.title)", level: .info)
        selectedItem = item
    }

    func deleteItem(_ item: QueueItem, playerState: PlayerState) {
        // Optimistically remove from UI immediately
        withAnimation {
            items.removeAll { $0.id == item.id }
        }

        // Remove from play queue if currently in queue
        playerState.removeFromQueue(itemId: item.id)

        Task { @MainActor in
            do {
                guard let apiClient else {
                    AppLogger.shared.log("API client not available", level: .error)
                    return
                }

                // Parse composite ID (format: "libraryItemId/episodeId")
                let components = item.id.split(separator: "/")
                guard components.count == 2 else {
                    AppLogger.shared.log("Invalid item ID format: \(item.id)", level: .error)
                    return
                }

                let libraryItemId = String(components[0])
                let episodeId = String(components[1])

                // Permanently delete episode from library
                try await apiClient.deleteEpisode(libraryItemId: libraryItemId, episodeId: episodeId)

                AppLogger.shared.log("Deleted '\(item.title)' from library", level: .info)
            } catch {
                AppLogger.shared.log("Failed to delete item: \(error)", level: .error)
                // Consider reloading the queue on error to sync with server state
            }
        }
    }

    func markAsFinished(_ item: QueueItem) {
        // Optimistically remove from UI immediately
        withAnimation {
            items.removeAll { $0.id == item.id }
        }

        Task { @MainActor in
            do {
                guard let apiClient else {
                    AppLogger.shared.log("API client not available", level: .error)
                    return
                }

                // Parse composite ID (format: "libraryItemId/episodeId")
                let components = item.id.split(separator: "/")
                guard components.count == 2 else {
                    AppLogger.shared.log("Invalid item ID format: \(item.id)", level: .error)
                    return
                }

                let libraryItemId = String(components[0])
                let episodeId = String(components[1])

                // Mark as finished on server
                try await apiClient.markAsFinished(libraryItemId: libraryItemId, episodeId: episodeId, duration: item.totalDuration)

                AppLogger.shared.log("Marked '\(item.title)' as finished", level: .info)
            } catch {
                AppLogger.shared.log("Failed to mark item as finished: \(error)", level: .error)
            }
        }
    }

    func restartProgress(_ item: QueueItem) {
        // Optimistically update UI immediately
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }

        withAnimation {
            items[index] = QueueItem(
                id: item.id,
                title: item.title,
                author: item.author,
                coverURL: item.coverURL,
                progress: 0.0,
                currentTime: 0,
                totalDuration: item.totalDuration
            )
        }

        Task { @MainActor in
            do {
                guard let apiClient else {
                    AppLogger.shared.log("API client not available", level: .error)
                    return
                }

                // Parse composite ID (format: "libraryItemId/episodeId")
                let components = item.id.split(separator: "/")
                guard components.count == 2 else {
                    AppLogger.shared.log("Invalid item ID format: \(item.id)", level: .error)
                    return
                }

                let libraryItemId = String(components[0])
                let episodeId = String(components[1])

                // Reset progress on server
                try await apiClient.resetProgress(libraryItemId: libraryItemId, episodeId: episodeId, duration: item.totalDuration)

                AppLogger.shared.log("Restarted '\(item.title)'", level: .info)
            } catch {
                AppLogger.shared.log("Failed to restart progress: \(error)", level: .error)
            }
        }
    }
}
