//
//  Helpers.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 16-08-16.
//
//

import class HTTP.Response
import struct BSON.Document
import protocol HTTP.ResponseRepresentable
import enum HTTP.Status


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

enum UnwrapError : Error {
    case noValue
}

postfix operator *
public postfix func *<T>(_ val: T?) throws -> T {
    switch val {
    case .none: throw UnwrapError.noValue
    case .some(let val): return val
    }
}

