import SwiftUI

struct LogsView: View {
    @ObservedObject var logger = AppLogger.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if logger.logs.isEmpty {
                    ContentUnavailableView(
                        "No Logs",
                        systemImage: "doc.text",
                        description: Text("Enable logs in Settings to see activity")
                    )
                } else {
                    List {
                        ForEach(logger.logs.reversed()) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.level.emoji)
                                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(entry.file):\(entry.line)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Text(entry.message)
                                    .font(.system(.caption, design: .monospaced))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            copyLogs()
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                        }

                        Button(role: .destructive) {
                            logger.clear()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func copyLogs() {
        UIPasteboard.general.string = logger.export()
    }
}

#Preview {
    LogsView()
}