import Foundation
import AppKit

enum TilePosition {
    case full       // Full screen grid
    case left       // Left half of screen
    case right      // Right half of screen
    case center     // Center 60% of screen
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

    /// Calculate the visible screen area accounting for dock and menu bar
    func getUsableScreenArea() -> CGRect {
        guard let screen = NSScreen.main else {
            return .zero
        }

        // visibleFrame excludes dock and menu bar
        return screen.visibleFrame
    }

    /// Calculate optimal grid dimensions for a given number of windows
    func calculateGrid(windowCount: Int) -> (rows: Int, columns: Int) {
        guard windowCount > 0 else { return (0, 0) }

        if windowCount == 1 {
            return (1, 1)
        }

        // Find the most square-like grid
        let sqrt = Double(windowCount).squareRoot()
        let columns = Int(ceil(sqrt))
        let rows = Int(ceil(Double(windowCount) / Double(columns)))

        return (rows, columns)
    }

    /// Generate tile rectangles for the given number of windows
    func generateTileRects(windowCount: Int, padding: CGFloat = 4) -> [CGRect] {
        guard windowCount > 0 else { return [] }

        let usableArea = getUsableScreenArea()
        let (rows, columns) = calculateGrid(windowCount: windowCount)

        let totalPaddingX = padding * CGFloat(columns + 1)
        let totalPaddingY = padding * CGFloat(rows + 1)

        let cellWidth = (usableArea.width - totalPaddingX) / CGFloat(columns)
        let cellHeight = (usableArea.height - totalPaddingY) / CGFloat(rows)

        var rects: [CGRect] = []

        for i in 0..<windowCount {
            let row = i / columns
            let col = i % columns

            let x = usableArea.origin.x + padding + CGFloat(col) * (cellWidth + padding)
            // Screen coordinates in macOS have origin at bottom-left
            // But we want to fill from top-left, so we calculate from top
            let y = usableArea.origin.y + usableArea.height - padding - cellHeight - CGFloat(row) * (cellHeight + padding)

            rects.append(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))
        }

        return rects
    }

    /// Convert from screen coordinates (origin bottom-left) to window coordinates (origin top-left)
    func convertToWindowCoordinates(_ rect: CGRect) -> CGRect {
        guard let screen = NSScreen.main else { return rect }

        // macOS screen coordinates have origin at bottom-left
        // Window positioning uses top-left origin
        let screenHeight = screen.frame.height
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

        // Try different grid configurations and pick the one with best aspect ratio cells
        for rows in 1...windowCount {
            let cols = Int(ceil(Double(windowCount) / Double(rows)))

            let cellWidth = areaWidth / CGFloat(cols)
            let cellHeight = areaHeight / CGFloat(rows)

            // We want cells that are reasonably proportioned (not too tall/thin)
            // Ideal terminal ratio is around 1.5-2.0 (wider than tall)
            let cellRatio = cellWidth / cellHeight
            let idealRatio = 1.5

            // Score: how far from ideal ratio, with penalty for very short cells
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

    /// Generate tile rectangles for a specific screen position
    func generateTileRects(windowCount: Int, position: TilePosition, padding: CGFloat = 4) -> [CGRect] {
        guard windowCount > 0 else { return [] }

        let usableArea = getUsableScreenArea()

        // Calculate the target area based on position
        let targetArea: CGRect
        switch position {
        case .full:
            targetArea = usableArea
        case .left:
            targetArea = CGRect(
                x: usableArea.origin.x,
                y: usableArea.origin.y,
                width: usableArea.width / 2,
                height: usableArea.height
            )
        case .right:
            targetArea = CGRect(
                x: usableArea.origin.x + usableArea.width / 2,
                y: usableArea.origin.y,
                width: usableArea.width / 2,
                height: usableArea.height
            )
        case .center:
            let centerWidth = usableArea.width * 0.6
            targetArea = CGRect(
                x: usableArea.origin.x + (usableArea.width - centerWidth) / 2,
                y: usableArea.origin.y,
                width: centerWidth,
                height: usableArea.height
            )
        }

        // Calculate optimal grid for this target area
        let (rows, columns) = calculateGridForArea(
            windowCount: windowCount,
            areaWidth: targetArea.width,
            areaHeight: targetArea.height
        )

        let totalPaddingX = padding * CGFloat(columns + 1)
        let totalPaddingY = padding * CGFloat(rows + 1)

        let cellWidth = (targetArea.width - totalPaddingX) / CGFloat(columns)
        let cellHeight = (targetArea.height - totalPaddingY) / CGFloat(rows)

        var rects: [CGRect] = []

        for i in 0..<windowCount {
            let row = i / columns
            let col = i % columns

            let x = targetArea.origin.x + padding + CGFloat(col) * (cellWidth + padding)
            let y = targetArea.origin.y + targetArea.height - padding - cellHeight - CGFloat(row) * (cellHeight + padding)

            rects.append(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))
        }

        return rects
    }
}
