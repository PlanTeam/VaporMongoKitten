//
//  InputValidation.swift
//  VaporMongoKitten
//
//  Created by Robbert Brandsma on 17-08-16.
//
//

import BSON

import MongoKitten
import class HTTP.Request
import class HTTP.Response
import enum HTTP.Status
import protocol HTTP.ResponseRepresentable

public indirect enum KeyType {
    // TODO: Update reference/model to support multiple index types
    case string, number, date, anyObject, bool
    case reference(Model.Type)
    case object(requiredFields: [String : KeyType], optionalFields: [String : KeyType])
    case enumeration([String])
    case array(KeyType)
    
    /// Anything, but not nothing.
    case anything
}

public enum InputValidationError : Error {
    case missingRequiredField(key: String, type: KeyType)
    case unknownFieldInRequest(key: String)
    case wrongFieldType(key: String, expected: KeyType)
    case missingRequestBody
    case referenceError(key: String)
    case unkeyedReferenceError(model: Model.Type)
    case unreadeableBody
    case invalidEnumerationValue
    
    var message: String? {
        switch self {
        case .missingRequiredField(let key, type: let type): return "Missing required field \"\(key)\" of type \(type)"
        case .unknownFieldInRequest(let key): return "Field \"\(key)\" in request not recognized"
        case .wrongFieldType(let key, let expectedType): return "Type of field \"\(key)\" incorrect, should be \(expectedType)"
        case .missingRequestBody: return "Request body expected but missing"
        case .referenceError(let key): return "Invalid reference for key \(key)"
        case .unkeyedReferenceError(let model): return "Reference error, entity of type \(model) not found"
        case .unreadeableBody: return "Unreadable request body"
        case .invalidEnumerationValue: return "Invalid enumeration value"
        }
    }
    
    var status: HTTP.Status? {
        return .badRequest
    }
}

public func validate(document: Document, requiredFields: [String : KeyType] = [:], optionalFields: [String : KeyType] = [:], errorKeyPrefix: String = "") throws {
    // check if all required keys are present
    let inputKeys = document.keys
    for (key, type) in requiredFields where !inputKeys.contains(key) {
        let errorKey = errorKeyPrefix + key
        log.verbose("Missing required field \(errorKey)")
        throw InputValidationError.missingRequiredField(key: errorKey, type: type)
    }
    
    // check if no extra fields are present, and validate the type of every field
    for (key, value) in document {
        let errorKey = errorKeyPrefix + key
        
        // Check if the field type is defined in either the required fields or the optional fields
        guard let expectedType = requiredFields[key] ?? optionalFields[key] else {
            log.verbose("Unknown field \(errorKey) in request)")
            throw InputValidationError.unknownFieldInRequest(key: errorKey)
        }
        
        func expect(_ expectedType: KeyType, for value: Value, maybeNull: Bool) throws {
            
            // Compare the expected field type with the actual field type and perform validation
            switch (expectedType, value) {
            case (.string, .string(_)): break
            case (.number, .int32(_)), (.number, .int64(_)), (.number, .double(_)): break
            case (.date, .dateTime(_)): break
            case (.reference(let ModelType), .objectId(let identifier)):
                // Check the reference
                let collection = ModelType.collection
                guard try collection.count(matching: "_id" == identifier) == 1 else {
                    throw InputValidationError.referenceError(key: errorKey)
                }
            case (.reference(let ModelType), .string(let identifierString)) where identifierString.characters.count == 24:
                let identifier = try ObjectId(identifierString)
                // Check the reference
                let collection = ModelType.collection
                guard try collection.count(matching: "_id" == identifier) == 1 else {
                    throw InputValidationError.referenceError(key: errorKey)
                }
            case (.object(let requiredFields, let optionalFields), .document(let doc)):
                try validate(document: doc, requiredFields: requiredFields, optionalFields: optionalFields, errorKeyPrefix: "\(errorKeyPrefix)\(key).")
            case (.anyObject, .document(_)): break
            case (.enumeration(let values), .string(let value)):
                if values.contains(value) {
                    break
                } else {
                    log.verbose("Invalid enumeration value \(value) is not inside \(values)")
                    throw InputValidationError.invalidEnumerationValue
                }
            case (.array(let keyType), .array(let doc)):
                for (_, val) in doc {
                    try expect(keyType, for: val, maybeNull: false)
                }
            case (.bool, .boolean(_)): break
            case (.anything, _) where value != .nothing: break
            case (_, .null) where maybeNull: break
            default:
                log.verbose("Type mismatch on field \(errorKey) with expected type \(expectedType) in request)")
                throw InputValidationError.wrongFieldType(key: errorKey, expected: expectedType)
            }
        }
        
        try expect(expectedType, for: value, maybeNull: optionalFields.keys.contains(key))
    }
}

public func validateReference<M : Model>(_ id: ObjectId, to: M.Type) throws {
    let collection = M.collection
    guard try collection.count(matching: "_id" == id) == 1 else {
        log.verbose("Invalid reference to \(id.hexString) on model \(M.modelName)")
        throw InputValidationError.unkeyedReferenceError(model: M.self)
    }
}

public func resolveReference<M : Model>(_ id: ObjectId) throws -> M {
    guard let instance = try M.findOne(matching: "_id" == id) else {
        throw InputValidationError.unkeyedReferenceError(model: M.self)
    }
    
    return instance
}

public func resolveReference<M : Model>(_ id: String) throws -> M {
    let objectId = try ObjectId(id)
    return try resolveReference(objectId)
}

public func resolveReference<M : Model>(_ id: BSON.Value) throws -> M {
    switch id {
    case .objectId(let id):
        return try resolveReference(id)
    case .string(let id):
        return try resolveReference(id)
    default:
        throw InputValidationError.unkeyedReferenceError(model: M.self)
    }
}

public func extract(from request: Request, requiredFields: [String : KeyType] = [:], optionalFields: [String : KeyType] = [:]) throws -> Document {
    guard let bytes = request.body.bytes else {
        throw InputValidationError.missingRequestBody
    }
    
    guard let json = try? String(bytes: bytes) else {
        throw InputValidationError.unreadeableBody
    }
    
    let document = try Document(extendedJSON: json)
    
    
    request.data
    
    
    try validate(document: document, requiredFields: requiredFields, optionalFields: optionalFields)
    
    return document
}
