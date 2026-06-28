import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let viewController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        viewController.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return viewController
    }

    func updateUIViewController(_ viewController: UIActivityViewController, context: Context) {}
}
