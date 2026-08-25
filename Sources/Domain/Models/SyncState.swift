import Foundation

/// Defines the synchronization lifecycle state of a local entity.
public enum SyncState: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Entity is confirmed to be synchronized with the remote backend.
    case synced = "synced"

    /// Entity was created locally and is queued to be uploaded to the backend.
    case pendingCreation = "pendingCreation"

    /// Entity was modified locally and its latest updates are queued to be uploaded.
    case pendingUpdate = "pendingUpdate"

    /// Entity was soft-deleted locally and is queued to be deleted on the backend.
    case pendingDeletion = "pendingDeletion"

    /// Synchronization failed permanently or reached maximum retry attempts.
    case syncFailed = "syncFailed"

    public var id: String { rawValue }

    /// Whether this entity has local changes pending synchronization.
    public var isPending: Bool {
        switch self {
        case .pendingCreation, .pendingUpdate, .pendingDeletion:
            return true
        case .synced, .syncFailed:
            return false
        }
    }

    /// Hex color code for UI sync indicators.
    public var badgeColorHex: String {
        switch self {
        case .synced: return "#10B981"
        case .pendingCreation, .pendingUpdate: return "#3B82F6"
        case .pendingDeletion: return "#F59E0B"
        case .syncFailed: return "#EF4444"
        }
    }

    /// System SF Symbol icon name representing the sync state.
    public var iconName: String {
        switch self {
        case .synced: return "checkmark.icloud.fill"
        case .pendingCreation, .pendingUpdate: return "arrow.triangle.2.circlepath.icloud.fill"
        case .pendingDeletion: return "xmark.icloud.fill"
        case .syncFailed: return "exclamationmark.icloud.fill"
        }
    }

    /// User-facing descriptive title.
    public var displayTitle: String {
        switch self {
        case .synced: return "Synced"
        case .pendingCreation: return "Pending Upload"
        case .pendingUpdate: return "Pending Sync"
        case .pendingDeletion: return "Pending Deletion"
        case .syncFailed: return "Sync Error"
        }
    }
}
