import AppKit
import Defaults
import Foundation
import SwiftUI

// MARK: - Placement & Geometry

enum RunningDockPlacement: String, CaseIterable, Codable, Identifiable, Defaults.Serializable {
    case bottom
    case left
    case right

    var id: String { rawValue }

    var isHorizontal: Bool {
        self == .bottom
    }

    var reservationEdge: ScreenReservationEdge {
        switch self {
        case .bottom:
            .bottom
        case .left:
            .left
        case .right:
            .right
        }
    }

    var localizedName: String {
        switch self {
        case .bottom:
            String(localized: "Bottom", comment: "Replacement Dock screen edge option")
        case .left:
            String(localized: "Left", comment: "Replacement Dock screen edge option")
        case .right:
            String(localized: "Right", comment: "Replacement Dock screen edge option")
        }
    }
}

enum RunningDockLayout {
    static let stride: CGFloat = 50
    static let padding: CGFloat = 8
    static let thickness: CGFloat = 60

    static func frame(
        in visible: CGRect,
        appCount: Int,
        placement: RunningDockPlacement = .bottom
    ) -> CGRect {
        let margin = min(8, min(visible.width, visible.height) / 4)
        let span = CGFloat(max(1, appCount)) * stride + 2 * padding

        switch placement {
        case .bottom:
            let width = min(visible.width - 2 * margin, span)
            let height = min(visible.height - 2 * margin, thickness)
            return CGRect(
                x: visible.midX - width / 2,
                y: visible.minY + margin,
                width: width,
                height: height
            )
        case .left:
            let width = min(visible.width - 2 * margin, thickness)
            let height = min(visible.height - 2 * margin, span)
            return CGRect(
                x: visible.minX + margin,
                y: visible.midY - height / 2,
                width: width,
                height: height
            )
        case .right:
            let width = min(visible.width - 2 * margin, thickness)
            let height = min(visible.height - 2 * margin, span)
            return CGRect(
                x: visible.maxX - margin - width,
                y: visible.midY - height / 2,
                width: width,
                height: height
            )
        }
    }
}

// MARK: - Durable Application Pins & Item Resolution

struct RunningDockPin: Codable, Equatable, Hashable, Identifiable, Defaults.Serializable {
    var bundleIdentifier: String
    var displayName: String
    var bundlePath: String?

    var id: String {
        Self.normalizedKey(bundleIdentifier: bundleIdentifier, bundlePath: bundlePath)
    }

    init(bundleIdentifier: String, displayName: String, bundlePath: String? = nil) {
        let cleanID = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPath = bundlePath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPath: String? = if let cleanPath, !cleanPath.isEmpty {
            URL(fileURLWithPath: cleanPath).standardizedFileURL.path
        } else {
            nil
        }

        self.bundleIdentifier = cleanID
        self.bundlePath = normalizedPath
        if !cleanName.isEmpty {
            self.displayName = cleanName
        } else if let normalizedPath {
            self.displayName = URL(fileURLWithPath: normalizedPath).deletingPathExtension().lastPathComponent
        } else {
            self.displayName = cleanID
        }
    }

    static func normalizedKey(bundleIdentifier: String?, bundlePath: String?) -> String {
        if let bundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bundleIdentifier.isEmpty
        {
            return "id:\(bundleIdentifier.lowercased())"
        }
        if let bundlePath = bundlePath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bundlePath.isEmpty
        {
            let standardized = URL(fileURLWithPath: bundlePath).standardizedFileURL.path
            return "path:\(standardized.lowercased())"
        }
        return ""
    }
}

struct RunningDockRunningApp: Equatable {
    let pid: pid_t
    let bundleIdentifier: String?
    let displayName: String
    let bundleURL: URL?
    let isHidden: Bool
    let icon: NSImage?

    init(
        pid: pid_t,
        bundleIdentifier: String?,
        displayName: String,
        bundleURL: URL? = nil,
        isHidden: Bool = false,
        icon: NSImage? = nil
    ) {
        self.pid = pid
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.bundleURL = bundleURL
        self.isHidden = isHidden
        self.icon = icon
    }

    init(runningApplication app: NSRunningApplication) {
        let fallbackName = app.bundleURL?.deletingPathExtension().lastPathComponent
            ?? app.bundleIdentifier
            ?? String(localized: "Application")
        pid = app.processIdentifier
        bundleIdentifier = app.bundleIdentifier
        displayName = app.localizedName ?? fallbackName
        bundleURL = app.bundleURL
        isHidden = app.isHidden
        icon = app.icon
    }

    var normalizedKey: String {
        RunningDockPin.normalizedKey(bundleIdentifier: bundleIdentifier, bundlePath: bundleURL?.path)
    }

    static func == (lhs: RunningDockRunningApp, rhs: RunningDockRunningApp) -> Bool {
        lhs.pid == rhs.pid
            && lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.displayName == rhs.displayName
            && lhs.bundleURL == rhs.bundleURL
            && lhs.isHidden == rhs.isHidden
    }
}

struct RunningDockResolvedBundle: Equatable {
    let bundleURL: URL
    let bundleIdentifier: String?
    let displayName: String
    let icon: NSImage?

    init(
        bundleURL: URL,
        bundleIdentifier: String?,
        displayName: String,
        icon: NSImage? = nil
    ) {
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.icon = icon
    }

    static func == (lhs: RunningDockResolvedBundle, rhs: RunningDockResolvedBundle) -> Bool {
        lhs.bundleURL == rhs.bundleURL
            && lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.displayName == rhs.displayName
    }
}

protocol RunningDockBundleResolving {
    func resolveBundle(for pin: RunningDockPin) -> RunningDockResolvedBundle?
}

struct WorkspaceDockBundleResolver: RunningDockBundleResolving {
    func resolveBundle(for pin: RunningDockPin) -> RunningDockResolvedBundle? {
        let fileManager = FileManager.default
        var candidateURL: URL?

        if let path = pin.bundlePath, fileManager.fileExists(atPath: path) {
            candidateURL = URL(fileURLWithPath: path).standardizedFileURL
        } else if !pin.bundleIdentifier.isEmpty,
                  let resolvedURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: pin.bundleIdentifier),
                  fileManager.fileExists(atPath: resolvedURL.path)
        {
            candidateURL = resolvedURL.standardizedFileURL
        }

        guard let bundleURL = candidateURL else {
            return nil
        }

        let bundle = Bundle(url: bundleURL)
        let bundleDisplayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent
        let finalName = bundleDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? pin.displayName
            : bundleDisplayName
        let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)

        return RunningDockResolvedBundle(
            bundleURL: bundleURL,
            bundleIdentifier: bundle?.bundleIdentifier ?? (pin.bundleIdentifier.isEmpty ? nil : pin.bundleIdentifier),
            displayName: finalName,
            icon: icon
        )
    }
}

struct RunningDockItem: Identifiable, Equatable {
    let id: String
    let pid: pid_t?
    let bundleIdentifier: String?
    let bundleURL: URL?
    let displayName: String
    let isPinned: Bool
    let isRunning: Bool
    let isActive: Bool
    let isHidden: Bool
    let isMissingBundle: Bool
    let icon: NSImage?

    var asPin: RunningDockPin? {
        let key = RunningDockPin.normalizedKey(bundleIdentifier: bundleIdentifier, bundlePath: bundleURL?.path)
        guard !key.isEmpty else { return nil }
        return RunningDockPin(
            bundleIdentifier: bundleIdentifier ?? "",
            displayName: displayName,
            bundlePath: bundleURL?.path
        )
    }

    static func == (lhs: RunningDockItem, rhs: RunningDockItem) -> Bool {
        lhs.id == rhs.id
            && lhs.pid == rhs.pid
            && lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.bundleURL == rhs.bundleURL
            && lhs.displayName == rhs.displayName
            && lhs.isPinned == rhs.isPinned
            && lhs.isRunning == rhs.isRunning
            && lhs.isActive == rhs.isActive
            && lhs.isHidden == rhs.isHidden
            && lhs.isMissingBundle == rhs.isMissingBundle
    }
}

enum RunningDockPinStore {
    static func sanitize(_ pins: [RunningDockPin]) -> [RunningDockPin] {
        var seen = Set<String>()
        var result: [RunningDockPin] = []
        for pin in pins {
            let key = pin.id
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(pin)
        }
        return result
    }

    static func pin(_ candidate: RunningDockPin, in pins: [RunningDockPin]) -> [RunningDockPin] {
        var current = sanitize(pins)
        let key = candidate.id
        guard !key.isEmpty else { return current }

        if let existingIndex = current.firstIndex(where: { $0.id == key }) {
            var updated = current[existingIndex]
            if !candidate.displayName.isEmpty {
                updated.displayName = candidate.displayName
            }
            if let path = candidate.bundlePath, !path.isEmpty {
                updated.bundlePath = path
            }
            if updated.bundleIdentifier.isEmpty, !candidate.bundleIdentifier.isEmpty {
                updated.bundleIdentifier = candidate.bundleIdentifier
            }
            current[existingIndex] = updated
            return current
        }

        current.append(candidate)
        return current
    }

    static func unpin(id: String, from pins: [RunningDockPin]) -> [RunningDockPin] {
        sanitize(pins).filter { $0.id != id }
    }

    static func movePin(id: String, by offset: Int, in pins: [RunningDockPin]) -> [RunningDockPin] {
        var current = sanitize(pins)
        guard let index = current.firstIndex(where: { $0.id == id }), offset != 0 else {
            return current
        }
        let targetIndex = max(0, min(current.count - 1, index + offset))
        guard targetIndex != index else { return current }
        let element = current.remove(at: index)
        current.insert(element, at: targetIndex)
        return current
    }

    static func buildItems(
        pins: [RunningDockPin],
        runningApps: [RunningDockRunningApp],
        activePID: pid_t?,
        excludedPID: pid_t = ProcessInfo.processInfo.processIdentifier,
        bundleResolver: RunningDockBundleResolving
    ) -> (items: [RunningDockItem], reconciledPins: [RunningDockPin]) {
        let sanitizedPins = sanitize(pins)
        let sortedRunning = runningApps
            .filter { $0.pid != excludedPID }
            .sorted {
                let order = $0.displayName.localizedStandardCompare($1.displayName)
                return order == .orderedSame ? $0.pid < $1.pid : order == .orderedAscending
            }

        var consumedPIDs = Set<pid_t>()
        var reconciledPins: [RunningDockPin] = []
        var items: [RunningDockItem] = []

        for pin in sanitizedPins {
            let matchingApps = sortedRunning.filter { app in
                guard !consumedPIDs.contains(app.pid) else { return false }
                if !pin.bundleIdentifier.isEmpty,
                   let appBundleID = app.bundleIdentifier,
                   appBundleID.caseInsensitiveCompare(pin.bundleIdentifier) == .orderedSame
                {
                    return true
                }
                if let pinPath = pin.bundlePath,
                   let appPath = app.bundleURL?.standardizedFileURL.path,
                   appPath.caseInsensitiveCompare(URL(fileURLWithPath: pinPath).standardizedFileURL.path) == .orderedSame
                {
                    return true
                }
                return app.normalizedKey == pin.id
            }

            if let primaryApp = matchingApps.first(where: { $0.pid == activePID }) ?? matchingApps.first {
                for app in matchingApps {
                    consumedPIDs.insert(app.pid)
                }
                let updatedPin = RunningDockPin(
                    bundleIdentifier: primaryApp.bundleIdentifier ?? pin.bundleIdentifier,
                    displayName: primaryApp.displayName.isEmpty ? pin.displayName : primaryApp.displayName,
                    bundlePath: primaryApp.bundleURL?.path ?? pin.bundlePath
                )
                reconciledPins.append(updatedPin)

                items.append(RunningDockItem(
                    id: pin.id,
                    pid: primaryApp.pid,
                    bundleIdentifier: primaryApp.bundleIdentifier ?? (pin.bundleIdentifier.isEmpty ? nil : pin.bundleIdentifier),
                    bundleURL: primaryApp.bundleURL ?? pin.bundlePath.map { URL(fileURLWithPath: $0) },
                    displayName: primaryApp.displayName,
                    isPinned: true,
                    isRunning: true,
                    isActive: matchingApps.contains { $0.pid == activePID },
                    isHidden: primaryApp.isHidden,
                    isMissingBundle: false,
                    icon: primaryApp.icon
                ))
            } else if let resolved = bundleResolver.resolveBundle(for: pin) {
                let updatedPin = RunningDockPin(
                    bundleIdentifier: pin.bundleIdentifier.isEmpty ? (resolved.bundleIdentifier ?? "") : pin.bundleIdentifier,
                    displayName: resolved.displayName.isEmpty ? pin.displayName : resolved.displayName,
                    bundlePath: resolved.bundleURL.path
                )
                reconciledPins.append(updatedPin)

                items.append(RunningDockItem(
                    id: pin.id,
                    pid: nil,
                    bundleIdentifier: resolved.bundleIdentifier ?? (pin.bundleIdentifier.isEmpty ? nil : pin.bundleIdentifier),
                    bundleURL: resolved.bundleURL,
                    displayName: resolved.displayName,
                    isPinned: true,
                    isRunning: false,
                    isActive: false,
                    isHidden: false,
                    isMissingBundle: false,
                    icon: resolved.icon
                ))
            } else {
                reconciledPins.append(pin)
                items.append(RunningDockItem(
                    id: pin.id,
                    pid: nil,
                    bundleIdentifier: pin.bundleIdentifier.isEmpty ? nil : pin.bundleIdentifier,
                    bundleURL: pin.bundlePath.map { URL(fileURLWithPath: $0) },
                    displayName: pin.displayName,
                    isPinned: true,
                    isRunning: false,
                    isActive: false,
                    isHidden: false,
                    isMissingBundle: true,
                    icon: nil
                ))
            }
        }

        var usedItemIDs = Set(items.map(\.id))
        for app in sortedRunning where !consumedPIDs.contains(app.pid) {
            let baseID = app.normalizedKey.isEmpty ? "pid:\(app.pid)" : app.normalizedKey
            let itemID = usedItemIDs.contains(baseID) ? "\(baseID)#\(app.pid)" : baseID
            usedItemIDs.insert(itemID)

            items.append(RunningDockItem(
                id: itemID,
                pid: app.pid,
                bundleIdentifier: app.bundleIdentifier,
                bundleURL: app.bundleURL,
                displayName: app.displayName,
                isPinned: false,
                isRunning: true,
                isActive: activePID == app.pid,
                isHidden: app.isHidden,
                isMissingBundle: false,
                icon: app.icon
            ))
        }

        return (items: items, reconciledPins: sanitize(reconciledPins))
    }
}

// MARK: - Native Dock Recovery Transaction

enum NativeDockPreferenceValue: Codable, Equatable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
}

struct NativeDockRecordedPreference: Codable, Equatable {
    let key: String
    let wasPresent: Bool
    let previousValue: NativeDockPreferenceValue?
}

struct NativeDockRecoveryJournal: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let recordedAt: Date
    let entries: [NativeDockRecordedPreference]
}

protocol DockPreferencesStore: AnyObject {
    func readValue(forKey key: String) -> NativeDockPreferenceValue?
    func writeValue(_ value: NativeDockPreferenceValue?, forKey key: String)
    @discardableResult
    func synchronize() -> Bool
    func applyRuntimeAutoHide(_ enabled: Bool)
}

final class CFPreferencesDockStore: DockPreferencesStore {
    static let domain: CFString = "com.apple.dock" as CFString

    func readValue(forKey key: String) -> NativeDockPreferenceValue? {
        guard let raw = CFPreferencesCopyAppValue(key as CFString, Self.domain) else {
            return nil
        }
        let typeID = CFGetTypeID(raw)
        if typeID == CFBooleanGetTypeID() {
            return .bool(CFBooleanGetValue((raw as! CFBoolean)))
        }
        if typeID == CFNumberGetTypeID() {
            let number = raw as! NSNumber
            if CFNumberIsFloatType((raw as! CFNumber)) {
                return .double(number.doubleValue)
            }
            return .int(number.intValue)
        }
        if let string = raw as? String {
            return .string(string)
        }
        return nil
    }

    func writeValue(_ value: NativeDockPreferenceValue?, forKey key: String) {
        let cfKey = key as CFString
        switch value {
        case let .bool(flag):
            CFPreferencesSetAppValue(cfKey, flag as CFBoolean, Self.domain)
        case let .int(intValue):
            CFPreferencesSetAppValue(cfKey, NSNumber(value: intValue), Self.domain)
        case let .double(doubleValue):
            CFPreferencesSetAppValue(cfKey, NSNumber(value: doubleValue), Self.domain)
        case let .string(stringValue):
            CFPreferencesSetAppValue(cfKey, stringValue as CFString, Self.domain)
        case nil:
            CFPreferencesSetAppValue(cfKey, nil, Self.domain)
        }
    }

    @discardableResult
    func synchronize() -> Bool {
        CFPreferencesAppSynchronize(Self.domain)
    }

    func applyRuntimeAutoHide(_ enabled: Bool) {
        CoreDockSetAutoHideEnabled(enabled)
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.apple.dock.prefchanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}

final class NativeDockRecoveryCoordinator {
    static let autohideKey = "autohide"
    static let autohideDelayKey = "autohide-delay"
    static let suppressionDelay: Double = 1000.0
    static let ownedKeys: [String] = [autohideKey, autohideDelayKey]

    let store: DockPreferencesStore
    let journalURL: URL

    init(
        store: DockPreferencesStore = CFPreferencesDockStore(),
        journalURL: URL = NativeDockRecoveryCoordinator.defaultJournalURL()
    ) {
        self.store = store
        self.journalURL = journalURL
    }

    static func defaultJournalURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "io.github.dannyhashim08.BetterDockDoor"
        return base
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("native-dock-recovery-journal.json", isDirectory: false)
    }

    var hasPendingJournal: Bool {
        FileManager.default.fileExists(atPath: journalURL.path)
    }

    func readJournal() throws -> NativeDockRecoveryJournal? {
        guard FileManager.default.fileExists(atPath: journalURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: journalURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(NativeDockRecoveryJournal.self, from: data)
    }

    func engage() throws {
        if (try? readJournal()) == nil {
            let entries = Self.ownedKeys.map { key -> NativeDockRecordedPreference in
                let current = store.readValue(forKey: key)
                return NativeDockRecordedPreference(
                    key: key,
                    wasPresent: current != nil,
                    previousValue: current
                )
            }
            let journal = NativeDockRecoveryJournal(
                schemaVersion: NativeDockRecoveryJournal.currentSchemaVersion,
                recordedAt: Date(),
                entries: entries
            )
            let directory = journalURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(journal)
            try data.write(to: journalURL, options: .atomic)
        }

        store.writeValue(.bool(true), forKey: Self.autohideKey)
        store.writeValue(.double(Self.suppressionDelay), forKey: Self.autohideDelayKey)
        store.synchronize()
        store.applyRuntimeAutoHide(true)
    }

    @discardableResult
    func restore() throws -> Bool {
        guard let journal = try readJournal() else {
            return false
        }

        var restoredAutoHide = false
        for entry in journal.entries {
            if entry.wasPresent, let previousValue = entry.previousValue {
                store.writeValue(previousValue, forKey: entry.key)
                if entry.key == Self.autohideKey, case let .bool(flag) = previousValue {
                    restoredAutoHide = flag
                }
            } else {
                store.writeValue(nil, forKey: entry.key)
            }
        }

        store.synchronize()
        store.applyRuntimeAutoHide(restoredAutoHide)
        try? FileManager.default.removeItem(at: journalURL)
        return true
    }

    func reconcile(shouldHideNativeDock: Bool) {
        if shouldHideNativeDock {
            do {
                try engage()
            } catch {
                DebugLogger.log("NativeDockRecoveryCoordinator", details: "Failed to engage native Dock hide: \(error.localizedDescription)")
            }
        } else if hasPendingJournal {
            do {
                try restore()
            } catch {
                DebugLogger.log("NativeDockRecoveryCoordinator", details: "Failed to restore native Dock from journal: \(error.localizedDescription)")
                emergencyRestore()
            }
        }
    }

    func emergencyRestore() {
        if (try? restore()) == true {
            return
        }
        store.writeValue(nil, forKey: Self.autohideDelayKey)
        store.writeValue(.bool(false), forKey: Self.autohideKey)
        store.synchronize()
        store.applyRuntimeAutoHide(false)
        try? FileManager.default.removeItem(at: journalURL)
    }
}

// MARK: - Controller, Model & View

@MainActor
final class RunningDockController: NSObject {
    static let screenReservationSource = "io.github.dannyhashim08.BetterDockDoor.runningDock"

    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: true
    )
    private let model = RunningDockModel()
    private let bundleResolver: RunningDockBundleResolving
    private var defaultsTask: Task<Void, Never>?

    init(bundleResolver: RunningDockBundleResolving = WorkspaceDockBundleResolver()) {
        self.bundleResolver = bundleResolver
        super.init()
        model.controller = self
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.setAccessibilityLabel(String(localized: "Running applications"))
        panel.contentView = NSHostingView(rootView: RunningDockView(model: model))

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.screensDidWakeNotification,
        ] {
            workspace.addObserver(self, selector: #selector(refresh), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        defaultsTask = Task { @MainActor [weak self] in
            for await _ in Defaults.updates([.runningDockPinnedApps, .runningDockPlacement], initial: false) {
                guard !Task.isCancelled, let self else { return }
                refresh()
            }
        }

        refresh()
    }

    func stop() {
        defaultsTask?.cancel()
        defaultsTask = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        ScreenReservations.shared.remove(source: Self.screenReservationSource)
        panel.orderOut(nil)
    }

    @objc func refresh() {
        guard let screen = NSScreen.screens.first else {
            ScreenReservations.shared.remove(source: Self.screenReservationSource)
            panel.orderOut(nil)
            return
        }

        let workspace = NSWorkspace.shared
        let runningSnapshots = workspace.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .map(RunningDockRunningApp.init(runningApplication:))

        let currentPins = Defaults[.runningDockPinnedApps]
        let placement = Defaults[.runningDockPlacement]
        let activePID = workspace.frontmostApplication?.processIdentifier
        let resolved = RunningDockPinStore.buildItems(
            pins: currentPins,
            runningApps: runningSnapshots,
            activePID: activePID,
            bundleResolver: bundleResolver
        )

        if resolved.reconciledPins != currentPins {
            Defaults[.runningDockPinnedApps] = resolved.reconciledPins
        }

        model.placement = placement
        model.items = resolved.items

        guard !model.items.isEmpty else {
            ScreenReservations.shared.remove(source: Self.screenReservationSource)
            panel.orderOut(nil)
            return
        }

        let targetFrame = RunningDockLayout.frame(
            in: screen.visibleFrame,
            appCount: model.items.count,
            placement: placement
        )
        panel.setFrame(targetFrame, display: true)
        panel.orderFrontRegardless()

        ScreenReservations.shared.report(
            ScreenReservation(
                edge: placement.reservationEdge,
                thickness: RunningDockLayout.thickness + 8,
                display: ScreenReservation.allDisplays
            ),
            from: Self.screenReservationSource
        )
    }
}

@MainActor
final class RunningDockModel: ObservableObject {
    @Published var items: [RunningDockItem] = []
    @Published var placement: RunningDockPlacement = .bottom
    weak var controller: RunningDockController?

    var pinnedItems: [RunningDockItem] {
        items.filter(\.isPinned)
    }

    var unpinnedRunningItems: [RunningDockItem] {
        items.filter { !$0.isPinned }
    }

    func activateOrLaunch(_ item: RunningDockItem) {
        if item.isRunning, let pid = item.pid, let app = NSRunningApplication(processIdentifier: pid) {
            if app.isHidden {
                app.unhide()
            }
            if !app.activate(options: [.activateIgnoringOtherApps]) {
                NSSound.beep()
            }
            return
        }

        guard !item.isMissingBundle, let bundleURL = item.bundleURL, FileManager.default.fileExists(atPath: bundleURL.path) else {
            NSSound.beep()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { [weak self] _, error in
            if error != nil {
                DispatchQueue.main.async {
                    NSSound.beep()
                }
            } else {
                DispatchQueue.main.async {
                    self?.controller?.refresh()
                }
            }
        }
    }

    func pin(_ item: RunningDockItem) {
        guard let candidate = item.asPin else { return }
        Defaults[.runningDockPinnedApps] = RunningDockPinStore.pin(candidate, in: Defaults[.runningDockPinnedApps])
        controller?.refresh()
    }

    func unpin(_ item: RunningDockItem) {
        Defaults[.runningDockPinnedApps] = RunningDockPinStore.unpin(id: item.id, from: Defaults[.runningDockPinnedApps])
        controller?.refresh()
    }

    func canMovePin(_ item: RunningDockItem, by offset: Int) -> Bool {
        guard item.isPinned else { return false }
        let pins = RunningDockPinStore.sanitize(Defaults[.runningDockPinnedApps])
        guard let index = pins.firstIndex(where: { $0.id == item.id }) else { return false }
        let target = index + offset
        return target >= 0 && target < pins.count && target != index
    }

    func movePin(_ item: RunningDockItem, by offset: Int) {
        Defaults[.runningDockPinnedApps] = RunningDockPinStore.movePin(
            id: item.id,
            by: offset,
            in: Defaults[.runningDockPinnedApps]
        )
        controller?.refresh()
    }

    func toggleHide(_ item: RunningDockItem) {
        guard let pid = item.pid, let app = NSRunningApplication(processIdentifier: pid) else { return }
        if app.isHidden {
            app.unhide()
            _ = app.activate(options: [.activateIgnoringOtherApps])
        } else {
            app.hide()
        }
        controller?.refresh()
    }

    func quit(_ item: RunningDockItem) {
        guard let pid = item.pid, let app = NSRunningApplication(processIdentifier: pid) else { return }
        _ = app.terminate()
    }
}

private struct RunningDockView: View {
    @ObservedObject var model: RunningDockModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ScrollView(model.placement.isHorizontal ? .horizontal : .vertical, showsIndicators: false) {
            if model.placement.isHorizontal {
                HStack(spacing: 0) {
                    dockItemsContent
                }
                .padding(.horizontal, RunningDockLayout.padding)
            } else {
                VStack(spacing: 0) {
                    dockItemsContent
                }
                .padding(.vertical, RunningDockLayout.padding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    @ViewBuilder
    private var dockItemsContent: some View {
        let pinned = model.pinnedItems
        let unpinned = model.unpinnedRunningItems

        ForEach(pinned) { item in
            dockButton(for: item)
        }

        if !pinned.isEmpty, !unpinned.isEmpty {
            if model.placement.isHorizontal {
                Divider()
                    .frame(height: 32)
                    .padding(.horizontal, 2)
            } else {
                Divider()
                    .frame(width: 32)
                    .padding(.vertical, 2)
            }
        }

        ForEach(unpinned) { item in
            dockButton(for: item)
        }
    }

    private func dockButton(for item: RunningDockItem) -> some View {
        let tooltip = item.isMissingBundle
            ? String(localized: "\(item.displayName) (Application not found)")
            : item.displayName
        let stateDescription: String = if item.isMissingBundle {
            String(localized: "Application not found")
        } else if item.isRunning && item.isHidden {
            String(localized: "Hidden")
        } else if item.isRunning {
            String(localized: "Running")
        } else {
            String(localized: "Pinned")
        }

        return Button {
            model.activateOrLaunch(item)
        } label: {
            Group {
                if model.placement.isHorizontal {
                    VStack(spacing: 2) {
                        itemIcon(for: item)
                        indicatorCapsule(for: item, horizontal: true)
                    }
                    .frame(width: RunningDockLayout.stride, height: 56)
                } else {
                    HStack(spacing: 2) {
                        if model.placement == .left {
                            indicatorCapsule(for: item, horizontal: false)
                        }
                        itemIcon(for: item)
                        if model.placement == .right {
                            indicatorCapsule(for: item, horizontal: false)
                        }
                    }
                    .frame(width: 56, height: RunningDockLayout.stride)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.displayName))
        .accessibilityValue(Text(stateDescription))
        .accessibilityAddTraits(item.isActive ? .isSelected : [])
        .help(tooltip)
        .contextMenu {
            if item.isPinned {
                Button(String(localized: "Unpin from Dock")) {
                    model.unpin(item)
                }
                if model.canMovePin(item, by: -1) {
                    Button(model.placement.isHorizontal ? String(localized: "Move Left in Dock") : String(localized: "Move Up in Dock")) {
                        model.movePin(item, by: -1)
                    }
                }
                if model.canMovePin(item, by: 1) {
                    Button(model.placement.isHorizontal ? String(localized: "Move Right in Dock") : String(localized: "Move Down in Dock")) {
                        model.movePin(item, by: 1)
                    }
                }
            } else if item.asPin != nil {
                Button(String(localized: "Pin to Dock")) {
                    model.pin(item)
                }
            }

            if item.isRunning {
                Divider()
                Button(item.isHidden ? String(localized: "Show") : String(localized: "Hide")) {
                    model.toggleHide(item)
                }
                Button(String(localized: "Quit")) {
                    model.quit(item)
                }
            } else if !item.isMissingBundle {
                Divider()
                Button(String(localized: "Open")) {
                    model.activateOrLaunch(item)
                }
            }
        }
    }

    @ViewBuilder
    private func itemIcon(for item: RunningDockItem) -> some View {
        if item.isMissingBundle {
            Image(systemName: "questionmark.app.dashed")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .frame(width: 36, height: 36)
                .foregroundStyle(.secondary)
                .opacity(0.6)
        } else if let icon = item.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)
                .opacity(item.isHidden ? 0.55 : 1.0)
        } else {
            Image(systemName: "app")
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .frame(width: 36, height: 36)
                .opacity(item.isHidden ? 0.55 : 1.0)
        }
    }

    private func indicatorCapsule(for item: RunningDockItem, horizontal: Bool) -> some View {
        let primarySpan: CGFloat = item.isActive ? 12 : 4
        let fill: Color = if !item.isRunning {
            .clear
        } else if item.isActive {
            .accentColor
        } else {
            .secondary
        }
        return Capsule()
            .fill(fill)
            .frame(
                width: horizontal ? primarySpan : 4,
                height: horizontal ? 4 : primarySpan
            )
    }
}
