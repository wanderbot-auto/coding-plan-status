import Foundation

public actor PollingService {
    private var task: Task<Void, Never>?

    public init() {}

    public func start(intervalSeconds: TimeInterval, action: @escaping @Sendable () async -> Void) {
        stop()
        task = Task {
            await action()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                    await action()
                } catch {
                    break
                }
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
