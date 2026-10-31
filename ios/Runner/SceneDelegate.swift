import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let urlContext = connectionOptions.urlContexts.first {
      AppDelegate.handleIncomingFileURL(urlContext.url, notifyImmediately: false)
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    for context in URLContexts {
      if AppDelegate.handleIncomingFileURL(context.url, notifyImmediately: true) {
        return
      }
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
