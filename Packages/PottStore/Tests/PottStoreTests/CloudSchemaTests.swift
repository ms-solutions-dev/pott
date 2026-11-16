import CoreData
import Foundation
import Testing

@testable import PottStore

/// `cloudkit/schema.ckdb` is imported into CloudKit by hand (production never creates types). This
/// checks that it covers every attribute and relationship of the model with the type Core Data uses,
/// so a model change cannot silently break sync.
@Suite("CloudKit schema file")
struct CloudSchemaTests {
    /// Record type → field → type, read from the schema file.
    static func schema() throws -> [String: [String: String]] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("cloudkit/schema.ckdb")
        let text = try String(contentsOf: url, encoding: .utf8)
        var result: [String: [String: String]] = [:]
        var current: String?
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("RECORD TYPE ") {
                current = String(line.dropFirst(12).split(separator: " ")[0]).replacingOccurrences(
                    of: "\"", with: "")
                result[current!] = [:]
            } else if let type = current, line.hasPrefix("CD_") {
                let parts = line.trimmingCharacters(in: CharacterSet(charactersIn: ",")).split(separator: " ")
                result[type]![String(parts[0])] = String(parts[1])
            }
        }
        return result
    }

    @Test("Every entity, attribute and to-one relationship is in the schema with the right type")
    func coversModel() throws {
        let schema = try Self.schema()
        #expect(schema["cloudkit.share"] != nil)
        for entity in PottModel.shared.entities {
            let name = "CD_\(entity.name!)"
            let fields = try #require(schema[name], "\(name) missing")
            for required in ["CD_entityName", "CD_moveReceipt", "CD_moveReceipt_ckAsset"] {
                #expect(fields[required] != nil, "\(name).\(required)")
            }
            for attribute in entity.attributesByName.values {
                let field = "CD_\(attribute.name)"
                let expected: String =
                    switch attribute.type {
                    case .string, .uuid: "STRING"
                    case .integer16, .integer32, .integer64, .boolean: "INT64"
                    case .date: "TIMESTAMP"
                    case .double, .float: "DOUBLE"
                    case .binaryData: "BYTES"
                    default: "unsupported \(attribute.type)"
                    }
                #expect(fields[field] == expected, "\(name).\(field)")
                if attribute.type == .string || attribute.type == .binaryData {
                    #expect(fields["\(field)_ckAsset"] == "ASSET", "\(name).\(field)_ckAsset")
                }
            }
            for relationship in entity.relationshipsByName.values where !relationship.isToMany {
                #expect(fields["CD_\(relationship.name)"] == "STRING", "\(name).\(relationship.name)")
            }
            // Many-to-many would need CDMR records, which the schema does not define.
            for relationship in entity.relationshipsByName.values where relationship.isToMany {
                #expect(relationship.inverseRelationship?.isToMany == false, "\(name).\(relationship.name)")
            }
        }
    }
}
