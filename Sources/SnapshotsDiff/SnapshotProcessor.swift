import Foundation

public final class SnapshotProcessor {
    public struct Config {
        let snapshotArtifactsPath: String
        let outputDiffDirectory: String
        let snapshotTestsPath: String

        public init(snapshotArtifactsPath: String, outputDiffDirectory: String, snapshotTestsPath: String) {
            self.snapshotArtifactsPath = snapshotArtifactsPath
            self.outputDiffDirectory = outputDiffDirectory
            self.snapshotTestsPath = snapshotTestsPath
        }
    }

    private let fileManager = FileManager.default
    private let config: Config

    public init(config: Config) {
        self.config = config
    }

    public func processAllSnapshots() {
        print("Processing snapshots...")
        print("  Artifacts: \(config.snapshotArtifactsPath)")
        print("  Output: \(config.outputDiffDirectory)")
        print("  Tests: \(config.snapshotTestsPath)")

        guard fileManager.fileExists(atPath: config.snapshotArtifactsPath) else {
            print("Error: Artifacts not found at \(config.snapshotArtifactsPath)")
            exit(1)
        }

        prepareOutputDirectory()

        guard let enumerator = fileManager.enumerator(atPath: config.snapshotArtifactsPath) else {
            print("Error: Cannot enumerate artifacts directory")
            exit(1)
        }

        var processed = 0
        var failed = 0

        for case let file as String in enumerator {
            guard file.hasSuffix(".png") else { continue }

            let failedImagePath = "\(config.snapshotArtifactsPath)/\(file)"
            print("\nProcessing: \(file)")

            if let referencePath = findReferenceImage(for: file) {
                print("  Reference: \(referencePath)")
                do {
                    try processSnapshot(failedPath: failedImagePath, referencePath: referencePath, fileName: file)
                    processed += 1
                    print("  Done")
                } catch {
                    print("  Error: \(error.localizedDescription)")
                    failed += 1
                }
            } else {
                print("  Warning: Reference not found")
                failed += 1
            }
        }

        print("\n--- Summary ---")
        print("Processed: \(processed)")
        print("Failed: \(failed)")
        if processed > 0 {
            print("Output: \(config.outputDiffDirectory)")
        }
    }

    // MARK: - Private

    private func prepareOutputDirectory() {
        do {
            if fileManager.fileExists(atPath: config.outputDiffDirectory) {
                try fileManager.removeItem(atPath: config.outputDiffDirectory)
            }
            try fileManager.createDirectory(
                atPath: config.outputDiffDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            print("Error: Cannot create output directory: \(error)")
            exit(1)
        }
    }

    private func findReferenceImage(for failedFilePath: String) -> String? {
        let fileName = (failedFilePath as NSString).lastPathComponent
        let baseName = (fileName as NSString).deletingPathExtension
        // Remove trailing .N suffix (e.g., "MySnapshot.1" -> "MySnapshot")
        let cleanName = baseName.replacingOccurrences(of: "\\.\\d+$", with: "", options: .regularExpression)

        guard let testsEnumerator = fileManager.enumerator(atPath: config.snapshotTestsPath) else {
            return nil
        }

        // Find all __Snapshots__ folders
        var snapshotsFolders: [String] = []
        for case let file as String in testsEnumerator {
            if file.contains("__Snapshots__") && !file.contains(".DS_Store") {
                snapshotsFolders.append(file)
            }
        }

        // Search for matching reference
        for snapshotsFolder in snapshotsFolders {
            let fullSnapshotsPath = "\(config.snapshotTestsPath)/\(snapshotsFolder)"

            guard let snapshotsEnumerator = fileManager.enumerator(atPath: fullSnapshotsPath) else {
                continue
            }

            for case let snapshotFile as String in snapshotsEnumerator {
                guard snapshotFile.hasSuffix(".png") else { continue }

                let snapshotFileName = (snapshotFile as NSString).lastPathComponent
                let snapshotBaseName = (snapshotFileName as NSString).deletingPathExtension

                if snapshotBaseName.contains(cleanName) || cleanName.contains(snapshotBaseName) {
                    let referencePath = "\(fullSnapshotsPath)/\(snapshotFile)"
                    if fileManager.fileExists(atPath: referencePath) {
                        return referencePath
                    }
                }
            }
        }

        return nil
    }

    private func processSnapshot(failedPath: String, referencePath: String, fileName: String) throws {
        let testPath = (fileName as NSString).deletingLastPathComponent
        let testName = (testPath as NSString).lastPathComponent
        let snapshotName = ((fileName as NSString).lastPathComponent as NSString).deletingPathExtension

        let safeTestName = testName.replacingOccurrences(of: "+", with: "_")
        let safeSnapshotName = snapshotName.replacingOccurrences(of: ".", with: "_")

        let outputDir = "\(config.outputDiffDirectory)/\(safeTestName)/\(safeSnapshotName)"

        if fileManager.fileExists(atPath: outputDir) {
            try fileManager.removeItem(atPath: outputDir)
        }
        try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let failedCopyPath = "\(outputDir)/failed.png"
        let referenceCopyPath = "\(outputDir)/reference.png"
        let diffPath = "\(outputDir)/diff.png"

        try fileManager.copyItem(atPath: failedPath, toPath: failedCopyPath)
        try fileManager.copyItem(atPath: referencePath, toPath: referenceCopyPath)

        try ImageDiffTool.createDiff(imageA: referenceCopyPath, imageB: failedCopyPath, outputPath: diffPath)
    }
}
