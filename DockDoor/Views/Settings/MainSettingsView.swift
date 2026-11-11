import AppKit
import Defaults
import LaunchAtLogin
import SwiftUI
import UniformTypeIdentifiers

struct MainSettingsView: View {
    @Default(.showRunningDock) private var showRunningDock
    @Default(.runningDockPlacement) private var runningDockPlacement
    @Default(.runningDockPinnedApps) private var runningDockPinnedApps
    @Default(.hideNativeDock) private var hideNativeDock
    @Default(.showMenuBarIcon) var showMenuBarIcon
    @Default(.showAnimations) var showAnimations
    @Default(.sortMinimizedToEnd) var sortMinimizedToEnd
    @Default(.showSettingsDescriptions) var showSettingsDescriptions

    var body: some View {
        SettingsFormView {
            supportAndContributionsSection
            applicationBasicsSection
            activeAppIndicatorSection
            backupAndRestoreSection
            resetAndQuitSection
        }
    }

    // MARK: - Support & Contributions

    private var supportAndContributionsSection: some View {
        SettingsSection("Support & Contributions") {
            SupportLinksSection()
        }
    }

    // MARK: - Application Basics

    private var applicationBasicsSection: some View {
        SettingsSection("Application Basics") {
            Toggle(String(localized: "Show running-app Dock"), isOn: $showRunningDock)
                .settingsAnnotation("Show a floating row of running apps on the primary display.")
                .settingsSearchTarget("general.showRunningDock")

            Picker(String(localized: "Replacement Dock edge"), selection: $runningDockPlacement) {
                ForEach(RunningDockPlacement.allCases) { placement in
                    Text(placement.localizedName).tag(placement)
                }
            }
            .pickerStyle(.menu)
            .settingsAnnotation("Position the replacement Dock along the bottom, left, or right edge of the primary display.")
            .settingsSearchTarget("general.runningDockPlacement")

            Toggle(String(localized: "Hide Apple's Dock while replacement Dock is active"), isOn: $hideNativeDock)
                .settingsAnnotation("Reversibly auto-hides Apple's Dock after recording your original Dock preferences to a recovery journal.")
                .settingsSearchTarget("general.hideNativeDock")

            LabeledContent(String(localized: "Restore Apple's Dock")) {
                Button(String(localized: "Restore Apple's Dock")) {
                    (NSApplication.shared.delegate as? AppDelegate)?.restoreNativeDockEmergency()
                }
                .buttonStyle(.settings)
            }
            .settingsAnnotation("Immediately restores Apple's Dock preferences from the recovery journal and disables native Dock hiding.")
            .settingsSearchTarget("general.restoreNativeDock")

            LabeledContent(String(localized: "Pinned Dock applications")) {
                HStack(spacing: 8) {
                    Button(String(localized: "Pin Application…")) {
                        promptToPinApplication()
                    }
                    .buttonStyle(.settings)

                    if !runningDockPinnedApps.isEmpty {
                        Button(String(localized: "Clear Pins"), role: .destructive) {
                            runningDockPinnedApps.removeAll()
                        }
                        .buttonStyle(.settings)
                    }
                }
            }
            .settingsAnnotation("Pinned applications stay in your chosen order across launches, even when closed or if their app bundle is missing.")
            .settingsSearchTarget("general.pinnedDockApps")

            ForEach(runningDockPinnedApps) { pin in
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(pin.displayName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if WorkspaceDockBundleResolver().resolveBundle(for: pin) == nil {
                        Text(String(localized: "Missing"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        runningDockPinnedApps = RunningDockPinStore.movePin(id: pin.id, by: -1, in: runningDockPinnedApps)
                    } label: {
                        Image(systemName: "chevron.up")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Move Up"))
                    .accessibilityLabel(String(localized: "Move \(pin.displayName) up"))

                    Button {
                        runningDockPinnedApps = RunningDockPinStore.movePin(id: pin.id, by: 1, in: runningDockPinnedApps)
                    } label: {
                        Image(systemName: "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Move Down"))
                    .accessibilityLabel(String(localized: "Move \(pin.displayName) down"))

                    Button {
                        runningDockPinnedApps = RunningDockPinStore.unpin(id: pin.id, from: runningDockPinnedApps)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Unpin"))
                    .accessibilityLabel(String(localized: "Unpin \(pin.displayName)"))
                }
            }

            LaunchAtLogin.Toggle(String(localized: "Launch BetterDockDoor at login"))
                .settingsSearchTarget("general.launchAtLogin")

            Toggle(isOn: $showMenuBarIcon, label: { Text("Show menu bar icon") })
                .settingsSearchTarget("general.menuBarIcon")
                .onChange(of: showMenuBarIcon) { isOn in
                    let appDelegate = NSApplication.shared.delegate as! AppDelegate
                    if isOn {
                        appDelegate.setupMenuBar()
                    } else {
                        appDelegate.removeMenuBar()
                    }
                }

            Toggle(isOn: Binding(
                get: { !showAnimations },
                set: { showAnimations = !$0 }
            )) {
                Text("Reduce motion")
            }
            .settingsSearchTarget("general.reduceMotion")

            Toggle(isOn: $showSettingsDescriptions, label: { Text("Show setting descriptions") })
                .settingsSearchTarget("general.showSettingDescriptions")
                .settingsAnnotation("Explain what each setting does underneath its row.")

            Toggle(isOn: $sortMinimizedToEnd, label: {
                Text("Sort minimized/hidden windows to end")
            })
            .settingsAnnotation("Minimized and hidden windows will appear after all visible windows in previews and switcher.")
            .settingsSearchTarget("general.sortMinimized")
        }
    }

    // MARK: - Active App Indicator

    private var activeAppIndicatorSection: some View {
        SettingsSection("Active App Indicator") {
            ActiveAppIndicatorSettingsView()
        }
    }

    // MARK: - Backup & Restore

    private var backupAndRestoreSection: some View {
        SettingsSection("Backup & Restore") {
            LabeledContent("Settings file") {
                HStack(spacing: 8) {
                    Button("Export Settings…") { SettingsBackupManager.exportSettings() }
                        .buttonStyle(.settings)
                        .settingsSearchTarget("general.exportSettings")
                    Button("Import Settings…") { SettingsBackupManager.importSettings() }
                        .buttonStyle(.settings)
                        .settingsSearchTarget("general.importSettings")
                }
            }
            .settingsAnnotation("Settings are saved as a JSON file you can keep in iCloud Drive or a dotfiles repository. Importing replaces your current settings and restarts DockDoor.")
        }
    }

    private var resetAndQuitSection: some View {
        SettingsSection("Reset and quit") {
            LabeledContent("Reset All Settings to Defaults") {
                Button("Reset", role: .destructive) { showResetConfirmation() }
                    .buttonStyle(.settings)
            }
            .settingsAnnotation("Every setting goes back to its default. This can't be undone.")

            LabeledContent("Quit BetterDockDoor") {
                Button("Quit") { (NSApplication.shared.delegate as! AppDelegate).quitApp() }
                    .buttonStyle(.settings)
            }
        }
    }

    // MARK: - Helper Functions

    private func promptToPinApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.title = String(localized: "Pin Application to Dock")

        guard panel.runModal() == .OK else { return }
        var updated = runningDockPinnedApps
        for url in panel.urls {
            let bundle = Bundle(url: url)
            let bundleID = bundle?.bundleIdentifier ?? ""
            let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            let candidate = RunningDockPin(
                bundleIdentifier: bundleID,
                displayName: displayName,
                bundlePath: url.path
            )
            updated = RunningDockPinStore.pin(candidate, in: updated)
        }
        runningDockPinnedApps = updated
    }

    private func showResetConfirmation() {
        MessageUtil.showAlert(title: String(localized: "Reset to Defaults"), message: String(localized: "Are you sure you want to reset all settings to their default values?"), actions: [.ok, .cancel]) { action in
            if action == .ok {
                (NSApplication.shared.delegate as? AppDelegate)?.restoreNativeDockEmergency()
                Defaults.removeAll()
                Defaults[.launched] = true

                Defaults[.showRunningDock] = Defaults.Keys.showRunningDock.defaultValue
                Defaults[.runningDockPlacement] = Defaults.Keys.runningDockPlacement.defaultValue
                Defaults[.runningDockPinnedApps] = Defaults.Keys.runningDockPinnedApps.defaultValue
                Defaults[.hideNativeDock] = Defaults.Keys.hideNativeDock.defaultValue

                Defaults[.hoverWindowOpenDelay] = Defaults.Keys.hoverWindowOpenDelay.defaultValue
                Defaults[.fadeOutDuration] = Defaults.Keys.fadeOutDuration.defaultValue
                Defaults[.tapEquivalentInterval] = Defaults.Keys.tapEquivalentInterval.defaultValue
                Defaults[.preventDockHide] = Defaults.Keys.preventDockHide.defaultValue
                Defaults[.screenCaptureCacheLifespan] = Defaults.Keys.screenCaptureCacheLifespan.defaultValue
                Defaults[.windowPreviewImageScale] = Defaults.Keys.windowPreviewImageScale.defaultValue
                Defaults[.bufferFromDock] = Defaults.Keys.bufferFromDock.defaultValue
                Defaults[.shouldHideOnDockItemClick] = Defaults.Keys.shouldHideOnDockItemClick.defaultValue
                Defaults[.dockClickAction] = Defaults.Keys.dockClickAction.defaultValue
                Defaults[.restoreAllMinimizedWindowsOnDockClick] = Defaults.Keys.restoreAllMinimizedWindowsOnDockClick.defaultValue
                Defaults[.enableCmdRightClickQuit] = Defaults.Keys.enableCmdRightClickQuit.defaultValue
                Defaults[.dockPreviewActivationMode] = Defaults.Keys.dockPreviewActivationMode.defaultValue
                Defaults[.dockPreviewActivationModifier] = Defaults.Keys.dockPreviewActivationModifier.defaultValue
                Defaults[.previewHoverAction] = Defaults.Keys.previewHoverAction.defaultValue
                Defaults[.keepPreviewOnHoverActivation] = Defaults.Keys.keepPreviewOnHoverActivation.defaultValue

                showMenuBarIcon = Defaults.Keys.showMenuBarIcon.defaultValue
                Defaults[.enableWindowSwitcher] = Defaults.Keys.enableWindowSwitcher.defaultValue
                Defaults[.instantWindowSwitcher] = Defaults.Keys.instantWindowSwitcher.defaultValue
                Defaults[.includeHiddenWindowsInSwitcher] = Defaults.Keys.includeHiddenWindowsInSwitcher.defaultValue
                Defaults[.includeHiddenWindowsInDockPreview] = Defaults.Keys.includeHiddenWindowsInDockPreview.defaultValue
                Defaults[.includeHiddenWindowsInCmdTab] = Defaults.Keys.includeHiddenWindowsInCmdTab.defaultValue
                Defaults[.showWindowlessAppsInSwitcher] = Defaults.Keys.showWindowlessAppsInSwitcher.defaultValue
                Defaults[.showWindowlessAppsInDockPreview] = Defaults.Keys.showWindowlessAppsInDockPreview.defaultValue
                Defaults[.showWindowlessAppsInCmdTab] = Defaults.Keys.showWindowlessAppsInCmdTab.defaultValue
                Defaults[.openNewWindowForWindowlessApps] = Defaults.Keys.openNewWindowForWindowlessApps.defaultValue
                Defaults[.ignoreAppsWithSingleWindowInCmdTab] = Defaults.Keys.ignoreAppsWithSingleWindowInCmdTab.defaultValue
                Defaults[.useClassicWindowOrdering] = Defaults.Keys.useClassicWindowOrdering.defaultValue
                Defaults[.limitSwitcherToFrontmostApp] = Defaults.Keys.limitSwitcherToFrontmostApp.defaultValue
                Defaults[.fullscreenAppBlacklist] = Defaults.Keys.fullscreenAppBlacklist.defaultValue

                Defaults[.UserKeybind] = Defaults.Keys.UserKeybind.defaultValue
                Defaults[.requireShiftTabToGoBack] = Defaults.Keys.requireShiftTabToGoBack.defaultValue
                Defaults[.windowSwitcherPlacementStrategy] = Defaults.Keys.windowSwitcherPlacementStrategy.defaultValue
                Defaults[.pinnedScreenIdentifier] = Defaults.Keys.pinnedScreenIdentifier.defaultValue
                Defaults[.enableShiftWindowSwitcherPlacement] = Defaults.Keys.enableShiftWindowSwitcherPlacement.defaultValue
                Defaults[.windowSwitcherHorizontalOffsetPercent] = Defaults.Keys.windowSwitcherHorizontalOffsetPercent.defaultValue
                Defaults[.windowSwitcherVerticalOffsetPercent] = Defaults.Keys.windowSwitcherVerticalOffsetPercent.defaultValue
                Defaults[.windowSwitcherAnchorToTop] = Defaults.Keys.windowSwitcherAnchorToTop.defaultValue

                Defaults[.enableDockPreviewGestures] = Defaults.Keys.enableDockPreviewGestures.defaultValue
                Defaults[.dockSwipeTowardsDockAction] = Defaults.Keys.dockSwipeTowardsDockAction.defaultValue
                Defaults[.dockSwipeAwayFromDockAction] = Defaults.Keys.dockSwipeAwayFromDockAction.defaultValue
                Defaults[.gestureSwipeThreshold] = Defaults.Keys.gestureSwipeThreshold.defaultValue
                Defaults[.middleClickAction] = Defaults.Keys.middleClickAction.defaultValue

                Defaults[.cmdShortcut1Key] = Defaults.Keys.cmdShortcut1Key.defaultValue
                Defaults[.cmdShortcut1Action] = Defaults.Keys.cmdShortcut1Action.defaultValue
                Defaults[.cmdShortcut2Key] = Defaults.Keys.cmdShortcut2Key.defaultValue
                Defaults[.cmdShortcut2Action] = Defaults.Keys.cmdShortcut2Action.defaultValue
                Defaults[.cmdShortcut3Key] = Defaults.Keys.cmdShortcut3Key.defaultValue
                Defaults[.cmdShortcut3Action] = Defaults.Keys.cmdShortcut3Action.defaultValue

                Defaults[.alternateKeybindKey] = Defaults.Keys.alternateKeybindKey.defaultValue
                Defaults[.alternateKeybindModifierFlags] = Defaults.Keys.alternateKeybindModifierFlags.defaultValue
                Defaults[.alternateKeybindMode] = Defaults.Keys.alternateKeybindMode.defaultValue
                Defaults[.additionalAlternateKeybinds] = Defaults.Keys.additionalAlternateKeybinds.defaultValue

                Defaults[.cmdTabAutoSelectFirstWindow] = Defaults.Keys.cmdTabAutoSelectFirstWindow.defaultValue
                Defaults[.cmdTabCycleKey] = Defaults.Keys.cmdTabCycleKey.defaultValue
                Defaults[.searchTriggerKey] = Defaults.Keys.searchTriggerKey.defaultValue

                Defaults[.showSpecialAppControls] = Defaults.Keys.showSpecialAppControls.defaultValue
                Defaults[.enableFolderWidget] = Defaults.Keys.enableFolderWidget.defaultValue
                Defaults[.folderWidgetDefaultSortOrder] = Defaults.Keys.folderWidgetDefaultSortOrder.defaultValue
                Defaults[.folderWidgetDefaultSortReversed] = Defaults.Keys.folderWidgetDefaultSortReversed.defaultValue
                Defaults[.folderWidgetRememberSortPerFolder] = Defaults.Keys.folderWidgetRememberSortPerFolder.defaultValue
                Defaults[.folderWidgetSortOrders] = Defaults.Keys.folderWidgetSortOrders.defaultValue
                Defaults[.folderWidgetSortReversed] = Defaults.Keys.folderWidgetSortReversed.defaultValue
                Defaults[.folderWidgetShowHiddenFiles] = Defaults.Keys.folderWidgetShowHiddenFiles.defaultValue
                Defaults[.showBigControlsWhenNoValidWindows] = Defaults.Keys.showBigControlsWhenNoValidWindows.defaultValue
                Defaults[.showMassActionButtons] = Defaults.Keys.showMassActionButtons.defaultValue
                Defaults[.useEmbeddedMediaControls] = Defaults.Keys.useEmbeddedMediaControls.defaultValue
                Defaults[.enablePinning] = Defaults.Keys.enablePinning.defaultValue

                Defaults[.enableDockLocking] = Defaults.Keys.enableDockLocking.defaultValue
                Defaults[.lockedDockScreenIdentifier] = Defaults.Keys.lockedDockScreenIdentifier.defaultValue
                Defaults[.dockLockOverrideModifier] = Defaults.Keys.dockLockOverrideModifier.defaultValue
                Defaults[.filteredCalendarIdentifiers] = Defaults.Keys.filteredCalendarIdentifiers.defaultValue
                Defaults[.groupAppInstancesInDock] = Defaults.Keys.groupAppInstancesInDock.defaultValue

                Defaults[.disableImagePreview] = Defaults.Keys.disableImagePreview.defaultValue

                askUserToRestartApplication()
            }
        }
    }
}
