import Foundation

@available(iOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
@available(macOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
public extension PendingCallback {
    func complete<Response, Error: Swift.Error>(_ error: Error) where ResultType == Result<Response, Error> {
        complete(.failure(error))
    }

    func complete<Response, Error: Swift.Error>(_ result: Response) where ResultType == Result<Response, Error> {
        complete(.success(result))
    }
}
