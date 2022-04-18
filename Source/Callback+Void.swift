import Foundation

private func makeVoid() {}

private func makeVoid<T>(_: T) -> Void {}

public extension Callback {
    func complete() where ResultType == Void {
        complete(makeVoid())
    }

    class func success() -> Callback<Void> where ResultType == Void {
        return .init(result: makeVoid())
    }

    class func success<T, Error: Swift.Error>() -> ResultCallback<Void, Error> where ResultType == Result<T, Error> {
        return .success(makeVoid())
    }

    func flatMapVoid() -> Callback<Void> {
        return flatMap(makeVoid)
    }

    func mapVoid<T, Error: Swift.Error>() -> ResultCallback<Void, Error> where ResultType == Result<T, Error> {
        return map(makeVoid)
    }

    func completeSuccessfully<Error: Swift.Error>() where ResultType == Result<Void, Error> {
        complete(.success(makeVoid()))
    }

    func onComplete(options: CallbackOption = .default, _ callback: @escaping () -> Void) where ResultType == Void {
        onComplete(options: options) { _ in
            callback()
        }
    }
}
