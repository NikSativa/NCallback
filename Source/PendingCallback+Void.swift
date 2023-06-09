import Foundation

@available(iOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
@available(macOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
public extension PendingCallback where ResultType == Void {
    func complete() {
        complete(())
    }
}

@available(iOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
@available(macOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
public extension PendingCallback {
    func completeSuccessfully<Error: Swift.Error>() where ResultType == Result<Void, Error> {
        complete(.success(()))
    }
}
