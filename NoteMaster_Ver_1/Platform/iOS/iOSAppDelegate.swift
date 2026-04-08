//
//  iOSAppDelegate.swift
//  NoteMaster_Ver_1
//
//  Created by Shaun on 2026/3/19.
//

#if os(iOS)
import UIKit

@main
final class iOSAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[Startup][iOSApp] didFinishLaunching begin")
        print("[Startup][iOSApp] bootstrap music fonts")
        MusicFontRegistry.bootstrapIfNeeded()
        print("[Startup][iOSApp] run fretboard validation")
        FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)
        print("[Startup][iOSApp] run staff validation")
        StaffValidationRunner.runAndReportIfNeeded(platform: .iOS)
        print("[Startup][iOSApp] run settings navigation validation")
        SettingsNavigationValidationRunner.runAndReportIfNeeded(platform: .iOS)
        print("[Startup][iOSApp] run piano validation")
        PianoValidationRunner.runAndReportIfNeeded(platform: .iOS)
        print("[Startup][iOSApp] run playback validation")
        PlaybackValidationRunner.runAndReportIfNeeded(platform: .iOS)
        print("[Startup][iOSApp] run play composition validation")
        PlayCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)
        print("[Startup][iOSApp] run exercise composition validation")
        ExerciseCompositionValidationRunner.runAndReportIfNeeded(platform: .iOS)

        #if DEBUG
        if RuntimeSmokeScenario.shouldRunStartupValidationOnly {
            print("[RuntimeSmoke][iOS] PASS scenario=startup_validation")
            exit(0)
        }
        #endif

        print("[Startup][iOSApp] create window")
        let window = UIWindow(frame: UIScreen.main.bounds)
        // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
        window.overrideUserInterfaceStyle = .light
        print("[Startup][iOSApp] create root view controller")
        window.rootViewController = iOSRootViewController()
        window.backgroundColor = .systemBackground
        print("[Startup][iOSApp] make window key and visible")
        window.makeKeyAndVisible()
        self.window = window

        #if DEBUG
        if RuntimeSmokeScenario.shouldRunLayoutPresetRegression {
            print("[RuntimeSmoke][iOS] scheduled scenario=layout_preset_regression")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard
                    let self,
                    let window = self.window,
                    let rootViewController = window.rootViewController
                    as? iOSRootViewController,
                    let viewController = rootViewController.activeExerciseViewController
                else {
                    let summary =
                        "[RuntimeSmoke][iOS] FAIL scenario=layout_preset_regression reason=missing_window_or_view_controller"
                    print(summary)
                    fatalError(summary)
                }

                viewController.runLayoutPresetRegressionSmokeTest(
                    in: window
                ) { passed, summary in
                    print(summary)
                    if passed {
                        exit(0)
                    } else {
                        fatalError(summary)
                    }
                }
            }
        }
        #endif

        print("[Startup][iOSApp] didFinishLaunching end")
        return true
    }
}

#if DEBUG
private enum RuntimeSmokeScenario {
    static let environmentKey = "NOTE_MASTER_RUNTIME_SMOKE_TEST"
    static let layoutPresetRegressionValue = "layout-preset-regression"
    static let startupValidationValue = "startup-validation"

    static var shouldRunLayoutPresetRegression: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == layoutPresetRegressionValue
    }

    static var shouldRunStartupValidationOnly: Bool {
        ProcessInfo.processInfo.environment[environmentKey]
            == startupValidationValue
    }
}
#endif
#endif
