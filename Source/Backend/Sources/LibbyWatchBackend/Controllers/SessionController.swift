import Vapor
import Fluent
import LibbyWatchShared

struct SessionController {
    static func export(req: Request) async throws -> SessionExportResponse {
        let user = try req.auth.require(User.self)
        
        struct ExportRequest: Content {
            let startDate: Date?
            let endDate: Date?
            let eventTypes: [String]?
        }
        
        let request = try req.content.decode(ExportRequest.self)
        
        var query = AuditLog.query(on: req.db)
            .filter(\.$user.$id == user.id!)
        
        if let startDate = request.startDate {
            query = query.filter(\.$createdAt >= startDate)
        }
        
        if let endDate = request.endDate {
            query = query.filter(\.$createdAt <= endDate)
        }
        
        if let eventTypes = request.eventTypes, !eventTypes.isEmpty {
            query = query.filter(\.$eventType ~~ eventTypes)
        }
        
        let logs = try await query.sort(\.$createdAt, .descending).all()
        
        let events = logs.map { log in
            SessionEvent(
                id: log.id?.uuidString ?? "",
                eventType: log.eventType,
                eventData: log.eventData?.value,
                ipAddress: log.ipAddress,
                userAgent: log.userAgent,
                timestamp: log.createdAt ?? Date()
            )
        }
        
        try await AuditLog(
            userId: user.id,
            eventType: "session_export",
            eventData: JSONValue(["event_count": events.count]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return SessionExportResponse(events: events, exportedAt: Date())
    }
    
    static func reportIncident(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        struct IncidentRequest: Content {
            let type: String
            let severity: String
            let description: String
            let metadata: [String: String]?
        }
        
        let request = try req.content.decode(IncidentRequest.self)
        
        try await AuditLog(
            userId: user.id,
            eventType: "incident_report",
            eventData: JSONValue([
                "type": request.type,
                "severity": request.severity,
                "description": request.description,
                "metadata": request.metadata ?? [:]
            ]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        req.logger.warning("Incident reported: \(request.type) - \(request.severity) - \(request.description)")
        
        return .accepted
    }
}

struct SessionExportResponse: Content {
    let events: [SessionEvent]
    let exportedAt: Date
}

struct SessionEvent: Content {
    let id: String
    let eventType: String
    let eventData: JSONValue?
    let ipAddress: String?
    let userAgent: String?
    let timestamp: Date
    
    init(id: String, eventType: String, eventData: Any?, ipAddress: String?, userAgent: String?, timestamp: Date) {
        self.id = id
        self.eventType = eventType
        self.eventData = eventData.map { JSONValue($0) }
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        eventType = try container.decode(String.self, forKey: .eventType)
        eventData = try container.decodeIfPresent(JSONValue.self, forKey: .eventData)
        ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
        userAgent = try container.decodeIfPresent(String.self, forKey: .userAgent)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(eventType, forKey: .eventType)
        try container.encodeIfPresent(eventData, forKey: .eventData)
        try container.encodeIfPresent(ipAddress, forKey: .ipAddress)
        try container.encodeIfPresent(userAgent, forKey: .userAgent)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, eventType, eventData, ipAddress, userAgent, timestamp
    }
}