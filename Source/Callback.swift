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

public class Callback<ResultType> {
    public typealias Completion = (_ result: ResultType) -> Void
    public typealias ServiceClosure = (Callback) -> Void

    private let start: ServiceClosure
    private let stop: ServiceClosure
    private var beforeCallback: Completion?
    private var completeCallback: Completion?
    private var deferredCallback: Completion?
    private var strongyfy: Callback?
    private var options: CallbackOption = .default
    private var mutex: Mutexing = Mutex.pthread(.recursive)
    private var completionQueue: DelayedQueue = .absent
    private var taskQueue: DelayedQueue = .absent

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

    // MARK: - assign

    public func assign(to variable: inout AnyObject?) -> Callback {
        variable = self
        return self
    }

    public func assign(to variable: inout AnyObject) -> Callback {
        variable = self
        return self
    }

    public func assign(to variable: inout Any?) -> Callback {
        variable = self
        return self
    }

    public func assign(to variable: inout Any) -> Callback {
        variable = self
        return self
    }

    public func assign(to variable: inout Callback?) -> Callback {
        variable = self
        return self
    }

    public func assign(to variable: inout Callback) -> Callback {
        variable = self
        return self
    }

    // MARK: - completion

    public func complete(_ result: ResultType) {
        completionQueue.fire {
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

        taskQueue.fire {
            self.start(self)
        }
    }

    public func on<Response, Error: Swift.Error>(options: CallbackOption = .default,
                                                 success: @escaping (Response) -> Void,
                                                 fail: @escaping (Error) -> Void)
    where ResultType == Result<Response, Error> {
        onComplete(options: options) { result in
            switch result {
            case .success(let response):
                success(response)
            case .failure(let error):
                fail(error)
            }
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
        onComplete(options: options) { _ in }
    }

    // MARK: - queueing

    public func schedule(completionIn queue: Queueable) -> Self {
        mutex.sync {
            self.completionQueue = .async(queue)
        }
        return self
    }

    public func schedule(completionIn queue: DelayedQueue) -> Self {
        mutex.sync {
            self.completionQueue = queue
        }
        return self
    }

    public func schedule(taskIn queue: Queueable) -> Self {
        mutex.sync {
            self.taskQueue = .async(queue)
        }
        return self
    }

    public func schedule(taskIn queue: DelayedQueue) -> Self {
        mutex.sync {
            self.taskQueue = queue
        }
        return self
    }

    // MARK: - mapping

    public func flatMap<NewResultType>(_ mapper: @escaping (ResultType) -> NewResultType) -> Callback<NewResultType> {
        let copy = Callback<NewResultType>(start: { _ in self.start(self) },
                                           stop: { _ in self.stop(self) })
        copy.hashKey = hashKey

        let originalCallback = completeCallback
        completeCallback = { [weak copy, weak self] result in
            originalCallback?(result)

            if let copy = copy {
                (self?.taskQueue ?? copy.taskQueue).forceAsync {
                    copy.complete(mapper(result))
                }
            }
        }

        options = .repeatable(.weakness)
        strongyfy = nil

        return copy
    }

    public func map<NewResponse, Response, Error: Swift.Error>(_ mapper: @escaping (Response) -> NewResponse) -> ResultCallback<NewResponse, Error>
    where ResultType == Result<Response, Error> {
        return flatMap {
            return $0.map(mapper)
        }
    }

    public func tryMap<NewResponse, Response>(_ mapper: @escaping (Response) throws -> NewResponse) -> ResultCallback<NewResponse, Swift.Error>
    where ResultType == Result<Response, Swift.Error> {
        return flatMap {
            do {
                switch $0 {
                case .success(let response):
                    return .success(try mapper(response))
                case .failure(let error):
                    return .failure(error)
                }
            } catch {
                return .failure(error)
            }
        }
    }

    public func mapError<Response, Error: Swift.Error, NewError: Swift.Error>(_ mapper: @escaping (Error) -> NewError) -> ResultCallback<Response, NewError>
    where ResultType == Result<Response, Error> {
        return flatMap {
            return $0.mapError(mapper)
        }
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
    public func deferredSuccess<Response, Error: Swift.Error>(_ success: @escaping (Response) -> Void) -> Callback<ResultType>
    where ResultType == Result<Response, Error> {
        return deferred { result in
            switch result {
            case .success(let response):
                success(response)
            case .failure:
                break
            }
        }
    }

    @discardableResult
    public func deferredFail<Response, Error: Swift.Error>(_ fail: @escaping (Error) -> Void) -> Callback<ResultType>
    where ResultType == Result<Response, Error> {
        return deferred { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                fail(error)
            }
        }
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

    @discardableResult
    public func beforeSuccess<Response, Error: Swift.Error>(_ success: @escaping (Response) -> Void) -> Callback<ResultType>
    where ResultType == Result<Response, Error> {
        return beforeComplete { result in
            switch result {
            case .success(let response):
                success(response)
            case .failure:
                break
            }
        }
    }

    @discardableResult
    public func beforeFail<Response, Error: Swift.Error>(_ fail: @escaping (Error) -> Void) -> Callback<ResultType>
    where ResultType == Result<Response, Error> {
        return beforeComplete { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                fail(error)
            }
        }
    }

    // MARK: - ResultCallback

    public func complete<Response, Error: Swift.Error>(_ response: Response) where ResultType == Result<Response, Error> {
        complete(.success(response))
    }

    public func complete<Response, Error: Swift.Error>(_ error: Error) where ResultType == Result<Response, Error> {
        complete(.failure(error))
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
            result.compactMap { $0 }
        }
    }

    public func filterNils<Response, Error: Swift.Error>() -> ResultCallback<[Response], Error>
    where ResultType == Result<[Response?], Error> {
        return map { result in
            result.compactMap { $0 }
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

    public func polling(scheduleQueue: Queueable? = nil,
                        retryCount: Int,
                        idleTimeInterval: TimeInterval,
                        minimumWaitingTime: TimeInterval? = nil,
                        shouldRepeat: @escaping (ResultType) -> Bool = { _ in false },
                        response: @escaping (ResultType) -> Void = { _ in }) -> Callback {
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
        hashKey.map { hasher.combine($0) } ?? hasher.combine(ObjectIdentifier(self))
    }

    public static func ==(lhs: Callback, rhs: Callback) -> Bool {
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
        return cached(())
    }
}

private extension DelayedQueue {
    func forceAsync(_ workItem: @escaping () -> Void) {
        switch self {
        case .absent:
            workItem()
        case .sync(let queue):
            queue.async(execute: workItem)
        case .async(let queue):
            queue.async(execute: workItem)
        case .asyncAfter(_, let queue):
            queue.async(execute: workItem)
        case .asyncAfterWithFlags(_, _, let queue):
            queue.async(execute: workItem)
        }
    }
}
