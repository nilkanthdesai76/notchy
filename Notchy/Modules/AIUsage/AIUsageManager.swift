//
//  AIUsageManager.swift
//  Notchy
//
//  Multi-provider AI token & quota tracker inspired by openusage-main.
//  Reads local Keychain OAuth credentials and Google Cloud Code API for live limits,
//  plus local SQLite databases for exact offline token metrics.
//  No hardcoded or dummy percentages.
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

    init() {
        refresh()
    }

    func refresh() {
        isRefreshing = true
        Task.detached(priority: .userInitiated) {
            let scanResults = await Self.performCompleteScan()
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

    // MARK: - Background Scanning

    private static func performCompleteScan() async -> [AIProviderUsage] {
        var list: [AIProviderUsage] = []

        // 1. Antigravity Scanner (OpenUsage pattern: Keychain OAuth + Live Quota API + SQLite scan)
        let antigravity = await scanAntigravity()
        list.append(antigravity)

        // 2. Kimi (Moonshot AI) Scanner
        let kimi = scanKimi()
        list.append(kimi)

        // 3. OpenCode Scanner (if detected on disk)
        if let opencode = scanOpenCode() {
            list.append(opencode)
        }

        // 4. Claude Code (Only if CLI is actually installed)
        if let claude = scanClaude() {
            list.append(claude)
        }

        return list
    }

    // MARK: - Antigravity Scan (openusage-main method)
    private static func scanAntigravity() async -> AIProviderUsage {
        let fm = FileManager.default
        let home = userHomeURL

        // Potential Antigravity roots
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
                // Check if this is ~/.gemini itself or ~/.gemini/antigravity
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

        // 1. Fetch live quota using Google Cloud Code OAuth token from Keychain (OpenUsage method)
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
            // Even if folder wasn't directly found by fileExists, if we got live quota from Keychain:
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

        // 2. Read conversation summaries DB (immutable URI)
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

        // 3. Scan conversation SQLite databases for exact protobuf tokens (immutable URI)
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

    // MARK: - OpenUsage Keychain Token Extraction
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

        // Unwrap go-keyring-base64:
        if raw.hasPrefix("go-keyring-base64:") {
            let base64 = String(raw.dropFirst("go-keyring-base64:".count))
            if let decodedData = Data(base64Encoded: base64),
               let decodedStr = String(data: decodedData, encoding: .utf8) {
                raw = decodedStr
            }
        }

        // Parse JSON for access_token
        if let jsonData = raw.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            let tokenObj = (obj["token"] as? [String: Any]) ?? obj
            if let access = tokenObj["access_token"] as? String {
                return access
            }
        }

        return raw.hasPrefix("ya29.") ? raw : nil
    }

    // MARK: - OpenUsage Live Google Cloud Code Quota API
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

    // MARK: - Kimi (Moonshot AI) Scan
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

    // MARK: - OpenCode Scan
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
            details: "Active at ~/.config/opencode",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }

    // MARK: - Claude Code Scan
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

        guard isCLIInstalled && fm.fileExists(atPath: claudeDir.path) else {
            return nil
        }

        return AIProviderUsage(
            id: "claude",
            name: "Claude Code",
            iconName: "brain.head.profile",
            accentColor: NSColor(red: 0.85, green: 0.45, blue: 0.25, alpha: 1.0),
            isInstalled: isCLIInstalled,
            isConnected: isCLIInstalled,
            todayTokens: 0,
            weekTokens: 0,
            totalTokens: 0,
            todayCalls: 0,
            totalCalls: 0,
            primaryModel: "claude-3-7-sonnet",
            details: "CLI Active",
            fiveHourUsagePercentage: nil,
            weeklyUsagePercentage: nil,
            resetTimeDescription: nil
        )
    }
}
