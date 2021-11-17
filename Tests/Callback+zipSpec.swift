import Foundation

import Nimble
import NSpry
import Quick

@testable import NCallback
@testable import NCallbackTestHelpers

final class Callback_ZipSpec: QuickSpec {
    override func spec() {
        describe("Callback") {
            describe("zip") {
                var result: (Int, Bool)!
                var subject: CallbackWrapper<Int>!
                var subject2: CallbackWrapper<Bool>!
                var zipped: Callback<(Int, Bool)>!

                beforeEach {
                    subject = .init()
                    subject2 = .init()
                    zipped = zipTuple(subject.real, subject2.real)
                }

                afterEach {
                    subject = nil
                    subject2 = nil
                    zipped = nil
                }

                it("should not start yet") {
                    expect(subject.started) == 0
                    expect(subject2.started) == 0
                }

                context("when started") {
                    beforeEach {
                        zipped.onComplete(options: .weakness) {
                            result = $0
                        }
                    }

                    afterEach {
                        result = nil
                    }

                    it("should not start yet") {
                        expect(subject.started) == 1
                        expect(subject2.started) == 1
                    }

                    it("should not receive result") {
                        expect(result).to(beNil())
                    }

                    context("when resolved the first") {
                        beforeEach {
                            subject.complete(1)
                        }

                        it("should not receive result") {
                            expect(result).to(beNil())
                        }

                        context("when resolved the second") {
                            beforeEach {
                                subject2.complete(true)
                            }

                            it("should receive result") {
                                expect(result) == (1, true)
                            }

                            context("when zip destructed") {
                                beforeEach {
                                    subject.cleanup()
                                    subject2.cleanup()
                                    zipped = nil
                                }

                                it("should stopped and removed from memory") {
                                    expect(subject.stopped) == 1
                                    expect(subject2.stopped) == 1

                                    expect(subject.weakValue).to(beNil())
                                    expect(subject2.weakValue).to(beNil())
                                }
                            }
                        }
                    }

                    context("when resolved the second") {
                        beforeEach {
                            subject2.complete(true)
                        }

                        it("should not receive result") {
                            expect(result).to(beNil())
                        }

                        context("when resolved the first") {
                            beforeEach {
                                subject.complete(2)
                            }

                            it("should receive result") {
                                expect(result) == (2, true)
                            }

                            context("when zip destructed") {
                                beforeEach {
                                    subject.cleanup()
                                    subject2.cleanup()
                                    zipped = nil
                                }

                                it("should stopped and removed from memory") {
                                    expect(subject.stopped) == 1
                                    expect(subject2.stopped) == 1

                                    expect(subject.weakValue).to(beNil())
                                    expect(subject2.weakValue).to(beNil())
                                }
                            }
                        }
                    }

                    context("when zip destructed") {
                        beforeEach {
                            subject.cleanup()
                            subject2.cleanup()
                            zipped = nil
                        }

                        it("should stopped and removed from memory") {
                            expect(subject.stopped) == 1
                            expect(subject2.stopped) == 1

                            expect(subject.weakValue).to(beNil())
                            expect(subject2.weakValue).to(beNil())
                        }
                    }
                }
            }

            describe("zip collection") {
                var result: [Int]!
                var subject: CallbackWrapper<Int>!
                var subject2: CallbackWrapper<Int>!
                var zipped: Callback<[Int]>!

                beforeEach {
                    subject = .init()
                    subject2 = .init()
                    zipped = zip([subject.real, subject2.real])
                }

                afterEach {
                    subject = nil
                    subject2 = nil
                    zipped = nil
                }

                it("should not start yet") {
                    expect(subject.started) == 0
                    expect(subject2.started) == 0
                }

                context("when started") {
                    beforeEach {
                        zipped.onComplete(options: .weakness) {
                            result = $0
                        }
                    }

                    afterEach {
                        result = nil
                    }

                    it("should not start yet") {
                        expect(subject.started) == 1
                        expect(subject2.started) == 1
                    }

                    it("should not receive result") {
                        expect(result).to(beNil())
                    }

                    context("when resolved the first") {
                        beforeEach {
                            subject.complete(1)
                        }

                        it("should not receive result") {
                            expect(result).to(beNil())
                        }

                        context("when resolved the second") {
                            beforeEach {
                                subject2.complete(2)
                            }

                            it("should receive result") {
                                expect(result) == [1, 2]
                            }

                            context("when zip destructed") {
                                beforeEach {
                                    subject.cleanup()
                                    subject2.cleanup()
                                    zipped = nil
                                }

                                it("should stopped and removed from memory") {
                                    expect(subject.stopped) == 1
                                    expect(subject2.stopped) == 1

                                    expect(subject.weakValue).to(beNil())
                                    expect(subject2.weakValue).to(beNil())
                                }
                            }
                        }
                    }

                    context("when resolved the second") {
                        beforeEach {
                            subject2.complete(1)
                        }

                        it("should not receive result") {
                            expect(result).to(beNil())
                        }

                        context("when resolved the first") {
                            beforeEach {
                                subject.complete(2)
                            }

                            it("should receive result") {
                                expect(result) == [2, 1]
                            }

                            context("when zip destructed") {
                                beforeEach {
                                    subject.cleanup()
                                    subject2.cleanup()
                                    zipped = nil
                                }

                                it("should stopped and removed from memory") {
                                    expect(subject.stopped) == 1
                                    expect(subject2.stopped) == 1

                                    expect(subject.weakValue).to(beNil())
                                    expect(subject2.weakValue).to(beNil())
                                }
                            }
                        }
                    }

                    context("when zip destructed") {
                        beforeEach {
                            subject.cleanup()
                            subject2.cleanup()
                            zipped = nil
                        }

                        it("should stopped and removed from memory") {
                            expect(subject.stopped) == 1
                            expect(subject2.stopped) == 1

                            expect(subject.weakValue).to(beNil())
                            expect(subject2.weakValue).to(beNil())
                        }
                    }
                }
            }
        }
    }
}
