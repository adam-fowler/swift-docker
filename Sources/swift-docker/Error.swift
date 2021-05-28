//
//  File.swift
//  
//
//  Created by Adam Fowler on 29/04/2021.
//

enum SwiftDockerError: Error {
    case failedToCreateFolder(String)
    case failedToCreateFile(String)
    case runRequiresAnExecutable
    case invalidTagCharacters
}

extension SwiftDockerError: CustomStringConvertible {
    var description: String {
        switch self {
        case .failedToCreateFolder(let folder):
            return "Failed to create \(folder) folder."
        case .failedToCreateFile(let file):
            return "Failed to create \(file) file."
        case .runRequiresAnExecutable:
            return "swift docker run requires an executable."
        case .invalidTagCharacters:
            return "Illegal Docker tag name."
        }
    }
}
