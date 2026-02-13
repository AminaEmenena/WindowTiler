import SwiftUI

struct MenuBarView: View {
    @ObservedObject var windowManager: WindowManager
    @State private var hasPermissions = AccessibilityService.shared.checkPermissions()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundColor(.accentColor)
                Text("Window Tiler")
                    .font(.headline)
                Spacer()
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
                // Permission warning
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
            } else if windowManager.appWindows.isEmpty {
                // No windows
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
            } else {
                // Main content
                VStack(spacing: 0) {
                    // Tile All button
                    Button(action: {
                        windowManager.tileAllWindows()
                    }) {
                        HStack {
                            Image(systemName: "square.grid.2x2")
                            Text("Tile All Windows")
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
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Divider()
                        .padding(.vertical, 8)

                    // App list header
                    HStack {
                        Text("Applications")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("All") {
                            windowManager.selectAllApps()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)

                        Button("None") {
                            windowManager.deselectAllApps()
                        }
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

                        // Position buttons
                        HStack(spacing: 8) {
                            TileButton(
                                icon: "rectangle.lefthalf.filled",
                                label: "Left",
                                disabled: windowManager.selectedWindowCount == 0
                            ) {
                                windowManager.tileSelectedWindows(position: .left)
                            }

                            TileButton(
                                icon: "rectangle.center.inset.filled",
                                label: "Center",
                                disabled: windowManager.selectedWindowCount == 0
                            ) {
                                windowManager.tileSelectedWindows(position: .center)
                            }

                            TileButton(
                                icon: "rectangle.righthalf.filled",
                                label: "Right",
                                disabled: windowManager.selectedWindowCount == 0
                            ) {
                                windowManager.tileSelectedWindows(position: .right)
                            }

                            TileButton(
                                icon: "square.grid.2x2",
                                label: "Grid",
                                disabled: windowManager.selectedWindowCount == 0
                            ) {
                                windowManager.tileSelectedWindows(position: .full)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)

                Spacer()
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 300, height: 400)
    }
}

struct TileButton: View {
    let icon: String
    let label: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(disabled ? Color.clear : Color.accentColor.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }
}

struct AppRowView: View {
    let app: AppWindows
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                // Checkbox
                Image(systemName: app.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(app.isSelected ? .accentColor : .secondary)

                // App icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "app.fill")
                        .frame(width: 20, height: 20)
                }

                // App name
                Text(app.name)
                    .lineLimit(1)

                Spacer()

                // Window count
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
