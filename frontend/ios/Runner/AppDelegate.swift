import Flutter
import UIKit
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  var screenshotEventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)

    // Register for push notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // Set up screenshot detection EventChannel
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterEventChannel(
        name: "com.disciplefy/screenshot",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setStreamHandler(ScreenshotStreamHandler(appDelegate: self))
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - Screenshot Detection
class ScreenshotStreamHandler: NSObject, FlutterStreamHandler {
  weak var appDelegate: AppDelegate?

  init(appDelegate: AppDelegate) {
    self.appDelegate = appDelegate
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    appDelegate?.screenshotEventSink = events
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(userDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(self, name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    appDelegate?.screenshotEventSink = nil
    return nil
  }

  @objc private func userDidTakeScreenshot() {
    appDelegate?.screenshotEventSink?(nil)
  }
}
