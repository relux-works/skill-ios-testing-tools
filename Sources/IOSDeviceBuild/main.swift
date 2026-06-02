import Foundation

struct DiscoveryInterface: OptionSet, Hashable, CustomStringConvertible {
    let rawValue: Int

    static let usb = Self(rawValue: 1 << 0)
    static let wifi = Self(rawValue: 1 << 1)

    static func parse(_ rawValue: String) throws -> Self {
        var interfaces: Self = []
        for part in rawValue.split(separator: ",") {
            switch part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "usb", "cable", "wired":
                interfaces.insert(.usb)
            case "wifi", "wi-fi", "wireless", "network":
                interfaces.insert(.wifi)
            case "":
                continue
            case let unknown:
                throw CLIError.invalidArguments(
                    "Unsupported --discovery value '\(unknown)'. Use 'usb', 'wifi', or 'usb,wifi'."
                )
            }
        }

        guard interfaces.isEmpty == false else {
            throw CLIError.invalidArguments("Pass at least one --discovery value.")
        }
        return interfaces
    }

    static func fromDeviceInterface(_ value: String?) -> Self? {
        switch value?.lowercased() {
        case "usb":
            return .usb
        case "wifi", "wi-fi", "wireless", "network":
            return .wifi
        default:
            return nil
        }
    }

    var description: String {
        var parts: [String] = []
        if contains(.usb) {
            parts.append("usb")
        }
        if contains(.wifi) {
            parts.append("wifi")
        }
        return parts.joined(separator: ",")
    }
}

enum BuildTarget: String, CaseIterable {
    case iphones
    case macbook

    static func parse(_ rawValue: String) throws -> Set<Self> {
        var targets: Set<Self> = []
        for part in rawValue.split(separator: ",") {
            switch part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "iphone", "iphones", "ios", "devices":
                targets.insert(.iphones)
            case "macbook", "mac", "designed-for-ipad", "designed-for-iphone":
                targets.insert(.macbook)
            case "":
                continue
            case let unknown:
                throw CLIError.invalidArguments(
                    "Unsupported --targets value '\(unknown)'. Use 'iphones', 'macbook', or 'iphones,macbook'."
                )
            }
        }

        guard targets.isEmpty == false else {
            throw CLIError.invalidArguments("Pass at least one --targets value.")
        }
        return targets
    }
}

struct Options {
    var workspace: String?
    var project: String?
    var scheme: String?
    var configuration: String?
    var discovery: DiscoveryInterface?
    var targets: Set<BuildTarget>?
    var macDestination: String?
    var derivedDataRoot: String?
    var developerDir = ProcessInfo.processInfo.environment["DEVELOPER_DIR"]
        ?? "/Applications/Xcode.app/Contents/Developer"
    var dryRun = false
    var passthroughXcodebuildArguments: [String] = []
}

struct XCDevice: Decodable {
    let name: String
    let identifier: String
    let platform: String?
    let simulator: Bool?
    let available: Bool?
    let interface: String?
    let modelName: String?
    let operatingSystemVersion: String?

    var isPhysicalIOS: Bool {
        platform == "com.apple.platform.iphoneos" && simulator != true
    }

    var isAvailable: Bool {
        available == true
    }

    var isUSB: Bool {
        interface?.lowercased() == "usb"
    }

    var summary: String {
        let model = modelName ?? "unknown model"
        let os = operatingSystemVersion ?? "unknown OS"
        let connection = interface ?? "unknown interface"
        return "\(name) [\(model), \(os), \(connection), \(identifier)]"
    }
}

struct BuildPlan {
    let label: String
    let destination: String
    let pathComponent: String

    var summary: String {
        "\(label) [\(destination)]"
    }
}

struct CommandResult {
    let status: Int32
    let output: String
    let error: String
}

enum CLIError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case commandFailed(String)
    case noDestinations
    case buildFailed([BuildFailure])

    var description: String {
        switch self {
        case .invalidArguments(let message):
            message
        case .commandFailed(let message):
            message
        case .noDestinations:
            "No matching build destinations were found."
        case .buildFailed(let failures):
            failures.map { "Build failed for \($0.plan.summary). Log: \($0.logPath)" }
                .joined(separator: "\n")
        }
    }
}

struct BuildFailure {
    let plan: BuildPlan
    let logPath: String
}

func printUsage() {
    print("""
    ios-device-build - Build an iOS app for connected physical devices.

    Usage:
      ios-device-build --workspace App.xcworkspace --scheme App --discovery usb --targets iphones --derived-data-root .temp/device-builds [options] [-- <xcodebuild args>]
      ios-device-build --project App.xcodeproj --scheme App --discovery usb --targets iphones --derived-data-root .temp/device-builds [options] [-- <xcodebuild args>]

    Options:
      --workspace <path>          Required unless --project is used. Xcode workspace path.
      --project <path>            Required unless --workspace is used. Xcode project path.
      --scheme <name>             Required. Scheme to build.
      --configuration <name>      Optional Xcode configuration.
      --discovery <usb|wifi>      Required when --targets includes iphones. Physical iOS discovery
                                  interfaces. Use comma-separated values, for example usb,wifi.
      --targets <value>           Required. Build target set: iphones, macbook, or iphones,macbook.
      --mac-destination <spec>    Required when --targets includes macbook. Destination for iOS app
                                  on Apple Silicon Mac.
      --derived-data-root <path>  Required. Root for per-device DerivedData and logs.
      --developer-dir <path>      Xcode developer dir. Default: DEVELOPER_DIR or /Applications/Xcode.app/Contents/Developer.
      --dry-run                   Print discovered devices and planned builds without running xcodebuild.
      --help                      Show this help.

    Examples:
      ios-device-build --workspace Tap2CashDemo.xcworkspace --scheme Tap2CashDemo --discovery usb --targets iphones --derived-data-root .temp/device-builds
      ios-device-build --project App.xcodeproj --scheme App --discovery usb,wifi --targets iphones --derived-data-root .temp/device-builds
      ios-device-build --workspace Tap2CashDemo.xcworkspace --scheme Tap2CashDemo --discovery usb --targets iphones,macbook --mac-destination 'platform=macOS,arch=arm64,variant=Designed for iPad' --derived-data-root .temp/device-builds
      ios-device-build --workspace Tap2CashDemo.xcworkspace --scheme Tap2CashDemo --targets macbook --mac-destination 'platform=macOS,arch=arm64,variant=Designed for iPad' --derived-data-root .temp/device-builds
    """)
}

func parseOptions(_ arguments: [String]) throws -> Options {
    var options = Options()
    var index = 1

    func requireValue(for flag: String) throws -> String {
        guard index + 1 < arguments.count else {
            throw CLIError.invalidArguments("Missing value for \(flag).")
        }
        index += 1
        return arguments[index]
    }

    while index < arguments.count {
        let argument = arguments[index]

        if argument == "--", index == 1 {
            index += 1
            continue
        }

        if argument == "--" {
            options.passthroughXcodebuildArguments = Array(arguments.dropFirst(index + 1))
            break
        }

        switch argument {
        case "--workspace":
            options.workspace = try requireValue(for: argument)
        case "--project":
            options.project = try requireValue(for: argument)
        case "--scheme":
            options.scheme = try requireValue(for: argument)
        case "--configuration":
            options.configuration = try requireValue(for: argument)
        case "--discovery":
            options.discovery = try DiscoveryInterface.parse(try requireValue(for: argument))
        case "--mode":
            _ = try requireValue(for: argument)
            throw CLIError.invalidArguments("--mode is not supported. Use --discovery usb, --discovery wifi, or --discovery usb,wifi.")
        case "--targets":
            options.targets = try BuildTarget.parse(try requireValue(for: argument))
        case "--mac-destination":
            options.macDestination = try requireValue(for: argument)
        case "--derived-data-root":
            options.derivedDataRoot = try requireValue(for: argument)
        case "--developer-dir":
            options.developerDir = try requireValue(for: argument)
        case "--dry-run":
            options.dryRun = true
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            throw CLIError.invalidArguments("Unknown argument: \(argument).")
        }

        index += 1
    }

    if options.workspace == nil && options.project == nil {
        throw CLIError.invalidArguments("Pass either --workspace or --project.")
    }

    if options.workspace != nil && options.project != nil {
        throw CLIError.invalidArguments("Pass only one of --workspace or --project.")
    }

    if options.scheme == nil {
        throw CLIError.invalidArguments("Pass --scheme.")
    }

    guard let targets = options.targets else {
        throw CLIError.invalidArguments("Pass --targets iphones, --targets macbook, or --targets iphones,macbook.")
    }

    guard targets.isEmpty == false else {
        throw CLIError.invalidArguments("Pass at least one --targets value.")
    }

    if targets.contains(.iphones) {
        guard let discovery = options.discovery else {
            throw CLIError.invalidArguments("Pass --discovery usb, --discovery wifi, or --discovery usb,wifi when --targets includes iphones.")
        }

        guard discovery.isEmpty == false else {
            throw CLIError.invalidArguments("Pass at least one --discovery value.")
        }
    }

    if targets.contains(.macbook), options.macDestination == nil {
        throw CLIError.invalidArguments("Pass --mac-destination when --targets includes macbook.")
    }

    if options.derivedDataRoot == nil {
        throw CLIError.invalidArguments("Pass --derived-data-root.")
    }

    return options
}

func runCommand(
    executable: String,
    arguments: [String],
    environment: [String: String],
    currentDirectoryPath: String? = nil
) throws -> CommandResult {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = arguments
    task.environment = environment
    if let currentDirectoryPath {
        task.currentDirectoryURL = URL(fileURLWithPath: currentDirectoryPath)
    }

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    task.standardOutput = outputPipe
    task.standardError = errorPipe

    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        throw CLIError.commandFailed("Failed to run \(executable): \(error.localizedDescription)")
    }

    return CommandResult(
        status: task.terminationStatus,
        output: String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
        error: String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    )
}

func discoverDevices(options: Options) throws -> [XCDevice] {
    var environment = ProcessInfo.processInfo.environment
    environment["DEVELOPER_DIR"] = options.developerDir

    let result = try runCommand(
        executable: "/usr/bin/xcrun",
        arguments: ["xcdevice", "list", "--json"],
        environment: environment
    )

    guard result.status == 0 else {
        throw CLIError.commandFailed(
            """
            xcrun xcdevice list --json failed with exit code \(result.status).
            stdout:
            \(result.output)
            stderr:
            \(result.error)
            """
        )
    }

    let data = Data(result.output.utf8)
    let devices = try JSONDecoder().decode([XCDevice].self, from: data)

    return devices.filter { device in
        guard device.isPhysicalIOS, device.isAvailable else { return false }

        guard let interface = DiscoveryInterface.fromDeviceInterface(device.interface) else { return false }
        return options.discovery?.contains(interface) == true
    }
}

func xcodebuildProjectArguments(options: Options) -> [String] {
    var arguments: [String] = []

    if let workspace = options.workspace {
        arguments += ["-workspace", workspace]
    }

    if let project = options.project {
        arguments += ["-project", project]
    }

    if let scheme = options.scheme {
        arguments += ["-scheme", scheme]
    }

    return arguments
}

func supportsMacDestination(options: Options) throws -> Bool {
    var environment = ProcessInfo.processInfo.environment
    environment["DEVELOPER_DIR"] = options.developerDir

    let result = try runCommand(
        executable: "/usr/bin/xcrun",
        arguments: ["xcodebuild"] + xcodebuildProjectArguments(options: options) + ["-showdestinations"],
        environment: environment
    )

    guard result.status == 0 else {
        return false
    }

    let searchableOutput = result.output + "\n" + result.error
    return searchableOutput.contains("platform:macOS")
        && searchableOutput.contains("variant:Designed for")
        && searchableOutput.contains("arch:arm64")
}

func buildPlans(options: Options) throws -> [BuildPlan] {
    var plans: [BuildPlan] = []

    if options.targets?.contains(.iphones) == true {
        let devices = try discoverDevices(options: options)
        plans += devices.map {
            BuildPlan(
                label: $0.summary,
                destination: "id=\($0.identifier)",
                pathComponent: sanitizedPathComponent("\($0.name)-\($0.identifier)")
            )
        }
    }

    if options.targets?.contains(.macbook) == true, try supportsMacDestination(options: options) {
        guard let macDestination = options.macDestination else {
            throw CLIError.invalidArguments("Pass --mac-destination when --targets includes macbook.")
        }

        plans.append(
            BuildPlan(
                label: "Apple Silicon Mac (Designed for iPad/iPhone)",
                destination: macDestination,
                pathComponent: "Apple-Silicon-Mac-Designed-for-iPad"
            )
        )
    }

    return plans
}

func absolutePath(_ path: String) -> String {
    if path.hasPrefix("/") {
        return path
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(path)
        .standardized
        .path
}

func sanitizedPathComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    return String(value.unicodeScalars.map { scalar in
        allowed.contains(scalar) ? Character(scalar) : "-"
    })
}

func buildArguments(options: Options, plan: BuildPlan, derivedDataPath: String) -> [String] {
    var arguments = xcodebuildProjectArguments(options: options)

    if let configuration = options.configuration {
        arguments += ["-configuration", configuration]
    }

    arguments += [
        "-destination", plan.destination,
        "-derivedDataPath", derivedDataPath,
    ]

    arguments += options.passthroughXcodebuildArguments
    arguments += ["build"]
    return arguments
}

func runBuild(options: Options, plan: BuildPlan, runRoot: String) throws -> BuildFailure? {
    let deviceRoot = URL(fileURLWithPath: runRoot).appendingPathComponent(plan.pathComponent).path
    let derivedDataPath = URL(fileURLWithPath: deviceRoot).appendingPathComponent("DerivedData").path
    let logPath = URL(fileURLWithPath: deviceRoot).appendingPathComponent("xcodebuild.log").path
    try FileManager.default.createDirectory(atPath: deviceRoot, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: logPath, contents: nil)

    let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
    defer {
        try? fileHandle.close()
    }

    var environment = ProcessInfo.processInfo.environment
    environment["DEVELOPER_DIR"] = options.developerDir

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    task.arguments = ["xcodebuild"] + buildArguments(options: options, plan: plan, derivedDataPath: derivedDataPath)
    task.environment = environment
    task.standardOutput = fileHandle
    task.standardError = fileHandle

    print("==> Building \(plan.summary)")
    print("    Log: \(logPath)")

    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        try? "Failed to run xcodebuild: \(error.localizedDescription)\n".write(
            toFile: logPath,
            atomically: false,
            encoding: .utf8
        )
        return BuildFailure(plan: plan, logPath: logPath)
    }

    guard task.terminationStatus == 0 else {
        printTail(logPath: logPath)
        return BuildFailure(plan: plan, logPath: logPath)
    }

    print("    Build succeeded")
    return nil
}

func printTail(logPath: String, maxLines: Int = 80) {
    guard let content = try? String(contentsOfFile: logPath, encoding: .utf8) else {
        return
    }

    let lines = content.split(separator: "\n", omittingEmptySubsequences: false).suffix(maxLines)
    print("    Last \(maxLines) log lines:")
    lines.forEach { print("    \($0)") }
}

func main() throws {
    let options = try parseOptions(CommandLine.arguments)
    let plans = try buildPlans(options: options)

    guard plans.isEmpty == false else {
        throw CLIError.noDestinations
    }

    print("Found \(plans.count) build destination(s):")
    plans.forEach { print("  - \($0.summary)") }

    if options.dryRun {
        print("Dry run: no builds were started.")
        return
    }

    guard let derivedDataRoot = options.derivedDataRoot else {
        throw CLIError.invalidArguments("Pass --derived-data-root.")
    }

    let runRoot = absolutePath(derivedDataRoot)
    try FileManager.default.createDirectory(atPath: runRoot, withIntermediateDirectories: true)

    var failures: [BuildFailure] = []
    for plan in plans {
        if let failure = try runBuild(options: options, plan: plan, runRoot: runRoot) {
            failures.append(failure)
        }
    }

    guard failures.isEmpty else {
        throw CLIError.buildFailed(failures)
    }

    print("All device builds succeeded.")
    print("Artifacts: \(runRoot)")
}

do {
    try main()
} catch let error as CLIError {
    print("Error: \(error.description)")
    print("")
    printUsage()
    exit(1)
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
