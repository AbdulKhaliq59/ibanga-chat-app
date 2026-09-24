import Foundation
import Observation

@Observable
final class PairingViewModel {
    enum DeviceStatus: Equatable {
        case idle
        case connecting(SecureConnectionState)
        case connected
        case failed(String)
    }

    private(set) var activeDeviceID: NearbyDevice.ID?
    private(set) var failures: [NearbyDevice.ID: String] = [:]
    private(set) var succeededDeviceID: NearbyDevice.ID?

    private let sessions: any SessionRepositoryProtocol
    private let connectToPeer: ConnectToPeerUseCase
    private let onConnected: (Conversation.ID) -> Void

    init(
        sessions: any SessionRepositoryProtocol,
        connectToPeer: ConnectToPeerUseCase,
        onConnected: @escaping (Conversation.ID) -> Void
    ) {
        self.sessions = sessions
        self.connectToPeer = connectToPeer
        self.onConnected = onConnected
    }

    var devices: [NearbyDevice] { sessions.nearbyDevices }
    var displayName: String { sessions.localDisplayName }

    func status(for device: NearbyDevice) -> DeviceStatus {
        if succeededDeviceID == device.id { return .connected }
        if activeDeviceID == device.id {
            let state = device.claimedPeerID.map { sessions.connectionState(for: $0) } ?? .connecting
            return .connecting(state.isInProgress ? state : .connecting)
        }
        if let failure = failures[device.id] { return .failed(failure) }
        if let peerID = device.claimedPeerID, sessions.connectionState(for: peerID) == .secure { return .connected }
        return .idle
    }

    func connect(to device: NearbyDevice) async {
        guard activeDeviceID == nil else { return }
        activeDeviceID = device.id
        failures[device.id] = nil
        defer { activeDeviceID = nil }

        do {
            let conversation = try await connectToPeer(device)
            succeededDeviceID = device.id
            try? await Task.sleep(for: .milliseconds(600))
            onConnected(conversation.id)
        } catch .identityMismatch {
            failures[device.id] = "This device’s identity could not be verified."
        } catch .peerUnavailable {
            failures[device.id] = "This device is no longer nearby."
        } catch {
            failures[device.id] = "Secure connection could not be established. Try again."
        }
    }

    func rename(to name: String) async {
        await sessions.updateLocalDisplayName(name)
    }
}
