import AppKit
@testable import DockDoor
import Foundation
import XCTest

private struct StubDockBundleResolver: RunningDockBundleResolving {
    var bundlesByID: [String: RunningDockResolvedBundle] = [:]

    func resolveBundle(for pin: RunningDockPin) -> RunningDockResolvedBundle? {
        bundlesByID[pin.id]
    }
}

private final class InMemoryDockPreferencesStore: DockPreferencesStore {
    var values: [String: NativeDockPreferenceValue]
    var syncCount = 0
    var runtimeAutoHideHistory: [Bool] = []

    init(values: [String: NativeDockPreferenceValue] = [:]) {
        self.values = values
    }

    func readValue(forKey key: String) -> NativeDockPreferenceValue? {
        values[key]
    }

    func writeValue(_ value: NativeDockPreferenceValue?, forKey key: String) {
        if let value {
            values[key] = value
        } else {
            values.removeValue(forKey: key)
        }
    }

    @discardableResult
    func synchronize() -> Bool {
        syncCount += 1
        return true
    }

    func applyRuntimeAutoHide(_ enabled: Bool) {
        runtimeAutoHideHistory.append(enabled)
    }
}

final class RunningDockLayoutTests: XCTestCase {
    func testCentersOnOffsetDisplay() {
        let screen = CGRect(x: -1440, y: 90, width: 1440, height: 810)
        let frame = RunningDockLayout.frame(in: screen, appCount: 4)
        XCTAssertEqual(frame.midX, screen.midX)
        XCTAssertEqual(frame.minY, screen.minY + 8)
        XCTAssertEqual(frame.width, 216)
    }

    func testOverflowStaysInsideRotatedDisplay() {
        let screen = CGRect(x: 1920, y: -500, width: 720, height: 1280)
        let frame = RunningDockLayout.frame(in: screen, appCount: 100)
        XCTAssertTrue(screen.contains(frame))
        XCTAssertEqual(frame.width, screen.width - 16)
    }

    func testLeftPlacementCentersVerticallyOnOffsetDisplay() {
        let screen = CGRect(x: -1440, y: 90, width: 1440, height: 810)
        let frame = RunningDockLayout.frame(in: screen, appCount: 4, placement: .left)
        XCTAssertTrue(screen.contains(frame))
        XCTAssertEqual(frame.minX, screen.minX + 8)
        XCTAssertEqual(frame.midY, screen.midY)
        XCTAssertEqual(frame.width, 60)
        XCTAssertEqual(frame.height, 216)
    }

    func testRightPlacementAnchorsToRightEdgeAndClampsVerticalOverflow() {
        let screen = CGRect(x: 1920, y: -500, width: 720, height: 1280)
        let frame = RunningDockLayout.frame(in: screen, appCount: 100, placement: .right)
        XCTAssertTrue(screen.contains(frame))
        XCTAssertEqual(frame.maxX, screen.maxX - 8)
        XCTAssertEqual(frame.midY, screen.midY)
        XCTAssertEqual(frame.width, 60)
        XCTAssertEqual(frame.height, screen.height - 16)
    }

    func testPinUnpinAndUserDefinedOrderPreserved() {
        let zed = RunningDockPin(bundleIdentifier: "dev.zed.Zed", displayName: "Zed", bundlePath: "/Applications/Zed.app")
        let safari = RunningDockPin(bundleIdentifier: "com.apple.Safari", displayName: "Safari", bundlePath: "/Applications/Safari.app")
        let calculator = RunningDockPin(bundleIdentifier: "com.apple.calculator", displayName: "Calculator", bundlePath: "/System/Applications/Calculator.app")

        var pins: [RunningDockPin] = []
        pins = RunningDockPinStore.pin(zed, in: pins)
        pins = RunningDockPinStore.pin(safari, in: pins)
        pins = RunningDockPinStore.pin(calculator, in: pins)
        XCTAssertEqual(pins.map(\.displayName), ["Zed", "Safari", "Calculator"])

        // Re-pinning an existing app updates metadata in place without changing user-defined order
        let updatedSafari = RunningDockPin(bundleIdentifier: "com.apple.Safari", displayName: "Safari Tech", bundlePath: "/Applications/Safari.app")
        pins = RunningDockPinStore.pin(updatedSafari, in: pins)
        XCTAssertEqual(pins.map(\.displayName), ["Zed", "Safari Tech", "Calculator"])

        // Reordering preserves user-defined positions
        pins = RunningDockPinStore.movePin(id: calculator.id, by: -2, in: pins)
        XCTAssertEqual(pins.map(\.displayName), ["Calculator", "Zed", "Safari Tech"])

        // Unpinning removes only the requested pin
        pins = RunningDockPinStore.unpin(id: zed.id, from: pins)
        XCTAssertEqual(pins.map(\.displayName), ["Calculator", "Safari Tech"])
    }

    func testBuildItemsHandlesInactiveRunningAndMissingBundlesInPinnedOrder() {
        let safariPin = RunningDockPin(bundleIdentifier: "com.apple.Safari", displayName: "Safari", bundlePath: "/Applications/Safari.app")
        let zedPin = RunningDockPin(bundleIdentifier: "dev.zed.Zed", displayName: "Zed", bundlePath: "/Applications/Zed.app")
        let missingPin = RunningDockPin(bundleIdentifier: "com.example.RemovedApp", displayName: "RemovedApp", bundlePath: "/Applications/RemovedApp.app")

        let resolver = StubDockBundleResolver(bundlesByID: [
            safariPin.id: RunningDockResolvedBundle(
                bundleURL: URL(fileURLWithPath: "/Applications/Safari.app"),
                bundleIdentifier: "com.apple.Safari",
                displayName: "Safari"
            ),
        ])

        let runningApps = [
            RunningDockRunningApp(
                pid: 300,
                bundleIdentifier: "com.apple.Terminal",
                displayName: "Terminal",
                bundleURL: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            ),
            RunningDockRunningApp(
                pid: 200,
                bundleIdentifier: "dev.zed.Zed",
                displayName: "Zed",
                bundleURL: URL(fileURLWithPath: "/Applications/Zed.app"),
                isHidden: true
            ),
            RunningDockRunningApp(
                pid: 100,
                bundleIdentifier: "com.apple.finder",
                displayName: "Finder",
                bundleURL: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            ),
            RunningDockRunningApp(
                pid: 999,
                bundleIdentifier: "io.github.dannyhashim08.BetterDockDoor",
                displayName: "BetterDockDoor"
            ),
        ]

        let result = RunningDockPinStore.buildItems(
            pins: [safariPin, zedPin, missingPin],
            runningApps: runningApps,
            activePID: 200,
            excludedPID: 999,
            bundleResolver: resolver
        )

        XCTAssertEqual(result.items.map(\.displayName), ["Safari", "Zed", "RemovedApp", "Finder", "Terminal"])

        // 1. Inactive pinned app resolved on disk
        XCTAssertTrue(result.items[0].isPinned)
        XCTAssertFalse(result.items[0].isRunning)
        XCTAssertFalse(result.items[0].isMissingBundle)
        XCTAssertEqual(result.items[0].bundleURL, URL(fileURLWithPath: "/Applications/Safari.app"))

        // 2. Running & active pinned app stays in its pinned slot
        XCTAssertTrue(result.items[1].isPinned)
        XCTAssertTrue(result.items[1].isRunning)
        XCTAssertTrue(result.items[1].isActive)
        XCTAssertTrue(result.items[1].isHidden)
        XCTAssertEqual(result.items[1].pid, 200)

        // 3. Missing bundle stays in its pinned slot and is retained in reconciledPins
        XCTAssertTrue(result.items[2].isPinned)
        XCTAssertFalse(result.items[2].isRunning)
        XCTAssertTrue(result.items[2].isMissingBundle)
        XCTAssertEqual(result.reconciledPins.count, 3)
        XCTAssertEqual(result.reconciledPins[2].bundleIdentifier, "com.example.RemovedApp")

        // 4. Unpinned running apps follow in localized name order without duplicating pinned Zed
        XCTAssertFalse(result.items[3].isPinned)
        XCTAssertTrue(result.items[3].isRunning)
        XCTAssertEqual(result.items[3].displayName, "Finder")
        XCTAssertFalse(result.items[4].isPinned)
        XCTAssertTrue(result.items[4].isRunning)
        XCTAssertEqual(result.items[4].displayName, "Terminal")
    }

    func testPinsPersistAcrossJSONAndBackupRoundTrip() throws {
        let pins = [
            RunningDockPin(bundleIdentifier: "dev.zed.Zed", displayName: "Zed", bundlePath: "/Applications/Zed.app"),
            RunningDockPin(bundleIdentifier: "com.example.Missing", displayName: "Missing", bundlePath: "/Volumes/External/Missing.app"),
        ]
        let encodedPins = try JSONEncoder().encode(pins)
        let decodedPins = try JSONDecoder().decode([RunningDockPin].self, from: encodedPins)
        XCTAssertEqual(decodedPins, pins)

        let backupData = try SettingsBackupManager.encode(domain: ["runningDockPinnedApps": encodedPins])
        let decodedBackup = try SettingsBackupManager.decode(backupData)
        let restoredData = try XCTUnwrap(decodedBackup.settings["runningDockPinnedApps"] as? Data)
        let restoredPins = try JSONDecoder().decode([RunningDockPin].self, from: restoredData)
        XCTAssertEqual(restoredPins, pins)
    }

    func testNativeDockRecoveryRestoresPriorValuesAndKeyAbsence() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let journalURL = tempDir.appendingPathComponent("native-dock-recovery-journal.json")

        let store = InMemoryDockPreferencesStore(values: [
            "autohide": .bool(false),
            "tilesize": .int(48),
        ])
        let coordinator = NativeDockRecoveryCoordinator(store: store, journalURL: journalURL)

        try coordinator.engage()
        XCTAssertTrue(coordinator.hasPendingJournal)
        XCTAssertEqual(store.readValue(forKey: "autohide"), .bool(true))
        XCTAssertEqual(store.readValue(forKey: "autohide-delay"), .double(NativeDockRecoveryCoordinator.suppressionDelay))
        XCTAssertEqual(store.readValue(forKey: "tilesize"), .int(48))
        XCTAssertEqual(store.runtimeAutoHideHistory, [true])

        let restored = try coordinator.restore()
        XCTAssertTrue(restored)
        XCTAssertFalse(coordinator.hasPendingJournal)
        XCTAssertEqual(store.readValue(forKey: "autohide"), .bool(false))
        XCTAssertNil(store.readValue(forKey: "autohide-delay"))
        XCTAssertEqual(store.readValue(forKey: "tilesize"), .int(48))
        XCTAssertEqual(store.runtimeAutoHideHistory, [true, false])
    }

    func testCrashRecoveryReconcilesJournalOnRelaunchWithoutOverwritingOriginalSnapshot() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let journalURL = tempDir.appendingPathComponent("native-dock-recovery-journal.json")

        let store = InMemoryDockPreferencesStore(values: [
            "autohide": .bool(false),
            "autohide-delay": .double(0.25),
        ])
        let firstSession = NativeDockRecoveryCoordinator(store: store, journalURL: journalURL)
        try firstSession.engage()

        // Simulate forced termination: firstSession is abandoned while journal and mutated prefs remain.
        let relaunchedWithHideStillOn = NativeDockRecoveryCoordinator(store: store, journalURL: journalURL)
        relaunchedWithHideStillOn.reconcile(shouldHideNativeDock: true)

        // The journal must still hold the pre-mutation values (false and 0.25), not the mutated ones.
        let persistedJournal = try XCTUnwrap(try relaunchedWithHideStillOn.readJournal())
        XCTAssertEqual(
            persistedJournal.entries,
            [
                NativeDockRecordedPreference(key: "autohide", wasPresent: true, previousValue: .bool(false)),
                NativeDockRecordedPreference(key: "autohide-delay", wasPresent: true, previousValue: .double(0.25)),
            ]
        )

        // Now reconcile with native Dock hiding turned off (or after crash recovery toggle-off).
        let relaunchedForRecovery = NativeDockRecoveryCoordinator(store: store, journalURL: journalURL)
        relaunchedForRecovery.reconcile(shouldHideNativeDock: false)

        XCTAssertFalse(relaunchedForRecovery.hasPendingJournal)
        XCTAssertEqual(store.readValue(forKey: "autohide"), .bool(false))
        XCTAssertEqual(store.readValue(forKey: "autohide-delay"), .double(0.25))
    }
}
