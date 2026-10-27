import Foundation
import AppKit
import ApplicationServices

/// Automatically confirms CoreServicesUIAgent dialogs using the Accessibility API.
/// Requires the app to be in System Settings > Privacy & Security > Accessibility.
final class DialogAutoConfirm {
    private var isRunning = false
    private var timer: Timer?
    private let queue = DispatchQueue(label: "autoconfirm", qos: .userInteractive)
    private var inFlight = false
    private var expectedAppName: String?

    /// Test Accessibility by making a real AX API call.
    /// Returns true if the API works, false if permission is missing.
    static func testPermission() -> Bool {
        let finder = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.finder"
        )
        guard let app = finder.first else { return false }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &ref)
        // .apiDisabled means no Accessibility permission
        return result != .apiDisabled
    }

    func start(expectedAppName: String) {
        guard !isRunning else { return }
        self.expectedAppName = expectedAppName
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        expectedAppName = nil
    }

    private func tick() {
        guard !inFlight, let expectedAppName else { return }
        inFlight = true
        queue.async { [weak self] in
            Self.clickUseButton(forAppNamed: expectedAppName)
            DispatchQueue.main.async { self?.inFlight = false }
        }
    }

    private static func clickUseButton(forAppNamed appName: String) {
        let apps = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.coreservices.uiagent"
        )
        guard let agent = apps.first else { return }

        let appElement = AXUIElementCreateApplication(agent.processIdentifier)

        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }

        for window in windows {
            guard containsText(appName, in: window) else { continue }
            if findAndClickUseButton(in: window) { return }
        }
    }

    /// Only inspect dialogs that mention the target app for this reassignment.
    private static func containsText(_ expectedText: String, in element: AXUIElement) -> Bool {
        let attributes = [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute]
        for attribute in attributes {
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success,
               let value = valueRef as? String,
               value.localizedCaseInsensitiveContains(expectedText) {
                return true
            }
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return false }
        return children.contains { containsText(expectedText, in: $0) }
    }

    private static func findAndClickUseButton(in element: AXUIElement) -> Bool {
        // Check if this element is a "Use..." button
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        if let role = roleRef as? String, role == kAXButtonRole {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
            if let title = titleRef as? String, title.hasPrefix("Use") {
                return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
            }
        }

        // Recurse into children
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return false }

        for child in children {
            if findAndClickUseButton(in: child) { return true }
        }
        return false
    }

    deinit {
        stop()
    }
}
