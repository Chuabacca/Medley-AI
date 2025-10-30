import Foundation

struct DataSchema: Codable {
    let version: String
    let intro: Intro
    let questions: [Question]

    var byId: [String: Question] { Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) }) }
}

struct Intro: Codable { let firstQuestionId: String }

enum QuestionType: String, Codable { case single_choice, multiple_choice, free_text, number, date }

struct Option: Codable { let id: String; let label: String }

struct NextRules: Codable { let `default`: String? }

struct Question: Codable {
    let id: String
    let info: String?
    let prompt: String
    let type: QuestionType
    let options: [Option]?
    let predefinedResponses: [String]?
    let next: NextRules?
}

enum SchemaLoaderError: Error { case fileMissing, decodeFailed }

enum SchemaLoader {
    static func load(named name: String = "data_schema") throws -> DataSchema {
        // Prefer app bundle
        if let url = Bundle.main.url(forResource: name, withExtension: "json") {
            return try decode(url: url)
        }
        // Fallback to working directory for non-app contexts
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        let url = URL(fileURLWithPath: cwd).appendingPathComponent("Resources/\(name).json")
        guard fm.fileExists(atPath: url.path) else { throw SchemaLoaderError.fileMissing }
        return try decode(url: url)
    }

    private static func decode(url: URL) throws -> DataSchema {
        let data = try Data(contentsOf: url)
        do { return try JSONDecoder().decode(DataSchema.self, from: data) }
        catch { throw SchemaLoaderError.decodeFailed }
    }
}
