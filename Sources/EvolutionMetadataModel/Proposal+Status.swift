
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors

import Foundation

extension Proposal {
    public enum Status: Equatable, Sendable, Comparable {
        case awaitingReview
        case scheduledForReview(start: String, end: String)
        case activeReview(start: String, end: String)
        case accepted
        case acceptedWithRevisions
        case previewing
        case implemented(version: String)
        case returnedForRevision
        case rejected
        case withdrawn
        case error(reason: String)
        
        // Error status reason values
        public static let statusExtractionNotAttempted: Status = .error(reason: "Status extraction not attempted")
        public static let statusExtractionFailed: Status = .error(reason: "Status extraction failed")
        public static func unknownStatus(_ status: String) -> Status {
            .error(reason: "Unknown status value '\(status)'")
        }
    }
}

extension Proposal.Status: Codable {
    
    enum CodingKeys: String, CodingKey {
        case state
        case version
        case start
        case end
        case reason
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let state = try container.decode(String.self, forKey: .state)

        switch state {
            case "awaitingReview": self = .awaitingReview
            case "scheduledForReview":
                let start = try container.decode(String.self, forKey: .start)
                let end = try container.decode(String.self, forKey: .end)
                self = .scheduledForReview(start: start, end: end)
            case "activeReview":
                let start = try container.decode(String.self, forKey: .start)
                let end = try container.decode(String.self, forKey: .end)
                self = .activeReview(start: start, end: end)
            case "accepted": self = .accepted
            case "acceptedWithRevisions": self = .acceptedWithRevisions
            case "previewing": self = .previewing
            case "implemented":
                let version = try container.decode(String.self, forKey: .version)
                self = .implemented(version: version)
            case "returnedForRevision": self = .returnedForRevision
            case "rejected": self = .rejected
            case "withdrawn": self = .withdrawn
            case "error":
                let reason = try container.decode(String.self, forKey: .reason)
                self = .error(reason: reason)
            default:
                self = .unknownStatus(state)
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        let state = switch self {
            case .awaitingReview: "awaitingReview"
            case .scheduledForReview: "scheduledForReview"
            case .activeReview: "activeReview"
            case .accepted: "accepted"
            case .acceptedWithRevisions: "acceptedWithRevisions"
            case .previewing: "previewing"
            case .implemented: "implemented"
            case .returnedForRevision: "returnedForRevision"
            case .rejected: "rejected"
            case .withdrawn: "withdrawn"
            case .error: "error"
        }
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state, forKey: .state)
        
        if case let .scheduledForReview(startDate, endDate) = self {
            try container.encode(startDate, forKey: .start)
            try container.encode(endDate, forKey: .end)
        }
        
        if case let .activeReview(startDate, endDate) = self {
            try container.encode(startDate, forKey: .start)
            try container.encode(endDate, forKey: .end)
        }
        
        if case let .implemented(version) = self {
            try container.encode(version, forKey: .version)
        }
        
        if case let .error(reason) = self {
            try container.encode(reason, forKey: .reason)
        }
    }
}
