//
//  Models.swift
//  Home Wall
//
//  Data models for climbing walls, climbs, and holds
//

import SwiftUI

// Model for a climbing wall with multiple climbs
struct ClimbingWall: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var imageData: Data
    var climbs: [Climb]
    var createdDate: Date
    
    init(id: UUID = UUID(), name: String, image: UIImage, climbs: [Climb] = []) {
        self.id = id
        self.name = name
        self.imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
        self.climbs = climbs
        self.createdDate = Date()
    }
    
    var image: UIImage? {
        UIImage(data: imageData)
    }
    
    // Helper computed property for total holds across all climbs
    var totalHolds: Int {
        climbs.reduce(0) { $0 + $1.holds.count }
    }
}

// Model for a single climb/route on a wall
struct Climb: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var holds: [SavedHold]
    var createdDate: Date
    var difficulty: String? // Optional difficulty rating (set when ticked)
    var notes: String? // Optional notes
    var matchAllowed: Bool // Whether matching (both hands on same hold) is allowed
    var tickDates: [Date] // Array of dates when climb was completed (for repeats)
    var isEstablished: Bool // Whether the climb is established (locked from editing holds)
    var rating: Int? // Star rating 1-4 (set when ticked)
    var betaVideoURL: URL? // DEPRECATED: kept for backwards compatibility, migrate to betaVideos
    var betaVideos: [BetaVideo] // Array of beta videos from multiple users
    
    // Computed property for backwards compatibility
    var isTicked: Bool {
        !tickDates.isEmpty
    }
    
    // Most recent tick date
    var lastTickDate: Date? {
        tickDates.max()
    }
    
    // Number of sends
    var sendCount: Int {
        tickDates.count
    }
    
    init(id: UUID = UUID(), name: String, holds: [SavedHold] = [], difficulty: String? = nil, notes: String? = nil, matchAllowed: Bool = true, tickDates: [Date] = [], isEstablished: Bool = false, rating: Int? = nil, betaVideoURL: URL? = nil, betaVideos: [BetaVideo] = []) {
        self.id = id
        self.name = name
        self.holds = holds
        self.createdDate = Date()
        self.difficulty = difficulty
        self.notes = notes
        self.matchAllowed = matchAllowed
        self.tickDates = tickDates
        self.isEstablished = isEstablished
        self.rating = rating
        self.betaVideoURL = betaVideoURL
        self.betaVideos = betaVideos
        
        // Migration: if betaVideoURL exists but betaVideos is empty, migrate it
        if let legacyURL = betaVideoURL, betaVideos.isEmpty {
            self.betaVideos = [BetaVideo(videoURL: legacyURL, uploaderName: "Legacy User", uploadDate: createdDate)]
        }
    }
}

// Model for a climbing hold (used during editing, before saving)
struct Hold: Identifiable {
    let id = UUID()
    var position: CGPoint
    var color: HoldColor
    var size: CGFloat
}

// Saved hold with position, color, and size (persisted)
struct SavedHold: Identifiable, Codable, Hashable {
    let id: UUID
    let relativeX: Double // Position as percentage of actual image width
    let relativeY: Double // Position as percentage of actual image height
    let color: String // "red", "green", "blue", or "purple"
    let relativeSize: Double // Size as percentage of container width
    
    init(id: UUID = UUID(), position: CGPoint, color: HoldColor, size: CGFloat, imageSize: CGSize, containerSize: CGSize) {
        self.id = id
        
        // Calculate actual displayed image size
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        let actualImageSize: CGSize
        let imageOffset: CGPoint
        
        if imageAspect > containerAspect {
            // Image fits to width
            let displayHeight = containerSize.width / imageAspect
            actualImageSize = CGSize(width: containerSize.width, height: displayHeight)
            imageOffset = CGPoint(x: 0, y: (containerSize.height - displayHeight) / 2)
        } else {
            // Image fits to height
            let displayWidth = containerSize.height * imageAspect
            actualImageSize = CGSize(width: displayWidth, height: containerSize.height)
            imageOffset = CGPoint(x: (containerSize.width - displayWidth) / 2, y: 0)
        }
        
        // Convert position to relative coordinates within actual image
        self.relativeX = Double((position.x - imageOffset.x) / actualImageSize.width)
        self.relativeY = Double((position.y - imageOffset.y) / actualImageSize.height)
        self.relativeSize = Double(size / containerSize.width)
        
        switch color {
        case .red: self.color = "red"
        case .green: self.color = "green"
        case .blue: self.color = "blue"
        case .purple: self.color = "purple"
        }
    }
    
    func position(imageSize: CGSize, containerSize: CGSize) -> CGPoint {
        // Calculate actual displayed image size and offset
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        let actualImageSize: CGSize
        let imageOffset: CGPoint
        
        if imageAspect > containerAspect {
            let displayHeight = containerSize.width / imageAspect
            actualImageSize = CGSize(width: containerSize.width, height: displayHeight)
            imageOffset = CGPoint(x: 0, y: (containerSize.height - displayHeight) / 2)
        } else {
            let displayWidth = containerSize.height * imageAspect
            actualImageSize = CGSize(width: displayWidth, height: containerSize.height)
            imageOffset = CGPoint(x: (containerSize.width - displayWidth) / 2, y: 0)
        }
        
        // Convert relative position back to absolute
        return CGPoint(
            x: imageOffset.x + (relativeX * actualImageSize.width),
            y: imageOffset.y + (relativeY * actualImageSize.height)
        )
    }
    
    func size(containerSize: CGSize) -> CGFloat {
        relativeSize * containerSize.width
    }
    
    var holdColor: HoldColor {
        switch color {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        default: return .red
        }
    }
}

// Available colors for holds
enum HoldColor {
    case red, green, blue, purple
    
    var color: Color {
        switch self {
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
    
    mutating func next() {
        switch self {
        case .red: self = .green
        case .green: self = .blue
        case .blue: self = .purple
        case .purple: self = .red // Cycle back to red, delete handled separately
        }
    }
}

// Model for beta videos with user attribution
struct BetaVideo: Identifiable, Codable, Hashable {
    let id: UUID
    var videoURL: URL
    var uploaderName: String
    var uploadDate: Date
    var notes: String? // Optional notes about the beta
    
    init(id: UUID = UUID(), videoURL: URL, uploaderName: String, uploadDate: Date = Date(), notes: String? = nil) {
        self.id = id
        self.videoURL = videoURL
        self.uploaderName = uploaderName
        self.uploadDate = uploadDate
        self.notes = notes
    }
}

// Playlist model
struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var climbIds: Set<UUID>
    
    init(id: UUID = UUID(), name: String, climbIds: Set<UUID> = []) {
        self.id = id
        self.name = name
        self.climbIds = climbIds
    }
}
