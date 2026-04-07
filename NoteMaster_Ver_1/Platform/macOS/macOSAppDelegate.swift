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
        print("[Startup][macOSApp] applicationDidFinishLaunching begin")
        print("[Startup][macOSApp] bootstrap music fonts")
        MusicFontRegistry.bootstrapIfNeeded()
        print("[Startup][macOSApp] run fretboard validation")
        FretboardValidationRunner.runAndReportIfNeeded(platform: .macOS)
        print("[Startup][macOSApp] run staff validation")
        StaffValidationRunner.runAndReportIfNeeded(platform: .macOS)
        print("[Startup][macOSApp] run settings navigation validation")
        SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .macOS)
        print("[Startup][macOSApp] run piano validation")
        PianoValidationRunner.runAndReportIfNeeded(platform: .macOS)
        print("[Startup][macOSApp] run exercise composition validation")
        ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .macOS)
        // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
        print("[Startup][macOSApp] apply aqua appearance")
        NSApp.appearance = NSAppearance(named: .aqua)

        print("[Startup][macOSApp] create root view controller")
        let viewController = macOSRootViewController()
        print("[Startup][macOSApp] create window")
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentMinSize = NSSize(width: 340, height: 420)
        window.title = "NoteMaster_Ver_1"
        window.center()
        print("[Startup][macOSApp] attach contentViewController")
        window.contentViewController = viewController
        print("[Startup][macOSApp] make window key and visible")
        window.makeKeyAndOrderFront(nil)

        print("[Startup][macOSApp] activate app")
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        #if DEBUG
        if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
            print(
                "[RuntimeSmoke][macOS] scheduled scenario=layout_preset_regression"
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard
                    let self,
                    let window = self.window,
                    let rootViewController = window.contentViewController
                    as? macOSRootViewController,
                    let viewController = rootViewController.activeExerciseViewController
                else {
                    let summary =
                        "[RuntimeSmoke][macOS] FAIL scenario=layout_preset_regression reason=missing_window_or_view_controller"
                    print(summary)
                    fatalError(summary)
                }

                viewController.runLayoutPresetRegressionSmokeTest(
                    in: window
                ) { passed, summary in
                    print(summary)
                    if passed {
                        NSApp.terminate(nil)
                    } else {
                        fatalError(summary)
                    }
                }
            }
        }
        #endif

        print("[Startup][macOSApp] applicationDidFinishLaunching end")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

#if DEBUG
private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let layoutPresetRegressionValue = "layout-preset-regression"

    static var shouldRunLayoutPresetRegression: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == layoutPresetRegressionValue
    }
}
#endif
#endif
