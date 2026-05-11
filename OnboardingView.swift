import SwiftUI
import AppKit

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var page = 0
    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: WelcomePage()
                case 1: OrgUUIDPage()
                case 2: SessionKeyPage()
                case 3: FinishPage()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
            .padding(.top, 32)
            .padding(.bottom, 16)

            footer
        }
        .frame(width: 760, height: 580)
    }

    private var footer: some View {
        HStack {
            Button("Skip") { onComplete() }
                .buttonStyle(.borderless)
                .opacity(page < pageCount - 1 ? 1 : 0)
                .disabled(page >= pageCount - 1)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if page > 0 {
                    Button("Back") { page -= 1 }
                }
                if page < pageCount - 1 {
                    Button("Next") { page += 1 }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Get started") { onComplete() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 144, height: 144)
            } else {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 96, weight: .light))
                    .foregroundColor(.accentColor)
            }
            VStack(spacing: 8) {
                Text("Welcome to ClaudeUsage")
                    .font(.system(size: 32, weight: .bold))
                Text("Live claude.ai usage in your menu bar.")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            Text("Setup takes about a minute. We'll grab two values from your browser and paste them into Settings.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
                .padding(.top, 16)
            Spacer()
        }
    }
}

// MARK: - Page 2: Org UUID

private struct OrgUUIDPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader("Step 1 of 3", title: "Find your Organization UUID")
            Text("Sign into claude.ai, open DevTools (⌥⌘I), click the **Network** tab, then click **Settings → Usage** in claude.ai.")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DevToolsMock(tab: "Network") {
                VStack(alignment: .leading, spacing: 6) {
                    requestRow("kyc_status", highlight: false)
                    requestRow("overage_credit_grant", highlight: false)
                    requestRow("organizations/<UUID>/usage", highlight: true)
                    requestRow("payment_method", highlight: false)
                    requestRow("prepaid/credits", highlight: false)
                }
            }
            .frame(height: 220)

            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.orange)
                Text("Copy the UUID between `organizations/` and `/usage` — a long hex string like `6fe01348-…-898cd8ad55f3`.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func requestRow(_ url: String, highlight: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .font(.caption2)
                .foregroundColor(highlight ? .primary : .secondary)
            Text(url)
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(highlight ? .primary : .secondary)
            Spacer()
            Text("200")
                .font(.caption.monospacedDigit())
                .foregroundColor(.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(highlight ? Color.yellow.opacity(0.35) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(highlight ? Color.orange : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Page 3: sessionKey

private struct SessionKeyPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepHeader("Step 2 of 3", title: "Find your sessionKey")
            Text("In the same DevTools window, click **Application** → **Storage → Cookies → https://claude.ai**.")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DevToolsMock(tab: "Application") {
                VStack(spacing: 0) {
                    cookieHeader
                    Divider()
                    cookieRow(name: "_ga", value: "GA1.2.123456…", highlight: false)
                    Divider()
                    cookieRow(name: "sessionKey", value: "sk-ant-sid01-XXXXX…", highlight: true)
                    Divider()
                    cookieRow(name: "intercom-session", value: "abc123…", highlight: false)
                    Divider()
                    cookieRow(name: "lastActiveOrganization", value: "6fe01348-…", highlight: false)
                }
            }
            .frame(height: 220)

            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(.orange)
                Text("The sessionKey is a secret — treat it like a password. Stored locally in macOS Keychain.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var cookieHeader: some View {
        HStack {
            Text("Name").font(.caption.bold()).foregroundColor(.secondary)
                .frame(width: 200, alignment: .leading)
            Text("Value").font(.caption.bold()).foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(white: 0.95))
    }

    private func cookieRow(name: String, value: String, highlight: Bool) -> some View {
        HStack {
            Text(name)
                .font(.system(.callout, design: .monospaced))
                .frame(width: 200, alignment: .leading)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(highlight ? .primary : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(highlight ? Color.yellow.opacity(0.35) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(highlight ? Color.orange : Color.clear, lineWidth: 2)
                )
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

// MARK: - Page 4: Finish

private struct FinishPage: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                stepHeader("Step 3 of 3", title: "Paste them into Settings")
                Text("Click the brain icon in your menu bar → **Settings…** and paste both values into the Authentication section.")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            settingsMock
                .frame(width: 540)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Click Save. Numbers populate in the menu bar within ~60 seconds.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var settingsMock: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 11, height: 11)
                Circle().fill(Color.yellow).frame(width: 11, height: 11)
                Circle().fill(Color.green).frame(width: 11, height: 11)
                Spacer()
                Text("ClaudeUsage Settings").font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(white: 0.93))

            VStack(alignment: .leading, spacing: 12) {
                Text("Authentication").font(.headline).foregroundColor(.primary)

                mockField(label: "Organization UUID",
                          value: "6fe01348-92af-466b-9234-…",
                          secure: false)
                mockField(label: "sessionKey",
                          value: String(repeating: "•", count: 32),
                          secure: true)

                HStack {
                    Spacer()
                    Text("Save")
                        .font(.callout.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .cornerRadius(6)
                }
            }
            .padding(16)
            .background(Color(NSColor.textBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private func mockField(label: String, value: String, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            HStack {
                Text(value)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2))
            .cornerRadius(5)
        }
    }
}

// MARK: - Shared bits

private func stepHeader(_ step: String, title: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(step)
            .font(.caption.weight(.semibold))
            .foregroundColor(.accentColor)
            .textCase(.uppercase)
        Text(title)
            .font(.system(size: 26, weight: .bold))
    }
}

/// Stylized "browser DevTools" frame.
private struct DevToolsMock<Content: View>: View {
    let tab: String
    @ViewBuilder let content: Content

    private let tabs = ["Elements", "Console", "Network", "Application", "Sources"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Window chrome
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 11, height: 11)
                Circle().fill(Color.yellow).frame(width: 11, height: 11)
                Circle().fill(Color.green).frame(width: 11, height: 11)
                Spacer()
                Text("DevTools — claude.ai")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Spacer().frame(width: 36)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(white: 0.93))

            // Tab strip
            HStack(spacing: 4) {
                ForEach(tabs, id: \.self) { name in
                    VStack(spacing: 4) {
                        Text(name)
                            .font(.caption)
                            .foregroundColor(name == tab ? .primary : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 6)
                        Rectangle()
                            .fill(name == tab ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .background(Color(white: 0.97))

            Divider()

            content
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.textBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}
