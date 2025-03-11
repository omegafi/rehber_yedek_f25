import UIKit
import Flutter
import Contacts

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // iOS'ta kişiler iznini aktif olarak iste
    requestContactPermission()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // iOS için özel izin isteği
  private func requestContactPermission() {
    let store = CNContactStore()
    store.requestAccess(for: .contacts) { granted, error in
      if let error = error {
        print("Rehber erişim izni hatası: \(error.localizedDescription)")
      }
      if granted {
        print("Rehber erişim izni verildi")
      } else {
        print("Rehber erişim izni reddedildi")
      }
    }
  }
}
