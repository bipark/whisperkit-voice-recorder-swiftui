import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    
    private init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("recordings.sqlite")
        
        if sqlite3_open(fileURL.path, &db) == SQLITE_OK {
            createTable()
            upgradeTableIfNeeded()
        } else {
            print("Error opening database")
        }
    }
    
    private func createTable() {
        let createTableString = """
            CREATE TABLE IF NOT EXISTS recordings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                file_path TEXT NOT NULL,
                created_at REAL NOT NULL,
                content TEXT
            );
        """
        
        var createTableStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("Recordings table created")
            } else {
                print("Recordings table could not be created")
            }
        } else {
            print("CREATE TABLE statement could not be prepared")
        }
        
        sqlite3_finalize(createTableStatement)
    }
    
    private func upgradeTableIfNeeded() {
        let checkColumnQuery = """
            SELECT COUNT(*) FROM pragma_table_info('recordings') WHERE name='content';
        """
        
        var checkStatement: OpaquePointer?
        var columnExists = false
        
        if sqlite3_prepare_v2(db, checkColumnQuery, -1, &checkStatement, nil) == SQLITE_OK {
            if sqlite3_step(checkStatement) == SQLITE_ROW {
                columnExists = sqlite3_column_int(checkStatement, 0) > 0
            }
        }
        sqlite3_finalize(checkStatement)
        
        if !columnExists {
            let alterTableString = "ALTER TABLE recordings ADD COLUMN content TEXT;"
            var alterStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, alterTableString, -1, &alterStatement, nil) == SQLITE_OK {
                if sqlite3_step(alterStatement) == SQLITE_DONE {
                    print("Added content column to recordings table")
                } else {
                    print("Failed to add content column")
                }
            } else {
                print("ALTER TABLE statement could not be prepared")
            }
            
            sqlite3_finalize(alterStatement)
        }
    }
    
    func saveRecording(_ recording: Recording) -> Int64? {
        let insertString = """
            INSERT INTO recordings (name, file_path, created_at, content)
            VALUES (?, ?, ?, ?);
        """
        
        var insertStatement: OpaquePointer?
        var newId: Int64?
        
        if sqlite3_prepare_v2(db, insertString, -1, &insertStatement, nil) == SQLITE_OK {
            let name = recording.name as NSString
            let path = recording.relativePath as NSString
            let timestamp = recording.createdAt.timeIntervalSince1970
            let content = recording.content as NSString
            
            sqlite3_bind_text(insertStatement, 1, name.utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, path.utf8String, -1, nil)
            sqlite3_bind_double(insertStatement, 3, timestamp)
            sqlite3_bind_text(insertStatement, 4, content.utf8String, -1, nil)
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                newId = sqlite3_last_insert_rowid(db)
                print("Recording inserted successfully with id: \(newId ?? -1)")
            } else {
                print("Could not insert recording")
            }
        } else {
            print("INSERT statement could not be prepared")
        }
        
        sqlite3_finalize(insertStatement)
        return newId
    }
    
    func getAllRecordings() -> [Recording] {
        var recordings: [Recording] = []
        let queryString = """
            SELECT id, name, file_path, created_at, content
            FROM recordings
            ORDER BY created_at DESC;
        """
        
        var queryStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = sqlite3_column_int64(queryStatement, 0)
                let name = String(cString: sqlite3_column_text(queryStatement, 1))
                let relativePath = String(cString: sqlite3_column_text(queryStatement, 2))
                let timestamp = sqlite3_column_double(queryStatement, 3)
                let createdAt = Date(timeIntervalSince1970: timestamp)
                let content = sqlite3_column_text(queryStatement, 4) != nil ? String(cString: sqlite3_column_text(queryStatement, 4)) : ""
                
                if let recording = Recording.fromRelativePath(id: id,
                                                            name: name,
                                                            relativePath: relativePath,
                                                            createdAt: createdAt,
                                                            content: content) {
                    recordings.append(recording)
                }
            }
        }
        
        sqlite3_finalize(queryStatement)
        return recordings
    }
    
    func deleteRecording(at path: String) {
        let beginTransaction = "BEGIN TRANSACTION;"
        let deleteString = "DELETE FROM recordings WHERE file_path = ?;"
        let commitTransaction = "COMMIT;"
        let rollbackTransaction = "ROLLBACK;"
        
        var beginStatement: OpaquePointer?
        var deleteStatement: OpaquePointer?
        var commitStatement: OpaquePointer?
        var rollbackStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, beginTransaction, -1, &beginStatement, nil) == SQLITE_OK {
            if sqlite3_step(beginStatement) == SQLITE_DONE {
                if sqlite3_prepare_v2(db, deleteString, -1, &deleteStatement, nil) == SQLITE_OK {
                    let pathString = path as NSString
                    sqlite3_bind_text(deleteStatement, 1, pathString.utf8String, -1, nil)
                    
                    if sqlite3_step(deleteStatement) == SQLITE_DONE {
                        if sqlite3_prepare_v2(db, commitTransaction, -1, &commitStatement, nil) == SQLITE_OK {
                            if sqlite3_step(commitStatement) == SQLITE_DONE {
                                print("Recording deleted successfully")
                            }
                        }
                    } else {
                        if sqlite3_prepare_v2(db, rollbackTransaction, -1, &rollbackStatement, nil) == SQLITE_OK {
                            sqlite3_step(rollbackStatement)
                        }
                        print("Could not delete recording")
                    }
                }
            }
        }
        
        sqlite3_finalize(beginStatement)
        sqlite3_finalize(deleteStatement)
        sqlite3_finalize(commitStatement)
        sqlite3_finalize(rollbackStatement)
    }
    
    func searchRecordings(query: String) -> [Recording] {
        var recordings: [Recording] = []
        let searchString = """
            SELECT id, name, file_path, created_at, content
            FROM recordings
            WHERE name LIKE ? OR content LIKE ?
            ORDER BY created_at DESC;
        """
        
        var queryStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, searchString, -1, &queryStatement, nil) == SQLITE_OK {
            let searchPattern = "%\(query)%"
            let pattern = searchPattern as NSString
            
            sqlite3_bind_text(queryStatement, 1, pattern.utf8String, -1, nil)
            sqlite3_bind_text(queryStatement, 2, pattern.utf8String, -1, nil)
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = sqlite3_column_int64(queryStatement, 0)
                let name = String(cString: sqlite3_column_text(queryStatement, 1))
                let relativePath = String(cString: sqlite3_column_text(queryStatement, 2))
                let timestamp = sqlite3_column_double(queryStatement, 3)
                let createdAt = Date(timeIntervalSince1970: timestamp)
                let content = sqlite3_column_text(queryStatement, 4) != nil ? String(cString: sqlite3_column_text(queryStatement, 4)) : ""
                
                if let recording = Recording.fromRelativePath(id: id,
                                                            name: name,
                                                            relativePath: relativePath,
                                                            createdAt: createdAt,
                                                            content: content) {
                    recordings.append(recording)
                }
            }
        }
        
        sqlite3_finalize(queryStatement)
        return recordings
    }
    
    func updateFilePath(id: Int64, newPath: String) {
        let updateString = "UPDATE recordings SET file_path = ? WHERE id = ?;"
        var updateStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateString, -1, &updateStatement, nil) == SQLITE_OK {
            let pathString = newPath as NSString
            sqlite3_bind_text(updateStatement, 1, pathString.utf8String, -1, nil)
            sqlite3_bind_int64(updateStatement, 2, id)
            
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("File path updated successfully")
            } else {
                print("Could not update file path")
            }
        } else {
            print("UPDATE statement could not be prepared")
        }
        
        sqlite3_finalize(updateStatement)
    }
    
    func updateRecording(id: Int64, newPath: String, newName: String) {
        let updateString = "UPDATE recordings SET file_path = ?, name = ? WHERE id = ?;"
        var updateStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateString, -1, &updateStatement, nil) == SQLITE_OK {
            let pathString = newPath as NSString
            let nameString = newName as NSString
            
            sqlite3_bind_text(updateStatement, 1, pathString.utf8String, -1, nil)
            sqlite3_bind_text(updateStatement, 2, nameString.utf8String, -1, nil)
            sqlite3_bind_int64(updateStatement, 3, id)
            
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("Recording updated successfully")
            } else {
                print("Could not update recording")
            }
        } else {
            print("UPDATE statement could not be prepared")
        }
        
        sqlite3_finalize(updateStatement)
    }
    
    func updateRecordingContent(id: Int64, content: String) {
        
        let updateString = "UPDATE recordings SET content = ? WHERE id = ?;"
        var updateStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateString, -1, &updateStatement, nil) == SQLITE_OK {
            let contentString = content as NSString
            
            sqlite3_bind_text(updateStatement, 1, contentString.utf8String, -1, nil)
            sqlite3_bind_int64(updateStatement, 2, id)
            
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                print("Recording content updated successfully")
                
                // Check recording status after update
                let verifyQuery = "SELECT content FROM recordings WHERE id = ?;"
                var verifyStatement: OpaquePointer?
                
                if sqlite3_prepare_v2(db, verifyQuery, -1, &verifyStatement, nil) == SQLITE_OK {
                    sqlite3_bind_int64(verifyStatement, 1, id)
                    
                    if sqlite3_step(verifyStatement) == SQLITE_ROW {
                        let savedContent = String(cString: sqlite3_column_text(verifyStatement, 0))
                        print("Verified saved content: \(savedContent)")
                    }
                }
                sqlite3_finalize(verifyStatement)
            } else {
                if let errorMessage = String(cString: sqlite3_errmsg(db), encoding: .utf8) {
                    print("SQLite error: \(errorMessage)")
                }
            }
        } else {
            if let errorMessage = String(cString: sqlite3_errmsg(db), encoding: .utf8) {
                print("SQLite error: \(errorMessage)")
            }
        }
        
        sqlite3_finalize(updateStatement)
    }
    
    func updateRecordingContentAndName(id: Int64, content: String, name: String) {
        
        let updateString = "UPDATE recordings SET content = ?, name = ? WHERE id = ?;"
        var updateStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateString, -1, &updateStatement, nil) == SQLITE_OK {
            let contentString = content as NSString
            let nameString = name as NSString
            
            sqlite3_bind_text(updateStatement, 1, contentString.utf8String, -1, nil)
            sqlite3_bind_text(updateStatement, 2, nameString.utf8String, -1, nil)
            sqlite3_bind_int64(updateStatement, 3, id)
            
            if sqlite3_step(updateStatement) == SQLITE_DONE {
                
                let verifyQuery = "SELECT content, name FROM recordings WHERE id = ?;"
                var verifyStatement: OpaquePointer?
                
                if sqlite3_prepare_v2(db, verifyQuery, -1, &verifyStatement, nil) == SQLITE_OK {
                    sqlite3_bind_int64(verifyStatement, 1, id)
                    
                    if sqlite3_step(verifyStatement) == SQLITE_ROW {
                        let savedContent = String(cString: sqlite3_column_text(verifyStatement, 0))
                        let savedName = String(cString: sqlite3_column_text(verifyStatement, 1))
                    }
                }
                sqlite3_finalize(verifyStatement)
            } else {
                if let errorMessage = String(cString: sqlite3_errmsg(db), encoding: .utf8) {
                    print("SQLite error: \(errorMessage)")
                }
            }
        } else {
            if let errorMessage = String(cString: sqlite3_errmsg(db), encoding: .utf8) {
                print("SQLite error: \(errorMessage)")
            }
        }
        
        sqlite3_finalize(updateStatement)
    }
    
    deinit {
        if sqlite3_close(db) != SQLITE_OK {
            print("Error closing database")
        }
    }
}
