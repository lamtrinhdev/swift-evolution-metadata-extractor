
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

enum FileUtilities {
    
    static func outputURLForPath(_ path: String, defaultFileName: String) -> URL {
        
        var url = expandedAndStandardizedURL(for: path)
        
        // If no path extension, take intent to be a directory and append the default file name
        if url.pathExtension.isEmpty {
            url = url.appending(component: defaultFileName)
        } else {
            // Warn if output path has a different file extension
            let defaultFileExtension = URL(filePath: defaultFileName).pathExtension
            if defaultFileExtension != url.pathExtension {
                print("WARNING: Specified filename '\(url.lastPathComponent)' does not have the expected extension '\(defaultFileExtension)'")
            }
        }
        
        return url
}

    private static func expandTildeInPath(from path: String) -> String {
        // maybe check if tilde appears multiple times?
        return path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
    }

    static func expandedAndStandardizedURL(for path: String) -> URL {
        let fullPath = expandTildeInPath(from: path)
        return URL(filePath: fullPath).standardizedFileURL
    }
    
    static let processDirectory: URL? = {
        if let commandPath = CommandLine.arguments.first {
            let commandURL = URL(filePath: commandPath)
            return commandURL.deletingLastPathComponent()
        }
        return nil
    }()
    
    static func decode<T: Decodable>(_ type: T.Type, from fileURL: URL, required: Bool = false) throws -> T? {
        do { let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let value = try decoder.decode(type, from: data)
            return value
        } catch let error as CocoaError {
            // Missing file is expected on occassion
            if error.code == CocoaError.fileReadNoSuchFile && !required {
                return nil
            }
            else { throw error }
        } catch {
            throw error
        }
    }

}

// A mechanism for adjusting the JSON produced by Codable
// Currently used to:
//   - Pretty print the array of implementation versions
//   - Transform status field to proposed new structure

enum JSONRewriter {
    
    static func applyRewritersToJSONData(rewriters: [(String) -> String], data: Data) -> Data {
        let sourceString = String(decoding: data, as: UTF8.self)
        var rewrittenString = sourceString
        for rewriter in rewriters {
            rewrittenString = rewriter(rewrittenString)
        }
        return Data(rewrittenString.utf8)
    }
    
    // Temporary shim
    static func futureStatusRewriter(_ sourceString: String) -> String {
        var rewrittenString: String = ""
        var processingStatusField = false
        var foundStateField = false
        var savedLines: [Substring] = []
        
        for line in sourceString.split(separator: "\n") {
        
            if line.starts(with:/\s*"status"\s*:\s{/) {
                rewrittenString += line + "\n"
                processingStatusField = true
                continue
            }

            if processingStatusField {
                if line.starts(with:/\s*},/) {
                    processingStatusField = false
                    foundStateField = false
                    savedLines = []
                    rewrittenString += "        }\n"
                    rewrittenString += line + "\n"
                    continue
                }
                
                if let match = line.firstMatch(of: /(\s*)"state" : "\.(.*)"/) {
                    rewrittenString += "\(match.1)\"\(match.2)\" : {\n"
                    let lastIndex = savedLines.count - 1
                    for (index, savedLine) in savedLines.enumerated() {
                        var processedLine = savedLine
                        if index == lastIndex {
                            processedLine = processedLine.replacing(",", with: "")
                        }
                        rewrittenString += "  " + processedLine + "\n"
                    }
                    foundStateField = true
                } else {
                    if foundStateField {
                        rewrittenString += "  " + line + "\n"
                    } else {
                        savedLines.append(line)
                    }
                }
            }
            else {
                rewrittenString += line + "\n"
            }
        }
        return rewrittenString
    }
    
    static func prettyPrintVersions(_ sourceString: String) -> String {
                
        var processedString = ""
        var processingVersionsField = false
        
        var itemCount = 0
        let maxPerLine = 10
        for line in sourceString.split(separator: "\n") {
            
            if line.contains(/"implementationVersions" :/) {
                processedString += line + "\n"
                processingVersionsField = true
                continue
            }

            if processingVersionsField {
                if line.contains(/],/) {
                    processedString += "\n" + line + "\n"
                    processingVersionsField = false
                    itemCount = 0
                    continue
                } else {
                    // Use first array item as-is
                    if itemCount == 0 {
                        processedString += line
                    }
                    // When we are at the max per line, put this array element on a new line
                    else if itemCount == maxPerLine {
                        itemCount = 0
                        processedString += "\n" + line
                    }
                    // Other array items on same line separated by a space
                    // The original line already contains the separating comma
                    else {
                        processedString += " " + line.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    itemCount += 1
                }
            } else {
                processedString += line + "\n"
            }
        }
        
        return processedString
    }
}
