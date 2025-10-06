import SwiftUI

/// Mini player bar shown at the bottom of the screen
struct NowPlayingBar: View {
    @ObservedObject var playerState: PlayerState

    private var progress: Double {
        guard playerState.audioPlayer.duration > 0 else { return 0 }
        return playerState.audioPlayer.currentTime / playerState.audioPlayer.duration
    }

    var body: some View {
        if let item = playerState.currentItem {
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
                    .padding(.leading, 20)

                    // Title, author, and progress
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

                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 3)

                                // Progress fill
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor)
                                    .frame(width: geometry.size.width * progress, height: 3)
                            }
                        }
                        .frame(height: 3)
                        .padding(.top, 2)
                    }

                    Spacer()

                    // Play/Pause button
                    Button {
                        playerState.audioPlayer.togglePlayPause()
                    } label: {
                        Image(systemName: playerState.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                    .padding(.trailing, 32)
                }
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive())
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .shadow(color: .black.opacity(0.2), radius: 10, y: -2)
                .onTapGesture {
                    playerState.expandPlayer()
                }
        }
    }
}
