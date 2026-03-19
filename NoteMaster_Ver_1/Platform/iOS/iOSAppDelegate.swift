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
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = iOSViewController()
        window.backgroundColor = .white
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
#endif
