import Foundation

@discardableResult
public func sync<T>(_ callback: Callback<T>,
                    seconds: Double? = nil,
                    timeoutResult timeout: @autoclosure () -> T) -> T {
    return sync(callback,
                seconds: seconds,
                timeoutResult: timeout)
}

@discardableResult
public func sync<T>(_ callback: Callback<T>,
                    seconds: Double? = nil,
                    timeoutResult timeout: () -> T) -> T {
    let group = DispatchGroup()
    var result: T!

    group.enter()
    callback.onComplete(options: .selfRetained) {
        result = $0
        group.leave()
    }

    assert(seconds.map { $0 > 0 } ?? true, "seconds must be nil or greater than 0")

    if let seconds, seconds > 0 {
        let timeoutResult = group.wait(timeout: .now() + seconds)
        switch timeoutResult {
        case .success:
            break
        case .timedOut:
            result = timeout()
        }
    } else {
        group.wait()
    }

    return result
}
