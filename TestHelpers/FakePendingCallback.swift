import Foundation
import NSpry
@testable import NCallback

@available(iOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
@available(macOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
public typealias FakeResultPendingCallback<Response, Error: Swift.Error> = FakePendingCallback<Result<Response, Error>>

@available(iOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
@available(macOS, deprecated, message: "moved to new framework 'DefferedTask' at https://github.com/NikSativa/NDefferedTask")
public final class FakePendingCallback<Response>: PendingCallback<Response>, Spryable {
    public enum ClassFunction: String, StringRepresentable {
        case empty
    }

    public enum Function: String, StringRepresentable {
        case current = "current()"
    }

    public var closure: ServiceClosure?
    override public func current(_ closure: @escaping ServiceClosure = { _ in }) -> Callback {
        self.closure = closure
        return spryify()
    }
}
