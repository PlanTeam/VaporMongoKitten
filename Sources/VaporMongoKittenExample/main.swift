import VaporMongoKitten
import Permissions
import LogKitten
import Vapor
import Cookies
import HTTP
import BCrypt

let server = try!  MongoKitten.Server("")
let server = try! MongoKitten.Server(at: "127.0.0.1")
let db = server["mydatabase"]
let log = Logger()

let gridFS = try! GridFS(in: db)

enum UserPermissions: Permission {
    case read, update, create, delete
    
    /// Return all the possible values for this permission
    public static var allValues: [Permission] {
        return [
            UserPermissions.read,
            UserPermissions.update,
            UserPermissions.create,
            UserPermissions.delete
        ]
    }
    
    /// Returns the machine and human identifier. See the documentation on `Permission` for more information.
    public var metadata: (machineIdentifier: String, humanIdentifier: String) {
        switch self {
        case .read: return ("users-read", "Read users")
        case .update: return ("users-update", "Update users")
        case .create: return ("users-create", "Create users")
        case .delete: return ("users-delete", "Delete users")
        }
    }
    
    /// A human-readable description for this permission set in general, like "Event permissions"
    public static var groupDescription = "User permissions"
}

enum FilePermissions: Permission {
    case download, upload
    
    public static var allValues: [Permission] {
        return [
            FilePermissions.upload,
            FilePermissions.download
        ]
    }
    
    var metadata: (machineIdentifier: String, humanIdentifier: String) {
        switch self {
        case .upload: return ("file-upload", "Upload Files")
        case .download: return ("file-download", "Download Files")
        }
    }
    
    static var groupDescription = "File Permissions"
}

public class Authenticator: Middleware {
    var sessions = [String: User]()
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        // Take the token
        tokenCheck: if let token = request.headers["Authorization"] ?? request.cookies["Authorization"] {
            // Find the corresponding `Session`
            if let user = sessions[token] {
                
                // Set the correct details for the `HTTP.Request`
                request.storage["user"] = user
            } else {
                log.verbose("Invalid token \"\(token)\" used for authorization at \"\(request.uri.path)\"")
            }
        }
        
        return try next.respond(to: request)
    }
}

public final class User : UserModel {
    public var deletable: Bool {
        return !admin
    }
    
    public var password: String {
        return self["password"].string
    }
    
    public var username: String {
        return self["email"].string
    }
    
    public var admin: Bool {
        return self["admin"].boolValue ?? false
    }
    
    public func deleteChildren() throws { }
    
    /// The groups this user belongs to
    public let groups: [Permissions.Group] = []
    
    /// The `Collection` that every `User` is stored in
    public static var collection: MongoKitten.Collection = db["users"]
    
    /// The public identifier for this `Model`
    public static let modelName = "user"
    
    /// The `Document` data that this `Model` is filled with
    public var data: Document = [:]

    /// Initializes this `User` with a `Document`
    public init(data: Document) {
        self.data = data
    }
    
    /// Creates a new `User` from the provided login details
    public init(email: String, password: String) throws {
        self["_id"] = ~ObjectId()
        self["email"] = ~email
        self["password"] = ~(try User.hash(password: password))
        
        self.setPermission(UserPermissions.read, atLevel: .allow)
        self.setPermission(FilePermissions.upload, atLevel: .allow)
        self.setPermission(FilePermissions.download, atLevel: .allow)
        
        try self.completeUpsert()
    }
    
    /// Sets the password to a hashes variant of the provided string
    public func setPassword(password: String) throws {
        // insert hashing algorithm here
        self["password"] = try ~User.hash(password: password)
        try self.update(fields: "password")
    }
    
    /// Checks whether the user with the provided email address exists
    ///
    /// And whether the User's password matches the provided one
    public static func authenticate(email: String, withPassword password: String) throws -> User? {
        guard let user = try User.findOne(matching: "email" == email) else {
            log.verbose("Unable to find user \(email)")
            return nil
        }
        
        if try user.validate(against: password) {
            return user
        }
        
        log.verbose("Invalid password for user \(email)")
        
        return nil
    }
}

let drop = Droplet()


// For security reasons, we don't want non-permission checked code. I'd rather crash than have a security leak
drop.middleware.append(FailsafeMiddleware() { request, response in
    fatalError("Request wasn't permission-checked: \(request), response: \(response)")
    })

let authenticator = Authenticator()
drop.middleware.append(authenticator)


drop.post("register") { request in
    request.allowAnonymous()
    
    // Requires an email, gender and password
    // Optionally allows a location, but within specific requirements
    // Friends need to be references to other users
    let input = try extract(from: request, requiredFields: [
        "email": .string,
        "gender": .enumeration(["male", "female"]),
        "password": .string
        ], optionalFields: [
            "location": .object(requiredFields: [
                "country": .enumeration(["NL", "US", "DE", "FR"]),
                "city": .string,
                ], optionalFields: [:]),
            "friends": .array(.reference(User.self))
        ])
    
    let user = try User(email: input["email"].string, password: input["password"].string)
    user["gender"] = input["gender"]
    user["location"] = input["location"]
    user["friends"] = input["friends"]
    
    try user.completeUpsert()
    
    return "You're registered."
}

drop.post("login") { request in
    request.allowAnonymous()
    
    if let u = request.storage["user"] as? User {
        return "already logged in"
    }
    
    let input = try extract(from: request, requiredFields: [
        "email": .string,
        "password": .string
        ], optionalFields: [:])
    
    guard let user = try User.authenticate(email: input["email"].string, withPassword: input["password"].string) else {
        return ["success": false, "message": "Invalid login credentials"] as Document
    }
    
    let sessionID = ObjectId().hexString
    let cookie = Cookie(name: "Authorization", value: sessionID)
    
    authenticator.sessions[sessionID] = user
    
    let response = Response.init(status: .ok, document: ["success": true])
    
    response.cookies = [cookie]
    
    return response
}

drop.get("download", ObjectId.self) { request, fileId in
//    try request.require(FilePermissions.download)
    request.allowAnonymous()
    
    return try gridFS.serve(byId: fileId)
}

drop.post("upload") { request in
//    try request.require(FilePermissions.upload)
    request.allowAnonymous()
    
    guard let file = request.multipart?["file"]?.file else {
        return "No file provided"
    }
    
    let oid = try gridFS.store(file: file)

    return "\(oid.hexString)"
}

drop.get("users") { request in
    try request.require(UserPermissions.read)
    
    return (Array(try User.find())).makeArrayDocument()
}

drop.serve()
