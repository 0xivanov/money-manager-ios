import Foundation

extension MoneyManagerStore {
    func startAction(
        scope: ActionScope? = nil,
        generation: Int? = nil,
        _ operation: @escaping @MainActor (Int) async -> Void
    ) {
        if let scope {
            cancelAction(scope: scope)
        }
        let id = UUID()
        let requestedGeneration = generation ?? sessionGeneration
        if let scope {
            scopedActionIDs[scope] = id
        }
        actionTasks[id] = Task { [weak self] in
            guard let self else { return }
            await operation(requestedGeneration)
            self.actionTasks[id] = nil
            if let scope, self.scopedActionIDs[scope] == id {
                self.scopedActionIDs[scope] = nil
            }
        }
    }

    func cancelAction(scope: ActionScope) {
        guard let id = scopedActionIDs.removeValue(forKey: scope) else { return }
        actionTasks.removeValue(forKey: id)?.cancel()
    }

    func runRequest(
        generation: Int,
        _ operation: @escaping () async throws -> Void
    ) async {
        guard generation == sessionGeneration else { return }
        let requestID = UUID()
        activeRequestIDs.insert(requestID)
        isLoading = true
        error = nil
        defer {
            activeRequestIDs.remove(requestID)
            isLoading = !activeRequestIDs.isEmpty
        }
        do {
            try Task.checkCancellation()
            try await operation()
            try Task.checkCancellation()
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch APIError.unauthorized {
            guard generation == sessionGeneration else { return }
            expireSession(message: APIError.unauthorized.localizedDescription)
        } catch {
            guard generation == sessionGeneration else { return }
            self.error = error.localizedDescription
        }
    }

}
