//
//  CSVWriter.swift
//  eegraw
//
//  Created by Elijah R on 2025/1/15.
//

import Foundation

class CSVWriter {
    static let shared = CSVWriter()
    
    private init() {}
    
    func appendToCSV(fileName: String, data: [String]) {
        let fileManager = FileManager.default
        
        // Get the document directory path
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        // Set the file path
        let fileURL = documentDirectory.appendingPathComponent("\(fileName).csv")
        
        // Prepare data to append
        let csvData = data.joined(separator: ",") + "\n"
        
        if !fileManager.fileExists(atPath: fileURL.path) {
            // If file doesn't exist, create it and write the header
            do {
                try csvData.write(to: fileURL, atomically: true, encoding: .utf8)
                print("CSV file created at \(fileURL.path)")
            } catch {
                print("Error creating CSV file: \(error.localizedDescription)")
            }
        } else {
            // Append data to the existing file
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                fileHandle.seekToEndOfFile()
                if let csvData = csvData.data(using: .utf8) {
                    fileHandle.write(csvData)
                }
                fileHandle.closeFile()
            } else {
                print("Failed to open CSV file for appending.")
            }
        }
    }
}
