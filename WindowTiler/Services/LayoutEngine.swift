import Foundation
import AppKit

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
}
