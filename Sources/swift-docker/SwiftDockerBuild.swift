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

protocol SwiftDockerBuild {
    var buildOptions: SwiftDockerCommand.BuildOptions { get }
    var operation: BuildOperation { get }
}

extension SwiftDockerBuild {

    /// Run SwiftDocker build
    func runBuild(_ postBuild: ((String?) -> ())? = nil) throws {
        let d = DispatchGroup()
        d.enter()

        var template = try HBMustacheTemplate(string: SwiftDocker.dockerFileTemplate)
        if let template2 = try loadTemplate() {
            template = template2
        }
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
                if let product = self.buildOptions.product {
                    if manifest.products.first(where: { $0.name == product })?.type == .executable {
                        executable = product
                    }
                } else if let target = self.buildOptions.target {
                    if manifest.targets.first(where: { $0.name == target })?.type == .executable {
                        executable = target
                    }
                } else {
                    if self.operation == .run {
                        executable = manifest.products.first(where: { $0.type == .executable })?.name ??
                            manifest.targets.first(where: { $0.type == .executable })?.name
                    }
                }
                var filename: String = ".build/Dockerfile"
                if self.buildOptions.output {
                    filename = "Dockerfile"
                }

                if self.operation == .run && executable == nil {
                    throw SwiftDockerError.runRequiresAnExecutable
                }

                try self.renderDockerfile(template: template, executable: executable, filename: filename)

                // get tag (either commandline option or if executable folder we are running in)
                var tag: String?
                if let tag2 = self.buildOptions.tag {
                    guard let first = tag2.first,
                          validTagStartCharacter.contains(first),
                          tag2.first(where: { !validTagCharacters.contains($0) }) == nil else {
                        throw SwiftDockerError.invalidTagCharacters
                    }
                    tag = tag2
                } else {
                    if executable != nil {
                        let path = FileManager.default.currentDirectoryPath.split(separator: "/")
                        tag = path.last.map({ String($0) })
                        if var tag2 = tag {
                            tag2 = tag2.lowercased()
                            // remove unrecognised characters
                            let chars = tag2.compactMap {
                                return validTagCharacters.contains($0) ? $0 : nil
                           }
                            tag = String(chars)
                        }
                    }
                }
                // only run docker if not outputting Dockerfile
                if self.buildOptions.output == false {
                    let rt = self.buildDocker(tag: tag)
                    // only run postBuild if buildDocker was successful
                    if rt == 0 {
                        postBuild?(tag)
                    }
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
    func loadTemplate(_ name: String = "template") throws -> HBMustacheTemplate? {
        let filename = ".swiftdocker-\(name)"
        let data: Data
        do {
            guard FileManager.default.fileExists(atPath: filename) else { return nil }
            data = try Data(contentsOf: URL(fileURLWithPath: filename))
            print("Using template \(filename)")
        } catch {
            return nil
        }
        let templateString = String(decoding: data, as: Unicode.UTF8.self)
        return try .init(string: templateString)
    }

    /// Render Dockerfile
    /// - Parameters:
    ///   - executable: Name of executable we are building, nil means we are building a library
    ///   - filename: Filename to save to
    func renderDockerfile(template: HBMustacheTemplate, executable: String?, filename: String) throws {
        var options = self.buildOptions.swiftOptions.joined(separator: " ")
        if let product = self.buildOptions.product {
            options = "--product \(product) \(options)"
        } else if let target = self.buildOptions.target {
            options = "--target \(target) \(options)"
        }
        if let configuration = self.buildOptions.configuration {
            options = "-c \(configuration) \(options)"
        }

        var operation = self.operation
        // if we are wanting to run an executable use swift build to build it
        if operation == .run {
            operation = .build
        }
        var context: [String: Any] = [
            "image": self.buildOptions.image,
            "operation": operation,
            "options": options,
            "noSlim": buildOptions.noSlim
        ]
        context["configuration"] = self.buildOptions.configuration
        context["executable"] = executable
        do {
            let dockerfile = template.render(context)
            try dockerfile.write(toFile: filename, atomically: true, encoding: .utf8)
        } catch {
            throw SwiftDockerError.failedToCreateFile(filename)
        }
    }

    /// Run docker build using Dockerfile
    /// - Parameter isExecutable: Are we building an executable
    func buildDocker(tag: String?) -> Int {
        var args = ["docker", "build", "-f", ".build/Dockerfile"]
        if let tag = tag {
            args += ["-t", tag]
        }
        args.append(".")
        return numericCast(ShellCommand.run(args, returnStdOut: false).0)
    }

}

private let validTagStartCharacter: Set<Character> = .init("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".map { $0 })
private let validTagCharacters: Set<Character> = .init("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.".map { $0 })
