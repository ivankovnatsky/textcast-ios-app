import Foundation
import Combine

/// Manages playback session state for progress syncing
@MainActor
class PlaybackSessionManager: ObservableObject {
    static let shared = PlaybackSessionManager()

    var currentSessionId: String?
    var lastSyncTime: Date = Date()
    var totalTimeListened: Double = 0

    private init() {}

    func reset() {
        currentSessionId = nil
        lastSyncTime = Date()
        totalTimeListened = 0
    }
}