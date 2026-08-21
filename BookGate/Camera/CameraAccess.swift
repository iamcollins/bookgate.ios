import AVFoundation

/// The single place camera authorization is read and requested. Gives the app one API to pre-warm
/// access (onboarding), gate the cover-capture / nightly-gate cameras, and warn — well before an
/// alarm ever fires.
enum CameraAccess {

    static var status: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    static var isAuthorized: Bool { status == .authorized }

    /// Whether this device actually has the camera we're about to ask for. Permission can be
    /// granted on a machine with no camera at all (every Simulator), where the preview layer stays
    /// black for ever and the user is left staring at a viewfinder that will never see anything.
    static func hasCamera(position: AVCaptureDevice.Position) -> Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) != nil
    }

    /// True once the user has answered the system prompt in either direction —
    /// the states where a warning/gate is warranted (as opposed to `.notDetermined`,
    /// where we simply haven't asked yet).
    static var isBlocked: Bool {
        switch status {
        case .denied, .restricted: return true
        default:                   return false
        }
    }

    /// Prompt only when still undecided; iOS never re-shows the dialog once
    /// answered, so this is safe to call from any selection point. Returns the
    /// resolved status.
    @discardableResult
    static func request() async -> AVAuthorizationStatus {
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        return status
    }
}
