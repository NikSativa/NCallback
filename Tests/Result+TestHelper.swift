import Foundation
import NSpry

internal extension Result {
    var error: Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let e):
            return e
        }
    }

    var value: Success? {
        switch self {
        case .success(let v):
            return v
        case .failure:
            return nil
        }
    }
}
