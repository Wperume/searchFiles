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
    @Argument (help: "path to search")
    var searchPath: String?
    
    mutating func run() async throws {
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
                        print("File to search: \(fileURL.path()) with size \(fileSize) before addTask")
                        taskgroup.addTask  {
                            let filePath = fileURL.path()
                                print("  Before searchLineByLine()")
                                let foundString = try await searchLineByLine(from: fileURL, with: "small")
                                print("  After searchLineByLine() await")
                                if foundString {
                                    print("  File \(fileURL.standardizedFileURL) contains search string")
                                }
                                print("  After checking foundString result")
                            return (filePath, foundString)
                        }
                        print("after task, but inside for loop for file enumerator")
                    }
                }
                // return results from TaskGroup here
                print("Gather child task results to return via TaskGroup")
                var childTaskResults = [String: Bool]()
                for try await result in taskgroup {
                    childTaskResults[result.0] = result.1
                }
                return childTaskResults
            }
            print("after for loop for file enumerator")
            // Iterate through found results
            print("Search Results:")
            results.forEach { print($0) }
        } else {
            print("**** File Enumerator was nil !!!")
        }
    }
    
}

func searchLineByLine(from fileUrl: URL, with searchString: String) async throws -> Bool {
    print("    Entering searchLineByLine with \(fileUrl.standardizedFileURL) for string \(searchString)")
    var found: Bool = false
    do {
        print("    inside do catch for searchLineByLine")
        let handle = try FileHandle(forReadingFrom: fileUrl)
        print("    After getting handle for \(fileUrl.standardizedFileURL)")
        for try await line in handle.bytes.lines {
            print("    processing: \(line)")
            if line.contains(searchString) {
                found = true
                break
            }
        }
        try handle.close()
    } catch {
        print("*** searchLineByLine getting file handle error \(error)")
    }
    print("    Exiting searchLineByLine with result \(found)")
    return found
}
