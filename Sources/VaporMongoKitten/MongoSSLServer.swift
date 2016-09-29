import MongoKitten
import TLS
import Core

extension TLS.Socket : MongoKitten.MongoTCP {
    public func receive() throws -> [UInt8] {
        return (try self.receive() as Bytes)
    }

    public static func open(address hostname: String, port: UInt16) throws -> MongoTCP {
        return try TLS.Socket(mode: .client, hostname: hostname, port: port, certificates: .none, verifyHost: true, verifyCertificates: true, cipher: .secure)
    }
    
    public func send(data binary: [UInt8]) throws {
        try self.send(binary)
    }
}
