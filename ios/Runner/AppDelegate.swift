import Flutter
import UIKit
import PDFKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  static var sharedChannel: FlutterMethodChannel?
  static var initialSharedFilePath: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      Self.handleIncomingFileURL(url, notifyImmediately: false)
    }

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let shareChannel = FlutterMethodChannel(
        name: "com.finance.spendo/share",
        binaryMessenger: controller.binaryMessenger
      )
      shareChannel.setMethodCallHandler { call, result in
        if call.method == "getInitialSharedFile" {
          let path = Self.initialSharedFilePath
          Self.initialSharedFilePath = nil
          result(path)
        } else if call.method == "extractPdfText" {
          if let path = call.arguments as? String {
            let text = Self.extractTextFromPDF(atPath: path)
            result(text)
          } else {
            result("")
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      Self.sharedChannel = shareChannel

      let timeZoneChannel = FlutterMethodChannel(
        name: "com.finance.spendo/timezone",
        binaryMessenger: controller.binaryMessenger
      )
      timeZoneChannel.setMethodCallHandler { call, result in
        if call.method == "getTimeZone" {
          result(TimeZone.current.identifier)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if Self.handleIncomingFileURL(url, notifyImmediately: true) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  @discardableResult
  static func handleIncomingFileURL(_ url: URL, notifyImmediately: Bool) -> Bool {
    guard url.isFileURL else { return false }
    let scoped = url.startAccessingSecurityScopedResource()
    defer {
      if scoped {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension.lowercased()
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("shared_invoice_\(Int(Date().timeIntervalSince1970 * 1000)).\(ext)")

    do {
      if FileManager.default.fileExists(atPath: tempURL.path) {
        try FileManager.default.removeItem(at: tempURL)
      }
      try FileManager.default.copyItem(at: url, to: tempURL)
      let savedPath = tempURL.path
      Self.initialSharedFilePath = savedPath
      if notifyImmediately, let channel = Self.sharedChannel {
        channel.invokeMethod("onSharedFile", arguments: savedPath)
      }
      return true
    } catch {
      return false
    }
  }

  static func extractTextFromPDF(atPath path: String) -> String {
    let url = URL(fileURLWithPath: path)
    guard let document = PDFDocument(url: url) else { return "" }
    var fullText = ""
    for i in 0..<document.pageCount {
      if let page = document.page(at: i), let pageText = page.string {
        fullText += pageText + "\n"
      }
    }
    return fullText
  }
}
