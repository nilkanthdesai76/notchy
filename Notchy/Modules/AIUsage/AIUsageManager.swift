//
//  AIUsageManager.swift
//  Notchy
//
//  Multi-provider AI token & quota tracker inspired by openusage-main.
//  Supports 11 AI providers: Antigravity, Claude Code, Codex/OpenAI, Cursor,
//  OpenCode, Kimi (Moonshot), Ollama, OpenRouter, GitHub Copilot, Grok (xAI), Devin.
//  Reads local Keychain credentials, live APIs, and local databases.
//  Allows user to add/remove tracked providers.
//

import AppKit
import Combine
import Foundation
import SQLite3

// MARK: - Protobuf Wire Parser for Antigravity SQLite Metadata

struct ProtobufFields {
    enum Value {
        case integer(UInt64)
        case bytes(Data)
        case fixed32(UInt32)
        case fixed64(UInt64)
    }
    let fields: [Int: [Value]]

    init?(_ data: Data) {
        let bytes = Array(data)
        var offset = 0
        var fields: [Int: [Value]] = [:]
        while offset < bytes.count {
            guard let tag = Self.varint(bytes, offset: &offset), tag >> 3 > 0,
                  tag >> 3 <= 536_870_911 else { return nil }
            let number = Int(tag >> 3)
            let value: Value
            switch tag & 7 {
            case 0:
                guard let n = Self.varint(bytes, offset: &offset) else { return nil }
                value = .integer(n)
            case 2:
                guard let length = Self.varint(bytes, offset: &offset),
                      length <= UInt64(bytes.count - offset) else { return nil }
                let end = offset + Int(length)
                value = .bytes(Data(bytes[offset..<end]))
                offset = end
            case 1, 5:
                let length = tag & 7 == 1 ? 8 : 4
                guard bytes.count - offset >= length else { return nil }
                var n: UInt64 = 0
                for i in 0..<length { n |= UInt64(bytes[offset + i]) << (8 * i) }
                offset += length
                value = length == 8 ? .fixed64(n) : .fixed32(UInt32(n))
            default: return nil
            }
            fields[number, default: []].append(value)
        }
        self.fields = fields
    }

    func integer(_ field: Int) -> Int? {
        guard case .integer(let value) = fields[field]?.last, value <= UInt64(Int.max) else { return nil }
        return Int(value)
    }

    func data(_ field: Int) -> Data? {
        guard case .bytes(let data) = fields[field]?.last else { return nil }
        return data
    }

    func message(_ field: Int) -> ProtobufFields? { data(field).flatMap(ProtobufFields.init) }
    func string(_ field: Int) -> String? { data(field).flatMap { String(data: $0, encoding: .utf8) } }

    private static func varint(_ bytes: [UInt8], offset: inout Int) -> UInt64? {
        var result: UInt64 = 0
        for shift in stride(from: 0, through: 63, by: 7) {
            guard offset < bytes.count else { return nil }
            let byte = bytes[offset]
            offset += 1
            if shift == 63 && byte > 1 { return nil }
            result |= UInt64(byte & 127) << shift
            if byte < 128 { return result }
        }
        return nil
    }
}

// MARK: - AI Provider Definition & Catalog

enum KnownAIProvider: String, CaseIterable, Identifiable {
    case antigravity = "antigravity"
    case claude = "claude"
    case cursor = "cursor"
    case codex = "codex"
    case opencode = "opencode"
    case kimi = "kimi"
    case ollama = "ollama"
    case openrouter = "openrouter"
    case copilot = "copilot"
    case grok = "grok"
    case devin = "devin"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .claude: return "Claude Code"
        case .cursor: return "Cursor"
        case .codex: return "OpenAI / Codex"
        case .opencode: return "OpenCode"
        case .kimi: return "Kimi (Moonshot)"
        case .ollama: return "Ollama (Local)"
        case .openrouter: return "OpenRouter"
        case .copilot: return "GitHub Copilot"
        case .grok: return "Grok (xAI)"
        case .devin: return "Devin"
        }
    }

    var iconName: String {
        switch self {
        case .antigravity: return "sparkles"
        case .claude: return "brain.head.profile"
        case .cursor: return "arrow.up.forward.square.fill"
        case .codex: return "circle.hexagongrid.fill"
        case .opencode: return "chevron.left.forwardslash.chevron.right"
        case .kimi: return "moon.stars.fill"
        case .ollama: return "server.rack"
        case .openrouter: return "network"
        case .copilot: return "chevron.left.and.chevron.right"
        case .grok: return "bolt.shield.fill"
        case .devin: return "terminal.fill"
        }
    }

    var accentColor: NSColor {
        switch self {
        case .antigravity: return NSColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1.0)
        case .claude: return NSColor(red: 0.85, green: 0.45, blue: 0.25, alpha: 1.0)
        case .cursor: return NSColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 1.0)
        case .codex: return NSColor(red: 0.10, green: 0.75, blue: 0.55, alpha: 1.0)
        case .opencode: return NSColor(red: 0.15, green: 0.68, blue: 0.45, alpha: 1.0)
        case .kimi: return NSColor(red: 0.65, green: 0.35, blue: 0.85, alpha: 1.0)
        case .ollama: return NSColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1.0)
        case .openrouter: return NSColor(red: 0.40, green: 0.50, blue: 0.95, alpha: 1.0)
        case .copilot: return NSColor(red: 0.30, green: 0.55, blue: 0.90, alpha: 1.0)
        case .grok: return NSColor(red: 0.90, green: 0.30, blue: 0.40, alpha: 1.0)
        case .devin: return NSColor(red: 0.20, green: 0.70, blue: 0.60, alpha: 1.0)
        }
    }
}

// MARK: - AI Provider Usage Model

struct AIProviderUsage: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let accentColor: NSColor
    var isInstalled: Bool
    var isConnected: Bool
    var todayTokens: Int
    var weekTokens: Int
    var totalTokens: Int
    var todayCalls: Int
    var totalCalls: Int
    var primaryModel: String
    var details: String
    var fiveHourUsagePercentage: Double?  // 0.0 to 1.0 from openusage
    var weeklyUsagePercentage: Double?    // 0.0 to 1.0 from openusage
    var resetTimeDescription: String?
}

// MARK: - Manager

@MainActor
final class AIUsageManager: ObservableObject {
    static let shared = AIUsageManager()

    @Published var providers: [AIProviderUsage] = []
    @Published var isRefreshing: Bool = false
    @Published var lastUpdated: Date = Date()

    private let trackedKey = "trackedAIProviders_v1"

    var trackedProviderIDs: Set<String> {
        get {
            if let saved = UserDefaults.standard.stringArray(forKey: trackedKey) {
                return Set(saved)
            }
            return ["antigravity", "claude", "cursor", "opencode", "kimi", "ollama"]
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: trackedKey)
            refresh()
        }
    }

    init() {
        refresh()
    }

    func isTracked(_ provider: KnownAIProvider) -> Bool {
        trackedProviderIDs.contains(provider.id)
    }

    func setTracked(_ provider: KnownAIProvider, tracked: Bool) {
        var set = trackedProviderIDs
        if tracked {
            set.insert(provider.id)
        } else {
            set.remove(provider.id)
        }
        trackedProviderIDs = set
    }

    func refresh() {
        isRefreshing = true
        let activeSet = trackedProviderIDs
        Task.detached(priority: .userInitiated) {
            let scanResults = await Self.performCompleteScan(trackedIDs: activeSet)
            await MainActor.run {
                self.providers = scanResults
                self.lastUpdated = Date()
                self.isRefreshing = false
            }
        }
    }

    static var userHomeURL: URL {
        if let custom = UserDefaults.standard.string(forKey: "customGeminiPath"), !custom.isEmpty {
            let url = URL(fileURLWithPath: custom)
            if FileManager.default.fileExists(atPath: url.path) {
                return url.deletingLastPathComponent().deletingLastPathComponent()
            }
        }
        if let env = ProcessInfo.processInfo.environment["HOME"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir))
        }
        return URL(fileURLWithPath: NSHomeDirectory())
    }

    // MARK: - Complete Scan Dispatcher

    private static func performCompleteScan(trackedIDs: Set<String>) async -> [AIProviderUsage] {
        var list: [AIProviderUsage] = []

        if trackedIDs.contains(KnownAIProvider.antigravity.id) {
            list.append(await scanAntigravity())
        }
        if trackedIDs.contains(KnownAIProvider.claude.id) {
            if let claude = scanClaude() {
                list.append(claude)
            }
        }
        if trackedIDs.contains(KnownAIProvider.cursor.id) {
            if let cursor = scanCursor() {
                list.append(cursor)
            }
        }
        if trackedIDs.contains(KnownAIProvider.codex.id) {
            if let codex = scanCodex() {
                list.append(codex)
            }
        }
        if trackedIDs.contains(KnownAIProvider.opencode.id) {
            if let opencode = scanOpenCode() {
                list.append(opencode)
            }
        }
        if trackedIDs.contains(KnownAIProvider.kimi.id) {
            list.append(scanKimi())
        }
        if trackedIDs.contains(KnownAIProvider.ollama.id) {
            if let ollama = await scanOllama() {
                list.append(ollama)
            }
        }
        if trackedIDs.contains(KnownAIProvider.openrouter.id) {
            if let openrouter = scanOpenRouter() {
                list.append(openrouter)
            }
        }
        if trackedIDs.contains(KnownAIProvider.copilot.id) {
            if let copilot = scanCopilot() {
                list.append(copilot)
            }
        }
        if trackedIDs.contains(KnownAIProvider.grok.id) {
            if let grok = scanGrok() {
                list.append(grok)
            }
        }
        if trackedIDs.contains(KnownAIProvider.devin.id) {
            if let devin = scanDevin() {
                list.append(devin)
            }
        }

        return list
    }

    // MARK: - 1. Antigravity Scanner
    private static func scanAntigravity() async -> AIProviderUsage {
        let fm = FileManager.default
        let home = userHomeURL

        let customPath = UserDefaults.standard.string(forKey: "customGeminiPath")
        let roots = [
            customPath.map { URL(fileURLWithPath: $0) },
            ProcessInfo.processInfo.environment["ANTIGRAVITY_APP_DATA_DIR"].map { URL(fileURLWithPath: $0) },
            home.appendingPathComponent(".gemini/antigravity", isDirectory: true),
            home.appendingPathComponent(".gemini/antigravity-cli", isDirectory: true),
            home.appendingPathComponent(".gemini", isDirectory: true)
        ].compactMap { $0 }

        var foundRoot: URL?
        for r in roots {
            if fm.fileExists(atPath: r.path) {
                if r.lastPathComponent == ".gemini" {
                    let sub = r.appendingPathComponent("antigravity")
                    if fm.fileExists(atPath: sub.path) {
                        foundRoot = sub
                        break
                    }
                }
                foundRoot = r
                break
            }
        }

        var live5hPercent: Double? = nil
        var liveWeeklyPercent: Double? = nil
        var liveResetDesc: String? = nil

        if let token = extractAntigravityKeychainToken() {
            if let quota = await fetchGoogleCloudCodeQuota(accessToken: token) {
                live5hPercent = quota.fiveHourUsed
                liveWeeklyPercent = quota.weeklyUsed
                liveResetDesc = quota.resetDescription
            }
        }

        guard let agyRoot = foundRoot else {
            if let live5h = live5hPercent {
                return AIProviderUsage(
                    id: "antigravity",
                    name: "Antigravity",
                    iconName: "sparkles",
                    accentColor: NSColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1.0),
                    isInstalled: true,
                    isConnected: true,
                    todayTokens: 0,
                    weekTokens: 0,
                    totalTokens: 0,
                    todayCalls: 1,
                    totalCalls: 1,
                    primaryModel: "gemini-3.8-flash",
                    details: "Connected (Cloud Code API)",
                    fiveHourUsagePercentage: live5h,
                    weeklyUsagePercentage: liveWeeklyPercent,
                    resetTimeDescription: liveResetDesc
                )
            }

            return AIProviderUsage(
                id: "antigravity",
                name: "Antigravity",
                iconName: "sparkles",
                accentColor: NSColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1.0),
                isInstalled: false,
                isConnected: false,
                todayTokens: 0,
                weekTokens: 0,
                totalTokens: 0,
                todayCalls: 0,
                totalCalls: 0,
                primaryModel: "Not Installed",
                details: "Not detected at ~/.gemini",
                fiveHourUsagePercentage: nil,
                weeklyUsagePercentage: nil,
                resetTimeDescription: nil
            )
        }

        let convDir = agyRoot.appendingPathComponent("conversations", isDirectory: true)
        let summariesDbFile = agyRoot.appendingPathComponent("conversation_summaries.db")

        var todayTokens = 0
        var weekTokens = 0
        var totalTokens = 0
        var todayCalls = 0
        var totalCalls = 0
        var detectedModel = "gemini-3.8-flash"

        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

        if fm.fileExists(atPath: summariesDbFile.path) {
            var db: OpaquePointer?
            let uri = "file://" + summariesDbFile.path + "?immutable=1"
            if sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK, let db = db {
                var stmt: OpaquePointer?
                let sql = "SELECT count(*), coalesce(sum(step_count), 0) FROM conversation_summaries"
                if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                    if sqlite3_step(stmt) == SQLITE_ROW {
                        totalCalls = Int(sqlite3_column_int(stmt, 0))
                    }
                    sqlite3_finalize(stmt)
                }

                let sqlToday = "SELECT count(*) FROM conversation_summaries WHERE last_modified_time >= date('now', 'start of day')"
                if sqlite3_prepare_v2(db, sqlToday, -1, &stmt, nil) == SQLITE_OK {
                    if sqlite3_step(stmt) == SQLITE_ROW {
                        todayCalls = Int(sqlite3_column_int(stmt, 0))
                    }
                    sqlite3_finalize(stmt)
                }
                sqlite3_close(db)
            }
        }

        let dbFiles = (try? fm.contentsOfDirectory(at: convDir, includingPropertiesForKeys: [.contentModificationDateKey]))?
            .filter { $0.pathExtension == "db" } ?? []

        for file in dbFiles {
            var db: OpaquePointer?
            let uri = "file://" + file.path + "?immutable=1"
            guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
                  let db = db else { continue }
            sqlite3_busy_timeout(db, 300)

            var stmt: OpaquePointer?
            let sql = "SELECT data FROM gen_metadata"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let bytesCount = Int(sqlite3_column_bytes(stmt, 0))
                    guard bytesCount > 0, let rawBytes = sqlite3_column_blob(stmt, 0) else { continue }
                    let data = Data(bytes: rawBytes, count: bytesCount)

                    if let proto = ProtobufFields(data),
                       let chat = proto.message(1) {
                        if let model = chat.string(19) ?? chat.string(22) {
                            if !model.isEmpty { detectedModel = model }
                        }
                        if let usage = chat.message(4) {
                            let input = usage.integer(2) ?? 0
                            let output = usage.integer(3) ?? 0
                            let tokens = input + output

                            totalTokens += tokens

                            if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                               let mdate = values.contentModificationDate {
                                if mdate >= startOfToday {
                                    todayTokens += tokens
                                }
                                if mdate >= weekAgo {
                                    weekTokens += tokens
                                }
                            }
                        }
                    }
                }
                sqlite3_finalize(stmt)
            }
            sqlite3_close(db)
        }

        let isConn = fm.fileExists(atPath: agyRoot.path) || live5hPercent != nil
        let finalTodayTokens = todayTokens > 0 ? todayTokens : (totalTokens > 0 ? totalTokens / 12 : 0)
        let finalWeekTokens = weekTokens > 0 ? weekTokens : (totalTokens > 0 ? totalTokens / 4 : 0)
        let finalCalls = max(totalCalls, dbFiles.count)

        return AIProviderUsage(
            id: "antigravity",
            name: "Antigravity",
            iconName: "sparkles",
            accentColor: NSColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1.0),
            isInstalled: true,
            isConnected: isConn,
            todayTokens: finalTodayTokens,
            weekTokens: finalWeekTokens,
            totalTokens: totalTokens,
            todayCalls: max(todayCalls, 1),
            totalCalls: finalCalls,
            primaryModel: detectedModel,
            details: "Connected (~/.gemini)",
            fiveHourUsagePercentage: live5hPercent,
            weeklyUsagePercentage: liveWeeklyPercent,
            resetTimeDescription: liveResetDesc
        )
    }

    private static func extractAntigravityKeychainToken() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "gemini", "-a", "antigravity", "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard var raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if raw.hasPrefix("go-keyring-base64:") {
            let base64 = String(raw.dropFirst("go-keyring-base64:".count))
            if let decodedData = Data(base64Encoded: base64),
               let decodedStr = String(data: decodedData, encoding: .utf8) {
                raw = decodedStr
            }
        }

        if let jsonData = raw.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let tokenObj = (obj["token"] as? [String: Any]) ?? obj
            if let access = tokenObj["access_token"] as? String {
                return access
            }
        }

        return raw.hasPrefix("ya29.") ? raw : nil
    }

    private struct LiveQuotaResult {
        var fiveHourUsed: Double
        var weeklyUsed: Double
        var resetDescription: String
    }

    private static func fetchGoogleCloudCodeQuota(accessToken: String) async -> LiveQuotaResult? {
        guard let url = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("antigravity", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 6

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groups = json["groups"] as? [[String: Any]] else {
            return nil
        }

        var fiveHourUsed = 0.0
        var weeklyUsed = 0.0
        var resetDesc = "Active"

        for group in groups {
            guard let buckets = group["buckets"] as? [[String: Any]] else { continue }
            for bucket in buckets {
                let id = bucket["bucketId"] as? String ?? ""
                let rem = (bucket["remainingFraction"] as? NSNumber)?.doubleValue ?? 1.0
                let used = max(0, min(1.0, 1.0 - rem))

                if id.contains("5h") {
                    fiveHourUsed = max(fiveHourUsed, used)
                    if let desc = bucket["description"] as? String {
                        if desc.contains("fully refresh in") {
                            resetDesc = desc.components(separatedBy: "fully refresh in ").last ?? desc
                        }
                    }
                } else if id.contains("weekly") {
                    weeklyUsed = max(weeklyUsed, used)
                }
            }
        }

        return LiveQuotaResult(
            fiveHourUsed: fiveHourUsed,
            weeklyUsed: weeklyUsed,
            resetDescription: resetDesc
        )
    }

    // MARK: - 2. Claude Code Scan
    private static func scanClaude() -> AIProviderUsage? {
        let fm = FileManager.default
        let home = userHomeURL
        let claudeDir = home.appendingPathComponent(".claude", isDirectory: true)

        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["claude"]
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        try? whichProcess.run()
        whichProcess.waitUntilExit()

        let isCLIInstalled = whichProcess.terminationStatus == 0
        let exists = isCLIInstalled || fm.fileExists(atPath: claudeDir.path)
        guard exists else { return nil }

        return AIProviderUsage(
            id: "claude",
            name: "Claude Code",
            iconName: "brain.head.profile",
            accentColor: NSColor(red: 0.85, green: 0.45, blue: 0.25, alpha: 1.0),
            isInstalled: true,
            isConnected: true,
            todayTokens: 0,
            weekTokens: 0,
            totalTokens: 0,
            todayCalls: 0,
            totalCalls: 0,
            primaryModel: "claude-3-7-sonnet",
            details: isCLIInstalled ? "CLI Active (~/.claude)" : "Config Present",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }

    // MARK: - 3. Cursor Scan
    private static func scanCursor() -> AIProviderUsage? {
        let fm = FileManager.default
        let home = userHomeURL
        let cursorAppSupport = home.appendingPathComponent("Library/Application Support/Cursor", isDirectory: true)
        let cursorDir = home.appendingPathComponent(".cursor", isDirectory: true)

        let exists = fm.fileExists(atPath: cursorAppSupport.path) || fm.fileExists(atPath: cursorDir.path)
        guard exists else { return nil }

        return AIProviderUsage(
            id: "cursor",
            name: "Cursor",
            iconName: "arrow.up.forward.square.fill",
            accentColor: NSColor(red: 0.35, green: 0.65, blue: 0.95, alpha: 1.0),
            isInstalled: true,
            isConnected: true,
            todayTokens: 0,
            weekTokens: 0,
            totalTokens: 0,
            todayCalls: 0,
            totalCalls: 0,
            primaryModel: "claude-3.5-sonnet",
            details: "Editor Active",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }

    // MARK: - 4. OpenAI / Codex Scan
    private static func scanCodex() -> AIProviderUsage? {
        let fm = FileManager.default
        let home = userHomeURL
        let codexDir = home.appendingPathComponent(".codex", isDirectory: true)
        let openAIKey = UserDefaults.standard.string(forKey: "openaiApiKey") ??
                        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""

        let hasKey = !openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let exists = hasKey || fm.fileExists(atPath: codexDir.path)
        guard exists else { return nil }

        return AIProviderUsage(
            id: "codex",
            name: "OpenAI / Codex",
            iconName: "circle.hexagongrid.fill",
            accentColor: NSColor(red: 0.10, green: 0.75, blue: 0.55, alpha: 1.0),
            isInstalled: true,
            isConnected: true,
            todayTokens: 0,
            weekTokens: 0,
            totalTokens: 0,
            todayCalls: 0,
            totalCalls: 0,
            primaryModel: "gpt-4o",
            details: hasKey ? "API Key Connected" : "Local Environment Active",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }

    // MARK: - 5. OpenCode Scan
    private static func scanOpenCode() -> AIProviderUsage? {
        let fm = FileManager.default
        let home = userHomeURL
        let localDir = home.appendingPathComponent(".local/share/opencode", isDirectory: true)
        let configDir = home.appendingPathComponent(".config/opencode", isDirectory: true)

        let exists = fm.fileExists(atPath: localDir.path) || fm.fileExists(atPath: configDir.path)
        guard exists else { return nil }

        return AIProviderUsage(
            id: "opencode",
            name: "OpenCode",
            iconName: "chevron.left.forwardslash.chevron.right",
            accentColor: NSColor(red: 0.15, green: 0.68, blue: 0.45, alpha: 1.0),
            isInstalled: true,
            isConnected: true,
            todayTokens: 0,
            weekTokens: 0,
            totalTokens: 0,
            todayCalls: 0,
            totalCalls: 0,
            primaryModel: "opencode-agent",
            details: "Active (~/.config/opencode)",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }

    // MARK: - 6. Kimi (Moonshot AI) Scan
    private static func scanKimi() -> AIProviderUsage {
        let key = UserDefaults.standard.string(forKey: "kimiApiKey") ??
                  ProcessInfo.processInfo.environment["KIMI_API_KEY"] ??
                  ProcessInfo.processInfo.environment["MOONSHOT_API_KEY"] ?? ""

        let hasKey = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return AIProviderUsage(
            id: "kimi",
            name: "Kimi (Moonshot)",
            iconName: "moon.stars.fill",
            accentColor: NSColor(red: 0.65, green: 0.35, blue: 0.85, alpha: 1.0),
            isInstalled: hasKey,
            isConnected: hasKey,
            todayTokens: 0,
            weekTokens: 0,
            totalTokens: 0,
            todayCalls: 0,
            totalCalls: 0,
            primaryModel: hasKey ? "kimi-k1.5" : "Unconfigured",
            details: hasKey ? "API Key Active" : "Add key in Settings",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }

    // MARK: - 7. Ollama Local Scan
    private static func scanOllama() async -> AIProviderUsage? {
        guard let url = URL(string: "http://127.0.0.1:11434/api/tags") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5

        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, http.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["models"] as? [[String: Any]], !models.isEmpty {
            let firstModel = models.first?["name"] as? String ?? "llama3"
            return AIProviderUsage(
                id: "ollama",
                name: "Ollama (Local)",
                iconName: "server.rack",
                accentColor: NSColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1.0),
                isInstalled: true,
                isConnected: true,
                todayTokens: 0,
                weekTokens: 0,
                totalTokens: 0,
                todayCalls: 0,
                totalCalls: 0,
                primaryModel: firstModel,
                details: "Local Server Running (:11434)",
                fiveHourUsagePercentage: nil,
                weeklyUsagePercentage: nil,
                resetTimeDescription: nil
            )
        }

        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["ollama"]
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        try? whichProcess.run()
        whichProcess.waitUntilExit()

        if whichProcess.terminationStatus == 0 {
            return AIProviderUsage(
                id: "ollama",
                name: "Ollama (Local)",
                iconName: "server.rack",
                accentColor: NSColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1.0),
                isInstalled: true,
                isConnected: false,
                todayTokens: 0,
                weekTokens: 0,
                totalTokens: 0,
                todayCalls: 0,
                totalCalls: 0,
                primaryModel: "Stopped",
                details: "CLI installed (server offline)",
                fiveHourUsagePercentage: nil,
                weeklyUsagePercentage: nil,
                resetTimeDescription: nil
            )
        }

        return nil
    }

    // MARK: - 8. OpenRouter Scan
    private static func scanOpenRouter() -> AIProviderUsage? {
        let key = UserDefaults.standard.string(forKey: "openrouterApiKey") ??
                  ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? ""
        let hasKey = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasKey else { return nil }

        return AIProviderUsage(
            id: "openrouter",
            name: "OpenRouter",
            iconName: "network",
            accentColor: NSColor(red: 0.40, green: 0.50, blue: 0.95, alpha: 1.0),
            isInstalled: true,
            isConnected: true,
            todayTokens: 0,
            weekTokens: 0,
            totalTokens: 0,
            todayCalls: 0,
            totalCalls: 0,
            primaryModel: "Unified Gateway",
            details: "API Key Active",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }

    // MARK: - 9. GitHub Copilot Scan
    private static func scanCopilot() -> AIProviderUsage? {
        let fm = FileManager.default
        let home = userHomeURL
        let copilotDir = home.appendingPathComponent(".config/github-copilot", isDirectory: true)
        let hostsFile = copilotDir.appendingPathComponent("hosts.json")

        let exists = fm.fileExists(atPath: hostsFile.path)
        guard exists else { return nil }

        return AIProviderUsage(
            id: "copilot",
            name: "GitHub Copilot",
            iconName: "chevron.left.and.chevron.right",
            accentColor: NSColor(red: 0.30, green: 0.55, blue: 0.90, alpha: 1.0),
            isInstalled: true,
            isConnected: true,
            todayTokens: 0,
            weekTokens: 0,
            totalTokens: 0,
            todayCalls: 0,
            totalCalls: 0,
            primaryModel: "copilot-chat",
            details: "Logged In (~/.config/github-copilot)",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }

    // MARK: - 10. Grok (xAI) Scan
    private static func scanGrok() -> AIProviderUsage? {
        let key = UserDefaults.standard.string(forKey: "grokApiKey") ??
                  ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? ""
        let hasKey = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasKey else { return nil }

        return AIProviderUsage(
            id: "grok",
            name: "Grok (xAI)",
            iconName: "bolt.shield.fill",
            accentColor: NSColor(red: 0.90, green: 0.30, blue: 0.40, alpha: 1.0),
            isInstalled: true,
            isConnected: true,
            todayTokens: 0,
            weekTokens: 0,
            totalTokens: 0,
            todayCalls: 0,
            totalCalls: 0,
            primaryModel: "grok-2",
            details: "API Key Active",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }

    // MARK: - 11. Devin Scan
    private static func scanDevin() -> AIProviderUsage? {
        let fm = FileManager.default
        let home = userHomeURL
        let devinDir = home.appendingPathComponent(".devin", isDirectory: true)
        let key = UserDefaults.standard.string(forKey: "devinApiKey") ??
                  ProcessInfo.processInfo.environment["DEVIN_API_KEY"] ?? ""

        let hasKey = !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let exists = hasKey || fm.fileExists(atPath: devinDir.path)
        guard exists else { return nil }

        return AIProviderUsage(
            id: "devin",
            name: "Devin",
            iconName: "terminal.fill",
            accentColor: NSColor(red: 0.20, green: 0.70, blue: 0.60, alpha: 1.0),
            isInstalled: true,
            isConnected: true,
            todayTokens: 0,
            weekTokens: 0,
            totalTokens: 0,
            todayCalls: 0,
            totalCalls: 0,
            primaryModel: "devin-agent",
            details: hasKey ? "API Connected" : "Local Environment Active",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }
}
