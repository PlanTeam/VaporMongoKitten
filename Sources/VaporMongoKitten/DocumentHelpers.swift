protocol DocumentRepresentable {
    var document: Document { get }
}

extension Document: DocumentRepresentable {
    var document: Document {
        return self
    }
}

extension Array where Element: DocumentRepresentable {
    var arrayDocument: Document {
        return Document(array: self.map {
            ~$0.document
        })
    }
} 
