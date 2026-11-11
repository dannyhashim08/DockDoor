import AppKit
import SwiftUI

enum RunningDockLayout {
    static let stride: CGFloat = 50
    static let padding: CGFloat = 8

    static func frame(in visible: CGRect, appCount: Int) -> CGRect {
        let margin = min(8, min(visible.width, visible.height) / 4)
        let width = min(visible.width - 2 * margin, CGFloat(max(1, appCount)) * stride + 2 * padding)
        let height = min(visible.height - 2 * margin, 60)
        return CGRect(x: visible.midX - width / 2, y: visible.minY + margin, width: width, height: height)
    }
}

@MainActor
final class RunningDockController: NSObject {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: true
    )
    private let model = RunningDockModel()

    override init() {
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.setAccessibilityLabel(String(localized: "Running applications"))
        panel.contentView = NSHostingView(rootView: RunningDockView(model: model))
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification, NSWorkspace.didUnhideApplicationNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.screensDidWakeNotification]
        {
            workspace.addObserver(self, selector: #selector(refresh), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        refresh()
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        panel.orderOut(nil)
    }

    @objc private func refresh() {
        guard let screen = NSScreen.screens.first else {
            panel.orderOut(nil)
            return
        }
        let workspace = NSWorkspace.shared
        model.apps = workspace.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }.sorted {
            let order = ($0.localizedName ?? "").localizedStandardCompare($1.localizedName ?? "")
            return order == .orderedSame ? $0.processIdentifier < $1.processIdentifier : order == .orderedAscending
        }
        model.activePID = workspace.frontmostApplication?.processIdentifier
        guard !model.apps.isEmpty else {
            panel.orderOut(nil)
            return
        }
        panel.setFrame(RunningDockLayout.frame(in: screen.visibleFrame, appCount: model.apps.count), display: true)
        panel.orderFrontRegardless()
    }
}

private final class RunningDockModel: ObservableObject {
    @Published var apps: [NSRunningApplication] = []
    @Published var activePID: pid_t?
}

private struct RunningDockView: View {
    @ObservedObject var model: RunningDockModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(model.apps, id: \.processIdentifier) { app in
                    let name = app.localizedName ?? app.bundleIdentifier ?? String(localized: "Application")
                    Button {
                        if app.isHidden { app.unhide() }
                        if !app.activate(options: [.activateIgnoringOtherApps]) { NSSound.beep() }
                    } label: {
                        VStack(spacing: 2) {
                            if let icon = app.icon {
                                Image(nsImage: icon).resizable().interpolation(.high).frame(width: 36, height: 36)
                            } else {
                                Image(systemName: "app").frame(width: 36, height: 36)
                            }
                            Capsule()
                                .fill(model.activePID == app.processIdentifier ? Color.accentColor : Color.secondary)
                                .frame(width: model.activePID == app.processIdentifier ? 12 : 4, height: 4)
                        }
                        .frame(width: RunningDockLayout.stride, height: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(name))
                    .accessibilityAddTraits(model.activePID == app.processIdentifier ? .isSelected : [])
                    .help(name)
                }
            }
            .padding(.horizontal, RunningDockLayout.padding)
        }
        .frame(maxHeight: .infinity)
        .background {
            if reduceTransparency { Color(nsColor: .windowBackgroundColor) } else { Rectangle().fill(.regularMaterial) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}
