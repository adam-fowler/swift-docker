import Foundation

enum ShellCommand {
    /// Run shell command without waiting for it to finish
    /// - Parameter args: array of strings representing shell command with args
    static func runNoWait(_ args: [String]) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.launch()
    }

    /// Run shell command and wait for its results
    /// - Parameters:
    ///   - args: array of strings representing shell command with args
    ///   - returnStdOut: Should we return stdout
    @discardableResult static func run(_ args: [String], returnStdOut: Bool) -> (Int32, String?) {
        print(args.joined(separator: " "))
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

    struct Signal: RawRepresentable {
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
    static func trap(signal sig: Signal, handler: @escaping (Signal) -> Void, on queue: DispatchQueue = .global(), cancelAfterTrap: Bool = true) -> DispatchSourceSignal {
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
