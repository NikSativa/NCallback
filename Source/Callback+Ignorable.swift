import Foundation

public extension Callback where ResultType == Ignorable {
    func complete() {
        complete(Ignorable())
    }

    class func success() -> Callback<Ignorable> {
        return .init(result: .init())
    }
}

public extension Callback {
    func flatMapIgnorable() -> Callback<Ignorable> {
        return flatMap(Ignorable.init)
    }

    func mapIgnorable<T, Error: Swift.Error>() -> ResultCallback<Ignorable, Error> where ResultType == Result<T, Error> {
        map(Ignorable.init)
    }

    func completeSuccessfully<Error: Swift.Error>() where ResultType == Result<Ignorable, Error> {
        complete(.success(Ignorable()))
    }

    class func success<Error>() -> ResultCallback<Ignorable, Error> {
        return .success(.init())
    }

    func onComplete(options: CallbackOption = .default, _ callback: @escaping () -> Void) where ResultType == Ignorable {
        onComplete(options: options) { _ in
            callback()
        }
    }

    func onSyncedComplete(options: CallbackOption = .default,
                          timeout: CallbackTimeout? = nil,
                          _ callback: () -> Void) where ResultType == Ignorable {
        onSyncedComplete(options: options,
                         timeout: timeout) { _ in
            callback()
        }
    }
}
