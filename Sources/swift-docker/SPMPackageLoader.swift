//
//  SPMPackageLoader.swift
//  
//
//  Created by Adam Fowler on 28/04/2021.
//

import Foundation
import PackageLoading
import PackageModel
import Workspace

struct SPMPackageLoader {

    let resources: UserManifestResources
    let loader: ManifestLoader

    // We will need to know where the Swift compiler is.
    var swiftCompiler: AbsolutePath = {
        let string: String
        #if os(macOS)
        string = try! Process.checkNonZeroExit(args: "xcrun", "--sdk", "macosx", "-f", "swiftc").spm_chomp()
        #else
        string = try! Process.checkNonZeroExit(args: "which", "swiftc").spm_chomp()
        #endif
        return AbsolutePath(string)
    }()

    init() throws {
        self.resources = try UserManifestResources(swiftCompiler: swiftCompiler, swiftCompilerFlags: [])
        self.loader = ManifestLoader(manifestResources: resources)
    }

    func load(
        _ path: String,
        completion: @escaping (Result<Manifest, Error>) -> Void
    ) throws {
        var toolsVersion = try ToolsVersionLoader().load(at: AbsolutePath(path), fileSystem: localFileSystem)
        if toolsVersion < ToolsVersion.minimumRequired {
            print("error: Package version is below minimum, trying minimum")
            toolsVersion = .minimumRequired
        }
        loader.load(
            package: AbsolutePath(path),
            baseURL: path,
            toolsVersion: toolsVersion,
            packageKind: .local,
            fileSystem: localFileSystem,
            on: DispatchQueue.global()
        ) { result in
            completion(result)
        }
    }
}
