import Foundation

/// Represents the synchronization state of a local entity with the server
enum SyncStatus: String, Codable {
    /// Entity is fully synced with server
    case synced

    /// Entity was created locally and needs to be uploaded
    case pendingUpload

    /// Entity was modified locally and needs to be updated on server
    case pendingUpdate

    /// Entity was deleted locally and needs to be deleted on server
    case pendingDelete
}
