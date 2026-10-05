import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  private var chromeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    chromeChannel = makeChromeChannel(messenger: flutterViewController.engine.binaryMessenger)
    titlebarAppearsTransparent = true

    super.awakeFromNib()
  }

  private func makeChromeChannel(messenger: FlutterBinaryMessenger) -> FlutterMethodChannel {
    let channel = FlutterMethodChannel(name: "swiftie_quiz/window_chrome", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "match",
        let arguments = call.arguments as? [String: Any],
        let dark = arguments["dark"] as? Bool,
        let background = arguments["background"] as? Int
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
      self?.backgroundColor = NSColor(
        srgbRed: CGFloat((background >> 16) & 0xFF) / 255,
        green: CGFloat((background >> 8) & 0xFF) / 255,
        blue: CGFloat(background & 0xFF) / 255,
        alpha: CGFloat((background >> 24) & 0xFF) / 255
      )
      result(nil)
    }
    return channel
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
