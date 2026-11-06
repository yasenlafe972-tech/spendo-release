import Flutter
import UIKit
import PDFKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate {
  static var sharedChannel: FlutterMethodChannel?
  static var initialSharedFilePath: String?
  static var deepLinkChannel: FlutterMethodChannel?
  static var initialDeepLink: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      if url.scheme == "spendo" {
        Self.initialDeepLink = url.absoluteString
      } else {
        Self.handleIncomingFileURL(url, notifyImmediately: false)
      }
    }

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let deepLinkChannel = FlutterMethodChannel(
        name: "com.finance.spendo/deeplink",
        binaryMessenger: controller.binaryMessenger
      )
      deepLinkChannel.setMethodCallHandler { call, result in
        if call.method == "getInitialLink" {
          let link = Self.initialDeepLink
          Self.initialDeepLink = nil
          result(link)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      Self.deepLinkChannel = deepLinkChannel

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
        } else if call.method == "extractImageText" {
          if let path = call.arguments as? String {
            Self.extractTextFromImage(atPath: path) { text in
              result(text)
            }
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
    if url.scheme == "spendo" {
      let link = url.absoluteString
      Self.initialDeepLink = link
      Self.deepLinkChannel?.invokeMethod("onDeepLink", arguments: link)
      return true
    }
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

  static func extractTextFromImage(atPath path: String, completion: @escaping (String) -> Void) {
    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      completion("")
      return
    }
    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    let request = VNRecognizeTextRequest { req, err in
      guard let observations = req.results as? [VNRecognizedTextObservation], err == nil else {
        DispatchQueue.main.async { completion("") }
        return
      }
      var fullText = ""
      for obs in observations {
        if let top = obs.topCandidates(1).first {
          fullText += top.string + "\n"
        }
      }
      DispatchQueue.main.async { completion(fullText) }
    }
    request.recognitionLevel = .accurate
    if #available(iOS 16.0, *) {
      request.recognitionLanguages = ["he-IL", "he", "en-US"]
    } else {
      request.recognitionLanguages = ["en-US"]
    }
    request.usesLanguageCorrection = true
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try requestHandler.perform([request])
      } catch {
        DispatchQueue.main.async { completion("") }
      }
    }
  }
}
