import SwiftUI

struct LatestView: View {
    @StateObject private var viewModel = QueueViewModel()
    @EnvironmentObject var authState: AuthenticationState
    @EnvironmentObject var playerState: PlayerState

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "No Latest Episodes",
                        systemImage: "list.bullet"
                    )
                } else {
                    List {
                        ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                            QueueItemRow(item: item)
                                .onTapGesture {
                                    // Always queue from tapped item to bottom (oldest)
                                    let queueItems = Array(viewModel.items[index...])
                                    playerState.playQueue(
                                        items: queueItems,
                                        startingAt: 0,
                                        apiClient: authState.getAPIClient()
                                    )
                                    playerState.expandPlayer()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteItem(item, playerState: playerState)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        // Always queue from tapped item to bottom (oldest)
                                        let queueItems = Array(viewModel.items[index...])
                                        playerState.playQueue(
                                            items: queueItems,
                                            startingAt: 0,
                                            apiClient: authState.getAPIClient()
                                        )
                                        playerState.expandPlayer()
                                    } label: {
                                        Label("Play", systemImage: "play.fill")
                                    }

                                    Button {
                                        viewModel.markAsFinished(item)
                                    } label: {
                                        Label("Mark as Finished", systemImage: "checkmark.circle")
                                    }

                                    Button {
                                        viewModel.restartProgress(item)
                                    } label: {
                                        Label("Restart", systemImage: "arrow.counterclockwise")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        viewModel.deleteItem(item, playerState: playerState)
                                    } label: {
                                        Label("Delete from Library", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Latest")
            .refreshable {
                // Refresh user progress before loading queue
                await authState.refreshUserProgress()
                await viewModel.loadQueue(progressMap: authState.mediaProgressMap)
            }
            .task {
                // Set API client from auth state
                viewModel.setAPIClient(authState.getAPIClient())

                // Wait for progress to load if not already loaded
                if authState.mediaProgressMap.isEmpty {
                    await authState.refreshUserProgress()
                }

                await viewModel.loadQueue(progressMap: authState.mediaProgressMap)
            }
            .onChange(of: playerState.isPlayerExpanded) { oldValue, newValue in
                // When player is collapsed (not expanded), refresh progress
                if oldValue == true, newValue == false {
                    Task {
                        await authState.refreshUserProgress()
                        await viewModel.loadQueue(progressMap: authState.mediaProgressMap)
                    }
                }
            }
        }
    }
}

// MARK: - Queue Item Row

struct QueueItemRow: View {
    let item: QueueItem

    var body: some View {
        HStack(spacing: 12) {
            // Cover art placeholder
            AsyncImage(url: item.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                if let author = item.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Progress bar
                ProgressView(value: item.progress)
                    .tint(.blue)

                Text(item.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Latest View") {
    LatestView()
}

#Preview("Latest Item Row") {
    List {
        QueueItemRow(item: QueueItem.preview)
        QueueItemRow(item: QueueItem.preview2)
    }
}
