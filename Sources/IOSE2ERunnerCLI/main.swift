import Foundation
import IOSE2ERunner

@main
struct IOSE2ERunnerMain {
    static func main() async {
        do {
            let options = try E2ERunnerCLIOptions.parse(CommandLine.arguments)
            if options.help {
                print(e2eRunnerUsage())
                return
            }

            let runtime = E2ERunnerRuntime(processRunner: E2ESystemProcessRunner())
            let output = try await runtime.run(options: options)
            print(output)
        } catch let error as E2ERunnerError {
            print("Error: \(error.description)")
            print("")
            print(e2eRunnerUsage())
            exit(1)
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
