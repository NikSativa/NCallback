import Foundation
import NQueue

private let defaultScheduleQueue: Queueable = Queue.custom(label: "PollingCallback",
                                                           qos: .utility,
                                                           attributes: .concurrent)

final class PollingCallback<ResultType> {
    private let generator: () -> Callback<ResultType>
    private var cached: Callback<ResultType>?
    private var isCanceled: Bool = false

    private let scheduleQueue: Queueable

    private let idleTimeInterval: TimeInterval
    private let shouldRepeat: (ResultType) -> Bool
    private let response: (ResultType) -> Void

    private let timestamp: TimeInterval
    private let minimumWaitingTime: TimeInterval?
    private let retryCount: Int

    init(scheduleQueue: Queueable?,
         generator: @escaping @autoclosure () -> Callback<ResultType>,
         idleTimeInterval: TimeInterval,
         shouldRepeat: @escaping (ResultType) -> Bool = { _ in false },
         retryCount: Int = 5,
         minimumWaitingTime: TimeInterval? = nil,
         response: @escaping (ResultType) -> Void = { _ in }) {
        assert(retryCount > 0, "do you really need polling? seems like `retryCount <= 0` is ignoring polling")

        self.scheduleQueue = scheduleQueue ?? defaultScheduleQueue
        self.generator = generator
        self.idleTimeInterval = idleTimeInterval
        self.shouldRepeat = shouldRepeat
        self.retryCount = max(1, retryCount)
        self.minimumWaitingTime = minimumWaitingTime
        self.response = response
        self.timestamp = Self.timestamp()
    }

    func start() -> Callback<ResultType> {
        return Callback { actual in
            self.startPolling(actual, retryCount: self.retryCount)
        } stop: { _ in
            self.cancel()
        }
    }

    private func cancel() {
        isCanceled = true
        cached = nil
    }

    private func new() -> Callback<ResultType> {
        let new = generator()
        cached = new
        return new
    }

    private func canWait() -> Bool {
        if let minimumWaitingTime = minimumWaitingTime {
            return max(Self.timestamp() - self.timestamp, 0) < minimumWaitingTime
        }
        return false
    }

    func canRepeat(_ retryCount: Int) -> Bool {
        return retryCount > 0 || canWait()
    }

    private static func timestamp() -> TimeInterval {
        return max(Date().timeIntervalSinceReferenceDate, 0)
    }

    private func startPolling(_ actual: Callback<ResultType>, retryCount: Int) {
        if isCanceled {
            return
        }

        new().onComplete(options: .repeatable(.weakness)) { [unowned self] result in
            self.response(result)

            if self.canRepeat(retryCount), self.shouldRepeat(result) {
                self.schedulePolling(actual, retryCount: retryCount - 1)
            } else {
                actual.complete(result)
            }
        }
    }

    private func schedulePolling(_ actual: Callback<ResultType>, retryCount: Int) {
        scheduleQueue.asyncAfter(deadline: .now() + max(idleTimeInterval, .leastNormalMagnitude)) { [unowned self] in
            self.startPolling(actual, retryCount: retryCount)
        }
    }
}
