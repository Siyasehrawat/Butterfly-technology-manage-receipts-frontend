import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var methodChannel: FlutterMethodChannel?
    private var pendingSharedFile: String?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Set up method channel for share intent
        if let controller = window?.rootViewController as? FlutterViewController {
            methodChannel = FlutterMethodChannel(
                name: "share_intent",
                binaryMessenger: controller.binaryMessenger
            )
            
        // Set up method call handler
        methodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
          if call.method == "getSharedFile" {
            result(self?.getSharedFile())
          } else if call.method == "cleanupSharedFile" {
            self?.cleanupSharedFile(call, result: result)
          } else {
            result(FlutterMethodNotImplemented)
          }
        }
        }
        
        // Check for shared file on launch
        checkForSharedFile()
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Handle URL scheme
    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        // Check if it's our share URL
        if url.scheme == "managereceipt" && url.host == "share" {
            checkForSharedFile()
            // Notify Flutter that a new shared file is available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.methodChannel?.invokeMethod("onSharedFileAvailable", arguments: nil)
            }
            return true
        }
        
        // Let other handlers process it (Google, Facebook, etc.)
        return super.application(app, open: url, options: options)
    }
    
  // Get shared file from UserDefaults
  private func getSharedFile() -> String? {
    // Use the same app group as ShareExtension
    if let sharedDefaults = UserDefaults(suiteName: "group.com.ButterflyTchnology.managereceipt"),
       let filePath = sharedDefaults.string(forKey: "sharedFilePath") {
      
      print("iOS: Retrieved shared file path: \(filePath)")
      
      // CRITICAL: Clear the shared data IMMEDIATELY to prevent reprocessing
      sharedDefaults.removeObject(forKey: "sharedFilePath")
      sharedDefaults.synchronize()
      
      return filePath
    }
    
    return pendingSharedFile
  }
  
  // Clean up shared file after processing
  @objc private func cleanupSharedFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let filePath = call.arguments as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "File path is required", details: nil))
      return
    }
    
    do {
      let fileURL = URL(fileURLWithPath: filePath)
      if FileManager.default.fileExists(atPath: filePath) {
        try FileManager.default.removeItem(at: fileURL)
        print("iOS: Cleaned up shared file: \(filePath)")
      }
      result(true)
    } catch {
      print("iOS: Failed to cleanup shared file: \(error)")
      result(FlutterError(code: "CLEANUP_ERROR", message: "Failed to delete file", details: error.localizedDescription))
    }
  }
    
    // Check for shared file from extension
    private func checkForSharedFile() {
        // Use the same app group as ShareExtension
        if let sharedDefaults = UserDefaults(suiteName: "group.com.ButterflyTchnology.managereceipt"),
           let filePath = sharedDefaults.string(forKey: "sharedFilePath") {
            
            pendingSharedFile = filePath
            print("iOS: Detected shared file: \(filePath)")
        }
    }
}
