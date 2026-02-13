import Foundation
import AppKit
import ApplicationServices

class AccessibilityService {
    static let shared = AccessibilityService()

    private init() {}

    func checkPermissions() -> Bool {
        return AXIsProcessTrusted()
    }

    func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func moveAndResizeWindow(pid: pid_t, windowIndex: Int, to rect: CGRect) -> Bool {
        let appRef = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success,
              let windows = windowsRef as? [AXUIElement],
              windowIndex < windows.count else {
            return false
        }

        let window = windows[windowIndex]

        // Set position
        var position = CGPoint(x: rect.origin.x, y: rect.origin.y)
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }

        // Set size
        var size = CGSize(width: rect.width, height: rect.height)
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }

        return true
    }

    func moveAndResizeWindowByID(pid: pid_t, targetBounds: CGRect, newRect: CGRect) -> Bool {
        let appRef = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success,
              let windows = windowsRef as? [AXUIElement] else {
            return false
        }

        // Find the window that matches the target bounds
        for window in windows {
            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?

            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

            guard let posValue = positionRef,
                  let szValue = sizeRef else {
                continue
            }

            var currentPosition = CGPoint.zero
            var currentSize = CGSize.zero

            AXValueGetValue(posValue as! AXValue, .cgPoint, &currentPosition)
            AXValueGetValue(szValue as! AXValue, .cgSize, &currentSize)

            let currentBounds = CGRect(origin: currentPosition, size: currentSize)

            // Check if this window roughly matches (allowing some tolerance)
            if abs(currentBounds.origin.x - targetBounds.origin.x) < 10 &&
               abs(currentBounds.origin.y - targetBounds.origin.y) < 10 {

                // Set new position
                var position = CGPoint(x: newRect.origin.x, y: newRect.origin.y)
                if let positionValue = AXValueCreate(.cgPoint, &position) {
                    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
                }

                // Set new size
                var size = CGSize(width: newRect.width, height: newRect.height)
                if let sizeValue = AXValueCreate(.cgSize, &size) {
                    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
                }

                return true
            }
        }

        return false
    }
}
