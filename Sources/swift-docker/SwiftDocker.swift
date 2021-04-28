//
//  File.swift
//  
//
//  Created by Adam Fowler on 27/04/2021.
//
import Foundation
import HummingbirdMustache
import PackageModel

struct SwiftDocker {
    let command: SwiftDockerCommand
    let library: HBMustacheLibrary

    init(command: SwiftDockerCommand) throws {
        self.command = command
        self.library = try .init(directory: Bundle.module.resourcePath!)
    }

    @discardableResult
    func shell(_ args: [String], returnStdOut: Bool) -> (Int32, String?) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        let pipe = Pipe()
        if returnStdOut {
            task.standardOutput = pipe
        }
        task.launch()
        task.waitUntilExit()

        var output: String?
        if returnStdOut {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            output = String(decoding: data, as: Unicode.UTF8.self)
        }
        return (task.terminationStatus, output)

    }

    func renderDockerfile(executable: String?) throws {
        struct RenderContext {
            let image: String
            let options: String
            let executable: String?
        }
        let context = RenderContext(image: command.image, options: "", executable: executable)
        let dockerfile = self.library.render(context, withTemplate: "Dockerfile")
        try dockerfile?.write(toFile: ".build/Dockerfile", atomically: true, encoding: .utf8)
    }

    func runDocker() throws {
        var args = ["docker", "build", "-f", ".build/Dockerfile"]
        if let tag = command.tag {
            args += ["-t", tag]
        } else {
            let path = FileManager.default.currentDirectoryPath.split(separator: "/")
            if let tag = path.last.map({ String($0) }) {
                args += ["-t", tag]
            }
        }
        args.append(".")
        shell(args, returnStdOut: false)
    }

    func run() throws {
        let d = DispatchGroup()
        d.enter()

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
                if manifest.products.first?.type == .executable {
                    executable = manifest.products.first?.name
                }
                try self.renderDockerfile(executable: executable)
                try self.runDocker()
            } catch {
                print("\(error)")
            }

            d.leave()
        }
        d.wait()
    }
}
