import Foundation
import NQueue

public enum MemoryOption: Equatable {
    case selfRetained
    case weakness

    public static let `default`: MemoryOption = .selfRetained
}

public enum CallbackOption: Equatable {
    case oneOff(MemoryOption)
    case repeatable(MemoryOption)

    public static let `default`: CallbackOption = .oneOff(.default)
    public static let weakness: CallbackOption = .oneOff(.weakness)
    public static let selfRetained: CallbackOption = .oneOff(.selfRetained)
}

public typealias ResultCallback<Response, Error: Swift.Error> = Callback<Result<Response, Error>>

public struct CallbackTimeout {
    public let seconds: Double
    public let callback: () -> Void

    public init(seconds: Double,
                callback: @escaping () -> Void) {
        self.seconds = seconds
        self.callback = callback
    }
}

public class Callback<ResultType> {
    public typealias Completion = (_ result: ResultType) -> Void
    public typealias ServiceClosure = (Callback) -> Void

    private let start: (Callback<ResultType>) -> Void
    private let stop: (Callback<ResultType>) -> Void
    private var beforeCallback: Completion?
    private var completeCallback: Completion?
    private var deferredCallback: Completion?
    private var strongyfy: Callback?
    private var options: CallbackOption = .default
    private var mutex: Mutexing = Mutex.pthread(.recursive)
    private var queue: DelayedQueue = .absent

    public var hashKey: String?

    public required init(start: @escaping ServiceClosure,
                         stop: @escaping ServiceClosure = { _ in }) {
        self.start = start
        self.stop = stop
    }

    public convenience init(result: @escaping () -> ResultType) {
        self.init(start: { $0.complete(result()) })
    }

    public convenience init(result: @escaping @autoclosure () -> ResultType) {
        self.init(start: { $0.complete(result()) })
    }

    public convenience init() {
        self.init(start: { _ in })
    }

    deinit {
        stop(self)
    }

    public func set(hashKey: String?) -> Callback {
        self.hashKey = hashKey
        return self
    }

    // MARK: - completion
    public func complete(_ result: ResultType) {
        queue.fire {
            typealias Callbacks = (before: Completion?, complete: Completion?, deferred: Completion?)

            let callbacks: Callbacks = self.mutex.sync {
                let callbacks: Callbacks = (before: self.beforeCallback, complete: self.completeCallback, deferred: self.deferredCallback)

                switch self.options {
                case .oneOff:
                    self.completeCallback = nil
                case .repeatable:
                    break
                }

                self.strongyfy = nil

                return callbacks
            }

            callbacks.before?(result)
            callbacks.complete?(result)
            callbacks.deferred?(result)
        }
    }

    internal func cleanup() {
        mutex.sync {
            completeCallback = nil
            strongyfy = nil
            stop(self)
        }
    }

    public func onComplete(options: CallbackOption = .default, _ callback: @escaping Completion) {
        self.options = options

        switch options {
        case .oneOff(let option):
            assert(completeCallback == nil, "was configured twice, please check it!")
            fallthrough
        case .repeatable(let option):
            switch option {
            case .selfRetained:
                strongyfy = self
            case .weakness:
                break
            }
        }

        completeCallback = callback
        start(self)
    }

    public func onSyncedComplete(options: CallbackOption = .default,
                                 timeout: CallbackTimeout? = nil,
                                 _ callback: Completion) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: ResultType!

        onComplete(options: options) {
            result = $0
            semaphore.signal()
        }

        if let timeout = timeout {
            let timeoutResult = semaphore.wait(timeout: .now() + timeout.seconds)
            switch timeoutResult {
            case .success:
                callback(result)
            case .timedOut:
                timeout.callback()
            }
        } else {
            semaphore.wait()
            callback(result)
        }
    }

    public func andThen<T>(_ waiter: @escaping (ResultType) -> Callback<T>) -> Callback<(ResultType, T)> {
        let lazy = LazyGenerator(generator: waiter)
        return .init(start: { actual in
            let actual = actual
            self.onComplete(options: .oneOff(.weakness)) { [unowned actual] result1 in
                lazy.cached(result1).onComplete(options: .oneOff(.weakness)) { [unowned actual] result2 in
                    actual.complete((result1, result2))
                }
            }
        }, stop: { _ in
            self.cleanup()
            lazy.cachedCallback?.cleanup()
        })
    }

    public func first<A, B>() -> Callback<A> where ResultType == (A, B) {
        return flatMap(\.0)
    }

    public func second<A, B>() -> Callback<B> where ResultType == (A, B) {
        return flatMap(\.1)
    }

    public func waitCompletion(of original: Callback) {
        let lazy = LazyGenerator(generator: self)
        Callback(start: { actual in
            let actual = actual
            original.onComplete(options: .oneOff(.weakness)) { [unowned actual] result in
                lazy.cached().complete(result)
                actual.complete(result)
            }
        }, stop: { _ in
            original.cleanup()
            lazy.cachedCallback?.cleanup()
        }).oneWay()
    }

    public func oneWay(options: CallbackOption = .default) {
        onComplete(options: options, { _ in })
    }

    public func oneWaySynced(options: CallbackOption = .default) {
        let semaphore = DispatchSemaphore(value: 0)
        onComplete(options: options, { _ in
            semaphore.signal()
        })
        semaphore.wait()
    }

    // MARK: - queueing
    public func schedule(in queue: Queueable) -> Self {
        self.queue = .async(queue)
        return self
    }

    public func schedule(in queue: DelayedQueue) -> Self {
        self.queue = queue
        return self
    }

    // MARK: - mapping
    public func flatMap<NewResultType>(_ mapper: @escaping (ResultType) -> NewResultType) -> Callback<NewResultType> {
        let copy = Callback<NewResultType>(start: { _ in self.start(self) },
                                           stop: { _ in self.stop(self) })
        copy.hashKey = hashKey

        let originalCallback = completeCallback
        completeCallback = { [weak copy] result in
            originalCallback?(result)
            copy?.complete(mapper(result))
        }

        options = .repeatable(.weakness)
        strongyfy = nil

        return copy
    }

    // MARK: - defer
    @discardableResult
    public func deferred(_ callback: @escaping Completion) -> Callback<ResultType> {
        mutex.sync {
            let originalCallback = deferredCallback
            deferredCallback = { result in
                originalCallback?(result)
                callback(result)
            }
        }

        return self
    }

    @discardableResult
    public func beforeComplete(_ callback: @escaping Completion) -> Callback<ResultType> {
        mutex.sync {
            let originalCallback = beforeCallback
            beforeCallback = { result in
                originalCallback?(result)
                callback(result)
            }
        }

        return self
    }

    // MARK: - ResultCallback
    public func complete<Response, Error: Swift.Error>(_ response: Response) where ResultType == Result<Response, Error> {
        complete(.success(response))
    }

    public func complete<Response, Error: Swift.Error>(_ error: Error) where ResultType == Result<Response, Error> {
        complete(.failure(error))
    }

    public func map<NewResponse, Response, Error: Swift.Error>(_ mapper: @escaping (Response) -> NewResponse) -> ResultCallback<NewResponse, Error>
    where ResultType == Result<Response, Error> {
        return flatMap { return $0.map(mapper) }
    }

    public func mapError<Response, Error: Swift.Error, NewError: Swift.Error>(_ mapper: @escaping (Error) -> NewError) -> ResultCallback<Response, NewError>
    where ResultType == Result<Response, Error> {
        return flatMap { return $0.mapError(mapper) }
    }

    public func recover<Response, Error: Swift.Error>(_ mapper: @escaping (Error) -> Response) -> Callback<Response>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure(let e):
                return mapper(e)
            }
        }
    }

    public func recover<Response, Error: Swift.Error>(_ recovered: @escaping () -> Response) -> Callback<Response>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure:
                return recovered()
            }
        }
    }

    public func recover<Response, Error: Swift.Error>(_ recovered: @escaping @autoclosure () -> Response) -> Callback<Response>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure:
                return recovered()
            }
        }
    }

    public func recoverNil<Response, Error: Swift.Error>() -> Callback<Response?>
    where ResultType == Result<Response, Error> {
        return flatMap {
            switch $0 {
            case .success(let v):
                return v
            case .failure:
                return nil
            }
        }
    }

    public func filterNils<Response>() -> Callback<[Response]>
    where ResultType == [Response?] {
        return flatMap { result in
            result.compactMap({ $0 })
        }
    }

    public func filterNils<Response, Error: Swift.Error>() -> ResultCallback<[Response], Error>
    where ResultType == Result<[Response?], Error> {
        return map { result in
            result.compactMap({ $0 })
        }
    }

    public class func success<Response, Error>(_ result: @escaping @autoclosure () -> Response) -> ResultCallback<Response, Error>
    where ResultType == Result<Response, Error> {
        return Callback { return .success(result()) }
    }

    public class func failure<Response, Error>(_ result: @escaping @autoclosure () -> Error) -> ResultCallback<Response, Error>
    where ResultType == Result<Response, Error> {
        return Callback { return .failure(result()) }
    }

    public func polling<Response, Error>(scheduleQueue: Queueable? = nil,
                                         retryCount: Int = 5,
                                         idleTimeInterval: TimeInterval = 10,
                                         minimumWaitingTime: TimeInterval? = nil,
                                         shouldRepeat: @escaping (Result<Response, Error>) -> Bool = { _ in false },
                                         response: @escaping (Result<Response, Error>) -> Void = { _ in }) -> Callback
    where ResultType == Result<Response, Error>, Error: Swift.Error {
        return PollingCallback(scheduleQueue: scheduleQueue,
                               generator: self,
                               idleTimeInterval: idleTimeInterval,
                               shouldRepeat: shouldRepeat,
                               retryCount: retryCount,
                               minimumWaitingTime: minimumWaitingTime,
                               response: response).start()
    }
}

// MARK: - Hashable
extension Callback: Hashable {
    public func hash(into hasher: inout Hasher) {
        hashKey.map({ hasher.combine($0) }) ?? hasher.combine(ObjectIdentifier(self))
    }

    public static func == (lhs: Callback, rhs: Callback) -> Bool {
        switch (lhs.hashKey, rhs.hashKey) {
        case (.some(let a), .some(let b)):
            return a == b
        case (.some, _):
            return false
        case (_, .some):
            return false
        case (.none, .none):
            return lhs === rhs
        }
    }
}

// MARK: - zip
public func zip<ResponseA, ResponseB>(_ lhs: Callback<ResponseA>,
                                      _ rhs: Callback<ResponseB>) -> Callback<(ResponseA, ResponseB)> {
    let startTask: Callback<(ResponseA, ResponseB)>.ServiceClosure = { original in
        var a: ResponseA?
        var b: ResponseB?

        let check = { [weak original] in
            if let a = a, let b = b {
                let result = (a, b)
                original?.complete(result)
            }
        }

        lhs.onComplete(options: .weakness) { result in
            a = result
            check()
        }

        rhs.onComplete(options: .weakness) { result in
            b = result
            check()
        }
    }

    let stopTask: Callback<(ResponseA, ResponseB)>.ServiceClosure = { _ in
        lhs.cleanup()
        rhs.cleanup()
    }

    return .init(start: startTask,
                 stop: stopTask)
}

private enum State<R> {
    case pending
    case value(R)
}

public func zip<Response>(_ input: [Callback<Response>]) -> Callback<[Response]> {
    if input.isEmpty {
        return .init(result: [])
    }

    var array = input
    var result: [State<Response>] = Array(repeating: .pending, count: array.count)
    let startTask: Callback<[Response]>.ServiceClosure = { original in
        for info in array.enumerated() {
            let offset = info.offset
            info.element.onComplete(options: .weakness) { [weak original] response in
                result.insert(.value(response), at: offset)

                let actual: [Response] = result.compactMap {
                    switch $0 {
                    case .pending:
                        return nil
                    case .value(let r):
                        return r
                    }
                }

                if array.count == actual.count {
                    original?.complete(actual)
                    array.removeAll()
                }
            }
        }
    }

    let stopTask: Callback<[Response]>.ServiceClosure = { _ in
        array.forEach { $0.cleanup() }
        array.removeAll()
    }

    return .init(start: startTask,
                 stop: stopTask)
}

public func zip<ResponseA, ResponseB, Error: Swift.Error>(_ lhs: ResultCallback<ResponseA, Error>,
                                                          _ rhs: ResultCallback<ResponseB, Error>) -> ResultCallback<(ResponseA, ResponseB), Error>  {
    let startTask: ResultCallback<(ResponseA, ResponseB), Error>.ServiceClosure = { original in
        var a: Result<ResponseA, Error>?
        var b: Result<ResponseB, Error>?

        let check = { [weak lhs, weak rhs, weak original] in
            if let a = a, let b = b {
                switch (a, b) {
                case (.success(let a), .success(let b)):
                    let result: (ResponseA, ResponseB) = (a, b)
                    original?.complete(result)
                case (.failure(let a), _),
                     (_, .failure(let a)):
                    original?.complete(a)
                }
            } else if let a = a {
                switch a {
                case .success:
                    break
                case .failure(let e):
                    original?.complete(e)
                    rhs?.cleanup()
                }
            } else if let b = b {
                switch b {
                case .success:
                    break
                case .failure(let e):
                    original?.complete(e)
                    lhs?.cleanup()
                }
            }
        }

        lhs.onComplete(options: .weakness) { result in
            a = result
            check()
        }

        rhs.onComplete(options: .weakness) { result in
            b = result
            check()
        }
    }

    let stopTask: ResultCallback<(ResponseA, ResponseB), Error>.ServiceClosure = { _ in
        lhs.cleanup()
        rhs.cleanup()
    }

    return .init(start: startTask,
                 stop: stopTask)
}

private final class LazyGenerator<In, Out> {
    typealias Generator = (In) -> Callback<Out>
    private let generator: Generator
    private(set) var cachedCallback: Callback<Out>?

    init(generator: @escaping Generator) {
        self.generator = generator
    }

    init(generator: @autoclosure @escaping () -> Callback<Out>) where In == Void {
        self.generator = { _ in
            return generator()
        }
    }

    func cached(_ in: In) -> Callback<Out> {
        if let cached = cachedCallback {
            return cached
        }
        let new = generator(`in`)
        cachedCallback = new
        return new
    }

    func cached() -> Callback<Out> where In == Void {
        return cached(Void())
    }
}
