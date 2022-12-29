import Foundation
import Nimble
import NSpry
import Quick
@testable import NCallback
@testable import NCallbackTestHelpers

final class PendingCallback_VoidSpec: QuickSpec {
    private enum TestError: Error {
        case case1
        case case2
    }

    override func spec() {
        describe("PendingCallback+Void") {
            describe("Simple PendingCallback") {
                describe("complete") {
                    var subject: PendingCallback<Int>!
                    var result: [Int]!

                    beforeEach {
                        result = []

                        subject = .init()

                        for _ in 0..<5 {
                            subject.current { _ in }.onComplete {
                                result.append($0)
                            }
                        }

                        subject.complete(1)
                    }

                    it("should receive result") {
                        expect(result) == .init(repeating: 1, count: 5)
                    }
                }
            }

            describe("PendingResultCallback") {
                describe("completeSuccessfully") {
                    var subject: PendingResultCallback<Void, TestError>!
                    var result: [Result<Void, TestError>]!

                    beforeEach {
                        result = []

                        subject = .init()

                        for _ in 0..<5 {
                            subject.current { _ in }.onComplete {
                                result.append($0)
                            }
                        }

                        subject.completeSuccessfully()
                    }

                    it("should receive result") {
                        expect(result.compactMap { try? $0.get() }.count) == 5
                    }
                }

                describe("complete with error") {
                    var subject: PendingResultCallback<Int, TestError>!
                    var result: [Result<Int, TestError>]!

                    beforeEach {
                        result = []

                        subject = .init()

                        for _ in 0..<5 {
                            subject.current { _ in }.onComplete {
                                result.append($0)
                            }
                        }

                        subject.complete(.case1)
                    }

                    it("should receive result") {
                        expect(result) == .init(repeating: .failure(.case1), count: 5)
                    }
                }

                describe("complete with error") {
                    var subject: PendingResultCallback<Int, TestError>!
                    var result: [Result<Int, TestError>]!

                    beforeEach {
                        result = []

                        subject = .init()

                        for _ in 0..<5 {
                            subject.current { _ in }.onComplete {
                                result.append($0)
                            }
                        }

                        subject.complete(1)
                    }

                    it("should receive result") {
                        expect(result) == .init(repeating: .success(1), count: 5)
                    }
                }
            }
        }
    }
}
