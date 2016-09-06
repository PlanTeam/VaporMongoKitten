import protocol Vapor.StringInitializable
import struct BSON.ObjectId

extension ObjectId: StringInitializable {
    public init?(from string: String) throws {
        self = try ObjectId(string)
    }
}
