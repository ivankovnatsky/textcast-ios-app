import Combine
import Foundation

/// Centralized logging service for debugging
@MainActor
class AppLogger: ObservableObject {
    static let shared = AppLogger()

    @Published var logs: [LogEntry] = []
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "debugLogsEnabled")
        }
    }

    private let maxLogs = 1000

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "debugLogsEnabled")
    }

    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }

        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            file: (file as NSString).lastPathComponent,
            function: function,
            line: line
        )

        logs.append(entry)

        // Keep only recent logs
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }

        // Also print to console
        print("[\(entry.level.emoji) \(entry.timestamp.formatted(date: .omitted, time: .standard))] \(entry.message)")
    }

    func clear() {
        logs.removeAll()
    }

    func export() -> String {
        logs.map { entry in
            "[\(entry.timestamp.ISO8601Format())] [\(entry.level.rawValue)] \(entry.file):\(entry.line) \(entry.function)\n\(entry.message)\n"
        }.joined(separator: "\n")
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let file: String
    let function: String
    let line: Int
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var emoji: String {
        switch self {
        case .debug: "🔍"
        case .info: "ℹ️"
        case .warning: "⚠️"
        case .error: "❌"
        }
    }

    var color: String {
        switch self {
        case .debug: "gray"
        case .info: "blue"
        case .warning: "orange"
        case .error: "red"
        }
    }
}
