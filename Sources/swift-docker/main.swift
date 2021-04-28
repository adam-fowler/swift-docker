
import ArgumentParser
import Foundation

enum BuildOperation: String, ExpressibleByArgument {
    case build
    case test
}

struct SwiftDockerCommand: ParsableCommand {
    @Option(name: .shortAndLong, help: "Docker image to use")
    var image: String = "swift:5.3"

    @Flag(name: .shortAndLong, help: "Output Dockerfile instead of building image")
    var output: Bool = false

    @Option(name: .shortAndLong, help: "Specify repository and tag for generated docker image")
    var tag: String?

    //@Option(name: .shortAndLong, help: "Specify repository and tag for generated docker image")
    //var swiftOptions: String?

    @Argument var operation: BuildOperation

    @Argument var swiftOptions: [String]

    func run() throws {
        try SwiftDocker(command: self).run()
    }
}

SwiftDockerCommand.main()
