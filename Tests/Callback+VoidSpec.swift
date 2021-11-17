import Foundation

import Nimble
import NSpry
import Quick

@testable import NCallback
@testable import NCallbackTestHelpers

final class Callback_VoidSpec: QuickSpec {
    private enum TestError: Error {
        case case1
        case case2
    }

    override func spec() {
        describe("Callback+Void") {
            describe("Simple Callback") {
                describe("complete") {
                    var subject: Callback<Void>!
                    var result: Void!

                    beforeEach {
                        subject = .init()
                        subject.onComplete {
                            result = $0
                        }

                        subject.complete()
                    }

                    it("should receive result") {
                        expect(result).toNot(beNil())
                    }
                }

                describe("complete") {
                    var subject: Callback<Int>!
                    var mapped: Callback<Void>!
                    var mappedResult: Void!
                    var result: Int!

                    beforeEach {
                        subject = .init()
                        subject.onComplete {
                            result = $0
                        }

                        mapped = subject.flatMapVoid()
                        mapped.onComplete {
                            mappedResult = $0
                        }

                        subject.complete(1)
                    }

                    it("should receive result") {
                        expect(result) == 1
                        expect(mappedResult).toNot(beNil())
                    }
                }
            }

            describe("ResultCallback") {
                describe("complete") {
                    var subject: ResultCallback<Void, TestError>!
                    var result: Result<Void, TestError>!

                    beforeEach {
                        subject = .init()
                        subject.onComplete {
                            result = $0
                        }

                        subject.completeSuccessfully()
                    }

                    it("should receive result") {
                        expect(result.value).toNot(beNil())
                    }
                }

                describe("complete") {
                    var subject: ResultCallback<Int, TestError>!
                    var mapped: ResultCallback<Void, TestError>!
                    var mappedResult: Result<Void, TestError>!
                    var result: Result<Int, TestError>!

                    beforeEach {
                        subject = .init()
                        subject.onComplete {
                            result = $0
                        }

                        mapped = subject.mapVoid()
                        mapped.onComplete {
                            mappedResult = $0
                        }
                    }

                    context("when completed successfully") {
                        beforeEach {
                            subject.complete(1)
                        }

                        it("should receive result") {
                            expect(result) == .success(1)
                            expect(result.value).toNot(beNil())
                        }
                    }

                    context("when completed unsuccessfully") {
                        beforeEach {
                            subject.complete(.case1)
                        }

                        it("should receive result") {
                            expect(result) == .failure(.case1)
                            expect(mappedResult.error) == .case1
                        }
                    }
                }
            }
        }
    }
}
