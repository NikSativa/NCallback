import Foundation

public func zip<Response>(_ input: Callback<Response>...) -> Callback<[Response]> {
    return zip(input)
}

public func zip<Response>(_ input: [Callback<Response>]) -> Callback<[Response]> {
    if input.isEmpty {
        return .init(result: [])
    }

    let infos: [Info<Response>] = input.map {
        return Info(original: $0)
    }

    let startTask: Callback<[Response]>.ServiceClosure = { [infos] original in
        for info in infos {
            info.start { [weak original] in
                let responses: [Response] = infos.compactMap(\.result)
                if infos.count == responses.count {
                    original?.complete(responses)
                }
            }
        }
    }

    let stopTask: Callback<[Response]>.ServiceClosure = { _ in
        for info in infos {
            info.stop()
        }
    }

    return .init(start: startTask,
                 stop: stopTask)
}

public func zipErroredTuple<ResponseA, ResponseB, Error: Swift.Error>(lhs: ResultCallback<ResponseA, Error>,
                                                                      rhs: ResultCallback<ResponseB, Error>) -> ResultCallback<(lhs: ResponseA, rhs: ResponseB), Error> {
    let startTask: ResultCallback<(lhs: ResponseA, rhs: ResponseB), Error>.ServiceClosure = { original in
        var a: Result<ResponseA, Error>?
        var b: Result<ResponseB, Error>?

        let check = { [weak lhs, weak rhs, weak original] in
            if let a = a, let b = b {
                switch (a, b) {
                case (.success(let a), .success(let b)):
                    let result: (ResponseA, ResponseB) = (a, b)
                    original?.complete(result)
                case (_, .failure(let a)),
                     (.failure(let a), _):
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

    let stopTask: ResultCallback<(lhs: ResponseA, rhs: ResponseB), Error>.ServiceClosure = { _ in
        lhs.cleanup()
        rhs.cleanup()
    }

    return .init(start: startTask,
                 stop: stopTask)
}

public func zipTuple<ResponseA, ResponseB>(_ lhs: Callback<ResponseA>,
                                           _ rhs: Callback<ResponseB>) -> Callback<(ResponseA, ResponseB)> {
    var a: ResponseA?
    var b: ResponseB?

    let startTask: Callback<(ResponseA, ResponseB)>.ServiceClosure = { original in
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

    return .init(start: startTask)
}

private final class Info<R> {
    enum State {
        case pending
        case value(R)
    }

    private var original: Callback<R>?
    private var state: State = .pending
    var result: R? {
        switch state {
        case .pending:
            return nil
        case .value(let r):
            return r
        }
    }

    init(original: Callback<R>) {
        self.original = original
    }

    func start(_ completion: @escaping () -> Void) {
        assert(original != nil)

        original?.onComplete(options: .weakness) { [weak self] result in
            self?.state = .value(result)
            self?.stop()
            completion()
        }
    }

    func stop() {
        original = nil
    }
}
