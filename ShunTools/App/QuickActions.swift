import UIKit

@MainActor final class QuickActionDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let action = options.shortcutItem { Self.route(action) }
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
    static func refresh() {
        UIApplication.shared.shortcutItems = [Tool.image, .ringtone, .deviceInfo].map {
            UIApplicationShortcutItem(type: $0.rawValue, localizedTitle: $0.title, localizedSubtitle: nil, icon: UIApplicationShortcutIcon(systemImageName: $0.symbol), userInfo: nil)
        }
    }
    @discardableResult static func route(_ item: UIApplicationShortcutItem) -> Bool {
        guard let tool = Tool(rawValue: item.type) else { return false }
        ToolRouter.shared.open(tool); return true
    }
}
@MainActor final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActionDelegate.route(shortcutItem))
    }
}
