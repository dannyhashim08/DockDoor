# BetterDockDoor progress

## Baseline and first native increment

**Source baseline.** baf6425a981b09acb79189ec568e7c189b70a0ce on the personal fork. The installed upstream app, version 1.42.4, opened to General. The pinned source declares version 1.18.3. Xcode resolved its dependencies, then stopped at the upstream team certificate requirement. The fork uses local signing. Settings search, permission-related categories, window switching, previews, widgets and backup controls were visible in the settings navigation or General pane. Global shortcuts, previews and OS interactions still need regression testing.

**Changes.** Debug and Release build BetterDockDoor.app with distinct io.github.dannyhashim08.BetterDockDoor.debug and io.github.dannyhashim08.BetterDockDoor identifiers. Standard defaults and the existing backup manager follow the product bundle ID. The Swift module remains DockDoor to preserve the XCTest imports. Local Mac signing replaces the upstream team selection. The fork has its own icon and debug notification prefix. The upstream update controller is no longer started; its update controls and paid-product promotions were removed from the active UI.

**First Dock behavior.** In General → Application Basics, Show running-app Dock creates a bottom-centered nonactivating panel on the primary screen. Regular applications appear in name order with icons, names for accessibility, hover tips and a selected-app indicator. Clicking an app requests activation and unhides it if needed. Overflow scrolls horizontally. The coordinator responds to workspace, wake and display notifications. Turning the setting off releases the panel and observers. Apple’s Dock preferences are never edited by this feature. Upstream enhancement mode is the initial configuration.

| Check | Actual result |
|---|---|
| Installed DockDoor Free startup | Verified General via the app's accessibility tree. |
| Replacement panel compilation | Swift compiler type-checked the production panel for arm64 macOS 13. |
| Layout tests | The production controller and its two XCTest cases built in an isolated package on macOS 27.2.1. Both tests passed. Cases cover an offset screen and overflow on a portrait screen. |
| Target configuration | plutil parsed both the Xcode project and Info.plist. The shared scheme and both test host paths refer to BetterDockDoor.app. |
| Fork icon | actool emitted BetterDockDoor.icns and matching CFBundleIconName and CFBundleIconFile. |
| Release product | Xcode Build For Profiling succeeded using the Release configuration. The arm64 app was packaged, extracted and passed strict nested code-signature verification. |
| Debug build and launch | Xcode built and ran the fork on My Mac. General showed the new switch, initially off. |
| Full Xcode tests | 131 passed, zero failed and zero skipped in the shared DockDoor scheme, verified in the Xcode result bundle. |
| Live Dock panel | Turning the switch on and closing settings exposed ten named running-app buttons in the accessibility tree. Clicking Xcode moved selection from Brave Browser to Xcode. |
| Hot-plug, fullscreen, Mission Control, permission revocation, sleep/wake and idle CPU | Pending on physical hardware. No performance measurements recorded. |

## Milestone 2 — Durable application pins, screen edges, and native-Dock recovery

**Implemented behavior.**
- **Durable application pins (`RunningDockPin`, `RunningDockPinStore`, `Defaults.Keys.runningDockPinnedApps`).** Pinned applications persist in user-defined order and round-trip through `Defaults` and `SettingsBackupManager`. `RunningDockPinStore.buildItems` merges pinned apps with live `NSWorkspace` applications:
  - Running pinned apps stay in their user-defined pinned slot, display running/active capsules, and refresh cached bundle metadata.
  - Inactive pinned apps resolve their bundle on disk (`WorkspaceDockBundleResolver`) and launch via `NSWorkspace.shared.openApplication` when clicked or chosen from the context menu.
  - Pinned apps whose bundle is missing or on an unmounted volume remain in their pinned slot (`isMissingBundle = true`, placeholder icon, `"Application not found"` accessibility value/tooltip, beep on click) and are never silently dropped on relaunch.
  - Unpinned running apps follow after a section divider in localized standard name order.
  - Users can pin, unpin, and reorder pinned apps via each Dock item's context menu or in **Settings → General → Application Basics**.
- **Left, right, and bottom placement (`RunningDockPlacement`, `Defaults.Keys.runningDockPlacement`).** `RunningDockLayout.frame(in:appCount:placement:)` positions the panel along the `.bottom` (horizontal), `.left` (vertical), or `.right` (vertical) edge of `visibleFrame` and reports the active edge thickness to `ScreenReservations.shared` (`io.github.dannyhashim08.BetterDockDoor.runningDock`) while visible. `RunningDockView` adapts its scroll axis, divider orientation, and active/running indicator placement to the selected edge.
- **Journaled native-Dock recovery transaction (`NativeDockRecoveryCoordinator`, `NativeDockRecoveryJournal`, `Defaults.Keys.hideNativeDock`).**
  - Before modifying `com.apple.dock` (`autohide` and `autohide-delay`), `NativeDockRecoveryCoordinator.engage()` records each owned key's prior presence (`wasPresent`) and typed value (`NativeDockPreferenceValue`) atomically to `native-dock-recovery-journal.json` in `Application Support`.
  - If a journal already exists on disk from a prior crash or forced exit, `engage()` preserves the original pre-mutation snapshot rather than overwriting it with mutated values.
  - `restore()` restores only the owned keys recorded in the journal (removing keys that were previously absent), synchronizes `com.apple.dock`, updates live Dock auto-hide via `CoreDockSetAutoHideEnabled` without terminating `com.apple.Dock.agent` (preserving Mission Control, Spaces, and Exposé), and deletes the journal.
  - `AppDelegate` reconciles the journal on launch, on setting changes, and in `applicationWillTerminate`.
  - Emergency recovery (`Restore Apple's Dock`) is exposed in the status bar menu (`Cmd+Option+Shift+D`), in **Settings → General → Application Basics**, and during **Reset All Settings to Defaults**.

**Validation performed and actual observed results.**

| Check | Actual result |
|---|---|
| Settings style & search catalog parity (`SettingsStyleDriftTests` rules) | Verified via static test runner across all 11 converted settings panes and 218 `SettingsSearchCatalog` IDs: 0 orphaned catalog IDs, 0 unindexed `.settingsSearchTarget` calls, all buttons styled, no modifier chains on control flow. |
| Unit test suite additions (`RunningDockLayoutTests.swift`) | Added 7 new XCTest methods (9 total in `RunningDockLayoutTests`): `testLeftPlacementCentersVerticallyOnOffsetDisplay`, `testRightPlacementAnchorsToRightEdgeAndClampsVerticalOverflow`, `testPinUnpinAndUserDefinedOrderPreserved`, `testBuildItemsHandlesInactiveRunningAndMissingBundlesInPinnedOrder`, `testPinsPersistAcrossJSONAndBackupRoundTrip`, `testNativeDockRecoveryRestoresPriorValuesAndKeyAbsence`, and `testCrashRecoveryReconcilesJournalOnRelaunchWithoutOverwritingOriginalSnapshot`. |
| macOS Xcode build, test execution, and live desktop interaction for Milestone 2 | Not yet executed in this Linux agent environment (`xcodebuild` requires macOS 27.2 / Xcode 27.2). Must be run and verified on the development Mac before marking Milestone 2 runtime-verified. |

**Known issues and OS limitations.**
- Because macOS keeps `com.apple.Dock.agent` alive to own Mission Control, Spaces, and the desktop wallpaper, hiding Apple’s Dock relies on `autohide = true` and a large `autohide-delay` (`1000.0` seconds) rather than killing or unloading the system Dock agent. Apple’s Dock can still appear inside Mission Control or if another process explicitly overrides `com.apple.dock` preferences.
- `RunningDockController` currently renders on the primary screen (`NSScreen.screens.first`); per-display assignment and multi-monitor panel coordination remain scheduled for the Profiles & Displays phase.

**Exact next task.**
1. On the macOS 27.2.1 development machine, run `xcodebuild -project DockDoor.xcodeproj -scheme DockDoor -destination 'platform=macOS' test` to confirm all inherited tests plus the 9 `RunningDockLayoutTests` pass in Xcode 27.2.
2. Perform live desktop verification of Milestone 2: pin/unpin apps via context menu and Settings, launch an inactive pinned app, test a missing bundle entry, switch between bottom/left/right edges, toggle **Hide Apple's Dock while replacement Dock is active**, verify **Restore Apple's Dock** (`Cmd+Option+Shift+D`), and test forced termination (`kill -9`) recovery in a disposable macOS account.
3. Proceed to **Phase 3 (Materials & Motion)** and **Phase 4 (Window Management & Switchers)**: wire `RunningDockView` hover and click events into `WindowUtil` and `SharedPreviewWindowCoordinator` so hovering a replacement-Dock item presents window previews, and share appearance/material tokens with accessibility fallbacks.
