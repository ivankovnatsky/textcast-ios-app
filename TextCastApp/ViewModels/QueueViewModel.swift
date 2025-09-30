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
        guard !isLoading else { return }
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
            await AppLogger.shared.log("Loaded \(items.count) episodes", level: .info)
            if let firstItem = items.first {
                await AppLogger.shared.log("First item ID: \(firstItem.id), title: \(firstItem.title), progress: \(firstItem.progress)", level: .info)
            }

        } catch let error as AudiobookshelfError {
            errorMessage = error.localizedDescription
            await AppLogger.shared.log("Failed to load latest (AudiobookshelfError): \(error)", level: .error)
        } catch {
            // Ignore cancellation errors (happens when refreshing while already loading)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                await AppLogger.shared.log("Load cancelled (user refreshed)", level: .info)
                return
            }

            errorMessage = "Failed to load latest: \(error.localizedDescription)"
            await AppLogger.shared.log("Failed to load latest: \(error)", level: .error)
        }
    }

    func refresh() async {
        await loadQueue()
    }

    func selectItem(_ item: QueueItem) {
        Task {
            await AppLogger.shared.log("selectItem called with id: \(item.id), title: \(item.title)", level: .info)
        }
        selectedItem = item
    }

    func deleteItem(_ item: QueueItem) {
        // TODO: Call API to remove item from server queue
        withAnimation {
            items.removeAll { $0.id == item.id }
        }
    }

    func markAsFinished(_ item: QueueItem) {
        // TODO: Call API to mark item as finished on server
        // For now, just remove from queue
        withAnimation {
            items.removeAll { $0.id == item.id }
        }
        Task {
            await AppLogger.shared.log("Marked '\(item.title)' as finished", level: .info)
        }
    }

    func restartProgress(_ item: QueueItem) {
        // TODO: Call API to reset progress on server
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
        Task {
            await AppLogger.shared.log("Restarted '\(item.title)'", level: .info)
        }
    }
}
