//
//  main.swift
//  searchFiles
//
//  Created by Dean Pulsifer on 6/18/24.
//

import ArgumentParser

@main
struct searchFiles: ParsableCommand {
    @Argument var searchPath: String
    
    mutating func run() throws {
            print("searchFiles !!!")
                
        }
}

