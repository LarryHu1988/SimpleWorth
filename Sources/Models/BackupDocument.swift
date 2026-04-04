import Foundation
import SwiftData
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
    let tagNames: [String]?
    let flow: FlowType
    let categoryName: String
    let categorySymbol: String
    let categoryColorHex: Int
}

struct TagSnapshot: Codable {
    let id: UUID
    let name: String
    let emoji: String?
    let tintHex: Int?
    let createdAt: Date
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
    let tags: [TagSnapshot]?
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
        payload = try LedgerBackupCodec.decodePayload(from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoded = try LedgerBackupCodec.encodePayload(payload)
        return FileWrapper(regularFileWithContents: encoded)
    }
}

enum LedgerBackupCodec {
    static func decodePayload(from data: Data) throws -> LedgerBackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LedgerBackupPayload.self, from: data)
    }

    static func encodePayload(_ payload: LedgerBackupPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }
}

enum LedgerBackupCoordinator {
    static func makePayload(
        appVersion: String,
        entries: [LedgerEntry],
        tags: [TagRecord],
        goals: [SavingsGoalRecord],
        deposits: [VaultDepositRecord]
    ) -> LedgerBackupPayload {
        LedgerBackupPayload(
            exportedAt: .now,
            appVersion: appVersion,
            entries: entries.map {
                LedgerEntrySnapshot(
                    id: $0.id,
                    createdAt: $0.createdAt,
                    amount: $0.amount,
                    originalAmount: $0.originalAmount,
                    currencyCode: $0.currencyCode,
                    exchangeRateToCNY: $0.exchangeRateToCNY,
                    note: $0.note,
                    tagNames: $0.tagNames,
                    flow: $0.flow,
                    categoryName: $0.categoryName,
                    categorySymbol: $0.categorySymbol,
                    categoryColorHex: $0.categoryColorHex
                )
            },
            tags: tags.map {
                TagSnapshot(
                    id: $0.id,
                    name: $0.name,
                    emoji: $0.emojiValue,
                    tintHex: $0.resolvedTintHex,
                    createdAt: $0.createdAt
                )
            },
            goals: goals.map {
                SavingsGoalSnapshot(
                    id: $0.id,
                    createdAt: $0.createdAt,
                    name: $0.name,
                    symbol: $0.symbol,
                    currentAmount: $0.currentAmount,
                    targetAmount: $0.targetAmount,
                    deadline: $0.deadline,
                    tintHex: $0.tintHex
                )
            },
            deposits: deposits.map {
                VaultDepositSnapshot(
                    id: $0.id,
                    date: $0.date,
                    amount: $0.amount,
                    note: $0.note,
                    goalID: $0.goal?.id
                )
            }
        )
    }

    static func replaceLocalData(
        with payload: LedgerBackupPayload,
        context modelContext: ModelContext,
        entries: [LedgerEntry],
        tags: [TagRecord],
        goals: [SavingsGoalRecord],
        deposits: [VaultDepositRecord]
    ) throws {
        deposits.forEach { modelContext.delete($0) }
        goals.forEach { modelContext.delete($0) }
        entries.forEach { modelContext.delete($0) }
        tags.forEach { modelContext.delete($0) }

        for snapshot in payload.tags ?? [] {
            modelContext.insert(
                TagRecord(
                    id: snapshot.id,
                    name: snapshot.name,
                    emoji: snapshot.emoji ?? TagEmojiLibrary.defaultEmoji,
                    tintHex: snapshot.tintHex ?? TagEmojiLibrary.colorHex(for: snapshot.name),
                    createdAt: snapshot.createdAt
                )
            )
        }

        var goalMap: [UUID: SavingsGoalRecord] = [:]
        for snapshot in payload.goals {
            let goal = SavingsGoalRecord(
                id: snapshot.id,
                createdAt: snapshot.createdAt,
                name: snapshot.name,
                symbol: snapshot.symbol,
                currentAmount: snapshot.currentAmount,
                targetAmount: snapshot.targetAmount,
                deadline: snapshot.deadline,
                tintHex: snapshot.tintHex
            )
            modelContext.insert(goal)
            goalMap[snapshot.id] = goal
        }

        for snapshot in payload.entries {
            let category = CategoryItem(
                flow: snapshot.flow,
                name: snapshot.categoryName,
                symbol: snapshot.categorySymbol,
                colorHex: snapshot.categoryColorHex
            )
            let entry = LedgerEntry(
                id: snapshot.id,
                createdAt: snapshot.createdAt,
                amount: snapshot.amount,
                originalAmount: snapshot.originalAmount ?? snapshot.amount,
                currencyCode: snapshot.currencyCode ?? "CNY",
                exchangeRateToCNY: snapshot.exchangeRateToCNY ?? 1,
                note: snapshot.note,
                flow: snapshot.flow,
                category: category,
                tagNames: snapshot.tagNames ?? []
            )
            modelContext.insert(entry)
        }

        for snapshot in payload.deposits {
            let deposit = VaultDepositRecord(
                id: snapshot.id,
                date: snapshot.date,
                amount: snapshot.amount,
                note: snapshot.note,
                goal: snapshot.goalID.flatMap { goalMap[$0] }
            )
            modelContext.insert(deposit)
        }

        try modelContext.save()
    }
}

struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = try LedgerSpreadsheetImporter.decodeText(from: data)
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        guard let encoded = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }

        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(encoded)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct LedgerSpreadsheetImportEntry {
    let createdAt: Date
    let flow: FlowType
    let categoryName: String
    let originalAmount: Double
    let currencyCode: String
    let note: String
    let tagNames: [String]
}

enum LedgerSpreadsheetImporter {
    static let importContentTypes: [UTType] = [.commaSeparatedText, .plainText]

    private enum Column: CaseIterable {
        case date
        case flow
        case category
        case amount
        case currency
        case note
        case tags
    }

    private enum ImportError: LocalizedError {
        case unsupportedEncoding
        case emptyFile
        case invalidHeader
        case noRows
        case invalidDate(row: Int, value: String)
        case invalidFlow(row: Int, value: String)
        case invalidAmount(row: Int, value: String)

        var errorDescription: String? {
            switch self {
            case .unsupportedEncoding:
                return "无法读取导入文件，请确认是 UTF-8 或常见文本编码的表格文件。".appLocalized
            case .emptyFile:
                return "导入文件为空，请先填写模板内容。".appLocalized
            case .invalidHeader:
                return "导入表头不正确，请使用简值提供的模板文件。".appLocalized
            case .noRows:
                return "没有读取到可导入的账单行，请先在模板里填写至少一条账单。".appLocalized
            case .invalidDate(let row, let value):
                return L10n.string("settings.importInvalidDate", locale: L10n.locale, Int64(row), value)
            case .invalidFlow(let row, let value):
                return L10n.string("settings.importInvalidFlow", locale: L10n.locale, Int64(row), value)
            case .invalidAmount(let row, let value):
                return L10n.string("settings.importInvalidAmount", locale: L10n.locale, Int64(row), value)
            }
        }
    }

    static func makeTemplateText(locale: Locale) -> String {
        let rows = [
            [
                "日期".appLocalized(in: locale),
                "类型".appLocalized(in: locale),
                "分类".appLocalized(in: locale),
                "金额".appLocalized(in: locale),
                "币种".appLocalized(in: locale),
                "备注".appLocalized(in: locale),
                "标签".appLocalized(in: locale)
            ],
            ["2026-03-18 08:32", "支出".appLocalized(in: locale), "交通".appLocalized(in: locale), "6", "CNY", "早高峰地铁通勤".appLocalized(in: locale), "通勤/上班".appLocalized(in: locale)],
            ["2026-03-25 19:40", "收入".appLocalized(in: locale), "工资".appLocalized(in: locale), "9800", "CNY", "3 月工资".appLocalized(in: locale), "工资/固定收入".appLocalized(in: locale)],
            ["2026-03-29", "支出".appLocalized(in: locale), "餐饮".appLocalized(in: locale), "88.5", "CNY", "周末聚餐".appLocalized(in: locale), "朋友/周末".appLocalized(in: locale)]
        ]

        return rows.map(csvRow).joined(separator: "\n")
    }

    static func parseEntries(from data: Data) throws -> [LedgerSpreadsheetImportEntry] {
        let text = try decodeText(from: data)
        let rows = parseCSVRows(from: text)
            .map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
            .filter { row in row.contains { !$0.isEmpty } }

        guard !rows.isEmpty else {
            throw ImportError.emptyFile
        }

        let headerMap = try resolveHeaderMap(from: rows[0])
        var importedEntries: [LedgerSpreadsheetImportEntry] = []

        for (offset, row) in rows.dropFirst().enumerated() {
            let rowNumber = offset + 2

            let dateText = value(for: .date, in: row, using: headerMap)
            let flowText = value(for: .flow, in: row, using: headerMap)
            let categoryText = value(for: .category, in: row, using: headerMap)
            let amountText = value(for: .amount, in: row, using: headerMap)
            let currencyText = value(for: .currency, in: row, using: headerMap)
            let noteText = value(for: .note, in: row, using: headerMap)
            let tagsText = value(for: .tags, in: row, using: headerMap)

            let createdAt = try parseDate(from: dateText, rowNumber: rowNumber)
            let flow = try parseFlow(from: flowText, rowNumber: rowNumber)
            let amount = try parseAmount(from: amountText, rowNumber: rowNumber)
            let categoryName = categoryText.isEmpty ? CategoryLibrary.defaultCategory(for: flow).name : categoryText
            let currencyCode = currencyText.isEmpty ? CurrencyCatalog.defaultBaseCode : CurrencyCatalog.normalize(code: currencyText)

            importedEntries.append(
                LedgerSpreadsheetImportEntry(
                    createdAt: createdAt,
                    flow: flow,
                    categoryName: categoryName,
                    originalAmount: abs(amount),
                    currencyCode: currencyCode,
                    note: noteText,
                    tagNames: parseTags(from: tagsText)
                )
            )
        }

        guard !importedEntries.isEmpty else {
            throw ImportError.noRows
        }

        return importedEntries
    }

    static func decodeText(from data: Data) throws -> String {
        let encodings: [String.Encoding] = [.utf8, .utf16LittleEndian, .utf16BigEndian, .unicode]
        for encoding in encodings {
            if let string = String(data: data, encoding: encoding) {
                return string.replacingOccurrences(of: "\u{FEFF}", with: "")
            }
        }

        throw ImportError.unsupportedEncoding
    }

    private static func resolveHeaderMap(from headerRow: [String]) throws -> [Column: Int] {
        var resolved: [Column: Int] = [:]

        for (index, header) in headerRow.enumerated() {
            let normalized = normalize(header)
            guard !normalized.isEmpty else { continue }

            for column in Column.allCases where resolved[column] == nil {
                if headerAliases(for: column).contains(normalized) {
                    resolved[column] = index
                    break
                }
            }
        }

        guard Column.allCases.allSatisfy({ resolved[$0] != nil }) else {
            throw ImportError.invalidHeader
        }

        return resolved
    }

    private static func value(for column: Column, in row: [String], using headerMap: [Column: Int]) -> String {
        guard let index = headerMap[column], index < row.count else { return "" }
        return row[index]
    }

    private static func headerAliases(for column: Column) -> Set<String> {
        let localizedVariants: [String]
        switch column {
        case .date:
            localizedVariants = ["日期", "Date", "日付", "時間"]
        case .flow:
            localizedVariants = ["类型", "收支类型", "Type", "Flow", "種類"]
        case .category:
            localizedVariants = ["分类", "Category", "カテゴリ"]
        case .amount:
            localizedVariants = ["金额", "Amount", "金額"]
        case .currency:
            localizedVariants = ["币种", "Currency", "通貨", "幣種"]
        case .note:
            localizedVariants = ["备注", "Note", "メモ"]
        case .tags:
            localizedVariants = ["标签", "Tags", "タグ"]
        }

        return Set(localizedVariants.map(normalize))
    }

    private static func parseFlow(from rawValue: String, rowNumber: Int) throws -> FlowType {
        let normalized = normalize(rawValue)
        let expenseAliases = flowAliases(for: .expense)
        let incomeAliases = flowAliases(for: .income)

        if expenseAliases.contains(normalized) {
            return .expense
        }
        if incomeAliases.contains(normalized) {
            return .income
        }

        throw ImportError.invalidFlow(row: rowNumber, value: rawValue)
    }

    private static func flowAliases(for flow: FlowType) -> Set<String> {
        var values = Set<String>()
        switch flow {
        case .expense:
            values.formUnion(["支出", "expense", "exp"])
        case .income:
            values.formUnion(["收入", "income", "inc"])
        }

        for locale in AppLanguage.allCases.map(\.locale) {
            values.insert(flow.localizedTitle(in: locale))
        }

        return Set(values.map(normalize))
    }

    private static func parseAmount(from rawValue: String, rowNumber: Int) throws -> Double {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ImportError.invalidAmount(row: rowNumber, value: rawValue)
        }

        let candidates = [
            trimmed
                .replacingOccurrences(of: "￥", with: "")
                .replacingOccurrences(of: "¥", with: "")
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: ""),
            trimmed
                .replacingOccurrences(of: "￥", with: "")
                .replacingOccurrences(of: "¥", with: "")
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
                .replacingOccurrences(of: " ", with: "")
        ]

        for candidate in candidates {
            if let value = Double(candidate) {
                return value
            }
        }

        throw ImportError.invalidAmount(row: rowNumber, value: rawValue)
    }

    private static func parseDate(from rawValue: String, rowNumber: Int) throws -> Date {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ImportError.invalidDate(row: rowNumber, value: rawValue)
        }

        if let serial = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
           serial > 20_000, serial < 80_000
        {
            let base = DateComponents(calendar: Calendar(identifier: .gregorian), year: 1899, month: 12, day: 30).date ?? .distantPast
            return base.addingTimeInterval(serial * 86_400)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        let formats = [
            "yyyy-MM-dd HH:mm",
            "yyyy/MM/dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy",
            "dd/MM/yyyy HH:mm",
            "dd/MM/yyyy"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: trimmed) {
            return date
        }

        throw ImportError.invalidDate(row: rowNumber, value: rawValue)
    }

    private static func parseTags(from rawValue: String) -> [String] {
        let separators = CharacterSet(charactersIn: "/,，、;；|")
        var seen = Set<String>()

        return rawValue
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { tag in
                seen.insert(tag.lowercased()).inserted
            }
    }

    private static func csvRow(_ values: [String]) -> String {
        values.map(escapeCSVValue).joined(separator: ",")
    }

    private static func escapeCSVValue(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func parseCSVRows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var current = ""
        var insideQuotes = false

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]

            if insideQuotes {
                if character == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        current.append("\"")
                        index = nextIndex
                    } else {
                        insideQuotes = false
                    }
                } else {
                    current.append(character)
                }
            } else {
                switch character {
                case "\"":
                    insideQuotes = true
                case ",":
                    row.append(current)
                    current = ""
                case "\n":
                    row.append(current)
                    rows.append(row)
                    row = []
                    current = ""
                case "\r":
                    row.append(current)
                    rows.append(row)
                    row = []
                    current = ""
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                        index = nextIndex
                    }
                default:
                    current.append(character)
                }
            }

            index = text.index(after: index)
        }

        if !current.isEmpty || !row.isEmpty {
            row.append(current)
            rows.append(row)
        }

        return rows
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }
}
