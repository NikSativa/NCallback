import Foundation
import NQueue
import NSpry
@testable import NCallback

@available(iOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
@available(macOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
typealias FakeResultCallback<Response, Error: Swift.Error> = FakeCallback<Result<Response, Error>>

@available(iOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
@available(macOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
final class FakeCallback<ResultType>: Callback<ResultType>, Spryable {
    enum ClassFunction: String, StringRepresentable {
        case success = "success(_:)"
        case failure = "failure(_:)"
    }

    enum Function: String, StringRepresentable {
        case complete = "complete(_:)"
        case cleanup = "cleanup()"

        case onComplete = "onComplete(options:_:)"
        case oneWay = "oneWay(kind:)"

        case flatMap = "flatMap(_:)"

        case deferred = "deferred(_:)"
        case beforeComplete = "beforeComplete(_:)"

        case map = "map(_:)"
        case mapError = "mapError(_:)"

        case polling = "polling(scheduleQueue:retryCount:idleTimeInterval:minimumWaitingTime:shouldRepeat:response:)"
        case scheduleCompletionInQueue = "schedule(completionIn:)"
        case scheduleTaskInQueue = "schedule(taskIn:)"
    }

    override func complete(_ result: ResultType) {
        return spryify(arguments: result)
    }

    override func cleanup() {
        return spryify()
    }

    var onComplete: Completion?
    override func onComplete(options: CallbackOption = .default, _ callback: @escaping Completion) {
        onComplete = callback
        return spryify(arguments: options, callback)
    }

    override func oneWay(options: CallbackOption = .default) {
        return spryify(arguments: options)
    }

    override func flatMap<NewResponse>(_ mapper: @escaping (ResultType) -> NewResponse) -> Callback<NewResponse> {
        return spryify(arguments: mapper)
    }

    var deferred: Completion?
    @discardableResult
    override func deferred(_ callback: @escaping Completion) -> Callback<ResultType> {
        deferred = callback
        return spryify(arguments: callback)
    }

    var beforeComplete: Completion?
    @discardableResult
    override func beforeComplete(_ callback: @escaping Completion) -> Callback<ResultType> {
        beforeComplete = callback
        return spryify(arguments: callback)
    }

    override func complete<Response, Error: Swift.Error>(_ response: Response)
    where ResultType == Result<Response, Error> {
        return spryify(arguments: response)
    }

    override func complete<Response, Error: Swift.Error>(_ error: Error)
    where ResultType == Result<Response, Error> {
        return spryify(arguments: error)
    }

    override func map<NewResponse, Response, Error: Swift.Error>(_ mapper: @escaping (Response) -> NewResponse) -> ResultCallback<NewResponse, Error>
    where ResultType == Result<Response, Error> {
        return spryify(arguments: mapper)
    }

    override func mapError<Response, Error: Swift.Error, NewError: Swift.Error>(_ mapper: @escaping (Error) -> NewError) -> ResultCallback<Response, NewError>
    where ResultType == Result<Response, Error> {
        return spryify(arguments: mapper)
    }

    override static func success<Response, Error>(_ result: @escaping @autoclosure () -> Response) -> ResultCallback<Response, Error>
    where ResultType == Result<Response, Error> {
        return spryify(arguments: result)
    }

    override static func failure<Response, Error>(_ result: @escaping @autoclosure () -> Error) -> ResultCallback<Response, Error>
    where ResultType == Result<Response, Error> {
        return spryify(arguments: result)
    }

    override func polling(scheduleQueue: Queueable? = nil,
                          retryCount: Int,
                          idleTimeInterval: TimeInterval,
                          minimumWaitingTime: TimeInterval? = nil,
                          shouldRepeat: @escaping (ResultType) -> Bool = { _ in false },
                          response: @escaping (ResultType) -> Void = { _ in }) -> Callback<ResultType> {
        return spryify(arguments: scheduleQueue, retryCount, idleTimeInterval, minimumWaitingTime, shouldRepeat, response)
    }

    override func schedule(completionIn queue: DelayedQueue) -> Self {
        return spryify(arguments: queue)
    }

    override func schedule(completionIn queue: Queueable) -> Self {
        return spryify(arguments: queue)
    }

    override func schedule(taskIn queue: DelayedQueue) -> Self {
        return spryify(arguments: queue)
    }

    override func schedule(taskIn queue: Queueable) -> Self {
        return spryify(arguments: queue)
    }
}
