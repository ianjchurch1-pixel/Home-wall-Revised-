import SwiftUI

// MARK: - Wall Model
struct Wall: Identifiable, Codable {
    let id: UUID
    var name: String
    var imageData: Data
    var routes: [Route]
    var dateCreated: Date
    
    init(id: UUID = UUID(), name: String, imageData: Data, routes: [Route] = [], dateCreated: Date = Date()) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.routes = routes
        self.dateCreated = dateCreated
    }
}

// MARK: - Route Model
struct Route: Identifiable, Codable {
    let id: UUID
    var name: String
    var holds: [Hold]
    var color: String // Hex color
    var grade: String?
    var dateCreated: Date
    
    init(id: UUID = UUID(), name: String, holds: [Hold] = [], color: String, grade: String? = nil, dateCreated: Date = Date()) {
        self.id = id
        self.name = name
        self.holds = holds
        self.color = color
        self.grade = grade
        self.dateCreated = dateCreated
    }
}

// MARK: - Hold Model
struct Hold: Identifiable, Codable {
    let id: UUID
    var position: CGPoint
    var colorHex: String // Store as hex string
    var size: CGFloat // Hold size
    
    init(id: UUID = UUID(), position: CGPoint, colorHex: String = "007AFF", size: CGFloat = 36) {
        self.id = id
        self.position = position
        self.colorHex = colorHex
        self.size = size
    }
}
