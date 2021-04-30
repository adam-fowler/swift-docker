//
//  SwiftDocker.swift
//  
//
//  Created by Adam Fowler on 27/04/2021.
//
#if os(macOS)
import Darwin
#else
import Glibc
#endif
import Foundation
import HummingbirdMustache
import PackageModel

class SwiftDocker {
    let command: SwiftDockerCommand
    var template: HBMustacheTemplate

    init(command: SwiftDockerCommand) throws {
        self.command = command
        self.template = try .init(string: Self.dockerfileTemplate)
    }

    /// Run SwiftDocker
    func run() throws {
        let d = DispatchGroup()
        d.enter()

        if command.operation == .edit {
            try editTemplate()
            return
        }

        try loadTemplate()
        try createBuildFolder()
        try writeDockerIgnore()

        try SPMPackageLoader().load(FileManager.default.currentDirectoryPath) { result in
            do {
                let manifest: Manifest
                switch result {
                case .failure(let error):
                    throw error
                case .success(let m):
                    manifest = m
                }
                var executable: String? = nil
                // are we building an executable or library
                if let product = self.command.product {
                    if manifest.products.first(where: { $0.name == product })?.type == .executable {
                        executable = product
                    }
                } else if let target = self.command.target {
                    if manifest.targets.first(where: { $0.name == target })?.type == .executable {
                        executable = target
                    }
                } else if manifest.products.first?.type == .executable {
                    executable = manifest.products.first?.name
                }
                var filename: String = ".build/Dockerfile"
                if self.command.output {
                    filename = "Dockerfile"
                }

                if self.command.operation == .run && executable == nil {
                    throw SwiftDockerError.runRequiresAnExecutable
                }

                try self.renderDockerfile(executable: executable, filename: filename)

                // get tag (either commandline option or if executable folder we are running in)
                var tag: String?
                if let tag2 = self.command.tag {
                    tag = tag2
                } else {
                    if executable != nil {
                        let path = FileManager.default.currentDirectoryPath.split(separator: "/")
                        tag = path.last.map({ String($0) })
                    }
                }

                // only run docker if not outputting Dockerfile
                if self.command.output == false {
                    self.buildDocker(tag: tag)
                }

                if self.command.operation == .run, let tag = tag {
                    self.runDocker(tag: tag)
                }
            } catch {
                print("\(error)")
            }

            d.leave()
        }
        d.wait()
    }

    /// Create .build folder
    func createBuildFolder() throws {
        do {
            if !FileManager.default.fileExists(atPath: ".build") {
                try FileManager.default.createDirectory(atPath: ".build", withIntermediateDirectories: true)
            }
        } catch {
            throw SwiftDockerError.failedToCreateFolder(".build")
        }
    }

    /// Create .dockerignore file
    func writeDockerIgnore() throws {
        do {
            guard !FileManager.default.fileExists(atPath: ".dockerignore") else { return }
            let dockerIgnore = """
                .build
                .git
                """
            try dockerIgnore.write(toFile: ".dockerignore", atomically: true, encoding: .utf8)
        } catch {
            throw SwiftDockerError.failedToCreateFile(".dockerignore")
        }
    }

    /// Load template file
    /// - Parameter name: template name
    func loadTemplate(_ name: String = "template") throws {
        let filename = ".swiftdocker-\(name)"
        let data: Data
        do {
            guard FileManager.default.fileExists(atPath: filename) else { return }
            data = try Data(contentsOf: URL(fileURLWithPath: filename))
            print("Using template \(filename)")
        } catch {
            return
        }
        let templateString = String(decoding: data, as: Unicode.UTF8.self)
        self.template = try .init(string: templateString)
    }

    /// Create template file if it doesn't exist and open in editor
    /// - Parameter name: name of template
    func editTemplate(_ name: String = "template") throws {
        let filename = ".swiftdocker-\(name)"
        do {
            if !FileManager.default.fileExists(atPath: filename) {
                try Self.dockerfileTemplate.write(toFile: filename, atomically: true, encoding: .utf8)
            }
            ShellCommand.runNoWait(["open", filename])
        } catch {
            throw SwiftDockerError.failedToCreateFile(filename)
        }
    }

    /// Render Dockerfile
    /// - Parameters:
    ///   - executable: Name of executable we are building, nil means we are building a library
    ///   - filename: Filename to save to
    func renderDockerfile(executable: String?, filename: String) throws {
        struct RenderContext {
            let image: String
            let operation: BuildOperation
            let options: String?
            let configuration: BuildConfiguration?
            let executable: String?
            let noSlim: Bool
        }
        var options = command.swiftOptions.joined(separator: " ")
        if let product = self.command.product {
            options = "--product \(product) \(options)"
        } else if let target = self.command.target {
            options = "--target \(target) \(options)"
        }
        if let configuration = self.command.configuration {
            options = "-c \(configuration) \(options)"
        }

        var operation = self.command.operation
        // if we are wanting to run an executable use swift build to build it
        if operation == .run {
            operation = .build
        }
        let context = RenderContext(
            image: command.image,
            operation: operation,
            options: options,
            configuration: self.command.configuration,
            executable: executable,
            noSlim: command.noSlim
        )
        do {
            let dockerfile = self.template.render(context)
            try dockerfile.write(toFile: filename, atomically: true, encoding: .utf8)
        } catch {
            throw SwiftDockerError.failedToCreateFile(filename)
        }
    }

    /// Run docker build using Dockerfile
    /// - Parameter isExecutable: Are we building an executable
    func buildDocker(tag: String?) {
        var args = ["docker", "build", "-f", ".build/Dockerfile"]
        if let tag = tag {
            args += ["-t", tag]
        }
        args.append(".")
        ShellCommand.run(args, returnStdOut: false)
    }

    /// Run docker run
    /// - Parameter isExecutable: Are we building an executable
    func runDocker(tag: String) {
        var args = ["docker", "run"]
        for p in self.command.publish {
            args += ["-p", p]
        }
        for e in self.command.env {
            args += ["-e", e]
        }
        args.append(tag)
        ShellCommand.run(args, returnStdOut: false)
    }
}
