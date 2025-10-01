import AVFoundation
import Combine
import Foundation
import MediaPlayer

@MainActor
class AudioPlayerService: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var didFinishPlaying = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var lastProgressSync: Date = .init()
    private var progressSyncInterval: TimeInterval = 30 // Sync every 30 seconds
    private var sessionStartTime: Date = .init()
    private var apiClient: AudiobookshelfAPI?
    private var nowPlayingTitle: String?
    private var nowPlayingAuthor: String?

    func setAPIClient(_ client: AudiobookshelfAPI?) {
        apiClient = client
    }

    init() {
        setupAudioSession()
        setupRemoteCommands()
    }

    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio)
            try audioSession.setActive(true)
        } catch {
            AppLogger.shared.log("Failed to set up audio session: \(error)", level: .error)
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.play()
            }
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        // Skip forward
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipForward()
            }
            return .success
        }

        // Skip backward
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipBackward()
            }
            return .success
        }
    }

    func updateNowPlayingInfo(title: String, author: String?, artwork: UIImage? = nil) {
        // Store title and author for periodic updates
        nowPlayingTitle = title
        nowPlayingAuthor = author

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title

        if let author = author {
            nowPlayingInfo[MPMediaItemPropertyArtist] = author
        }

        if let artwork = artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateNowPlayingTime() {
        guard let title = nowPlayingTitle else { return }

        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title

        if let author = nowPlayingAuthor {
            nowPlayingInfo[MPMediaItemPropertyArtist] = author
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func load(url: URL) {
        AppLogger.shared.log("AudioPlayerService loading URL: \(url)", level: .info)

        // Reset finish flag
        didFinishPlaying = false

        // Remove previous time observer if any
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        // Clear previous cancellables
        cancellables.removeAll()

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Observe when item finishes playing
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                guard let self else { return }
                AppLogger.shared.log("Episode finished playing", level: .info)
                self.didFinishPlaying = true
                self.isPlaying = false
            }
            .store(in: &cancellables)

        // Observe player item status
        player?.currentItem?.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self else { return }
                AppLogger.shared.log("Player status changed: \(status.rawValue)", level: .info)
                if status == .readyToPlay {
                    self.updateDuration()
                    AppLogger.shared.log("Duration ready: \(self.duration)s", level: .info)
                } else if status == .failed {
                    if let error = self.player?.currentItem?.error {
                        AppLogger.shared.log("Player failed: \(error.localizedDescription)", level: .error)
                        // Log underlying error details
                        let nsError = error as NSError
                        AppLogger.shared.log("Error domain: \(nsError.domain), code: \(nsError.code)", level: .error)
                        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                            AppLogger.shared.log("Underlying error: \(underlyingError.localizedDescription)", level: .error)
                        }
                    }
                }
            }
            .store(in: &cancellables)

        // Add periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            // Also update duration in case it wasn't available initially
            if let duration = self.player?.currentItem?.duration.seconds,
               duration.isFinite,
               self.duration == 0
            {
                self.duration = duration
            }

            // Update now playing info with current time
            self.updateNowPlayingTime()

            // Sync progress periodically if playing
            if self.isPlaying {
                let now = Date()
                if now.timeIntervalSince(self.lastProgressSync) >= self.progressSyncInterval {
                    self.lastProgressSync = now
                    Task {
                        await self.syncProgress()
                    }
                }
            }
        }

        AppLogger.shared.log("Player loaded, waiting for ready state...", level: .info)
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        player?.play()
        isPlaying = true
        sessionStartTime = Date()
        AppLogger.shared.log("Playback started", level: .info)
    }

    func pause() {
        player?.pause()
        isPlaying = false
        AppLogger.shared.log("Playback paused", level: .info)

        // Sync progress when pausing
        Task {
            await syncProgress()
        }
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime)
    }

    func skipForward(seconds: Double = 15) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }

    func skipBackward(seconds: Double = 15) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }

    private func updateDuration() {
        if let duration = player?.currentItem?.duration.seconds, duration.isFinite {
            self.duration = duration
        }
    }

    private func syncProgress() async {
        guard let apiClient,
              let sessionId = PlaybackSessionManager.shared.currentSessionId,
              duration > 0
        else {
            return
        }

        let timeListened = Date().timeIntervalSince(sessionStartTime)
        PlaybackSessionManager.shared.totalTimeListened += timeListened
        sessionStartTime = Date()

        do {
            try await apiClient.syncPlaybackProgress(
                sessionId: sessionId,
                currentTime: currentTime,
                duration: duration,
                timeListened: PlaybackSessionManager.shared.totalTimeListened
            )
        } catch {
            AppLogger.shared.log("Failed to sync progress: \(error.localizedDescription)", level: .error)
        }
    }
}
