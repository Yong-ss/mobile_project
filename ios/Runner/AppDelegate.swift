import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let googleMapsApiKey = getEnvVar("GOOGLE_MAPS_API_KEY") ?? ""
    GMSServices.provideAPIKey(googleMapsApiKey)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getEnvVar(_ key: String) -> String? {
    guard let path = Bundle.main.path(forResource: "flutter_assets/.env", ofType: nil) else {
      return nil
    }
    do {
      let content = try String(contentsOfFile: path, encoding: .utf8)
      let lines = content.components(separatedBy: .newlines)
      for line in lines {
        let parts = line.components(separatedBy: "=")
        if parts.count >= 2 && parts[0].trimmingCharacters(in: .whitespaces) == key {
          return parts[1].trimmingCharacters(in: .whitespaces)
        }
      }
    } catch {
      return nil
    }
    return nil
  }
}