import CloudKit
import PottFeatures
import SwiftUI
import UIKit

/// Silent pushes for CloudKit and accepting a household invitation that the system opens.
///
/// SwiftUI has no hook for `userDidAcceptCloudKitShareWith`; it arrives at the scene delegate,
/// which SwiftUI only uses when the app delegate names it.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set by `PottApp.init` before any delegate call.
    @MainActor static var model: AppModel?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

/// Receives accepted invitations, both when the app runs and when the link launches it.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata { accept(metadata) }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata)
    {
        accept(metadata)
    }

    private func accept(_ metadata: CKShare.Metadata) {
        guard let model = AppDelegate.model else { return }
        Task { await model.accept(metadata) }
    }
}

/// The system sheet to invite people, manage participants or stop sharing.
struct CloudSharingView: UIViewControllerRepresentable {
    var share: CKShare
    var container: CKContainer
    var onChange: (CKShare?) -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onChange: (CKShare?) -> Void

        init(onChange: @escaping (CKShare?) -> Void) { self.onChange = onChange }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            String(localized: "Our household in Pott")
        }

        func cloudSharingController(
            _ csc: UICloudSharingController, failedToSaveShareWithError error: any Error
        ) {
            onChange(csc.share)
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) { onChange(csc.share) }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) { onChange(nil) }
    }
}
