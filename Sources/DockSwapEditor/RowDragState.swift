import SwiftUI
import DockSwapCore

/// Tracks the in-flight row drag for the hover-to-combine gesture.
/// Holds a reference to the source row and, once a hover-hold completes,
/// the highlighted target row. Release while a target is highlighted
/// triggers the merge; release without a highlight cancels.
@MainActor
final class RowDragState: ObservableObject {
    /// Stable id of the row being dragged.
    var sourceID: UUID?
    /// Stable id of the row currently hovered (drop candidate).
    var hoverID: UUID?
    /// Whether the hover-hold has completed on `hoverID` (affordance shown).
    @Published var holdCompleted = false
    /// Current drag location in the list's coordinate space (for an optional
    /// indicator overlay).
    @Published var dragLocation: CGPoint = .zero

    private var holdTask: Task<Void, Never>?
    private let holdDuration: Duration = .milliseconds(202)

    func begin(_ id: UUID) {
        sourceID = id
        hoverID = nil
        holdCompleted = false
        holdTask?.cancel()
    }

    func hover(_ id: UUID?) {
        guard id != sourceID else { return }
        guard id != hoverID else { return }
        holdTask?.cancel()
        hoverID = id
        holdCompleted = false
        guard id != nil else { return }
        holdTask = Task { [weak self] in
            try? await Task.sleep(for: self?.holdDuration ?? .milliseconds(200))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run { self.holdCompleted = true }
        }
    }

    func end() -> (source: UUID, target: UUID)? {
        holdTask?.cancel()
        defer { sourceID = nil; hoverID = nil; holdCompleted = false }
        guard let s = sourceID, let t = hoverID, holdCompleted, s != t else { return nil }
        return (s, t)
    }

    func cancel() {
        holdTask?.cancel()
        sourceID = nil
        hoverID = nil
        holdCompleted = false
    }
}
