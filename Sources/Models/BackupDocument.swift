import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct LedgerEntrySnapshot: Codable {
    let id: UUID
    let createdAt: Date
    let amount: Double
    let originalAmount: Double?
    let currencyCode: String?
    let exchangeRateToCNY: Double?
    let note: String
    let flow: FlowType
    let categoryName: String
    let categorySymbol: String
    let categoryColorHex: Int
}

struct SavingsGoalSnapshot: Codable {
    let id: UUID
    let createdAt: Date
    let name: String
    let symbol: String
    let currentAmount: Double
    let targetAmount: Double
    let deadline: Date?
    let tintHex: Int
}

struct VaultDepositSnapshot: Codable {
    let id: UUID
    let date: Date
    let amount: Double
    let note: String
    let goalID: UUID?
}

struct LedgerBackupPayload: Codable {
    let exportedAt: Date
    let appVersion: String
    let entries: [LedgerEntrySnapshot]
    let goals: [SavingsGoalSnapshot]
    let deposits: [VaultDepositSnapshot]
}

struct LedgerBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var payload: LedgerBackupPayload

    init(payload: LedgerBackupPayload) {
        self.payload = payload
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        payload = try decoder.decode(LedgerBackupPayload.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let encoded = try encoder.encode(payload)
        return FileWrapper(regularFileWithContents: encoded)
    }
}
