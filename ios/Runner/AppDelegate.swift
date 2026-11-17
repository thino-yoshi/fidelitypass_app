import Flutter
import PassKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Bouton officiel « Ajouter à Apple Wallet » (classes en bas de ce fichier).
    if let registrar = self.registrar(forPlugin: "QartaAddPassButton") {
      registrar.register(AddPassButtonFactory(messenger: registrar.messenger()), withId: "qarta/add_pass_button")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// Bouton officiel « Ajouter à Apple Wallet » (PKAddPassButton) affiché dans Flutter.
// Règle Apple : utiliser uniquement ce bouton système, jamais le redessiner.
// Côté Flutter : UiKitView(viewType: "qarta/add_pass_button"), et le toucher
// arrive par le canal "qarta/add_pass_button_<id>" (méthode "pressed").

class AddPassButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return AddPassButtonView(frame: frame, viewId: viewId, messenger: messenger)
  }
}

class AddPassButtonView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger) {
    container = UIView(frame: frame)
    channel = FlutterMethodChannel(name: "qarta/add_pass_button_\(viewId)", binaryMessenger: messenger)
    super.init()

    let button = PKAddPassButton(addPassButtonStyle: .black)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(pressed), for: .touchUpInside)
    container.addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      button.topAnchor.constraint(equalTo: container.topAnchor),
      button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
  }

  @objc private func pressed() {
    channel.invokeMethod("pressed", arguments: nil)
  }

  func view() -> UIView { container }
}
