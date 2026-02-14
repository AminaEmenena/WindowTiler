import Foundation
import AppKit

enum TilePosition {
    case full               // Full screen grid
    case left               // Left half of screen
    case right              // Right half of screen
    case center             // Center 60% of screen
    case top                // Top half of screen
    case bottom             // Bottom half of screen
    case topLeft            // Top-left quarter
    case topRight           // Top-right quarter
    case bottomLeft         // Bottom-left quarter
    case bottomRight        // Bottom-right quarter
    case twoThirdsLeft      // Left 2/3 of screen
    case oneThirdRight      // Right 1/3 of screen
    case oneThirdLeft       // Left 1/3 of screen
    case twoThirdsRight     // Right 2/3 of screen
    case allDisplays        // Distribute windows across all monitors
}

struct TileLayout {
    let rows: Int
    let columns: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let startX: CGFloat
    let startY: CGFloat
}

class LayoutEngine {

    // MARK: - Multi-Monitor Support

    /// Determine which screen a window belongs to based on its bounds.
    /// Returns the screen that contains the largest portion of the window,
    /// or the main screen if no screen contains the window.
    func screenForWindowBounds(_ windowBounds: CGRect) -> NSScreen {
        guard let mainScreen = NSScreen.main else {
            return NSScreen.screens.first ?? NSScreen()
        }

        let screenHeight = mainScreen.frame.height
        let screenBounds = CGRect(
            x: windowBounds.origin.x,
            y: screenHeight - windowBounds.origin.y - windowBounds.height,
            width: windowBounds.width,
            height: windowBounds.height
        )

        var bestScreen: NSScreen = mainScreen
        var largestIntersectionArea: CGFloat = 0

        for screen in NSScreen.screens {
            let intersection = screen.frame.intersection(screenBounds)
            if !intersection.isNull {
                let area = intersection.width * intersection.height
                if area > largestIntersectionArea {
                    largestIntersectionArea = area
                    bestScreen = screen
                }
            }
        }

        return bestScreen
    }

    /// Get all available screens
    func getAllScreens() -> [NSScreen] {
        return NSScreen.screens
    }

    /// Get the usable area for a specific screen
    func getUsableScreenArea(for screen: NSScreen) -> CGRect {
        return screen.visibleFrame
    }

    /// Calculate the visible screen area accounting for dock and menu bar
    func getUsableScreenArea() -> CGRect {
        guard let screen = NSScreen.main else {
            return .zero
        }
        return screen.visibleFrame
    }

    /// Get the current padding value from settings
    private var currentPadding: CGFloat {
        return SettingsService.shared.windowGap
    }

    /// Calculate optimal grid dimensions for a given number of windows
    func calculateGrid(windowCount: Int) -> (rows: Int, columns: Int) {
        guard windowCount > 0 else { return (0, 0) }

        if windowCount == 1 {
            return (1, 1)
        }

        let sqrt = Double(windowCount).squareRoot()
        let columns = Int(ceil(sqrt))
        let rows = Int(ceil(Double(windowCount) / Double(columns)))

        return (rows, columns)
    }

    /// Generate tile rectangles for the given number of windows
    func generateTileRects(windowCount: Int, padding: CGFloat? = nil) -> [CGRect] {
        guard windowCount > 0 else { return [] }

        let actualPadding = padding ?? currentPadding
        let usableArea = getUsableScreenArea()
        let (rows, columns) = calculateGrid(windowCount: windowCount)

        let totalPaddingX = actualPadding * CGFloat(columns + 1)
        let totalPaddingY = actualPadding * CGFloat(rows + 1)

        let cellWidth = (usableArea.width - totalPaddingX) / CGFloat(columns)
        let cellHeight = (usableArea.height - totalPaddingY) / CGFloat(rows)

        var rects: [CGRect] = []

        for i in 0..<windowCount {
            let row = i / columns
            let col = i % columns

            let x = usableArea.origin.x + actualPadding + CGFloat(col) * (cellWidth + actualPadding)
            let y = usableArea.origin.y + usableArea.height - actualPadding - cellHeight - CGFloat(row) * (cellHeight + actualPadding)

            rects.append(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))
        }

        return rects
    }

    /// Convert from screen coordinates (origin bottom-left) to window coordinates (origin top-left)
    func convertToWindowCoordinates(_ rect: CGRect) -> CGRect {
        guard let screen = NSScreen.main else { return rect }

        let screenHeight = screen.frame.height
        let newY = screenHeight - rect.origin.y - rect.height

        return CGRect(x: rect.origin.x, y: newY, width: rect.width, height: rect.height)
    }

    /// Convert from screen coordinates to window coordinates using a specific screen's context
    func convertToWindowCoordinates(_ rect: CGRect, relativeTo screen: NSScreen) -> CGRect {
        guard let mainScreen = NSScreen.main else { return rect }

        let screenHeight = mainScreen.frame.height
        let newY = screenHeight - rect.origin.y - rect.height

        return CGRect(x: rect.origin.x, y: newY, width: rect.width, height: rect.height)
    }

    /// Calculate optimal grid for a target area, preferring wider cells for usability
    func calculateGridForArea(windowCount: Int, areaWidth: CGFloat, areaHeight: CGFloat) -> (rows: Int, columns: Int) {
        guard windowCount > 0 else { return (0, 0) }

        if windowCount == 1 {
            return (1, 1)
        }

        var bestRows = 1
        var bestCols = windowCount
        var bestScore = Double.infinity

        for rows in 1...windowCount {
            let cols = Int(ceil(Double(windowCount) / Double(rows)))

            let cellWidth = areaWidth / CGFloat(cols)
            let cellHeight = areaHeight / CGFloat(rows)

            let cellRatio = cellWidth / cellHeight
            let idealRatio = 1.5

            let ratioScore = abs(cellRatio - idealRatio)
            let heightPenalty = cellHeight < 200 ? (200 - cellHeight) / 50 : 0
            let score = ratioScore + heightPenalty

            if score < bestScore {
                bestScore = score
                bestRows = rows
                bestCols = cols
            }
        }

        return (bestRows, bestCols)
    }

    /// Calculate the target area for a given position
    private func calculateTargetArea(for position: TilePosition, in usableArea: CGRect) -> CGRect {
        switch position {
        case .full, .allDisplays:
            return usableArea
        case .left:
            return CGRect(
                x: usableArea.origin.x,
                y: usableArea.origin.y,
                width: usableArea.width / 2,
                height: usableArea.height
            )
        case .right:
            return CGRect(
                x: usableArea.origin.x + usableArea.width / 2,
                y: usableArea.origin.y,
                width: usableArea.width / 2,
                height: usableArea.height
            )
        case .center:
            let centerWidth = usableArea.width * 0.6
            return CGRect(
                x: usableArea.origin.x + (usableArea.width - centerWidth) / 2,
                y: usableArea.origin.y,
                width: centerWidth,
                height: usableArea.height
            )
        case .top:
            return CGRect(
                x: usableArea.origin.x,
                y: usableArea.origin.y + usableArea.height / 2,
                width: usableArea.width,
                height: usableArea.height / 2
            )
        case .bottom:
            return CGRect(
                x: usableArea.origin.x,
                y: usableArea.origin.y,
                width: usableArea.width,
                height: usableArea.height / 2
            )
        case .topLeft:
            return CGRect(
                x: usableArea.origin.x,
                y: usableArea.origin.y + usableArea.height / 2,
                width: usableArea.width / 2,
                height: usableArea.height / 2
            )
        case .topRight:
            return CGRect(
                x: usableArea.origin.x + usableArea.width / 2,
                y: usableArea.origin.y + usableArea.height / 2,
                width: usableArea.width / 2,
                height: usableArea.height / 2
            )
        case .bottomLeft:
            return CGRect(
                x: usableArea.origin.x,
                y: usableArea.origin.y,
                width: usableArea.width / 2,
                height: usableArea.height / 2
            )
        case .bottomRight:
            return CGRect(
                x: usableArea.origin.x + usableArea.width / 2,
                y: usableArea.origin.y,
                width: usableArea.width / 2,
                height: usableArea.height / 2
            )
        case .twoThirdsLeft:
            return CGRect(
                x: usableArea.origin.x,
                y: usableArea.origin.y,
                width: usableArea.width * 2 / 3,
                height: usableArea.height
            )
        case .oneThirdRight:
            return CGRect(
                x: usableArea.origin.x + usableArea.width * 2 / 3,
                y: usableArea.origin.y,
                width: usableArea.width / 3,
                height: usableArea.height
            )
        case .oneThirdLeft:
            return CGRect(
                x: usableArea.origin.x,
                y: usableArea.origin.y,
                width: usableArea.width / 3,
                height: usableArea.height
            )
        case .twoThirdsRight:
            return CGRect(
                x: usableArea.origin.x + usableArea.width / 3,
                y: usableArea.origin.y,
                width: usableArea.width * 2 / 3,
                height: usableArea.height
            )
        }
    }

    /// Generate tile rectangles for a specific screen position
    func generateTileRects(windowCount: Int, position: TilePosition, padding: CGFloat? = nil) -> [CGRect] {
        guard windowCount > 0 else { return [] }

        if position == .allDisplays {
            return []
        }

        let actualPadding = padding ?? currentPadding
        let usableArea = getUsableScreenArea()
        let targetArea = calculateTargetArea(for: position, in: usableArea)

        let (rows, columns) = calculateGridForArea(
            windowCount: windowCount,
            areaWidth: targetArea.width,
            areaHeight: targetArea.height
        )

        let totalPaddingX = actualPadding * CGFloat(columns + 1)
        let totalPaddingY = actualPadding * CGFloat(rows + 1)

        let cellWidth = (targetArea.width - totalPaddingX) / CGFloat(columns)
        let cellHeight = (targetArea.height - totalPaddingY) / CGFloat(rows)

        var rects: [CGRect] = []

        for i in 0..<windowCount {
            let row = i / columns
            let col = i % columns

            let x = targetArea.origin.x + actualPadding + CGFloat(col) * (cellWidth + actualPadding)
            let y = targetArea.origin.y + targetArea.height - actualPadding - cellHeight - CGFloat(row) * (cellHeight + actualPadding)

            rects.append(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))
        }

        return rects
    }

    /// Generate tile rectangles for a specific screen
    func generateTileRects(windowCount: Int, position: TilePosition, screen: NSScreen, padding: CGFloat? = nil) -> [CGRect] {
        guard windowCount > 0 else { return [] }

        if position == .allDisplays {
            return []
        }

        let actualPadding = padding ?? currentPadding
        let usableArea = getUsableScreenArea(for: screen)
        let targetArea = calculateTargetArea(for: position, in: usableArea)

        let (rows, columns) = calculateGridForArea(
            windowCount: windowCount,
            areaWidth: targetArea.width,
            areaHeight: targetArea.height
        )

        let totalPaddingX = actualPadding * CGFloat(columns + 1)
        let totalPaddingY = actualPadding * CGFloat(rows + 1)

        let cellWidth = (targetArea.width - totalPaddingX) / CGFloat(columns)
        let cellHeight = (targetArea.height - totalPaddingY) / CGFloat(rows)

        var rects: [CGRect] = []

        for i in 0..<windowCount {
            let row = i / columns
            let col = i % columns

            let x = targetArea.origin.x + actualPadding + CGFloat(col) * (cellWidth + actualPadding)
            let y = targetArea.origin.y + targetArea.height - actualPadding - cellHeight - CGFloat(row) * (cellHeight + actualPadding)

            rects.append(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))
        }

        return rects
    }

    /// Generate tile rectangles distributed across all displays.
    func generateTileRectsAcrossDisplays(windowCount: Int, padding: CGFloat? = nil) -> [(rect: CGRect, screen: NSScreen)] {
        guard windowCount > 0 else { return [] }

        let screens = getAllScreens()
        guard !screens.isEmpty else { return [] }

        let windowsPerScreen = windowCount / screens.count
        let extraWindows = windowCount % screens.count

        var results: [(rect: CGRect, screen: NSScreen)] = []
        var windowIndex = 0

        for (screenIndex, screen) in screens.enumerated() {
            let countForThisScreen = windowsPerScreen + (screenIndex < extraWindows ? 1 : 0)
            guard countForThisScreen > 0 else { continue }

            let rects = generateTileRects(
                windowCount: countForThisScreen,
                position: .full,
                screen: screen,
                padding: padding
            )

            for rect in rects {
                results.append((rect: rect, screen: screen))
                windowIndex += 1
                if windowIndex >= windowCount { break }
            }
        }

        return results
    }
}
