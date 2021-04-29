//
//  File.swift
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

    func shellNoWait(_ args: [String]) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.launch()
    }

    @discardableResult
    func shell(_ args: [String], returnStdOut: Bool) -> (Int32, String?) {
        let task = Process()
        // trap signal so they can be passed onto shell command
        let intSignal = trap(signal: .INT) { _ in
            task.interrupt()
        }
        let termSignal = trap(signal: .TERM) { _ in
            task.terminate()
        }
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        let pipe = Pipe()
        if returnStdOut {
            task.standardOutput = pipe
        }
        task.launch()
        task.waitUntilExit()

        intSignal.cancel()
        termSignal.cancel()

        var output: String?
        if returnStdOut {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            output = String(decoding: data, as: Unicode.UTF8.self)
        }
        return (task.terminationStatus, output)
    }

    func createBuildFolder() throws {
        if !FileManager.default.fileExists(atPath: ".build") {
            try FileManager.default.createDirectory(atPath: ".build", withIntermediateDirectories: true)
        }
    }

    func writeDockerIgnore() throws {
        guard !FileManager.default.fileExists(atPath: ".dockerignore") else { return }
        let dockerIgnore = """
            .build/x86_64-apple-macosx
            .build/release
            .build/debug
            """
        try dockerIgnore.write(toFile: ".dockerignore", atomically: true, encoding: .utf8)
    }

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

    func editTemplate(_ name: String = "template") throws {
        let filename = ".swiftdocker-\(name)"
        guard !FileManager.default.fileExists(atPath: filename) else { return }
        try Self.dockerfileTemplate.write(toFile: filename, atomically: true, encoding: .utf8)
        shellNoWait(["open", filename])
    }

    func renderDockerfile(executable: String?, filename: String) throws {
        struct RenderContext {
            let image: String
            let operation: BuildOperation
            let options: String?
            let executable: String?
            let noSlim: Bool
        }
        let context = RenderContext(
            image: command.image,
            operation: self.command.operation,
            options: command.swiftOptions.joined(separator: " "),
            executable: executable,
            noSlim: command.noSlim
        )
        let dockerfile = self.template.render(context)
        try dockerfile.write(toFile: filename, atomically: true, encoding: .utf8)
    }

    func runDocker(isExecutable: Bool) throws {
        var args = ["docker", "build", "-f", ".build/Dockerfile"]
        if let tag = command.tag {
            args += ["-t", tag]
        } else {
            // if isExecutable automatically tag the image with the folder name
            if isExecutable {
                let path = FileManager.default.currentDirectoryPath.split(separator: "/")
                if let tag = path.last.map({ String($0) }) {
                    args += ["-t", tag]
                }
            }
        }
        args.append(".")
        shell(args, returnStdOut: false)
    }

    /// Run SwiftDocker
    func run() throws {
        let d = DispatchGroup()
        d.enter()

        try loadTemplate()

        if command.operation == .edit {
            try editTemplate()
            return
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
                if manifest.products.first?.type == .executable {
                    executable = manifest.products.first?.name
                }
                var filename: String = ".build/Dockerfile"
                if self.command.output {
                    filename = "Dockerfile"
                }
                try self.renderDockerfile(executable: executable, filename: filename)
                // only run docker if not outputting Dockerfile
                if self.command.output == false {
                    try self.runDocker(isExecutable: executable != nil)
                }
            } catch {
                print("\(error)")
            }

            d.leave()
        }
        d.wait()
    }
}

extension SwiftDocker {
    public struct Signal: Equatable {
        internal var rawValue: CInt

        public static let TERM = Signal(rawValue: SIGTERM)
        public static let INT = Signal(rawValue: SIGINT)
        public static let USR1 = Signal(rawValue: SIGUSR1)
        public static let USR2 = Signal(rawValue: SIGUSR2)
        public static let HUP = Signal(rawValue: SIGHUP)

        // for testing
        internal static let ALRM = Signal(rawValue: SIGALRM)
    }

    /// setup handlers for signals
    func trap(signal sig: Signal, handler: @escaping (Signal) -> Void, on queue: DispatchQueue = .global(), cancelAfterTrap: Bool = true) -> DispatchSourceSignal {
        let signalSource = DispatchSource.makeSignalSource(signal: sig.rawValue, queue: queue)
        signal(sig.rawValue, SIG_IGN)
        signalSource.setEventHandler(handler: {
            if cancelAfterTrap {
                signalSource.cancel()
            }
            handler(sig)
        })
        signalSource.resume()
        return signalSource
    }
}
