import Foundation

struct Recording: Identifiable {
    let id: Int64
    var name: String
    let fileURL: URL
    let createdAt: Date
    var content: String
    
    init(id: Int64 = -1, name: String, fileURL: URL, createdAt: Date = Date(), content: String = "") {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.content = content
    }
    
    var relativePath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return fileURL.path.replacingOccurrences(of: documentsPath.path, with: "")
    }
    
    static func fromRelativePath(id: Int64, name: String, relativePath: String, createdAt: Date, content: String = "") -> Recording? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(relativePath)
        
        // Check if file actually exists
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return Recording(id: id, name: name, fileURL: fileURL, createdAt: createdAt, content: content)
        }
        return nil
    }
}
