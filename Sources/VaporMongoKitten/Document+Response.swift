//
//  Helpers.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 16-08-16.
//
//

import HTTP
import Vapor
import struct BSON.Document

extension Document : ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return Response(status: .ok, headers: ["Content-Type": "application/json"], body: self.makeExtendedJSON())
    }
}

extension HTTP.Response {
    public convenience init(status: HTTP.Status, document: Document) {
        self.init(status: status, headers: ["Content-Type": "application/json"], body: document.makeExtendedJSON())
    }
}

public enum UnwrapError : Error {
    case noValue
}

postfix operator *
public postfix func *<T>(_ val: T?) throws -> T {
    switch val {
    case .none: throw UnwrapError.noValue
    case .some(let val): return val
    }
}

extension Request {
    public var document: Document? {
        guard let bytes = self.body.bytes else {
            return nil
        }
        
        guard let json = try? String(bytes: bytes) else {
            return nil
        }
        
        return try? Document(extendedJSON: json)
    }
}
