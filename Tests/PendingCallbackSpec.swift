import Foundation
import Nimble
import NSpry
import NSpry_Nimble
import Quick
@testable import NCallback
@testable import NCallbackTestHelpers

final class PendingCallbackSpec: QuickSpec {
    private enum Constant {
        static let sharedBehavior = "PendingCallback Behavior"
        static let sharedInitialState = "PendingCallback Initial State"
    }

    override func spec() {
        describe("PendingCallback") {
            var callback: FakeCallback<Int>!
            var subject: PendingCallback<Int>!

            beforeEach {
                callback = .init()
            }

            sharedExamples(Constant.sharedInitialState) {
                it("should be clear") {
                    expect(subject.isPending).to(beFalse())
                }

                context("when no pending callbacks") {
                    context("when cancelling") {
                        beforeEach {
                            subject.cancel()
                        }

                        it("should nothing to do") {
                            expect(true).to(beTrue())
                        }
                    }

                    // #warning("should check UT when throwAssertion will work correctly")
                    xcontext("when completing") {
                        it("should throw assertion") {
                            expect { subject.complete(1) }.to(throwAssertion())
                        }
                    }
                }
            }

            sharedExamples(Constant.sharedBehavior) {
                context("when requesting the first callback") {
                    var actual: Callback<Int>!
                    var deferred: FakeCallback<Int>!

                    beforeEach {
                        deferred = .init()
                        callback.stub(.deferred).andReturn(deferred)
                        actual = subject.current { _ in }
                    }

                    it("should generate new instance") {
                        expect(callback).to(haveReceived(.deferred, with: Argument.anything))
                        expect(actual).to(be(deferred))
                    }

                    it("should be in the pending state") {
                        expect(subject.isPending).to(beTrue())
                    }

                    context("cancel") {
                        beforeEach {
                            callback.stub(.cleanup).andReturn()
                            subject.cancel()
                        }

                        it("should cancel cached callback") {
                            expect(callback).to(haveReceived(.cleanup))
                        }

                        it("should be clear") {
                            expect(subject.isPending).to(beFalse())
                        }
                    }

                    context("complete") {
                        beforeEach {
                            callback.stub(.complete).andReturn()
                            subject.complete(1)
                        }

                        it("should complete cached callback") {
                            expect(callback).to(haveReceived(.complete, with: 1))
                        }

                        it("should be clear") {
                            expect(subject.isPending).to(beFalse())
                        }
                    }

                    context("when requesting the second callback") {
                        var actual2: Callback<Int>!
                        var closure: Callback<Int>.Completion?
                        var result: Int!

                        beforeEach {
                            callback.stubAgain(.deferred).andDo { args in
                                closure = args[0] as? Callback<Int>.Completion
                                return deferred
                            }
                            actual2 = subject.current { _ in }
                            actual2.onComplete { result = $0 }
                            closure?(2)
                        }

                        it("should generate new instance") {
                            expect(actual2).toNot(be(deferred))
                            expect(actual2).toNot(be(actual))
                            expect(actual2).toNot(be(callback))
                        }

                        it("should receive result") {
                            expect(result) == 2
                        }
                    }
                }
            }

            describe("empty init") {
                beforeEach {
                    subject = .init()
                }

                itBehavesLike(Constant.sharedInitialState)

                context("when requesting the first callback") {
                    var actual: Callback<Int>!

                    beforeEach {
                        actual = subject.current { _ in }
                    }

                    it("should generate new instance") {
                        expect(actual).toNot(be(callback))
                    }

                    it("should not be in the pending state") {
                        expect(subject.isPending).to(beFalse())
                    }

                    context("cancel") {
                        beforeEach {
                            subject.cancel()
                        }

                        it("should not be in the pending state") {
                            expect(subject.isPending).to(beFalse())
                        }
                    }

                    context("onComplete") {
                        var result: Int!

                        beforeEach {
                            actual.onComplete {
                                result = $0
                            }
                        }

                        afterEach {
                            result = nil
                        }

                        it("should be in the pending state") {
                            expect(subject.isPending).to(beTrue())
                            expect(result).to(beNil())
                        }

                        context("complete") {
                            beforeEach {
                                subject.complete(1)
                            }

                            it("should receive result") {
                                expect(result) == 1
                            }

                            it("should be clear") {
                                expect(subject.isPending).to(beFalse())
                            }
                        }
                    }
                }
            }
        }
    }
}
