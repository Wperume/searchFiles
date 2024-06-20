//
//  main.swift
//  searchFiles
//
//  Created by Dean Pulsifer on 6/18/24.
//

import Foundation
import ArgumentParser

@main
struct searchFiles: ParsableCommand {
    @Argument (help: "path to search")
    var searchPath: String?
    
    mutating func run() throws {
        let fileManager = FileManager.default
        let pwd = fileManager.currentDirectoryPath
        print("The current path is \(pwd)")
        
        var actualPath: String = pwd
        if let argString = searchPath {
            print("Path argument is \(argString)")
            actualPath = argString
        }
        print("Actual path to start the search \(actualPath)")
    }
    
}

