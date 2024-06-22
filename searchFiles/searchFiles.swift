//
//  main.swift
//  searchFiles
//
//  Created by Dean Pulsifer on 6/18/24.
//

import Foundation
import ArgumentParser

@main
struct searchFiles: AsyncParsableCommand {
    @Argument (help: "Arguments combined for search string")
        var searchStrings: [String] = []
    @Option (name: .shortAndLong, help: "path to search")
    var path: String?
    
    mutating func run() async throws {
        let fileManager = FileManager.default
        let pwd = fileManager.currentDirectoryPath
        print("The current path is \(pwd)")
        
        var actualPath: String = pwd
        if let argString = path {
            print("Path argument is \(argString)")
            actualPath = argString
        }
        let actualURL = URL.init(fileURLWithPath: NSString(string: actualPath).expandingTildeInPath)
        print("Actual URL is \(actualURL.standardizedFileURL)")
        
        // gather arguments to build search string
        let searchString = searchStrings.joined(separator: " ")
        if searchStrings.isEmpty {
            print("No search string provided!!!")
            return
        }
        
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .isRegularFileKey, .fileSizeKey])
        if let file_enumerator = fileManager.enumerator(at: actualURL, includingPropertiesForKeys: Array(resourceKeys),
                                                        options: [.skipsHiddenFiles],
                                                        errorHandler: { (url, error) -> Bool in
            print("File enumerator error at \(url): ", error)
            return true} ) {
            // try using a TaskGroup
            let results = try await withThrowingTaskGroup(of: (String, Bool).self, returning: [String: Bool].self) { taskgroup in
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
//                        print("File to search: \(fileURL.path()) with size \(fileSize) before addTask")
                        taskgroup.addTask  {
                            let filePath = fileURL.path()
                                let foundString = try await searchLineByLine(from: fileURL, with: searchString)
//                                if foundString {
//                                    print("  File \(fileURL.standardizedFileURL) contains search string")
//                                }
                            return (filePath, foundString)
                        }
                    }
                }
                // return results from TaskGroup here
                var childTaskResults = [String: Bool]()
                for try await result in taskgroup {
                    childTaskResults[result.0] = result.1
                }
                return childTaskResults
            }
            // Iterate through found results
            print("Files containing '\(searchString)' in \(actualPath):")
            results.filter({$0.value == true}).forEach { print($0.key) }
//            results.forEach { print($0) }
        } else {
            print("**** File Enumerator was nil !!!")
        }
    }
    
}

func searchLineByLine(from fileUrl: URL, with searchString: String) async throws -> Bool {
    var found: Bool = false
    do {
        let handle = try FileHandle(forReadingFrom: fileUrl)
        for try await line in handle.bytes.lines {
            if line.contains(searchString) {
                found = true
                break
            }
        }
        try handle.close()
    } catch {
        print("*** searchLineByLine getting file handle error \(error)")
    }
    return found
}
