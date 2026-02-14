import SwiftUI

struct MenuBarView: View {
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var groupStorage = GroupStorage.shared
    @ObservedObject var layoutStorage = LayoutStorage.shared
    @ObservedObject var settingsService = SettingsService.shared
    @State private var hasPermissions = AccessibilityService.shared.checkPermissions()
    @State private var isGroupsSectionExpanded = false
    @State private var showingSaveGroupSheet = false
    @State private var newGroupName = ""
    @State private var showingSaveLayoutSheet = false
    @State private var newLayoutName = ""
    @State private var showingLayoutsList = false
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundColor(.accentColor)
                Text("Window Tiler")
                    .font(.headline)
                Spacer()
                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Settings")
                Button(action: {
                    windowManager.refreshWindows()
                    hasPermissions = AccessibilityService.shared.checkPermissions()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh window list")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if !hasPermissions {
                PermissionWarningView()
            } else if windowManager.appWindows.isEmpty {
                NoWindowsView()
            } else {
                MainContentView(
                    windowManager: windowManager,
                    groupStorage: groupStorage,
                    layoutStorage: layoutStorage,
                    isGroupsSectionExpanded: $isGroupsSectionExpanded,
                    showingSaveGroupSheet: $showingSaveGroupSheet,
                    newGroupName: $newGroupName,
                    showingSaveLayoutSheet: $showingSaveLayoutSheet,
                    showingLayoutsList: $showingLayoutsList
                )
            }

            Divider()

            // Footer
            FooterView()
        }
        .frame(width: 320, height: 580)
        .sheet(isPresented: $showingSaveGroupSheet) {
            SaveSheet(
                title: "Save Selection as Group",
                name: $newGroupName,
                isPresented: $showingSaveGroupSheet,
                onSave: {
                    let bundleIds = windowManager.getSelectedBundleIdentifiers()
                    if !bundleIds.isEmpty && !newGroupName.isEmpty {
                        groupStorage.saveGroup(name: newGroupName, bundleIdentifiers: bundleIds)
                    }
                    newGroupName = ""
                }
            )
        }
        .sheet(isPresented: $showingSaveLayoutSheet) {
            SaveSheet(
                title: "Save Layout",
                name: $newLayoutName,
                isPresented: $showingSaveLayoutSheet,
                onSave: {
                    let allWindows = windowManager.appWindows.flatMap { $0.windows }
                    _ = layoutStorage.saveLayout(name: newLayoutName, windows: allWindows)
                    newLayoutName = ""
                }
            )
        }
        .sheet(isPresented: $showingLayoutsList) {
            LayoutsListSheet(layoutStorage: layoutStorage, isPresented: $showingLayoutsList)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(settingsService: settingsService, isPresented: $showingSettings)
        }
    }
}

// MARK: - Permission Warning

struct PermissionWarningView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("Accessibility Permission Required")
                .font(.headline)

            Text("WindowTiler needs accessibility access to move and resize windows.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Open System Settings") {
                AccessibilityService.shared.requestPermissions()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - No Windows

struct NoWindowsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "macwindow")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No Windows Found")
                .font(.headline)

            Text("Open some application windows to tile them.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Main Content

struct MainContentView: View {
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var groupStorage: GroupStorage
    @ObservedObject var layoutStorage: LayoutStorage
    @Binding var isGroupsSectionExpanded: Bool
    @Binding var showingSaveGroupSheet: Bool
    @Binding var newGroupName: String
    @Binding var showingSaveLayoutSheet: Bool
    @Binding var showingLayoutsList: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Tile All & Undo buttons
            HStack(spacing: 8) {
                Button(action: { windowManager.tileAllWindows() }) {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                        Text("Tile All")
                        Spacer()
                        Text("\(windowManager.totalWindowCount)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: { windowManager.undoLastTile() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .padding(8)
                        .background(windowManager.canUndo ? Color.orange.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!windowManager.canUndo)
                .opacity(windowManager.canUndo ? 1.0 : 0.4)
                .help("Undo last tile")
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Focus Mode Exit
            if windowManager.isInFocusMode {
                Button(action: { windowManager.exitFocusMode() }) {
                    HStack {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                        Text("Exit Focus")
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 4)
            }

            Divider().padding(.vertical, 8)

            // Quick Groups Section
            QuickGroupsSection(
                windowManager: windowManager,
                groupStorage: groupStorage,
                isExpanded: $isGroupsSectionExpanded,
                showingSaveGroupSheet: $showingSaveGroupSheet
            )

            Divider().padding(.vertical, 8)

            // Layouts Section
            LayoutsSectionView(
                layoutStorage: layoutStorage,
                showingSaveSheet: $showingSaveLayoutSheet,
                showingLayoutsList: $showingLayoutsList
            )

            Divider().padding(.vertical, 8)

            // App list header
            HStack {
                Text("Applications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button("All") { windowManager.selectAllApps() }
                    .buttonStyle(.borderless)
                    .font(.caption)
                Button("None") { windowManager.deselectAllApps() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(.horizontal)

            // App list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(windowManager.appWindows) { app in
                        AppRowView(app: app) {
                            windowManager.toggleAppSelection(appID: app.id)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Divider()

            // Tile Selected section
            TileSelectedSection(windowManager: windowManager)
        }
    }
}

// MARK: - Tile Selected Section

struct TileSelectedSection: View {
    @ObservedObject var windowManager: WindowManager

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tile Selected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(windowManager.selectedWindowCount) windows")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Row 1: Halves
            HStack(spacing: 6) {
                TileButton(icon: "rectangle.lefthalf.filled", label: "Left",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .left)
                }
                TileButton(icon: "rectangle.center.inset.filled", label: "Center",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .center)
                }
                TileButton(icon: "rectangle.righthalf.filled", label: "Right",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .right)
                }
                TileButton(icon: "square.grid.2x2", label: "Grid",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .full)
                }
            }
            .padding(.horizontal)

            // Row 2: Top/Bottom
            HStack(spacing: 6) {
                TileButton(icon: "rectangle.tophalf.filled", label: "Top",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .top)
                }
                TileButton(icon: "rectangle.bottomhalf.filled", label: "Bottom",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .bottom)
                }
                TileButton(icon: "arrow.up.left.and.arrow.down.right", label: "Focus",
                           disabled: !windowManager.canEnterFocusMode) {
                    windowManager.enterFocusMode()
                }
                TileButton(icon: "display.2", label: "All",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileWindowsAcrossAllDisplays()
                }
            }
            .padding(.horizontal)

            // Row 3: Quarters
            HStack(spacing: 6) {
                TileButton(icon: "rectangle.inset.topleft.filled", label: "TL",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .topLeft)
                }
                TileButton(icon: "rectangle.inset.topright.filled", label: "TR",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .topRight)
                }
                TileButton(icon: "rectangle.inset.bottomleft.filled", label: "BL",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .bottomLeft)
                }
                TileButton(icon: "rectangle.inset.bottomright.filled", label: "BR",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .bottomRight)
                }
            }
            .padding(.horizontal)

            // Row 4: Thirds
            HStack(spacing: 6) {
                TileButton(icon: "rectangle.lefthalf.inset.filled", label: "2/3 L",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .twoThirdsLeft)
                }
                TileButton(icon: "rectangle.righthalf.inset.filled", label: "1/3 R",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .oneThirdRight)
                }
                TileButton(icon: "rectangle.lefthalf.inset.filled", label: "1/3 L",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .oneThirdLeft)
                }
                TileButton(icon: "rectangle.righthalf.inset.filled", label: "2/3 R",
                           disabled: windowManager.selectedWindowCount == 0) {
                    windowManager.tileSelectedWindows(position: .twoThirdsRight)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Quick Groups Section

struct QuickGroupsSection: View {
    @ObservedObject var windowManager: WindowManager
    @ObservedObject var groupStorage: GroupStorage
    @Binding var isExpanded: Bool
    @Binding var showingSaveGroupSheet: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Button(action: { isExpanded.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Quick Groups")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { showingSaveGroupSheet = true }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(windowManager.selectedWindowCount > 0 ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(windowManager.selectedWindowCount == 0)
                .help("Save selection as group")
            }
            .padding(.horizontal)

            if isExpanded {
                if groupStorage.groups.isEmpty {
                    Text("No groups saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(groupStorage.groups) { group in
                                GroupRowView(group: group,
                                    onApply: { windowManager.selectAppsByBundleIdentifiers(group.bundleIdentifiers) },
                                    onDelete: { groupStorage.deleteGroup(id: group.id) }
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(maxHeight: 60)
                }
            }
        }
    }
}

// MARK: - Layouts Section

struct LayoutsSectionView: View {
    @ObservedObject var layoutStorage: LayoutStorage
    @Binding var showingSaveSheet: Bool
    @Binding var showingLayoutsList: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Layouts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()

                Button(action: { showingSaveSheet = true }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .help("Save current layout")

                if !layoutStorage.savedLayouts.isEmpty {
                    Button(action: { showingLayoutsList = true }) {
                        Image(systemName: "list.bullet")
                    }
                    .buttonStyle(.borderless)
                    .help("Manage layouts")
                }
            }
            .padding(.horizontal)

            if layoutStorage.savedLayouts.isEmpty {
                Text("No saved layouts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            } else {
                ForEach(layoutStorage.savedLayouts.prefix(2)) { layout in
                    LayoutQuickAccessRow(layout: layout, layoutStorage: layoutStorage)
                }
            }
        }
    }
}

struct LayoutQuickAccessRow: View {
    let layout: SavedLayout
    @ObservedObject var layoutStorage: LayoutStorage

    var body: some View {
        Button(action: {
            layoutStorage.restoreLayout(layout, using: AccessibilityService.shared)
        }) {
            HStack {
                Image(systemName: "rectangle.3.group")
                    .foregroundColor(.accentColor)
                Text(layout.name)
                    .lineLimit(1)
                Spacer()
                Text("\(layout.windowCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

// MARK: - Group Row

struct GroupRowView: View {
    let group: AppGroup
    let onApply: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onApply) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                    Text(group.name)
                        .lineLimit(1)
                    Spacer()
                    Text("\(group.bundleIdentifiers.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .onHover { hovering in isHovering = hovering }
    }
}

// MARK: - Footer

struct FooterView: View {
    @StateObject private var launchAtLoginService = LaunchAtLoginService.shared

    var body: some View {
        HStack {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)

            Spacer()

            Toggle(isOn: Binding(
                get: { launchAtLoginService.isEnabled },
                set: { _ in launchAtLoginService.toggle() }
            )) {
                Text("Launch at Login")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .toggleStyle(.checkbox)
            .onAppear { launchAtLoginService.updateStatus() }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Tile Button

struct TileButton: View {
    let icon: String
    let label: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.body)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(disabled ? Color.clear : Color.accentColor.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }
}

// MARK: - App Row

struct AppRowView: View {
    let app: AppWindows
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: app.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(app.isSelected ? .accentColor : .secondary)

                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "app.fill")
                        .frame(width: 20, height: 20)
                }

                Text(app.name)
                    .lineLimit(1)

                Spacer()

                Text("\(app.windowCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(app.isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Save Sheet (reusable)

struct SaveSheet: View {
    let title: String
    @Binding var name: String
    @Binding var isPresented: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            HStack(spacing: 12) {
                Button("Cancel") {
                    name = ""
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    onSave()
                    isPresented = false
                }
                .keyboardShortcut(.return)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}

// MARK: - Layouts List Sheet

struct LayoutsListSheet: View {
    @ObservedObject var layoutStorage: LayoutStorage
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Saved Layouts")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            if layoutStorage.savedLayouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.3.group")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No saved layouts")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(layoutStorage.savedLayouts) { layout in
                        LayoutListRow(layout: layout, layoutStorage: layoutStorage, isPresented: $isPresented)
                    }
                    .onDelete { offsets in
                        layoutStorage.deleteLayout(at: offsets)
                    }
                }
            }
        }
        .frame(width: 320, height: 300)
    }
}

struct LayoutListRow: View {
    let layout: SavedLayout
    @ObservedObject var layoutStorage: LayoutStorage
    @Binding var isPresented: Bool
    @State private var showingDeleteConfirm = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(layout.name)
                    .font(.body)
                Text("\(layout.windowCount) windows, \(layout.uniqueAppCount) apps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                layoutStorage.restoreLayout(layout, using: AccessibilityService.shared)
                isPresented = false
            }) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("Restore layout")

            Button(action: { showingDeleteConfirm = true }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .alert("Delete Layout?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                layoutStorage.deleteLayout(id: layout.id)
            }
        } message: {
            Text("Are you sure you want to delete \"\(layout.name)\"?")
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @ObservedObject var settingsService: SettingsService
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Window Gap")
                    .font(.subheadline)

                HStack {
                    Slider(value: $settingsService.windowGap, in: 0...20, step: 1)
                    Text("\(Int(settingsService.windowGap))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 280, height: 150)
    }
}
