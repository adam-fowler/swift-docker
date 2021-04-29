
import ArgumentParser
import Foundation

enum BuildOperation: String, ExpressibleByArgument {
    case build
    case test
    case edit
    case run
}

enum BuildConfiguration: String, ExpressibleByArgument {
    case debug
    case release
}

struct SwiftDockerCommand: ParsableCommand {
    /// Docker image to use as basis for building image
    @Option(name: .shortAndLong, help: "Docker image to use")
    var image: String = "swift:5.4"

    /// Output Dockerfile instead of build it
    @Flag(name: .shortAndLong, help: "Output Dockerfile instead of building image")
    var output: Bool = false

    /// name to tag docker image
    @Option(name: .shortAndLong, help: "Specify repository and tag for generated docker image. Will default to directory name if not specified.")
    var tag: String?

    /// whether to use slim version of swift docker image
    @Flag(name: .shortAndLong, help: "Disable using of slim version of swift docker image for running.")
    var noSlim: Bool = false

    /// build configuration
    @Option(name: .shortAndLong, help: "Build configuration")
    var configuration: BuildConfiguration?

    /// product to build
    @Option(name: .long, help: "Build the specified product")
    var product: String?

    /// target to build
    @Option(name: .long, help: "Build the specified target")
    var target: String?

    /// ports to expose
    @Option(name: .shortAndLong, help: "Publish a container's port(s) to the host")
    var publish: [String]

    /// environment variables to set while running
    @Option(name: .shortAndLong, help: "Set environment variables")
    var env: [String]

    /// build or test
    @Argument var operation: BuildOperation

    /// remaining options are passed through to swift build/test operations
    @Argument var swiftOptions: [String] = []

    func run() throws {
        try SwiftDocker(command: self).run()
    }
}

SwiftDockerCommand.main()
