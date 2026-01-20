import Foundation

func printUsage() {
    print("""
    snapshotsdiff - Create visual diffs between snapshot images

    USAGE:
        snapshotsdiff                                                       Compare all (default paths)
        snapshotsdiff --artifacts <path> --output <path> --tests <path>     Compare all (custom paths)
        snapshotsdiff <image-a> <image-b> <output-path>                     Compare two images

    OPTIONS:
        --artifacts <path>    Path to snapshot artifacts (failed snapshots)
        --output <path>       Output directory for diffs
        --tests <path>        Path to snapshot tests (reference images in __Snapshots__ folders)
        --help                Show this help

    EXAMPLES:
        snapshotsdiff
        snapshotsdiff --artifacts ./SnapshotArtifacts --output ./SnapshotDiffs --tests ./AppSnapshotTests
        snapshotsdiff before.png after.png diff.png

    OUTPUT:
        For batch mode, creates for each failed snapshot:
          <output>/<test>/<snapshot>/
            ├── reference.png   (expected)
            ├── failed.png      (actual)
            └── diff.png        (visual diff)

        Diff visualization:
          - Different pixels: highlighted (boosted color)
          - Same pixels: dimmed gray with transparency

        Color comparison uses squared Euclidean distance in RGBA space:
          distance² = (r1-r2)² + (g1-g2)² + (b1-b2)² + (a1-a2)²
          Default threshold: 1600 (≈ perceptual distance of 40)
    """)
}

let mode = Args.parse(CommandLine.arguments)

switch mode {
case .compareAll(let artifactsPath, let outputPath, let testsPath):
    let config = SnapshotProcessor.Config(
        snapshotArtifactsPath: artifactsPath,
        outputDiffDirectory: outputPath,
        snapshotTestsPath: testsPath
    )
    let processor = SnapshotProcessor(config: config)
    processor.processAllSnapshots()

case .compareTwo(let imageA, let imageB, let outputPath):
    do {
        try ImageDiffTool.createDiff(imageA: imageA, imageB: imageB, outputPath: outputPath)
        print("Diff created: \(outputPath)")
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }

case .help:
    printUsage()
    exit(0)

case .error(let message):
    print("Error: \(message)\n")
    printUsage()
    exit(1)
}
