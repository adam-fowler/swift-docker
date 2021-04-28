
import ArgumentParser
import Foundation

struct SwiftDockerCommand: ParsableCommand {

    @Option(name: .shortAndLong, help: "Docker image to use")
    var image: String = "swift:5.3"

    @Option(name: .shortAndLong, help: "Specify repository and tag")
    var tag: String?

    func run() throws {
        try SwiftDocker(command: self).run()
    }
}

SwiftDockerCommand.main()
