import BSON
import Permissions

extension PermissionSet {
    /// Creates an array of `(Permission, Level)` from a Document
    public static func make(from document: Document) -> PermissionSet {
        let array = document.flatMap { (identifier, value) -> (Permission, Level)? in
            let level: Level
            
            switch value.int32 {
            case 30:
                level = .forceAllow
            case 20:
                level = .deny
            case 10:
                level = .allow
            default:
                level = .undefined
            }
            
            do {
                let permission = try PermissionManager.find(identifier)
                return (permission, level)
            } catch {
                return nil
            }
        }
        
        return PermissionSet(array: array)
    }
    
    public func makeDocument() -> Document {
        var document: Document = [:]
        
        for (permission, level) in self.permissions.map({ $0.pair }) {
            document[permission.machineIdentifier] = ~level.rawValue
        }
        
        return document
    }
}

extension Level {
    public var rawValue: Int32 {
        switch self {
        case .undefined: return 0
        case .allow: return 10
        case .deny: return 20
        case .forceAllow: return 30
        }
    }
}
