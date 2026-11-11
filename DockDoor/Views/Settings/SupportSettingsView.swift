import Defaults
import SwiftUI

struct SupportSettingsView: View {
    @ObservedObject var updaterState: UpdaterState
    @StateObject private var permissionsChecker = PermissionsChecker()

    init(updaterState: UpdaterState) {
        self.updaterState = updaterState
    }

    var body: some View {
        SettingsFormView {
            permissionsSection
            diagnosticsSection
            acknowledgmentsSection
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        SettingsSection("Permissions", footer: "Changes to permissions require an app restart to take effect.") {
            PermissionRow(
                title: "Accessibility",
                description: "Required for dock hover detection and window switcher hotkeys",
                icon: "accessibility",
                isGranted: permissionsChecker.accessibilityPermission,
                action: { SystemPreferencesHelper.openAccessibilityPreferences() }
            )
            .settingsSearchTarget("support.accessibility")

            PermissionRow(
                title: "Screen Recording",
                description: "Required for capturing window previews. Without this, only compact list view is available.",
                icon: "record.circle",
                isGranted: permissionsChecker.screenRecordingPermission,
                action: { SystemPreferencesHelper.openScreenRecordingPreferences() }
            )
            .settingsSearchTarget("support.screenRecording")
        }
    }

    private var diagnosticsSection: some View {
        SettingsSection("Diagnostics") {
            LabeledContent("Current Version", value: updaterState.currentVersion)
            DebugLoggingRow()
                .settingsSearchTarget("support.debugLogging")
        }
    }

    // MARK: - Acknowledgments Section

    @ViewBuilder
    private var acknowledgmentsSection: some View {
        SettingsSection("Community Contributors") {
            CreditRow(name: "illavoluntas", detail: "Website, documentation, Discord moderation", icon: "person")
        }

        SettingsSection("Translation Contributors") {
            ForEach(Self.translators, id: \.profile) { translator in
                CreditRow(
                    name: translator.name,
                    detail: translator.language,
                    icon: "globe",
                    url: URL(string: "https://crowdin.com/profile/\(translator.profile)")
                )
            }
        }

        SettingsSection("Audio Assets") {
            CreditRow(
                name: "Magic Glow",
                detail: "IENBA · CC0",
                icon: "speaker.wave.2",
                url: URL(string: "https://freesound.org/s/752274/")
            )
        }
    }

    private static let translators: [(name: String, language: String, profile: String)] = [
        ("Rocco 'Roccobot' Casadei", "Italian", "Roccobot"),
        ("favorsjewelry5", "Chinese Traditional", "favorsjewelry5"),
        ("Денис Єгоров", "Ukrainian", "makedonsky47"),
        ("HuangxinDong", "Chinese Simplified", "HuangxinDong"),
        ("don.julien.7", "German", "JuGro1332"),
        ("awaustin", "Chinese Simplified", "awaustin"),
        ("illavoluntas", "French", "illavoluntas"),
        ("Diamant", "French", "Diamant"),
    ]
}

// MARK: - Helper Views

private struct PermissionRow: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let icon: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon, color: isGranted ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isGranted ? .green : .red)
                    .font(.callout)

                if !isGranted {
                    Button("Grant") {
                        action()
                    }
                    .buttonStyle(.settings)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DebugLoggingRow: View {
    @Default(.debugMode) var debugMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                SettingsIcon(systemName: "ant.fill", color: .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Debug Logging")
                        .font(.body)
                    Text("Capture performance metrics for troubleshooting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $debugMode)
                    .labelsHidden()
            }

            if debugMode {
                HStack(spacing: 12) {
                    Button("Export Logs") {
                        if let url = DebugLogger.exportLogs() {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                    .buttonStyle(.settings)

                    Button("Clear Logs") {
                        DebugLogger.clearLogs()
                    }
                    .buttonStyle(.settings)
                }
                .padding(.leading, 40)
            }
        }
    }
}

private struct CreditRow: View {
    let name: String
    let detail: String
    let icon: String
    var url: URL?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: name)
                    .lineLimit(1)
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let url {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(url.host() ?? url.absoluteString)
                .accessibilityLabel("Open \(name)")
            }
        }
    }
}
