import SwiftUI

// MARK: - License Gate (full-screen modal shown when trial expires)

struct LicenseGateView: View {
    @ObservedObject private var lm = LicenseManager.shared
    @State private var email = ""
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var showDeviceList = false

    var body: some View {
        ZStack {
            // Dark blurred background
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("Your trial has ended")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Enter your purchase email and license key to continue.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 36)
                .padding(.horizontal, 32)

                Divider()
                    .background(.white.opacity(0.08))
                    .padding(.vertical, 20)

                // Activation credentials
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PURCHASE EMAIL")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1.5)

                        TextField("you@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("LICENSE KEY")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1.5)

                        HStack(spacing: 10) {
                            TextField("NOTCHY-XXXX-XXXX-XXXX", text: $licenseKey)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.12), lineWidth: 1))
                                .autocorrectionDisabled()
                                .onSubmit { Task { await activate() } }

                            Button {
                                Task { await activate() }
                            } label: {
                                Group {
                                    if isActivating {
                                        ProgressView().scaleEffect(0.7)
                                            .frame(width: 56, height: 34)
                                    } else {
                                        Text("Activate")
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 9)
                                    }
                                }
                                .foregroundStyle(.black)
                                .background(Color(licensingHex: "#ff2b84"))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty || email.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
                        }
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(licensingHex: "#ff6b6b"))
                    }
                }
                .padding(.horizontal, 32)

                Divider()
                    .background(.white.opacity(0.08))
                    .padding(.vertical, 24)

                // Buy link
                VStack(spacing: 8) {
                    Button {
                        lm.openBuyPage()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Don't have a license? Get one at nildesai.com/notchy")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(licensingHex: "#ff2b84"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)
            }
            .frame(width: 420)
            .background(Color(licensingHex: "#0d0b0f"))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 40, y: 10)
        }
        // Device-limit sheet
        .sheet(isPresented: $showDeviceList) {
            DeviceLimitView(licenseKey: licenseKey) {
                showDeviceList = false
                Task { await activate() }
            }
        }
    }

    private func activate() async {
        isActivating = true
        errorMessage = nil
        let result = await lm.activateLicense(key: licenseKey, email: email)
        isActivating = false
        switch result {
        case .success:
            break  // state automatically updates
        case .failure(let err):
            if case .deviceLimitReached = err {
                showDeviceList = true
            } else {
                errorMessage = err.errorDescription
            }
        }
    }
}

// MARK: - Device Limit View (shown when limit hit)

struct DeviceLimitView: View {
    let licenseKey: String
    let onDone: () -> Void

    @ObservedObject private var lm = LicenseManager.shared
    @State private var isDeactivating: String? = nil   // device_id being deactivated
    @State private var done = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Device Limit Reached")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(20)

            Divider().background(.white.opacity(0.08))

            Text("This license is already active on \(lm.activatedDevices.count) device(s). Deactivate one to add this Mac.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .padding(20)

            VStack(spacing: 8) {
                ForEach(lm.activatedDevices) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.device_name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text("Last seen: \(relativeTime(device.last_seen_at))")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        Button {
                            Task {
                                isDeactivating = device.device_id
                                let ok = await lm.deactivateDevice(licenseKey: licenseKey, deviceID: device.device_id)
                                isDeactivating = nil
                                if ok { onDone() }
                            }
                        } label: {
                            if isDeactivating == device.device_id {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Text("Deactivate")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color(licensingHex: "#ff6b6b"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(licensingHex: "#ff6b6b").opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .background(.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Button("Cancel") { onDone() }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 20)
        }
        .frame(width: 380)
        .background(Color(licensingHex: "#0d0b0f"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            Task { await lm.fetchDevices(licenseKey: licenseKey) }
        }
    }

    private func relativeTime(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return iso }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Trial Banner (shown inside the notch panel footer)

struct TrialBannerView: View {
    @ObservedObject private var lm = LicenseManager.shared

    var body: some View {
        Group {
            if case .trial(let days) = lm.state {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(licensingHex: "#fbbf24"))

                    Text(days == 1 ? "Trial: 1 day left" : "Trial: \(days) days left")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Button("Upgrade →") {
                        lm.openBuyPage(plan: "single")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(licensingHex: "#ff2b84"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.white.opacity(0.04))
            }
        }
    }
}

// MARK: - Color hex helper

private extension Color {
    init(licensingHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:  (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (1, 1, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }
}
