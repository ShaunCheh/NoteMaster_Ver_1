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

        print("[Startup][iOSApp] create window")
        let window = UIWindow(frame: UIScreen.main.bounds)
        // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
        window.overrideUserInterfaceStyle = .light
        print("[Startup][iOSApp] create root view controller")
        window.rootViewController = iOSViewController()
        window.backgroundColor = .systemBackground
        print("[Startup][iOSApp] make window key and visible")
        window.makeKeyAndVisible()
        self.window = window
        print("[Startup][iOSApp] didFinishLaunching end")
        return true
    }
}
#endif
