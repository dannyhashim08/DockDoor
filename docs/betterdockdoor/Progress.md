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

**Limitations.** This first panel is restricted to running apps on the primary display. Pinning, other edges, native-Dock hiding, recovery and independent replacement-panel previews are pending. The inherited native-Dock hover path remains active. The panel has no global shortcut or event tap of its own.

**Exact next task.** Implement durable application pins in user-defined order. Validate pin/unpin, inactive pinned apps, relaunch and missing bundles, then add left/right placement and the native-Dock recovery transaction. Remaining desktop checks include hide/unhide, overflow, adding/removing running apps and physical display transitions.
