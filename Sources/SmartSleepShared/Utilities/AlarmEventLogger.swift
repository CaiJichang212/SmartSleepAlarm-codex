import Foundation
import SmartSleepDomain

public struct AlarmRuntimeLogEntry: Codable, Sendable {
    public var alarmID: UUID?
    public var state: RuntimeState?
    public var timestamp: Date
    public var source: String
    public var event: String
    public var detail: String?

    public init(
        alarmID: UUID?,
        state: RuntimeState?,
        timestamp: Date = Date(),
        source: String,
        event: String,
        detail: String? = nil
    ) {
        self.alarmID = alarmID
        self.state = state
        self.timestamp = timestamp
        self.source = source
        self.event = event
        self.detail = detail
    }
}

public protocol AlarmEventLogger: Sendable {
    func log(_ entry: AlarmRuntimeLogEntry) async
}

public actor JSONLineAlarmEventLogger: AlarmEventLogger {
    private let fileURL: URL
    private let encoder: JSONEncoder

    public init(
        baseDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    ) {
        let directory = baseDirectory.appendingPathComponent("SmartSleepAlarm/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("runtime-events.jsonl")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func log(_ entry: AlarmRuntimeLogEntry) async {
        guard let data = try? encoder.encode(entry),
              let line = String(data: data, encoding: .utf8) else {
            return
        }
        appendLine(line)
    }

    private func appendLine(_ line: String) {
        let payload = line + "\n"
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(payload.utf8))
            }
        } else {
            try? Data(payload.utf8).write(to: fileURL, options: .atomic)
        }
    }
}
