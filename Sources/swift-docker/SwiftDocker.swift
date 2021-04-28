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

struct SwiftDocker {
    let command: SwiftDockerOptions
    let template: HBMustacheTemplate

    init(command: SwiftDockerOptions) throws {
        self.command = command
        self.template = try .init(string: Self.dockerfileTemplate)
    }

    @discardableResult
    func shell(_ args: [String], returnStdOut: Bool) -> (Int32, String?) {
        let task = Process()
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

    func writeDockerIgnore() throws {
        let dockerIgnore = ".build/x86_64-apple-macosx"
        try dockerIgnore.write(toFile: ".dockerignore", atomically: true, encoding: .utf8)
    }

    func renderDockerfile(executable: String?, filename: String) throws {
        struct RenderContext {
            let image: String
            let operation: BuildOperation
            let options: String
            let executable: String?
        }
        let context = RenderContext(image: command.options.image, operation: self.command.operation, options: "", executable: executable)
        let dockerfile = self.template.render(context)
        try dockerfile.write(toFile: filename, atomically: true, encoding: .utf8)
    }

    func runDocker() throws {
        var args = ["docker", "build", "-f", ".build/Dockerfile"]
        if let tag = command.options.tag {
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
                if self.command.options.output {
                    filename = "Dockerfile"
                }
                try self.renderDockerfile(executable: executable, filename: filename)
                // only run docker if not outputting Dockerfile
                if self.command.options.output == false {
                    try self.runDocker()
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
    public struct Signal: Equatable, CustomStringConvertible {
        internal var rawValue: CInt

        public static let TERM = Signal(rawValue: SIGTERM)
        public static let INT = Signal(rawValue: SIGINT)
        public static let USR1 = Signal(rawValue: SIGUSR1)
        public static let USR2 = Signal(rawValue: SIGUSR2)
        public static let HUP = Signal(rawValue: SIGHUP)

        // for testing
        internal static let ALRM = Signal(rawValue: SIGALRM)

        public var description: String {
            var result = "Signal("
            switch self {
            case Signal.TERM: result += "TERM, "
            case Signal.INT: result += "INT, "
            case Signal.ALRM: result += "ALRM, "
            case Signal.USR1: result += "USR1, "
            case Signal.USR2: result += "USR2, "
            case Signal.HUP: result += "HUP, "
            default: () // ok to ignore
            }
            result += "rawValue: \(self.rawValue))"
            return result
        }
    }

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
