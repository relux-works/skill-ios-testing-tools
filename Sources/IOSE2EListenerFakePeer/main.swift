import Darwin
import Foundation
import IOSE2ECoordinatorCore
import IOSE2EPeerClient

struct ListenerFakePeerOptions: Equatable {
    var scenario: String?
    var delayMs: UInt64 = 0
    var timeout: TimeInterval = 10
    var help = false

    static func parse(_ arguments: [String]) throws -> ListenerFakePeerOptions {
        var options = ListenerFakePeerOptions()
        var index = 1

        func requireValue(for flag: String) throws -> String {
            guard index + 1 < arguments.count else {
                throw ListenerFakePeerError.invalidArguments("Missing value for \(flag).")
            }
            index += 1
            return arguments[index]
        }

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--scenario":
                options.scenario = try requireValue(for: argument)
            case "--delay-ms":
                let value = try requireValue(for: argument)
                guard let delay = UInt64(value) else {
                    throw ListenerFakePeerError.invalidArguments("Invalid --delay-ms value \(value).")
                }
                options.delayMs = delay
            case "--timeout":
                let value = try requireValue(for: argument)
                guard let timeout = TimeInterval(value) else {
                    throw ListenerFakePeerError.invalidArguments("Invalid --timeout value \(value).")
                }
                options.timeout = timeout
            case "--help", "-h":
                options.help = true
            default:
                throw ListenerFakePeerError.invalidArguments("Unknown argument: \(argument).")
            }

            index += 1
        }

        return options
    }
}

enum ListenerFakePeerError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case invalidPayload(String)
    case publishDidNotAck(String)
    case unknownScenario(String)

    var description: String {
        switch self {
        case let .invalidArguments(message):
            return message
        case let .invalidPayload(message):
            return message
        case let .publishDidNotAck(state):
            return "Publish did not reach acked state. Last state: \(state)."
        case let .unknownScenario(scenario):
            return "Unknown scenario \(scenario)."
        }
    }
}

@main
struct ListenerFakePeerMain {
    static func main() async {
        do {
            let options = try ListenerFakePeerOptions.parse(CommandLine.arguments)
            if options.help {
                printUsage()
                return
            }

            if options.delayMs > 0 {
                try await Task.sleep(nanoseconds: options.delayMs * 1_000_000)
            }

            let client = try await UITestE2EClient.fromEnvironment()
            defer { client.close() }

            let scenario = options.scenario ?? client.environment.peerName.rawValue
            switch scenario {
            case "alpha":
                try await runAlpha(client: client)
            case "beta":
                try await runBeta(client: client, timeout: options.timeout)
            case "observer":
                try await runObserver(client: client, timeout: options.timeout)
            default:
                throw ListenerFakePeerError.unknownScenario(scenario)
            }
        } catch let error as ListenerFakePeerError {
            print("Error: \(error.description)")
            exit(1)
        } catch {
            print("Error: \(error)")
            exit(1)
        }
    }

    private static func runAlpha(client: UITestE2EClient) async throws {
        let receipt = try await client.publish(
            "alpha.ready",
            payload: .object([
                "sample": .string("peer-listener-coordinator"),
                "origin": .string("alpha"),
                "ready": .bool(true)
            ]),
            delivery: .acked(requiredPeers: ["beta", "observer"])
        )

        guard receipt.state == "acked" else {
            throw ListenerFakePeerError.publishDidNotAck(receipt.state)
        }
        print("alpha.ready ackedBy=\(receipt.ackedBy.sorted().joined(separator: ","))")

        _ = try await client.publish(
            "alpha.completed",
            payload: .object([
                "ackedBy": .array(receipt.ackedBy.sorted().map(E2EJSONValue.string))
            ]),
            delivery: .accepted
        )
    }

    private static func runBeta(client: UITestE2EClient, timeout: TimeInterval) async throws {
        let event = try await client.waitFor("alpha.ready", originPeer: "alpha", timeout: timeout)
        try assertReadyEvent(event)
        print("beta observed alpha.ready seq=\(event.seq.rawValue)")
        _ = try await client.publish(
            "beta.observed",
            payload: .object([
                "observedSeq": .number(Double(event.seq.rawValue))
            ]),
            delivery: .accepted
        )
    }

    private static func runObserver(client: UITestE2EClient, timeout: TimeInterval) async throws {
        let event = try await client.waitFor("alpha.ready", originPeer: "alpha", timeout: timeout)
        try assertReadyEvent(event)
        print("observer observed alpha.ready seq=\(event.seq.rawValue)")
        _ = try await client.publish(
            "observer.observed",
            payload: .object([
                "observedSeq": .number(Double(event.seq.rawValue))
            ]),
            delivery: .accepted
        )
    }

    private static func assertReadyEvent(_ event: UITestE2EObservedEvent) throws {
        guard case let .object(values) = event.payload,
              values["sample"] == .string("peer-listener-coordinator"),
              values["origin"] == .string("alpha"),
              values["ready"] == .bool(true) else {
            throw ListenerFakePeerError.invalidPayload("alpha.ready payload did not match expected JSON object.")
        }
    }

    private static func printUsage() {
        print("""
        e2e-listener-fake-peer - Sample process peer for peer-listener E2E transport.

        Usage:
          e2e-listener-fake-peer [--scenario alpha|beta|observer] [--delay-ms value] [--timeout seconds]

        The peer reads E2E_* environment values produced by ios-e2e-runner.
        """)
    }
}
