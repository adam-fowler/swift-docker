
import ArgumentParser
import Foundation

enum BuildOperation: String {
    case build
    case test
}

protocol SwiftDockerOptions {
    var options: SwiftDockerCommand.Options { get }
    var operation: BuildOperation { get }
}

struct SwiftDockerCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Build/Test swift inside Docker",
        subcommands: [Build.self, Test.self]
    )

    struct Options: ParsableArguments {
        @Option(name: .shortAndLong, help: "Docker image to use")
        var image: String = "swift:5.3"

        @Flag(name: .shortAndLong, help: "Output Dockerfile instead of building image")
        var output: Bool = false

        @Option(name: .shortAndLong, help: "Specify repository and tag for generated docker image")
        var tag: String?
    }

    struct Build: ParsableCommand, SwiftDockerOptions {
        static var configuration = CommandConfiguration(abstract: "Build docker image")

        @OptionGroup var options: Options

        var operation: BuildOperation { .build }

        func run() throws {
            try SwiftDocker(command: self).run()
        }
    }

    struct Test: ParsableCommand, SwiftDockerOptions {
        static var configuration = CommandConfiguration(abstract: "Test docker image")

        @OptionGroup var options: Options

        var operation: BuildOperation { .test }

        func run() throws {
            try SwiftDocker(command: self).run()
        }
    }

}

SwiftDockerCommand.main()
