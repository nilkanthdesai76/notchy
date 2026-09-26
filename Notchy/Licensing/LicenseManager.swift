import Foundation
import IOKit
import Security
import Combine
import AppKit

// MARK: - Models

enum LicenseState: Equatable {
    case loading
    case trial(daysLeft: Int)
    case trialExpired
    case licensed(plan: String)
    case offlineGrace(plan: String, daysLeft: Int)
}

struct LicenseCache: Codable {
    let licenseKey: String
    let email: String
    let plan: String
    let validatedAt: Date
    var gracePeriodDays: Int { 7 }
    var isGraceExpired: Bool {
        let graceCutoff = validatedAt.addingTimeInterval(Double(gracePeriodDays) * 86400)
        return Date() > graceCutoff
    }
    var graceDaysLeft: Int {
        let graceCutoff = validatedAt.addingTimeInterval(Double(gracePeriodDays) * 86400)
        let left = graceCutoff.timeIntervalSince(Date())
        return max(0, Int(ceil(left / 86400)))
    }
}

struct ActivatedDevice: Identifiable, Codable {
    var id: String { device_id }
    let device_id: String
    let device_name: String
    let activated_at: String
    let last_seen_at: String
}

// MARK: - LicenseManager

@MainActor
final class LicenseManager: ObservableObject {

    static let shared = LicenseManager()

    // MARK: Config
    private let baseURL = "https://piaymlvggvuhdalprtwa.supabase.co/rest/v1/rpc"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpYXltbHZnZ3Z1aGRhbHBydHdhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA0MTk5MDYsImV4cCI6MjEwNTk5NTkwNn0.uj_dK-WvyTTB4qr0QZFRr-lGxURj8X-rwjTunpu0DLc"
    private let pricingURL = "https://www.nildesai.com/notchy#pricing"

    // MARK: Published state
    @Published private(set) var state: LicenseState = .loading
    @Published private(set) var activatedDevices: [ActivatedDevice] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // MARK: Private
    private let keychainService = "com.nilkanth.Notchy.License"

    private init() {}

    // MARK: - Hardware UUID

    var hardwareUUID: String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        let cfUUID = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
        return cfUUID?.takeRetainedValue() as? String ?? UUID().uuidString
    }

    var deviceName: String {
        Host.current().localizedName ?? "Unknown Mac"
    }

    // MARK: - Boot Check

    func checkOnLaunch() async {
        state = .loading
        isLoading = true
        defer { isLoading = false }

        // 1. Check keychain for cached license
        if let cache = loadLicenseCache() {
            if cache.isGraceExpired {
                // Try to re-validate online
                if let plan = await validateOnline(licenseKey: cache.licenseKey) {
                    saveLicenseCache(LicenseCache(licenseKey: cache.licenseKey, email: cache.email, plan: plan, validatedAt: Date()))
                    state = .licensed(plan: plan)
                } else {
                    // Offline AND grace expired → treat as expired (but don't delete key — user may reconnect)
                    state = .trialExpired
                }
            } else {
                // Within grace — go licensed immediately, validate silently in background
                state = .licensed(plan: cache.plan)
                Task { await silentRevalidate(cache: cache) }
            }
            return
        }

        // 2. No license — check trial via Supabase
        do {
            let trialResponse = try await callFunction("check_or_start_trial", body: ["p_device_id": hardwareUUID])
            let expired = trialResponse["expired"] as? Bool ?? true
            let daysLeft = trialResponse["days_left"] as? Int ?? 0
            state = expired ? .trialExpired : .trial(daysLeft: daysLeft)
        } catch {
            // Network failure on first launch — assume trial active (offline tolerance)
            state = .trial(daysLeft: 2)
        }
    }

    // MARK: - Activate License

    func activateLicense(key: String, email: String) async -> Result<Void, LicenseError> {
        let trimmedKey = key.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            let err = LicenseError.emailRequired
            errorMessage = err.localizedDescription
            return .failure(err)
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await callFunction("activate_license", body: [
                "p_license_key": trimmedKey,
                "p_email": trimmedEmail,
                "p_device_id": hardwareUUID,
                "p_device_name": deviceName
            ])

            if let ok = result["ok"] as? Bool, ok {
                let plan = result["plan"] as? String ?? "single"
                let returnEmail = (result["email"] as? String) ?? trimmedEmail
                saveLicenseCache(LicenseCache(licenseKey: trimmedKey, email: returnEmail, plan: plan, validatedAt: Date()))
                state = .licensed(plan: plan)
                return .success(())
            } else {
                let errCode = result["error"] as? String ?? "unknown"
                if errCode == "device_limit_reached" {
                    // Parse devices for deregistration UI
                    if let rawDevices = result["devices"] as? [[String: Any]] {
                        let data = try JSONSerialization.data(withJSONObject: rawDevices)
                        activatedDevices = (try? JSONDecoder().decode([ActivatedDevice].self, from: data)) ?? []
                    }
                    return .failure(.deviceLimitReached)
                }
                let err = LicenseError(code: errCode)
                errorMessage = err.localizedDescription
                return .failure(err)
            }
        } catch {
            let err = LicenseError.networkError(error.localizedDescription)
            errorMessage = err.localizedDescription
            return .failure(err)
        }
    }

    // MARK: - Deactivate Device

    func deactivateDevice(licenseKey: String, deviceID: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await callFunction("deactivate_device", body: [
                "p_license_key": licenseKey,
                "p_device_id": deviceID
            ])
            return result["ok"] as? Bool ?? false
        } catch {
            return false
        }
    }

    // MARK: - Deactivate THIS Mac

    func deactivateCurrentDevice() async -> Bool {
        guard let cache = loadLicenseCache() else { return false }
        let ok = await deactivateDevice(licenseKey: cache.licenseKey, deviceID: hardwareUUID)
        if ok {
            deleteLicenseCache()
            state = .trialExpired
        }
        return ok
    }

    // MARK: - Fetch Device List

    func fetchDevices(licenseKey: String) async {
        do {
            let result = try await callFunction("list_license_devices", body: ["p_license_key": licenseKey])
            if let rawDevices = result["devices"] as? [[String: Any]] {
                let data = try JSONSerialization.data(withJSONObject: rawDevices)
                activatedDevices = (try? JSONDecoder().decode([ActivatedDevice].self, from: data)) ?? []
            }
        } catch { }
    }

    // MARK: - Buy

    func openBuyPage(plan: String = "single") {
        if let url = URL(string: pricingURL) {
            NSWorkspace.shared.open(url)
        }
    }

    var currentLicenseKey: String? { loadLicenseCache()?.licenseKey }
    var currentEmail: String? { loadLicenseCache()?.email }
    var currentPlan: String? { loadLicenseCache()?.plan }

    // MARK: - Private Helpers

    private func silentRevalidate(cache: LicenseCache) async {
        if let plan = await validateOnline(licenseKey: cache.licenseKey) {
            saveLicenseCache(LicenseCache(licenseKey: cache.licenseKey, email: cache.email, plan: plan, validatedAt: Date()))
            if case .offlineGrace = state { state = .licensed(plan: plan) }
        }
    }

    private func validateOnline(licenseKey: String) async -> String? {
        do {
            let result = try await callFunction("validate_license", body: [
                "p_license_key": licenseKey,
                "p_device_id": hardwareUUID
            ])
            guard result["valid"] as? Bool == true else { return nil }
            return result["plan"] as? String ?? "single"
        } catch {
            return nil
        }
    }

    private func callFunction(_ name: String, body: [String: String]) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/\(name)") else { throw LicenseError.networkError("bad url") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 10

        let (data, _) = try await URLSession.shared.data(for: req)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Keychain

    private func saveLicenseCache(_ cache: LicenseCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "license_cache",
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadLicenseCache() -> LicenseCache? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "license_cache",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(LicenseCache.self, from: data)
    }

    private func deleteLicenseCache() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "license_cache"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - LicenseError

enum LicenseError: Error, LocalizedError {
    case emailRequired
    case emailMismatch
    case invalidKey
    case deviceLimitReached
    case licenseRevoked
    case licenseRefunded
    case networkError(String)
    case unknown(String)

    init(code: String) {
        switch code {
        case "email_required":        self = .emailRequired
        case "email_mismatch":        self = .emailMismatch
        case "invalid_key":           self = .invalidKey
        case "device_limit_reached":  self = .deviceLimitReached
        case "license_refunded":      self = .licenseRefunded
        case "license_revoked", "license_expired": self = .licenseRevoked
        default:                      self = .unknown(code)
        }
    }

    var errorDescription: String? {
        switch self {
        case .emailRequired:         return "Please enter the email address used during purchase."
        case .emailMismatch:         return "Email does not match the purchase email for this license key."
        case .invalidKey:            return "Invalid license key. Please check and try again."
        case .deviceLimitReached:    return "This license is already active on the maximum number of devices."
        case .licenseRevoked:        return "This license has been revoked or expired."
        case .licenseRefunded:       return "This license has been refunded and is no longer valid."
        case .networkError(let msg): return "Network error: \(msg)"
        case .unknown(let code):     return "Activation failed (\(code))."
        }
    }
}
