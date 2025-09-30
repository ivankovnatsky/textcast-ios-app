import Foundation

struct QueueItem: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String?
    let coverURL: URL?
    let progress: Double // 0.0 to 1.0
    let currentTime: TimeInterval // in seconds
    let totalDuration: TimeInterval // in seconds

    var progressText: String {
        let current = formatDuration(currentTime)
        let total = formatDuration(totalDuration)
        let percentage = Int(progress * 100)
        return "\(current) / \(total) (\(percentage)%)"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Preview Data

extension QueueItem {
    static let preview = QueueItem(
        id: "1",
        title: "Project Hail Mary",
        author: "Andy Weir",
        coverURL: nil,
        progress: 0.35,
        currentTime: 12600, // 3.5 hours
        totalDuration: 36000 // 10 hours
    )

    static let preview2 = QueueItem(
        id: "2",
        title: "The Martian",
        author: "Andy Weir",
        coverURL: nil,
        progress: 0.75,
        currentTime: 27000, // 7.5 hours
        totalDuration: 36000 // 10 hours
    )
}
