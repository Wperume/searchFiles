//
//  searchFiles: Example app for a command line tool using Swift with concurrency
//
//  Created by Dean Pulsifer on 6/18/24.
//

import Foundation
import ArgumentParser

@main
struct searchFiles: AsyncParsableCommand { // use AsyncParsableCommand so that we can use async / await and TaskGroups
    @Argument (help: "Arguments combined for search string")
        var searchStrings: [String] = []
    @Option (name: .shortAndLong, help: "path to search")
    var path: String?
    
    mutating func run() async throws {
        let fileManager = FileManager.default
        let pwd = fileManager.currentDirectoryPath
//        print("The current path is \(pwd)")
        
        var actualPath: String = pwd
        if let argString = path {
            print("Path argument is \(argString)")
            actualPath = argString
        }
        let actualURL = URL.init(fileURLWithPath: NSString(string: actualPath).expandingTildeInPath)
        print("Expanded URL is \(actualURL.standardizedFileURL)")
        
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
            // Use a TaskGroup so that we can run file searches in parallel
            let results = try await withThrowingTaskGroup(of: (String, Bool).self, returning: [String: Bool].self) { taskgroup in
                for case let fileURL as URL in file_enumerator { // enumerate all files underneath search path
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                          let isDirectory = resourceValues.isDirectory,
                          let name = resourceValues.name,
                          let isRegularFile = resourceValues.isRegularFile,
                          let fileSize = resourceValues.fileSize
                    else {
                        continue
                    }
                    // determine which type of file we are accessing
                    if isDirectory {
                        if name == "_extras" {
                            file_enumerator.skipDescendants()
                        }
                    } else if isRegularFile { // only search regular files
//                        print("File to search: \(fileURL.path()) with size \(fileSize) before addTask")
                        taskgroup.addTask  { // add a new task for each file to search
                            let filePath = fileURL.path()
                                let foundString = try await searchLineByLine(from: fileURL, with: searchString)
//                                if foundString {
//                                    print("  File \(fileURL.standardizedFileURL) contains search string")
//                                }
                            return (filePath, foundString)
                        }
                    }
                }
                // aggregate results from TaskGroup here after waiting for child tasks to complete
                var childTaskResults = [String: Bool]()
                for try await result in taskgroup {
                    childTaskResults[result.0] = result.1
                }
                return childTaskResults
            }
            // Iterate through found results
            print("Files containing '\(searchString)' in \(actualPath):")
            results.filter({$0.value == true}).forEach { print($0.key) }
        } else {
            print("**** File Enumerator was nil !!!")
        }
    }
    
}

// search a file for text using asynchronous handle.bytes.lines feature for processing a file without
// reading it entirely into a String first
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
        print("*** searchLineByLine getting file handle error or reading file error: \(error)")
    }
    return found
}
