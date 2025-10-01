import Combine
import SwiftUI

/// Global player state that persists across views
@MainActor
class PlayerState: ObservableObject {
    @Published var currentItem: QueueItem?
    @Published var isPlayerExpanded = false
    @Published var playQueue: [QueueItem] = []
    @Published var currentQueueIndex: Int = 0

    /// Shared audio player service
    let audioPlayer = AudioPlayerService()

    private var cancellables = Set<AnyCancellable>()
    private var apiClient: AudiobookshelfAPI?

    init() {
        // Forward audioPlayer changes to trigger view updates
        audioPlayer.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)

        // Auto-play next when current episode finishes
        audioPlayer.$didFinishPlaying
            .sink { [weak self] didFinish in
                if didFinish {
                    AppLogger.shared.log("Episode finished, playing next in queue", level: .info)
                    self?.playNext()
                }
            }
            .store(in: &cancellables)
    }

    /// Play a single item (clears queue)
    func play(item: QueueItem, apiClient: AudiobookshelfAPI?) {
        playQueue = [item]
        currentQueueIndex = 0
        self.apiClient = apiClient
        playCurrentItem()
    }

    /// Play from a queue starting at a specific item
    func playQueue(items: [QueueItem], startingAt index: Int, apiClient: AudiobookshelfAPI?) {
        playQueue = items
        currentQueueIndex = index
        self.apiClient = apiClient
        playCurrentItem()
    }

    /// Play next item in queue
    func playNext() {
        guard currentQueueIndex < playQueue.count - 1 else {
            AppLogger.shared.log("End of queue reached", level: .info)
            return
        }
        currentQueueIndex += 1
        playCurrentItem()
    }

    /// Play previous item in queue
    func playPrevious() {
        guard currentQueueIndex > 0 else {
            AppLogger.shared.log("At start of queue", level: .info)
            return
        }
        currentQueueIndex -= 1
        playCurrentItem()
    }

    private func playCurrentItem() {
        guard currentQueueIndex < playQueue.count else { return }

        let item = playQueue[currentQueueIndex]
        currentItem = item

        // Set API client for progress syncing
        audioPlayer.setAPIClient(apiClient)

        Task {
            // Get stream URL from API
            if let apiClient,
               let streamURL = await apiClient.getStreamURL(itemId: item.id)
            {
                AppLogger.shared.log("Loading stream URL: \(streamURL)", level: .info)
                audioPlayer.load(url: streamURL)

                // Wait for player to be ready
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                // Resume from saved position if available
                if item.currentTime > 0 {
                    AppLogger.shared.log("Resuming from saved position: \(item.currentTime)s", level: .info)
                    audioPlayer.seek(to: item.currentTime)
                }

                // Auto-play
                audioPlayer.play()

                // Update Now Playing Info for Control Center and Lock Screen
                audioPlayer.updateNowPlayingInfo(
                    title: item.title,
                    author: item.author
                )
            } else {
                AppLogger.shared.log("Failed to get stream URL for item: \(item.id)", level: .error)
            }
        }
    }

    func expandPlayer() {
        isPlayerExpanded = true
    }

    func collapsePlayer() {
        isPlayerExpanded = false
    }

    func stopPlayback() {
        audioPlayer.pause()
        currentItem = nil
    }

    /// Remove an item from the play queue (e.g., when deleted from library)
    func removeFromQueue(itemId: String) {
        // Remove from queue
        playQueue.removeAll { $0.id == itemId }

        // If currently playing item was deleted, stop playback
        if currentItem?.id == itemId {
            audioPlayer.pause()
            currentItem = nil

            // Try to play next item if available
            if currentQueueIndex < playQueue.count {
                playCurrentItem()
            }
        } else if let currentIndex = playQueue.firstIndex(where: { $0.id == currentItem?.id }) {
            // Update current index if items before it were removed
            currentQueueIndex = currentIndex
        }

        AppLogger.shared.log("Removed item \(itemId) from play queue", level: .info)
    }
}
