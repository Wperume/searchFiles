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
        let actualURL = URL.init(fileURLWithPath: NSString(string: actualPath).expandingTildeInPath)
        print("Actual URL is \(actualURL.standardizedFileURL)")
        
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .isRegularFileKey, .fileSizeKey])
        if let file_enumerator = fileManager.enumerator(at: actualURL, includingPropertiesForKeys: Array(resourceKeys),
                                                        options: [.skipsHiddenFiles],
                                                        errorHandler: { (url, error) -> Bool in
                                                            print("directoryEnumerator error at \(url): ", error)
            return true} ) {
            for case let fileURL as URL in file_enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                      let isDirectory = resourceValues.isDirectory,
                      let name = resourceValues.name,
                      let isRegularFile = resourceValues.isRegularFile,
                      let fileSize = resourceValues.fileSize
                else {
                    continue
                }
                // determine which type of URL we are accessing
                if isDirectory {
                    if name == "_extras" {
                        file_enumerator.skipDescendants()
                    }
                } else if isRegularFile {
                    print("File to search: \(fileURL.path()) with size \(fileSize)")
                }
            }
        } else {
            print("**** File Enumerator was nil !!!")
        }
    }
    
}

