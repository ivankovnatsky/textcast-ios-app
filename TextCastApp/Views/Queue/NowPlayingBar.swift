import SwiftUI

/// Mini player bar shown at the bottom of the screen
struct NowPlayingBar: View {
    @ObservedObject var playerState: PlayerState

    var body: some View {
        if let item = playerState.currentItem {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: playerState.audioPlayer.currentTime, total: playerState.audioPlayer.duration)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .frame(height: 2)

                HStack(spacing: 12) {
                    // Cover art
                    AsyncImage(url: item.coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)

                    // Title and author
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        if let author = item.author {
                            Text(author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Playback controls
                    HStack(spacing: 20) {
                        // Skip backward
                        Button {
                            playerState.audioPlayer.skipBackward()
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.title3)
                                .foregroundStyle(.primary)
                        }

                        // Play/Pause button
                        Button {
                            playerState.audioPlayer.togglePlayPause()
                        } label: {
                            Image(systemName: playerState.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }

                        // Skip forward
                        Button {
                            playerState.audioPlayer.skipForward()
                        } label: {
                            Image(systemName: "goforward.15")
                                .font(.title3)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.trailing, 8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(0.2), radius: 10, y: -2)
            .onTapGesture {
                playerState.expandPlayer()
            }
        }
    }
}