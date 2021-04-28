
import ArgumentParser
import Foundation

struct SwiftDockerCommand: ParsableCommand {

    @Option(name: .shortAndLong, help: "Docker image to use")
    var image: String = "swift:5.3"

    @Option(name: .shortAndLong, help: "Specify repository and tag for generated docker image")
    var tag: String?

    @Flag(name: .shortAndLong, help: "Output Dockerfile instead of building image")
    var output: Bool = false

    func run() throws {
        try SwiftDocker(command: self).run()
    }
}

SwiftDockerCommand.main()
