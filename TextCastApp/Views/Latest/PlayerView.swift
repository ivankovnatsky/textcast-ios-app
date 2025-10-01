import SwiftUI

struct PlayerView: View {
    @ObservedObject var playerState: PlayerState
    @EnvironmentObject var authState: AuthenticationState
    @GestureState private var dragOffset: CGFloat = 0
    @State private var accumulatedOffset: CGFloat = 0

    private var audioPlayer: AudioPlayerService {
        playerState.audioPlayer
    }

    var body: some View {
        if let item = playerState.currentItem {
            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                VStack(spacing: 32) {
                    Spacer()

                    // Cover art
                    AsyncImage(url: item.coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(maxWidth: 300, maxHeight: 300)
                    .cornerRadius(16)
                    .shadow(radius: 10)

                    // Metadata
                    VStack(spacing: 8) {
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        if let author = item.author {
                            Text(author)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Playback controls
                    VStack(spacing: 16) {
                        // Progress slider
                        VStack(spacing: 4) {
                            Slider(value: Binding(
                                get: { audioPlayer.currentTime },
                                set: { audioPlayer.seek(to: $0) }
                            ), in: 0 ... audioPlayer.duration)

                            HStack {
                                Text(formatTime(audioPlayer.currentTime))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatTime(audioPlayer.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Main controls
                        VStack(spacing: 32) {
                            // Primary controls (top row)
                            HStack(spacing: 40) {
                                // Skip backward
                                Button {
                                    audioPlayer.skipBackward()
                                } label: {
                                    Image(systemName: "gobackward.15")
                                        .font(.title)
                                }

                                // Play/Pause
                                Button {
                                    audioPlayer.togglePlayPause()
                                } label: {
                                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 64))
                                }

                                // Skip forward
                                Button {
                                    audioPlayer.skipForward()
                                } label: {
                                    Image(systemName: "goforward.15")
                                        .font(.title)
                                }
                            }

                            // Episode navigation (bottom row)
                            HStack(spacing: 80) {
                                // Previous episode
                                Button {
                                    playerState.playPrevious()
                                } label: {
                                    Image(systemName: "backward.end.fill")
                                        .font(.title)
                                }
                                .disabled(playerState.currentQueueIndex == 0)
                                .opacity(playerState.currentQueueIndex == 0 ? 0.3 : 1.0)

                                // Next episode
                                Button {
                                    playerState.playNext()
                                } label: {
                                    Image(systemName: "forward.end.fill")
                                        .font(.title)
                                }
                                .disabled(playerState.currentQueueIndex >= playerState.playQueue.count - 1)
                                .opacity(playerState.currentQueueIndex >= playerState.playQueue.count - 1 ? 0.3 : 1.0)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
                .padding()
            }
            .background(Color(UIColor.systemBackground))
            .offset(y: max(dragOffset + accumulatedOffset, 0))
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        if value.translation.height > 0 {
                            state = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            // Swipe down to collapse
                            playerState.collapsePlayer()
                            accumulatedOffset = 0
                        } else {
                            // Snap back
                            withAnimation(.spring()) {
                                accumulatedOffset = 0
                            }
                        }
                    }
            )
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        let seconds = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
