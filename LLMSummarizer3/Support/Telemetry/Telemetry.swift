import Foundation
import os.log

enum TelemetryEvent: String {
    case fetchStarted = "event.fetch.started"
    case fetchFinished = "event.fetch.finished"
    case fetchFailed = "event.fetch.failed"
    case parseStarted = "event.parse.started"
    case parseFinished = "event.parse.finished"
    case parseFailed = "event.parse.failed"
    case summarizeStarted = "event.summarize.started"
    case summarizeFinished = "event.summarize.finished"
    case summarizeFailed = "event.summarize.failed"
}

enum TelemetryProp: String {
    case urlDomain
    case durationMs
    case chars
    case modelId
    case errorCode
}

final class Telemetry {
    static let shared = Telemetry()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "telemetry")

    func logEvent(_ event: TelemetryEvent, props: [TelemetryProp: String] = [:]) {
        let dict = props.map { "\($0.key.rawValue)=\($0.value)" }.joined(separator: ",")
        logger.log("\(event.rawValue, privacy: .public) \(dict, privacy: .public)")
    }
}

