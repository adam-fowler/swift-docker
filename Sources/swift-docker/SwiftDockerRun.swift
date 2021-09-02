//
//  File.swift
//  
//
//  Created by Adam Fowler on 30/04/2021.
//

extension SwiftDockerCommand.Run {
    
    /// Run docker run
    /// - Parameter isExecutable: Are we building an executable
    func runDocker(tag: String) {
        var args = ["docker", "run"]
        for p in self.publish {
            args += ["-p", p]
        }
        for e in self.buildOptions.env {
            args += ["-e", e]
        }
        if self.removeOnExit {
            args.append("--rm")
        }
        args.append(tag)
        ShellCommand.run(args, returnStdOut: false)
    }
}
