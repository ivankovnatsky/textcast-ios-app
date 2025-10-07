import Foundation

struct QueueItem: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String?
    let coverURL: URL?
    let progress: Double // 0.0 to 1.0
    let currentTime: TimeInterval // in seconds
    let totalDuration: TimeInterval // in seconds

    var minutesRemaining: Int {
        let remaining = totalDuration - currentTime
        return max(0, Int(remaining) / 60)
    }

    var minutesRemainingText: String {
        let minutes = minutesRemaining
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
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
