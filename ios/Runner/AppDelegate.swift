import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerScreenChannel(engineBridge.applicationRegistrar.messenger())
  }

  private func registerScreenChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.narrowroad.scriptureup/screen",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "keepAwake":
        guard let on = call.arguments as? Bool else {
          result(
            FlutterError(code: "bad-arguments", message: "keepAwake takes a Bool", details: nil)
          )
          return
        }
        UIApplication.shared.isIdleTimerDisabled = on
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
