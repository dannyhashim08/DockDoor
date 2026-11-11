# BetterDockDoor architecture and delivery plan

## Baseline and build

Start from dannyhashim08/DockDoor at baf6425a981b09acb79189ec568e7c189b70a0ce. On the development Mac, macOS 27.2.1 (26B8132), Xcode 27.2 (27B52) and Apple Swift 6.4.2 target arm64. The app's deployment target is macOS 13.0 and the test host requires 14.5. The installed upstream 1.42.4 app opened to General. Search, the sidebar and backup controls appeared in the accessibility tree. This establishes an installed baseline independently of the fork's build.

For a clean reproduction, check out that commit for upstream, or the fork's milestone branch for BetterDockDoor. Open DockDoor.xcodeproj in Xcode 27.2. Let Xcode resolve the checked-in Package.resolved, select DockDoor and My Mac, then use Product > Run and Product > Test. Use local Mac signing for a personal build. The BuildTools subproject also resolves SwiftFormat. Record the revision, package-lock changes, signed bundle ID and result when testing. Quit the upstream app before testing global shortcuts.

## Existing subsystems

| Owner | Existing responsibility |
|---|---|
| AppDelegate | Composes the menu-bar app, onboarding, permission reconciliation, wake and display observers. |
| DockObserver and DockObserver+CmdTab | Dock hover and native app-switcher integration. |
| WindowUtil, WindowSeeder and WindowManipulationObservers | AX window discovery, focus and actions, cache updates and cross-Space discovery. Some inherited behavior uses private interfaces in PrivateApis.swift. |
| SharedPreviewWindowCoordinator | Preview panels, switcher content, presentation lifetime. |
| KeybindHelper and WindowGestureController | Keyboard switching, shortcuts and trackpad gesture routing. |
| consts.swift and SettingsSearchCatalog | Defaults, searchable general, preview, switcher, Cmd+Tab, gestures, keybinds, appearance, filters, widgets and advanced preferences. |
| SettingsBackupManager | Existing settings JSON import/export, including reset/restart behavior. |
| Existing folder, media and calendar views | Preview content to reuse, independent of a replacement Dock's future widget registry. |

The app package lock includes Defaults, LaunchAtLogin-Modern, ConfettiSwiftUI, SmoothGradient, MediaRemote-Adapter, Sparkle and SwiftSyntax. BuildTools pins SwiftFormat separately. The upstream XCTest target covers alternate keybinds, DockLocker geometry, native tab grouping, screen reservations, settings backup and style, shortcut modifiers, trackpad swipes, gesture recognition and resolution, window placement and title presentation.

## Delivery sequence

1. **Baseline and identity.** Keep the existing target and Swift module. Give the built app its own identity, icon and preferences. Verify both product configurations, shared scheme and test host. Rebuild and run the complete inherited test suite.
2. **Replacement Dock.** AppDelegate owns an opt-in AppKit panel coordinator. Regular running apps come from NSWorkspace. Position panels in each screen's coordinate system. Add durable typed pins and atomic configuration before hiding the native Dock. Implement recovery as a separate transaction: record prior value and presence of each owned preference before any write, restore only owned changes, and reconcile a journal on relaunch. Validate forced exit in a disposable macOS account.
3. **Materials and motion.** Share appearance tokens with panels. Probe real glass availability. Respect accessibility preferences and measure redraws at rest.
4. **Window management.** Feed existing WindowUtil and preview coordinators from both Dock surfaces. Extend filters/actions at the model level. Validate denied AX and Screen Recording separately.
5. **Profiles and displays.** Version profile data, persist display assignments and debounce activation triggers. Treat transient Space IDs as session-local until verified.
6. **Folders and shelf.** Persist file references as bookmarks. Resolve missing/stale references explicitly. Stage references only. Use temporary test volumes to verify same-volume moves, cross-volume copies and Option-drag.
7. **Drawer and widgets.** Implement local command routing and a versioned registry of bundled widgets. Activate observers while a widget is visible. Validate availability and permissions per widget. Review source terms before enabling online providers.
8. **Extensions and release.** Isolate optional external code, test revocation, keyboard and VoiceOver navigation, measure idle CPU and capture load, and exercise the full matrix on physical displays.
