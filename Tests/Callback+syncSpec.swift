import Foundation
import Nimble
import NQueue
import NSpry
import Quick
@testable import NCallback
@testable import NCallbackTestHelpers

final class Callback_syncSpec: QuickSpec {
    private enum Value: Equatable, SpryEquatable {
        case idle
        case timedOut
        case correct
    }

    override func spec() {
        describe("Callback+sync") {
            var result: Value!
            var subject: CallbackWrapper<Value>!

            beforeEach {
                result = .idle
                subject = .init()
            }

            afterEach {
                subject = nil
            }

            it("should not start yet") {
                expect(subject.started) == 0
            }

            context("when timeout is absent") {
                var startDate: Date!
                var fireDate: Date!
                var endDate: Date!

                beforeEach {
                    startDate = .init()
                    Queue.background.asyncAfter(deadline: .now() + 1) {
                        fireDate = .init()
                        subject.complete(.correct)
                    }

                    result = sync(subject.real,
                                  timeoutResult: .timedOut)
                    endDate = .init()
                }

                it("should receive result") {
                    expect(result) == .correct

                    expect(startDate.timeIntervalSinceReferenceDate).toNot(beCloseTo(endDate.timeIntervalSinceReferenceDate))
                    expect(fireDate.timeIntervalSinceReferenceDate).to(beCloseTo(endDate.timeIntervalSinceReferenceDate, within: 0.25))
                }
            }

            context("when timeout is correct") {
                var startDate: Date!
                var endDate: Date!

                context("when timed out") {
                    beforeEach {
                        startDate = .init()

                        result = sync(subject.real,
                                      seconds: 0.1,
                                      timeoutResult: .timedOut)
                        endDate = .init()
                    }

                    it("should receive result") {
                        expect(result) == .timedOut
                        expect(endDate.timeIntervalSinceReferenceDate - startDate.timeIntervalSinceReferenceDate).to(beCloseTo(0.1, within: 0.05))
                    }
                }

                context("when has ended") {
                    var fireDate: Date!

                    beforeEach {
                        startDate = .init()
                        Queue.background.asyncAfter(deadline: .now() + 1) {
                            fireDate = .init()
                            subject.complete(.correct)
                        }

                        result = sync(subject.real,
                                      seconds: 5,
                                      timeoutResult: .timedOut)
                        endDate = .init()
                    }

                    it("should receive result") {
                        expect(result) == .correct

                        expect(startDate.timeIntervalSinceReferenceDate).toNot(beCloseTo(endDate.timeIntervalSinceReferenceDate))
                        expect(fireDate.timeIntervalSinceReferenceDate).to(beCloseTo(endDate.timeIntervalSinceReferenceDate, within: 0.25))
                    }
                }
            }

            context("when timeout is less than or equal zero") {
                it("should throw assert") {
                    expect {
                        sync(Callback<Int>(),
                             seconds: -1,
                             timeoutResult: -1)
                    }.to(throwAssertion())
                }
            }
        }
    }
}
