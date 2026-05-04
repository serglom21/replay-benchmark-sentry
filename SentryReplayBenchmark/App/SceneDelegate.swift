import UIKit

/// Closest thing to "globally disable the focus engine". The window is the root
/// `UIFocusEnvironment` for the entire app — overriding its focus surface here
/// prunes the engine's traversal before it ever descends into a view controller.
/// Apple doesn't ship an Info.plist flag or `UIApplication`-level switch for this;
/// the window override is the highest interception point.
private final class NoFocusWindow: UIWindow {
    override var canBecomeFocused: Bool { false }
    override var preferredFocusEnvironments: [any UIFocusEnvironment] { [] }
    override func focusItems(in rect: CGRect) -> [any UIFocusItem] { [] }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = NoFocusWindow(windowScene: windowScene)
        let nav = UINavigationController(rootViewController: SetupViewController())
        nav.navigationBar.prefersLargeTitles = true
        window.rootViewController = nav
        self.window = window
        window.makeKeyAndVisible()
    }
}
