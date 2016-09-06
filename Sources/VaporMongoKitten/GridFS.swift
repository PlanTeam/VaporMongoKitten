import Vapor
import HTTP
import SMTP
import MongoKitten

extension GridFS {
    public func serve(byId id: ObjectId) throws -> Response {
        guard let file = try self.findOne(byID: id) else {
            return Response(status: .notFound)
        }
        
        return Response(chunked: { stream in
            for chunk in try file.chunked() {
                try stream.send(chunk.data)
            }
            
            try stream.close()
        })
    }
    
    public func store(file: Multipart.File) throws -> ObjectId {
         return try self.store(data: file.data, named: file.name, withType: file.type)
    }
}

extension GridFS.File: EmailAttachmentRepresentable {
    public var emailAttachment: EmailAttachment {
        return EmailAttachment(filename: self.filename ?? "", contentType: self.contentType ?? "", body: (try? self.read()) ?? [])
    }
}
