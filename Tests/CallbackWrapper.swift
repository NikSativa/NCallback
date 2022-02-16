import Foundation

@testable import NCallback
@testable import NCallbackTestHelpers

final class CallbackWrapper<Value> {
    private(set) var real: Callback<Value>!

    private(set) weak var weakValue: Callback<Value>?
    private(set) var stopped: Int = 0
    private(set) var started: Int = 0

    init() {
        self.real = .init(start: { [weak self] _ in
            self?.started += 1
        }, stop: { [weak self] _ in
            self?.stopped += 1
        })
    }

    func cleanup() {
        real = nil
    }

    func complete(_ result: Value) {
        real.complete(result)
    }

    func onComplete(options: CallbackOption = .default,
                    _ callback: @escaping Callback<Value>.Completion) {
        real.onComplete(options: options, callback)
    }
}
