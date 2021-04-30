import Foundation

extension SwiftDockerCommand.Edit {
    func run() throws {
        try editTemplate()
    }

    /// Create template file if it doesn't exist and open in editor
    /// - Parameter name: name of template
    func editTemplate(_ name: String = "template") throws {
        let filename = ".swiftdocker-\(name)"
        do {
            if !FileManager.default.fileExists(atPath: filename) {
                try SwiftDocker.dockerFileTemplate.write(toFile: filename, atomically: true, encoding: .utf8)
            }
            ShellCommand.runNoWait(["open", filename])
        } catch {
            throw SwiftDockerError.failedToCreateFile(filename)
        }
    }
}
