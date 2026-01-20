import Foundation

enum Args {
    enum Mode {
        case compareAll(artifactsPath: String, outputPath: String, testsPath: String)
        case compareTwo(imageA: String, imageB: String, outputPath: String)
        case help
        case error(String)
    }

    static func parse(_ arguments: [String]) -> Mode {
        let args = Array(arguments.dropFirst()) // Drop executable name

        if args.isEmpty {
            return .compareAll(
                artifactsPath: "../SnapshotArtifacts",
                outputPath: "../SnapshotDiffs",
                testsPath: "../AppSnapshotTests"
            )
        }

        if args.contains("--help") || args.contains("-h") {
            return .help
        }

        // Compare two images: snapshotsdiff <a> <b> <output>
        if args.count == 3 && !args[0].hasPrefix("-") {
            return .compareTwo(
                imageA: args[0],
                imageB: args[1],
                outputPath: args[2]
            )
        }

        // Parse named arguments
        var artifactsPath: String?
        var outputPath: String?
        var testsPath: String?

        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--artifacts":
                guard i + 1 < args.count else { return .error("Missing value for --artifacts") }
                artifactsPath = args[i + 1]
                i += 2
            case "--output":
                guard i + 1 < args.count else { return .error("Missing value for --output") }
                outputPath = args[i + 1]
                i += 2
            case "--tests":
                guard i + 1 < args.count else { return .error("Missing value for --tests") }
                testsPath = args[i + 1]
                i += 2
            default:
                return .error("Unknown argument: \(arg)")
            }
        }

        guard let artifacts = artifactsPath,
              let output = outputPath,
              let tests = testsPath else {
            return .error("Missing required arguments. Need --artifacts, --output, and --tests")
        }

        return .compareAll(artifactsPath: artifacts, outputPath: output, testsPath: tests)
    }
}
