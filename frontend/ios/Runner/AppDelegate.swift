import Flutter
import UIKit
import Firebase
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate {
  var screenshotEventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    configureGoogleSignInAppCheck()
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

  /// Prepares App Check for Google Sign-In so its OAuth requests carry an
  /// App Check token (App Attest in release, debug provider in debug builds
  /// and on the simulator). Must run before the first sign-in. Enforcement is
  /// not on yet: failures are logged and sign-in proceeds without a token.
  /// See docs/ops/ios-app-check.md.
  private func configureGoogleSignInAppCheck() {
    #if DEBUG || targetEnvironment(simulator)
    // The iOS API key from GoogleService-Info.plist; it must allow the
    // Firebase App Check API. The debug token is printed to the Xcode console
    // after "App Check debug token:" and must be registered in Firebase.
    guard let apiKey = FirebaseApp.app()?.options.apiKey else {
      NSLog("[AppCheck] Google Sign-In debug provider skipped: no API key")
      return
    }
    GIDSignIn.sharedInstance.configureDebugProvider(withAPIKey: apiKey) { error in
      if let error = error as NSError? {
        NSLog("[AppCheck] Google Sign-In debug provider failed: %@ %ld", error.domain, error.code)
      }
    }
    #else
    GIDSignIn.sharedInstance.configure { error in
      if let error = error as NSError? {
        NSLog("[AppCheck] Google Sign-In App Check failed: %@ %ld", error.domain, error.code)
      }
    }
    #endif
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
