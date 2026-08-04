import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

#if os(iOS)
struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true) {
                self.onFinish()
            }
        }
    }

    static var canSendText: Bool {
        MFMessageComposeViewController.canSendText()
    }

    @MainActor
    static func openSMSURL(phone: String, body: String) {
        var components = URLComponents()
        components.scheme = "sms"
        components.path = phone
        components.queryItems = [URLQueryItem(name: "body", value: body)]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }
}
#endif
