import Foundation
import NQueue

@available(iOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
@available(macOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
public typealias PendingResultCallback<Response, Error: Swift.Error> = PendingCallback<Result<Response, Error>>

@available(iOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
@available(macOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
public class PendingCallback<ResultType> {
    public typealias Callback = NCallback.Callback<ResultType>
    public typealias ServiceClosure = Callback.ServiceClosure
    public typealias Completion = Callback.Completion

    @Atomic
    private var cached: Callback?

    private var beforeCallback: Completion?
    private var deferredCallback: Completion?

    public var isPending: Bool {
        return cached != nil
    }

    public init() {
        _cached = Atomic(wrappedValue: nil,
                         mutex: Mutex.pthread(.recursive),
                         read: .sync,
                         write: .sync)
    }

    public func current(_ closure: @escaping ServiceClosure) -> Callback {
        return current(.init(start: closure))
    }

    public func current(_ closure: @autoclosure () -> Callback) -> Callback {
        return current(closure)
    }

    public func current(_ closure: () -> Callback) -> Callback {
        return $cached.mutate { cached in
            let info = Info(original: cached ?? closure())
            return .init(start: { [weak self, info] actual in
                guard let self else {
                    assert(info.original != nil)
                    info.original?.onComplete(actual.complete)
                    return
                }

                if let _ = self.cached {
                    info.original?.deferred { [info] result in
                        actual.complete(result)
                        info.stop()
                    }
                } else {
                    info.original?.beforeComplete { [weak self] result in
                        self?.cached = nil
                        self?.beforeCallback?(result)
                    }
                    .deferred { [weak self, info] result in
                        self?.deferredCallback?(result)
                        info.stop()
                    }
                    .assign(to: &self.cached)
                    .onComplete(options: .weakness) { result in
                        actual.complete(result)
                    }
                }
            })
        }
    }

    public func complete(_ result: ResultType) {
        assert(cached != nil, "nobody will receive this event while cache is empty")
        cached?.complete(result)
    }

    public func cancel() {
        cached?.cleanup()
        cached = nil
    }

    @discardableResult
    public func deferred(_ callback: @escaping Completion) -> Self {
        let originalCallback = deferredCallback
        deferredCallback = { result in
            originalCallback?(result)
            callback(result)
        }
        return self
    }

    @discardableResult
    public func beforeComplete(_ callback: @escaping Completion) -> Self {
        let originalCallback = beforeCallback
        beforeCallback = { result in
            originalCallback?(result)
            callback(result)
        }
        return self
    }
}

@available(iOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
@available(macOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
private final class Info<R> {
    private(set) var original: Callback<R>?

    init(original: Callback<R>) {
        self.original = original
    }

    func stop() {
        original = nil
    }
}
