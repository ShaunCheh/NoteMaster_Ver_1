//
//  macOSAppDelegate.swift
//  NoteMaster_Ver_1
//
//  Created by Shaun on 2026/3/19.
//

#if os(macOS)
import Foundation
import AppKit

@main
final class macOSAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private static let sharedDelegate = macOSAppDelegate()
    
    static func main() {
        let app = NSApplication.shared
        app.delegate = sharedDelegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MusicFontRegistry.bootstrapIfNeeded()
        FretboardValidationRunner.runAndReportIfNeeded(platform: .macOS)
        StaffValidationRunner.runAndReportIfNeeded(platform: .macOS)
        // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
        NSApp.appearance = NSAppearance(named: .aqua)

        let viewController = macOSViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentMinSize = NSSize(width: 640, height: 420)
        window.title = "NoteMaster_Ver_1"
        window.center()
        window.contentViewController = viewController
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
