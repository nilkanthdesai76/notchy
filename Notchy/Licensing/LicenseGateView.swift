import SwiftUI

// MARK: - License Gate (full-screen modal shown when trial expires)

struct LicenseGateView: View {
    @ObservedObject private var lm = LicenseManager.shared
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

                    Text("Enter your license key or purchase Notchy to continue.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 36)
                .padding(.horizontal, 32)

                Divider()
                    .background(.white.opacity(0.08))
                    .padding(.vertical, 24)

                // License key entry
                VStack(alignment: .leading, spacing: 8) {
                    Text("LICENSE KEY")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1.5)

                    HStack(spacing: 10) {
                        TextField("NOTCHY-XXXX-XXXX-XXXX", text: $licenseKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
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
                                        .frame(width: 56, height: 36)
                                } else {
                                    Text("Activate")
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                }
                            }
                            .foregroundStyle(.black)
                            .background(Color(licensingHex: "#ff2b84"))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
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

                // Buy options
                VStack(spacing: 10) {
                    Text("Don't have a license?")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))

                    HStack(spacing: 10) {
                        BuyOptionButton(
                            title: "Single License",
                            price: "$9.99",
                            subtitle: "1 Mac · One-time",
                            color: Color(licensingHex: "#ff2b84")
                        ) {
                            lm.openBuyPage(plan: "single")
                        }

                        BuyOptionButton(
                            title: "Pro License",
                            price: "$14.99",
                            subtitle: "2 Macs · One-time",
                            color: Color(licensingHex: "#3ec7ff")
                        ) {
                            lm.openBuyPage(plan: "pro")
                        }
                    }

                    Text("After purchase, your license key will arrive in your email.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
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
        let result = await lm.activateLicense(key: licenseKey)
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

// MARK: - Buy Option Button

private struct BuyOptionButton: View {
    let title: String
    let price: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(price)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
