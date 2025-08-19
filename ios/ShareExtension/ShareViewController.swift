import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Customize the action button text from "Post" to "Upload"
        if let navigationController = self.navigationController {
            navigationController.navigationBar.topItem?.rightBarButtonItem?.title = "Upload"
        }
    }
    
    override func isContentValid() -> Bool {
        return true
    }
    
    override func didSelectPost() {
        // Get the shared items
        if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem {
            if let itemProvider = extensionItem.attachments?.first {
                
                // Handle images
                if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                        if let url = item as? URL {
                            self?.saveAndOpenApp(fileURL: url)
                        } else if let image = item as? UIImage {
                            self?.saveImageAndOpenApp(image: image)
                        } else if let data = item as? Data, let image = UIImage(data: data) {
                            self?.saveImageAndOpenApp(image: image)
                        }
                    }
                    return
                }
                
                // Handle PDFs
                if itemProvider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                    itemProvider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { [weak self] (item, error) in
                        if let url = item as? URL {
                            self?.saveAndOpenApp(fileURL: url)
                        }
                    }
                    return
                }
            }
        }
        
        // Close extension
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    override func configurationItems() -> [Any]! {
        return []
    }
    
    private func saveAndOpenApp(fileURL: URL) {
        // Copy file to shared App Group container
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.ButterflyTchnology.managereceipt"
        ) else {
            print("ShareExtension: Failed to get container URL")
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        let sharedDirectory = containerURL.appendingPathComponent("Library/Caches/SharedFiles", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: sharedDirectory, withIntermediateDirectories: true, attributes: nil)
        
        // Generate unique filename
        let fileName = "shared_\(Date().timeIntervalSince1970)_\(UUID().uuidString).\(fileURL.pathExtension)"
        let destinationURL = sharedDirectory.appendingPathComponent(fileName)
        
        do {
            // Copy file to shared container
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            
            print("ShareExtension: Copied file to shared container: \(destinationURL.path)")
            
            // Save path to shared UserDefaults
            if let sharedDefaults = UserDefaults(suiteName: "group.com.ButterflyTchnology.managereceipt") {
                sharedDefaults.set(destinationURL.path, forKey: "sharedFilePath")
                sharedDefaults.synchronize()
                print("ShareExtension: Saved path to UserDefaults")
            }
            
            // Open main app
            openMainApp()
        } catch {
            print("ShareExtension: Failed to copy file: \(error)")
        }
        
        // Close extension
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    private func saveImageAndOpenApp(image: UIImage) {
        // Save image to App Group shared container
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.ButterflyTchnology.managereceipt"
        ) else {
            print("ShareExtension: Failed to get container URL")
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        let sharedDirectory = containerURL.appendingPathComponent("Library/Caches/SharedFiles", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: sharedDirectory, withIntermediateDirectories: true, attributes: nil)
        
        let fileName = "shared_\(Date().timeIntervalSince1970)_\(UUID().uuidString).jpg"
        let fileURL = sharedDirectory.appendingPathComponent(fileName)
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            do {
                try imageData.write(to: fileURL)
                print("ShareExtension: Saved image to: \(fileURL.path)")
                saveAndOpenApp(fileURL: fileURL)
            } catch {
                print("ShareExtension: Failed to save image: \(error)")
                extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        } else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    private func openMainApp() {
        // Open main app using URL scheme
        let url = URL(string: "managereceipt://share")!
        
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = responder?.next
        }
        
        // Alternative method for iOS 10+
        if #available(iOS 10.0, *) {
            self.extensionContext?.open(url, completionHandler: nil)
        }
    }
}
