import Foundation
import IOSE2ECoordinatorTransport

public struct E2ERunnerArtifactWriter: @unchecked Sendable {
    private let encoder: JSONEncoder
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func prepare(plan: E2ELaunchPlan) throws {
        try fileManager.createDirectory(atPath: plan.artifactRoot, withIntermediateDirectories: true)
        try writeJSON(plan, to: path(plan.artifactRoot, "resolved-config.json"))
        try writeText("", to: path(plan.artifactRoot, "event-log.jsonl"))
        try writeText("", to: path(plan.artifactRoot, "receipts.jsonl"))
        try writeText("Coordinator: \(plan.coordinatorURL)\n", to: path(plan.artifactRoot, "coordinator.log"))

        for peer in plan.peers {
            try fileManager.createDirectory(atPath: peer.artifactsDirectory, withIntermediateDirectories: true)
            try writeJSON(peer, to: path(peer.artifactsDirectory, "launch.json"))
        }
    }

    public func writePeerResult(_ result: E2EPeerExecutionResult, plan: E2ELaunchPlan) throws {
        guard let peer = plan.peers.first(where: { $0.name == result.peerName }) else {
            return
        }

        let logName = peer.kind == "xctest" ? "xcodebuild.log" : "process.log"
        let content = [
            "status: \(result.result.status)",
            "",
            "stdout:",
            result.result.output,
            "",
            "stderr:",
            result.result.error
        ].joined(separator: "\n")
        try writeText(content, to: path(peer.artifactsDirectory, logName))
    }

    public func writeSummary(
        plan: E2ELaunchPlan,
        results: [E2EPeerExecutionResult],
        status: String
    ) throws {
        let summary = E2ERunnerSessionSummary(
            sessionID: plan.sessionID,
            profileName: plan.profileName,
            status: status,
            coordinatorURL: plan.coordinatorURL,
            artifactRoot: plan.artifactRoot,
            resolvedConfigPath: path(plan.artifactRoot, "resolved-config.json"),
            eventLogPath: path(plan.artifactRoot, "event-log.jsonl"),
            receiptsPath: path(plan.artifactRoot, "receipts.jsonl"),
            coordinatorLogPath: path(plan.artifactRoot, "coordinator.log"),
            peers: plan.peers.map { peer in
                let result = results.first(where: { $0.peerName == peer.name })
                let logName = peer.kind == "xctest" ? "xcodebuild.log" : "process.log"
                return E2ERunnerSessionSummary.Peer(
                    name: peer.name,
                    role: peer.role,
                    kind: peer.kind,
                    status: result?.result.status,
                    artifactsDirectory: peer.artifactsDirectory,
                    launchPath: path(peer.artifactsDirectory, "launch.json"),
                    logPath: path(peer.artifactsDirectory, logName),
                    resultBundlePath: peer.kind == "xctest"
                        ? path(peer.artifactsDirectory, "result.xcresult")
                        : nil,
                    screenshotsDirectory: path(peer.artifactsDirectory, "screenshots")
                )
            }
        )

        try writeJSON(summary, to: path(plan.artifactRoot, "session-summary.json"))
    }

    private func writeJSON<T: Encodable>(_ value: T, to filePath: String) throws {
        let data = try encoder.encode(value)
        try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
    }

    private func writeText(_ value: String, to filePath: String) throws {
        try value.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    private func path(_ root: String, _ component: String) -> String {
        URL(fileURLWithPath: root).appendingPathComponent(component).standardized.path
    }
}

public final class E2ERunnerFileSessionRecorder: E2EWebSocketSessionRecording, @unchecked Sendable {
    private let eventLogPath: String
    private let receiptsPath: String
    private let lock = NSLock()

    public init(artifactRoot: String) {
        self.eventLogPath = URL(fileURLWithPath: artifactRoot)
            .appendingPathComponent("event-log.jsonl")
            .standardized
            .path
        self.receiptsPath = URL(fileURLWithPath: artifactRoot)
            .appendingPathComponent("receipts.jsonl")
            .standardized
            .path
    }

    public func recordEventJSON(_ json: String) {
        append(json, to: eventLogPath)
    }

    public func recordReceiptJSON(_ json: String) {
        append(json, to: receiptsPath)
    }

    private func append(_ line: String, to path: String) {
        lock.lock()
        defer { lock.unlock() }

        let data = Data((line + "\n").utf8)
        if FileManager.default.fileExists(atPath: path),
           let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}

private struct E2ERunnerSessionSummary: Codable, Equatable, Sendable {
    var sessionID: String
    var profileName: String
    var status: String
    var coordinatorURL: String
    var artifactRoot: String
    var resolvedConfigPath: String
    var eventLogPath: String
    var receiptsPath: String
    var coordinatorLogPath: String
    var peers: [Peer]

    struct Peer: Codable, Equatable, Sendable {
        var name: String
        var role: String?
        var kind: String
        var status: Int32?
        var artifactsDirectory: String
        var launchPath: String
        var logPath: String
        var resultBundlePath: String?
        var screenshotsDirectory: String
    }
}
