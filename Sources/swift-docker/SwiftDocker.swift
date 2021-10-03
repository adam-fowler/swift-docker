
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
    static var configuration = CommandConfiguration(
        commandName: "swift-docker",
        subcommands: [Build.self, Test.self, Run.self, Edit.self]
    )

    struct BuildOptions: ParsableArguments {
        /// Docker image to use as basis for building image
        @Option(name: .shortAndLong, help: "Docker image to use")
        var image: String = "swift:5.5"

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

        /// environment variables to set while running
        @Option(name: .shortAndLong, help: "Set environment variables")
        var env: [String] = []

        /// remaining options are passed through to swift build/test operations
        @Argument var swiftOptions: [String] = []
    }

    struct Build: ParsableCommand, SwiftDockerBuild {
        static var configuration = CommandConfiguration(
            abstract: "Build product"
        )

        var operation: BuildOperation { .build }

        @OptionGroup var buildOptions: BuildOptions

        func run() throws {
            try runBuild()
        }
    }

    struct Test: ParsableCommand, SwiftDockerBuild {
        static var configuration = CommandConfiguration(
            abstract: "Test product"
        )

        var operation: BuildOperation { .test }

        @OptionGroup var buildOptions: BuildOptions

        func run() throws {
            try runBuild()
        }
    }

    struct Run: ParsableCommand, SwiftDockerBuild {
        static var configuration = CommandConfiguration(
            abstract: "Build and run product"
        )

        var operation: BuildOperation { .run }

        @OptionGroup var buildOptions: BuildOptions

        /// ports to expose
        @Option(name: .shortAndLong, help: "Publish a container's port(s) to the host")
        var publish: [String] = []

        /// environment variables to set while running
        @Flag(name: .customLong("rm"), help: "Automatically remove the container when it exits")
        var removeOnExit: Bool = false

        func run() throws {
            try runBuild() { tag in
                if let tag = tag {
                    self.runDocker(tag: tag)
                }
            }
        }

    }

    struct Edit: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Edit Dockerfile template"
        )
    }
}

