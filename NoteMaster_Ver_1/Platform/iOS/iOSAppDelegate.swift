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
        MusicFontRegistry.bootstrapIfNeeded()
        FretboardValidationRunner.runAndReportIfNeeded(platform: .iOS)

        let window = UIWindow(frame: UIScreen.main.bounds)
        // 从应用入口统一锁定浅色外观，避免语义色跟随系统进入深色模式。
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = iOSViewController()
        window.backgroundColor = .systemBackground
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
#endif
