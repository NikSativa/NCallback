import Foundation

import Nimble
import NSpry
import Quick

@testable import NCallback
@testable import NCallbackTestHelpers

private typealias ResultSubjectWrapper<Value, Error: Swift.Error> = SubjectWrapper<Result<Value, Error>>

private enum TestError: Swift.Error, Equatable {
    case anyError1
    case anyError2
}

private enum TestError2: Swift.Error, Equatable {
    case anyError
}

private final class SubjectWrapper<Value> {
    private(set) weak var weakValue: Callback<Value>?
    var value: Callback<Value>!
    var stopped: Bool = false
    var started: Bool {
        action != nil
    }

    func set(_ value: Callback<Value>?) {
        self.value = value
    }

    var action: ((Value) -> Void)?
    lazy var start: (Callback<Value>) -> Void = { [weak self] original in
        let original = original
        self?.action = { [weak original] value in
            original?.complete(value)
        }
    }

    lazy var stop: (Callback<Value>) -> Void = { [weak self] _ in
        self?.stopped = true
    }

    func onComplete(options: CallbackOption = .default,
                    _ callback: @escaping Callback<Value>.Completion) {
        value.onComplete(options: options, callback)
    }
}

final class CallbackSpec: QuickSpec {
    override func spec() {
        describe("Callback") {
            describe("Simple Callback") {
                var wrapper: SubjectWrapper<Int>!
                var subject: Callback<Int>! {
                    get {
                        wrapper.value
                    }
                    set {
                        wrapper.set(newValue)
                    }
                }

                beforeEach {
                    wrapper = .init()
                }

                let lifecycle: (_ action: @escaping (CallbackOption, _ callback: @escaping Callback<Int>.Completion) -> Void) -> Void = { action in
                    describe("lifecycle") {
                        var result: Int!

                        beforeEach {
                            wrapper.stopped = false
                            result = nil
                        }

                        describe("weakness") {
                            beforeEach {
                                action(.weakness) { result = $0 }
                            }

                            context("when destructed before completion") {
                                beforeEach {
                                    subject = nil
                                    wrapper.action?(1)
                                }

                                it("should not receive result") {
                                    expect(result).to(beNil())
                                }

                                it("should call stop on deinit") {
                                    expect(wrapper.stopped).to(beTrue())
                                }
                            }

                            context("when complete correctly and destructed") {
                                beforeEach {
                                    wrapper.action?(1)
                                    wrapper.value = nil
                                }

                                it("should receive result") {
                                    expect(result) == 1
                                }

                                it("should call stop on deinit") {
                                    expect(wrapper.stopped).to(beTrue())
                                }
                            }
                        }

                        describe("selfRetained") {
                            beforeEach {
                                action(.selfRetained) { result = $0 }
                                subject = nil
                            }

                            context("when cant be destructed before completion") {
                                beforeEach {
                                    wrapper.stopped = false
                                }

                                it("should not receive result") {
                                    expect(result).to(beNil())
                                }

                                it("should not call stop") {
                                    expect(wrapper.stopped).to(beFalse())
                                }

                                context("when complete correctly and destructed") {
                                    beforeEach {
                                        wrapper.action?(2)
                                    }

                                    it("should receive result") {
                                        expect(result) == 2
                                    }

                                    it("should call stop on deinit") {
                                        expect(wrapper.stopped).to(beTrue())
                                    }
                                }
                            }

                            context("when complete correctly and destructed") {
                                beforeEach {
                                    wrapper.stopped = false
                                    wrapper.action?(1)
                                }

                                it("should receive result") {
                                    expect(result) == 1
                                }

                                it("should call stop on deinit") {
                                    expect(wrapper.stopped).to(beTrue())
                                }
                            }
                        }

                        describe("repeatable") {
                            beforeEach {
                                action(.repeatable(.weakness)) { result = $0 }
                            }

                            context("when destructed before completion") {
                                beforeEach {
                                    wrapper.stopped = false
                                    subject = nil
                                    wrapper.action?(1)
                                }

                                it("should not receive result") {
                                    expect(result).to(beNil())
                                }

                                it("should call stop on deinit") {
                                    expect(wrapper.stopped).to(beTrue())
                                }
                            }

                            context("when complete correctly and destructed") {
                                beforeEach {
                                    wrapper.stopped = false
                                    wrapper.action?(1)
                                }

                                it("should receive result") {
                                    expect(result) == 1
                                }

                                it("should not call stop") {
                                    expect(wrapper.stopped).to(beFalse())
                                }

                                context("when completed twice") {
                                    beforeEach {
                                        wrapper.stopped = false
                                        wrapper.action?(2)
                                    }

                                    it("should receive result") {
                                        expect(result) == 2
                                    }

                                    it("should not call stop") {
                                        expect(wrapper.stopped).to(beFalse())
                                    }

                                    context("when destructed before") {
                                        beforeEach {
                                            wrapper.stopped = false
                                            result = nil
                                            subject = nil
                                            wrapper.action?(1)
                                        }

                                        it("should not receive result") {
                                            expect(result).to(beNil())
                                        }

                                        it("should call stop on deinit") {
                                            expect(wrapper.stopped).to(beTrue())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                let commonEvents = {
                    describe("beforeComplete and deferred") {
                        enum Events: Hashable {
                            case beforeComplete
                            case onComplete
                            case deferred
                        }
                        var events: [Events]!

                        beforeEach {
                            events = []

                            subject.beforeComplete { _ in events.append(.beforeComplete) }
                            subject.deferred { _ in events.append(.deferred) }
                            subject.onComplete { _ in events.append(.onComplete) }

                            wrapper.action?(1)
                        }

                        it("should resolve events in correct order") {
                            let expected: [Events] = [.beforeComplete, .onComplete, .deferred]
                            expect(events) == expected
                        }
                    }

                    describe("flatMap") {
                        var result: Bool!
                        var originalResult: Int!
                        var mapped: Callback<Bool>!

                        context("when original value is greater then 0") {
                            beforeEach {
                                subject.onComplete { originalResult = $0 }
                                mapped = subject.flatMap { $0 > 0 }
                                mapped.onComplete { result = $0 }

                                wrapper.action?(1)
                            }

                            it("should be other instance") {
                                expect(mapped).toNot(be(subject))
                            }

                            it("should be receive original result") {
                                expect(originalResult) == 1
                            }

                            it("should be receive mapped result") {
                                expect(result).to(beTrue())
                            }
                        }

                        context("when original value is greater then 0") {
                            beforeEach {
                                subject.onComplete { originalResult = $0 }
                                mapped = subject.flatMap { $0 < 0 }
                                mapped.onComplete { result = $0 }

                                wrapper.action?(1)
                            }

                            it("should be other instance") {
                                expect(mapped).toNot(be(subject))
                            }

                            it("should be receive original result") {
                                expect(originalResult) == 1
                            }

                            it("should be receive mapped result") {
                                expect(result).to(beFalse())
                            }
                        }
                    }
                }

                describe("empty init") {
                    beforeEach {
                        subject = .init()
                        wrapper.action = { [weak wrapper] v in
                            wrapper?.value?.complete(v)
                        }
                    }

                    #if arch(x86_64) && canImport(Darwin)
                    context("when configured twice") {
                        beforeEach {
                            subject.onComplete { _ in }
                        }

                        it("should throw assert") {
                            expect({ subject.onComplete { _ in } }).to(throwAssertion())
                        }
                    }
                    #endif

                    commonEvents()
                }

                describe("init with deferred autoclosure result") {
                    beforeEach {
                        subject = .init(result: 1)
                    }

                    #if arch(x86_64) && canImport(Darwin)
                    context("when configured twice") {
                        beforeEach {
                            subject.onComplete { _ in }
                        }

                        it("should not throw assert; should clear completion callback after synced completions") {
                            expect({ subject.onComplete { _ in } }).toNot(throwAssertion())
                        }
                    }
                    #endif

                    commonEvents()
                }

                describe("init with deferred result") {
                    beforeEach {
                        subject = .init(result: { return 1 })
                    }

                    #if arch(x86_64) && canImport(Darwin)
                    context("when configured twice") {
                        beforeEach {
                            subject.onComplete { _ in }
                        }

                        it("should not throw assert; should clear completion callback after synced completions") {
                            expect({ subject.onComplete { _ in } }).toNot(throwAssertion())
                        }
                    }
                    #endif

                    commonEvents()
                }

                describe("init with deferred result and cancel action") {
                    beforeEach {
                        subject = .init(start: wrapper.start,
                                        stop: wrapper.stop)
                    }

                    afterEach {
                        wrapper.stopped = false
                    }

                    commonEvents()

                    lifecycle { option, callback in
                        subject.onComplete(options: option, callback)
                    }

                    lifecycle { option, callback in
                        subject.beforeComplete(callback)
                        subject.oneWay(options: option)
                    }

                    context("when configured for the second time") {
                        beforeEach {
                            subject.onComplete { _ in }
                        }

                        #if arch(x86_64) && canImport(Darwin)
                        it("should throw assert") {
                            expect({ subject.onComplete { _ in } }).to(throwAssertion())
                        }
                        #endif

                        context("when canceled") {
                            beforeEach {
                                subject.cleanup()
                            }

                            it("should call stop on deinit") {
                                expect(wrapper.stopped).to(beTrue())
                            }
                        }

                        context("when self retained; when configuring for the third time") {
                            weak var saved: Callback<Int>?

                            beforeEach {
                                subject.cleanup()
                                subject.onComplete(options: .selfRetained) { _ in }

                                saved = subject
                                subject = nil
                            }

                            it("should contains reference") {
                                expect(saved).toNot(beNil())
                            }
                        }
                    }

                    describe("deinit") {
                        beforeEach {
                            subject = nil
                        }

                        it("should call stop on deinit") {
                            expect(wrapper.stopped).to(beTrue())
                        }
                    }
                }

                describe("Hashable") {
                    var subject2: Callback<Int>!

                    beforeEach {
                        subject = .init(start: wrapper.start,
                                        stop: wrapper.stop)
                        subject2 = .init()
                    }

                    context("when hashing by ref") {
                        beforeEach {
                            subject.hashKey = nil
                            subject2.hashKey = nil
                        }

                        it("should not equal") {
                            expect(subject) != subject2
                        }

                        it("should generate different hashes") {
                            expect(subject.hashValue) != subject2.hashValue
                        }
                    }

                    context("when hashing both by hashKey") {
                        beforeEach {
                            subject.hashKey = "123"
                            subject2.hashKey = "123"
                        }

                        it("should be equal") {
                            expect(subject) == subject2
                        }

                        it("should generate same hashes") {
                            expect(subject.hashValue) == subject2.hashValue
                        }
                    }

                    context("when hashing the first by hashKey") {
                        beforeEach {
                            subject.hashKey = "123"
                            subject2.hashKey = nil
                        }

                        it("should not equal") {
                            expect(subject) != subject2
                        }

                        it("should generate different hashes") {
                            expect(subject.hashValue) != subject2.hashValue
                        }
                    }

                    context("when hashing the second by hashKey") {
                        beforeEach {
                            subject.hashKey = nil
                            subject2.hashKey = "123"
                        }

                        it("should not equal") {
                            expect(subject) != subject2
                        }

                        it("should generate different hashes") {
                            expect(subject.hashValue) != subject2.hashValue
                        }
                    }
                }

                describe("zip") {
                    var result: (Int, Bool)!
                    var wrapper2: SubjectWrapper<Bool>!
                    var subject2: Callback<Bool>! {
                        get {
                            wrapper2.value
                        }
                        set {
                            wrapper2.set(newValue)
                        }
                    }

                    var zipped: Callback<(Int, Bool)>!

                    beforeEach {
                        subject = .init(start: wrapper.start,
                                        stop: wrapper.stop)

                        wrapper2 = .init()
                        subject2 = .init(start: wrapper2.start,
                                         stop: wrapper2.stop)

                        zipped = zipTuple(subject, subject2)
                    }

                    afterEach {
                        subject = nil
                        subject2 = nil
                        zipped = nil
                    }

                    it("should not start yet") {
                        expect(wrapper.started).to(beFalse())
                        expect(wrapper2.started).to(beFalse())
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
                            expect(wrapper.started).to(beTrue())
                            expect(wrapper2.started).to(beTrue())
                        }

                        it("should not receive result") {
                            expect(result).to(beNil())
                        }

                        context("when resolved the first") {
                            beforeEach {
                                wrapper.action?(1)
                            }

                            it("should not receive result") {
                                expect(result).to(beNil())
                            }

                            context("when resolved the second") {
                                beforeEach {
                                    wrapper2.action?(true)
                                }

                                it("should receive result") {
                                    expect(result.0) == 1
                                    expect(result.1).to(beTrue())
                                }

                                context("when both are completed") {
                                    beforeEach {
                                        wrapper.value.cleanup()
                                        wrapper.value = nil

                                        wrapper2.value.cleanup()
                                        wrapper2.value = nil
                                    }

                                    it("should stopped and removed from memory") {
                                        expect(wrapper.stopped).to(beTrue())
                                        expect(wrapper2.stopped).to(beTrue())

                                        expect(wrapper.weakValue).to(beNil())
                                        expect(wrapper2.weakValue).to(beNil())
                                    }
                                }
                            }
                        }

                        context("when resolved the second") {
                            beforeEach {
                                wrapper2.action?(true)
                            }

                            it("should not receive result") {
                                expect(result).to(beNil())
                            }

                            context("when resolved the first") {
                                beforeEach {
                                    wrapper.action?(2)
                                }

                                it("should receive result") {
                                    expect(result.0) == 2
                                    expect(result.1).to(beTrue())
                                }

                                context("when both are completed") {
                                    beforeEach {
                                        wrapper.value.cleanup()
                                        wrapper.value = nil

                                        wrapper2.value.cleanup()
                                        wrapper2.value = nil
                                    }

                                    it("should stopped and removed from memory") {
                                        expect(wrapper.stopped).to(beTrue())
                                        expect(wrapper2.stopped).to(beTrue())

                                        expect(wrapper.weakValue).to(beNil())
                                        expect(wrapper2.weakValue).to(beNil())
                                    }
                                }
                            }
                        }
                    }
                }

                describe("empty zip array") {
                    it("should return empty array") {
                        let array: [Callback<[Int]>] = []
                        zip(array).onComplete {
                            expect($0).to(beEmpty())
                        }
                    }
                }

                describe("zip array") {
                    var result: [Int]!
                    var wrapper2: SubjectWrapper<Int>!
                    var subject2: Callback<Int>! {
                        get {
                            wrapper2.value
                        }
                        set {
                            wrapper2.set(newValue)
                        }
                    }

                    var zipped: Callback<[Int]>!

                    beforeEach {
                        subject = .init(start: wrapper.start,
                                        stop: wrapper.stop)

                        wrapper2 = .init()
                        subject2 = .init(start: wrapper2.start,
                                         stop: wrapper2.stop)

                        zipped = zip([subject, subject2])
                    }

                    afterEach {
                        subject = nil
                        subject2 = nil
                        zipped = nil
                    }

                    it("should not start yet") {
                        expect(wrapper.started).to(beFalse())
                        expect(wrapper2.started).to(beFalse())
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
                            expect(wrapper.started).to(beTrue())
                            expect(wrapper2.started).to(beTrue())
                        }

                        it("should not receive result") {
                            expect(result).to(beNil())
                        }

                        context("when resolved the first") {
                            beforeEach {
                                wrapper.action?(1)
                            }

                            it("should not receive result") {
                                expect(result).to(beNil())
                            }

                            context("when resolved the second") {
                                beforeEach {
                                    wrapper2.action?(2)
                                }

                                it("should receive result") {
                                    expect(result) == [1, 2]
                                }

                                context("when both are completed") {
                                    beforeEach {
                                        wrapper.value = nil
                                        wrapper2.value = nil
                                    }

                                    it("should stopped and removed from memory") {
                                        expect(wrapper.stopped).to(beTrue())
                                        expect(wrapper2.stopped).to(beTrue())

                                        expect(wrapper.weakValue).to(beNil())
                                        expect(wrapper2.weakValue).to(beNil())
                                    }
                                }
                            }
                        }

                        context("when resolved the second") {
                            beforeEach {
                                wrapper2.action?(2)
                            }

                            it("should not receive result") {
                                expect(result).to(beNil())
                            }

                            context("when resolved the first") {
                                beforeEach {
                                    wrapper.action?(1)
                                }

                                it("should receive result") {
                                    expect(result) == [1, 2]
                                }

                                context("when both are completed") {
                                    beforeEach {
                                        wrapper.value = nil
                                        wrapper2.value = nil
                                    }

                                    it("should stopped and removed from memory") {
                                        expect(wrapper.stopped).to(beTrue())
                                        expect(wrapper2.stopped).to(beTrue())

                                        expect(wrapper.weakValue).to(beNil())
                                        expect(wrapper2.weakValue).to(beNil())
                                    }
                                }
                            }
                        }
                    }
                }
            }

            describe("Callback with collections") {
                var wrapper: SubjectWrapper<[Int?]>!
                var subject: Callback<[Int?]>! {
                    get {
                        wrapper.value
                    }
                    set {
                        wrapper.set(newValue)
                    }
                }

                beforeEach {
                    wrapper = .init()
                    subject = .init(start: wrapper.start,
                                    stop: wrapper.stop)
                }

                describe("filterNils") {
                    var result: [Int]!
                    var originalResult: [Int?]!
                    var mapped: Callback<[Int]>!

                    context("when no nils") {
                        beforeEach {
                            subject.onComplete { originalResult = $0 }
                            mapped = subject.filterNils()
                            mapped.onComplete { result = $0 }

                            wrapper.action?([1, 2, 3])
                        }

                        it("should be other instance") {
                            expect(mapped).toNot(be(subject))
                        }

                        it("should be receive original result") {
                            expect(originalResult) == [1, 2, 3]
                        }

                        it("should be receive mapped result") {
                            expect(result) == [1, 2, 3]
                        }
                    }

                    context("when has nils") {
                        beforeEach {
                            subject.onComplete { originalResult = $0 }
                            mapped = subject.filterNils()
                            mapped.onComplete { result = $0 }

                            wrapper.action?([1, nil, 2, nil, 3])
                        }

                        it("should be other instance") {
                            expect(mapped).toNot(be(subject))
                        }

                        it("should be receive original result") {
                            expect(originalResult) == [1, nil, 2, nil, 3]
                        }

                        it("should be receive mapped result") {
                            expect(result) == [1, 2, 3]
                        }
                    }
                }
            }

            describe("ResultCallback with collections") {
                var wrapper: SubjectWrapper<Result<[Int?], TestError>>!
                var subject: ResultCallback<[Int?], TestError>! {
                    get {
                        wrapper.value
                    }
                    set {
                        wrapper.set(newValue)
                    }
                }

                beforeEach {
                    wrapper = .init()
                    subject = .init(start: wrapper.start,
                                    stop: wrapper.stop)
                }

                describe("filterNils") {
                    var result: Result<[Int], TestError>!
                    var originalResult: Result<[Int?], TestError>!
                    var mapped: ResultCallback<[Int], TestError>!

                    context("when no nils") {
                        beforeEach {
                            subject.onComplete { originalResult = $0 }
                            mapped = subject.filterNils()
                            mapped.onComplete { result = $0 }

                            wrapper.action?(.success([1, 2, 3]))
                        }

                        it("should be other instance") {
                            expect(mapped).toNot(be(subject))
                        }

                        it("should be receive original result") {
                            expect(originalResult) == .success([1, 2, 3])
                        }

                        it("should be receive mapped result") {
                            expect(result) == .success([1, 2, 3])
                        }
                    }

                    context("when has nils") {
                        beforeEach {
                            subject.onComplete { originalResult = $0 }
                            mapped = subject.filterNils()
                            mapped.onComplete { result = $0 }

                            wrapper.action?(.success([1, nil, 2, nil, 3]))
                        }

                        it("should be other instance") {
                            expect(mapped).toNot(be(subject))
                        }

                        it("should be receive original result") {
                            expect(originalResult) == .success([1, nil, 2, nil, 3])
                        }

                        it("should be receive mapped result") {
                            expect(result) == .success([1, 2, 3])
                        }
                    }
                }
            }

            describe("ResultCallback") {
                var wrapper: ResultSubjectWrapper<Int, TestError>!
                var subject: ResultCallback<Int, TestError>! {
                    get {
                        wrapper.value
                    }
                    set {
                        wrapper.set(newValue)
                    }
                }

                beforeEach {
                    wrapper = .init()
                }

                describe("instances") {
                    beforeEach {
                        subject = .init(start: wrapper.start,
                                        stop: wrapper.stop)
                    }

                    describe("zipErroredTuple") {
                        var result: Result<(lhs: Int, rhs: Bool), TestError>!
                        var wrapper2: ResultSubjectWrapper<Bool, TestError>!
                        var subject2: ResultCallback<Bool, TestError>! {
                            get {
                                wrapper2.value
                            }
                            set {
                                wrapper2.set(newValue)
                            }
                        }

                        var zipped: ResultCallback<(lhs: Int, rhs: Bool), TestError>!

                        beforeEach {
                            wrapper2 = .init()
                            subject2 = .init(start: wrapper2.start,
                                             stop: wrapper2.stop)

                            zipped = zipErroredTuple(lhs: subject, rhs: subject2)
                        }

                        afterEach {
                            subject = nil
                            subject2 = nil
                            zipped = nil
                        }

                        let itBehavesLikeFirstWithError: (Bool) -> Void = { independent in
                            context("when resolved the first with error") {
                                beforeEach {
                                    wrapper.action?(.failure(.anyError1))
                                }

                                it("should receive result") {
                                    expect(result.error) == .anyError1
                                }

                                it("should not call stop") {
                                    expect(wrapper.stopped).to(beFalse())
                                }

                                if independent {
                                    it("should call stop") {
                                        expect(wrapper2.stopped).to(beTrue())
                                    }
                                }

                                context("when both are completed") {
                                    beforeEach {
                                        wrapper.value.cleanup()
                                        wrapper.value = nil

                                        wrapper2.value.cleanup()
                                        wrapper2.value = nil
                                    }

                                    it("should stopped and removed from memory") {
                                        expect(wrapper.stopped).to(beTrue())
                                        expect(wrapper2.stopped).to(beTrue())

                                        expect(wrapper.weakValue).to(beNil())
                                        expect(wrapper2.weakValue).to(beNil())
                                    }
                                }
                            }
                        }

                        let itBehavesLikeSecondWithError: (Bool) -> Void = { independent in
                            context("when resolved the second with error") {
                                beforeEach {
                                    wrapper2.action?(.failure(.anyError2))
                                }

                                it("should receive result") {
                                    expect(result.error) == .anyError2
                                }

                                it("should not call stop") {
                                    expect(wrapper2.stopped).to(beFalse())
                                }

                                if independent {
                                    it("should call stop") {
                                        expect(wrapper.stopped).to(beTrue())
                                    }
                                }

                                context("when both are completed") {
                                    beforeEach {
                                        wrapper.value.cleanup()
                                        wrapper.value = nil

                                        wrapper2.value.cleanup()
                                        wrapper2.value = nil
                                    }

                                    it("should stopped and removed from memory") {
                                        expect(wrapper.stopped).to(beTrue())
                                        expect(wrapper2.stopped).to(beTrue())

                                        expect(wrapper.weakValue).to(beNil())
                                        expect(wrapper2.weakValue).to(beNil())
                                    }
                                }
                            }
                        }

                        it("should not start yet") {
                            expect(wrapper.started).to(beFalse())
                            expect(wrapper2.started).to(beFalse())
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
                                expect(wrapper.started).to(beTrue())
                                expect(wrapper2.started).to(beTrue())
                            }

                            it("should not receive result") {
                                expect(result).to(beNil())
                            }

                            context("should .weakness both") {
                                beforeEach {
                                    wrapper.value = nil
                                    wrapper2.value = nil
                                    zipped = nil
                                }

                                it("should not call stop") {
                                    expect(wrapper.stopped).to(beTrue())
                                    expect(wrapper2.stopped).to(beTrue())
                                }
                            }

                            context("when resolved the first") {
                                beforeEach {
                                    wrapper.action?(.success(1))
                                }

                                it("should not receive result") {
                                    expect(result).to(beNil())
                                }

                                context("when resolved the second") {
                                    beforeEach {
                                        wrapper2.action?(.success(true))
                                    }

                                    it("should receive result") {
                                        let value = result.value
                                        expect(value?.0) == 1
                                        expect(value?.1).to(beTrue())
                                    }

                                    context("when both are completed") {
                                        beforeEach {
                                            wrapper.value.cleanup()
                                            wrapper.value = nil

                                            wrapper2.value.cleanup()
                                            wrapper2.value = nil
                                        }

                                        it("should stopped and removed from memory") {
                                            expect(wrapper.stopped).to(beTrue())
                                            expect(wrapper2.stopped).to(beTrue())

                                            expect(wrapper.weakValue).to(beNil())
                                            expect(wrapper2.weakValue).to(beNil())
                                        }
                                    }
                                }

                                itBehavesLikeSecondWithError(false)
                            }

                            context("when resolved the second") {
                                beforeEach {
                                    wrapper2.action?(.success(true))
                                }

                                it("should not receive result") {
                                    expect(result).to(beNil())
                                }

                                context("when resolved the first") {
                                    beforeEach {
                                        wrapper.action?(.success(1))
                                    }

                                    it("should receive result") {
                                        let value = result.value
                                        expect(value?.0) == 1
                                        expect(value?.1).to(beTrue())
                                    }

                                    context("when both are completed") {
                                        beforeEach {
                                            wrapper.value.cleanup()
                                            wrapper.value = nil

                                            wrapper2.value.cleanup()
                                            wrapper2.value = nil
                                        }

                                        it("should stopped and removed from memory") {
                                            expect(wrapper.stopped).to(beTrue())
                                            expect(wrapper2.stopped).to(beTrue())

                                            expect(wrapper.weakValue).to(beNil())
                                            expect(wrapper2.weakValue).to(beNil())
                                        }
                                    }
                                }

                                itBehavesLikeFirstWithError(false)
                            }

                            itBehavesLikeFirstWithError(true)
                            itBehavesLikeSecondWithError(true)
                        }
                    }

                    describe("mapError") {
                        var result: Result<Int, TestError2>!
                        var originalResult: Result<Int, TestError>!
                        var mapped: ResultCallback<Int, TestError2>!

                        beforeEach {
                            subject.onComplete { originalResult = $0 }
                            mapped = subject.mapError { _ in return TestError2.anyError }
                            mapped.onComplete { result = $0 }
                        }

                        it("should be other instance") {
                            expect(mapped).toNot(be(subject))
                        }

                        context("when original value is 0") {
                            beforeEach {
                                subject.complete(0)
                            }

                            it("should be receive mapped result") {
                                expect(result.value) == 0
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 0
                            }
                        }

                        context("when original value is less then 0") {
                            beforeEach {
                                subject.complete(-1)
                            }

                            it("should be receive mapped result") {
                                expect(result.value) == -1
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == -1
                            }
                        }

                        context("when original value is greater then 0") {
                            beforeEach {
                                subject.complete(1)
                            }

                            it("should be receive mapped result") {
                                expect(result.value) == 1
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 1
                            }
                        }

                        context("when received error .anyError1") {
                            beforeEach {
                                subject.complete(.anyError1)
                            }

                            it("should receive the same error as result") {
                                expect(result.error) == .anyError
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError1
                            }
                        }

                        context("when received error .anyError2") {
                            beforeEach {
                                subject.complete(.anyError2)
                            }

                            it("should receive the same error as result") {
                                expect(result.error) == .anyError
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError2
                            }
                        }
                    }

                    describe("map") {
                        var result: Result<Bool, TestError>!
                        var originalResult: Result<Int, TestError>!
                        var mapped: ResultCallback<Bool, TestError>!

                        beforeEach {
                            subject.onComplete { originalResult = $0 }
                            mapped = subject.map { $0 > 0 }
                            mapped.onComplete { result = $0 }
                        }

                        it("should be other instance") {
                            expect(mapped).toNot(be(subject))
                        }

                        context("when original value is 0") {
                            beforeEach {
                                subject.complete(0)
                            }

                            it("should be receive mapped result") {
                                expect(result.value).to(beFalse())
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 0
                            }
                        }

                        context("when original value is less then 0") {
                            beforeEach {
                                subject.complete(-1)
                            }

                            it("should be receive mapped result") {
                                expect(result.value).to(beFalse())
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == -1
                            }
                        }

                        context("when original value is greater then 0") {
                            beforeEach {
                                subject.complete(1)
                            }

                            it("should be receive mapped result") {
                                expect(result.value).to(beTrue())
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 1
                            }
                        }

                        context("when received error .anyError1") {
                            beforeEach {
                                subject.complete(.anyError1)
                            }

                            it("should receive the same error as result") {
                                expect(result.error) == .anyError1
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError1
                            }
                        }

                        context("when received error .anyError2") {
                            beforeEach {
                                subject.complete(.anyError2)
                            }

                            it("should receive the same error as result") {
                                expect(result.error) == .anyError2
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError2
                            }
                        }
                    }

                    describe("recover with error mapping") {
                        var result: Int!
                        var originalResult: Result<Int, TestError>!
                        var mapped: Callback<Int>!

                        beforeEach {
                            subject.onComplete { originalResult = $0 }
                            mapped = subject.recover { $0 == .anyError1 ? 1 : 2 }
                            mapped.onComplete { result = $0 }
                        }

                        it("should be other instance") {
                            expect(mapped).toNot(be(subject))
                        }

                        context("when original value is 0") {
                            beforeEach {
                                subject.complete(0)
                            }

                            it("should be receive mapped result") {
                                expect(result) == 0
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 0
                            }
                        }

                        context("when original value is less then 0") {
                            beforeEach {
                                subject.complete(-1)
                            }

                            it("should be receive mapped result") {
                                expect(result) == -1
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == -1
                            }
                        }

                        context("when original value is greater then 0") {
                            beforeEach {
                                subject.complete(1)
                            }

                            it("should be receive mapped result") {
                                expect(result) == 1
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 1
                            }
                        }

                        context("when received error .anyError1") {
                            beforeEach {
                                subject.complete(.anyError1)
                            }

                            it("should receive the same error as result") {
                                expect(result) == 1
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError1
                            }
                        }

                        context("when received error .anyError2") {
                            beforeEach {
                                subject.complete(.anyError2)
                            }

                            it("should receive the same error as result") {
                                expect(result) == 2
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError2
                            }
                        }
                    }

                    describe("recover with static value") {
                        var result: Int!
                        var originalResult: Result<Int, TestError>!
                        var mapped: Callback<Int>!

                        beforeEach {
                            subject.onComplete { originalResult = $0 }
                            mapped = subject.recover(1)
                            mapped.onComplete { result = $0 }
                        }

                        it("should be other instance") {
                            expect(mapped).toNot(be(subject))
                        }

                        context("when original value is 0") {
                            beforeEach {
                                subject.complete(0)
                            }

                            it("should be receive mapped result") {
                                expect(result) == 0
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 0
                            }
                        }

                        context("when original value is less then 0") {
                            beforeEach {
                                subject.complete(-1)
                            }

                            it("should be receive mapped result") {
                                expect(result) == -1
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == -1
                            }
                        }

                        context("when original value is greater then 0") {
                            beforeEach {
                                subject.complete(1)
                            }

                            it("should be receive mapped result") {
                                expect(result) == 1
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 1
                            }
                        }

                        context("when received error .anyError1") {
                            beforeEach {
                                subject.complete(.anyError1)
                            }

                            it("should receive the same error as result") {
                                expect(result) == 1
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError1
                            }
                        }

                        context("when received error .anyError2") {
                            beforeEach {
                                subject.complete(.anyError2)
                            }

                            it("should receive the same error as result") {
                                expect(result) == 1
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError2
                            }
                        }
                    }

                    describe("recover with nil") {
                        var result: Int?
                        var originalResult: Result<Int, TestError>!
                        var mapped: Callback<Int?>!

                        beforeEach {
                            subject.onComplete { originalResult = $0 }
                            mapped = subject.recoverNil()
                            mapped.onComplete { result = $0 }
                        }

                        it("should be other instance") {
                            expect(mapped).toNot(be(subject))
                        }

                        context("when original value is 0") {
                            beforeEach {
                                subject.complete(0)
                            }

                            it("should be receive mapped result") {
                                expect(result) == 0
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 0
                            }
                        }

                        context("when original value is less then 0") {
                            beforeEach {
                                subject.complete(-1)
                            }

                            it("should be receive mapped result") {
                                expect(result) == -1
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == -1
                            }
                        }

                        context("when original value is greater then 0") {
                            beforeEach {
                                subject.complete(1)
                            }

                            it("should be receive mapped result") {
                                expect(result) == 1
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 1
                            }
                        }

                        context("when received error .anyError1") {
                            beforeEach {
                                subject.complete(.anyError1)
                            }

                            it("should receive the same error as result") {
                                expect(result).to(beNil())
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError1
                            }
                        }

                        context("when received error .anyError2") {
                            beforeEach {
                                subject.complete(.anyError2)
                            }

                            it("should receive the same error as result") {
                                expect(result).to(beNil())
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError2
                            }
                        }
                    }

                    describe("recover with dynamic value") {
                        var value: Int!
                        var result: Int!
                        var originalResult: Result<Int, TestError>!
                        var mapped: Callback<Int>!

                        beforeEach {
                            value = (0...10).randomElement() ?? 3
                            subject.onComplete { originalResult = $0 }
                            mapped = subject.recover { value }
                            mapped.onComplete { result = $0 }
                        }

                        it("should be other instance") {
                            expect(mapped).toNot(be(subject))
                        }

                        context("when original value is 0") {
                            beforeEach {
                                subject.complete(0)
                            }

                            it("should be receive mapped result") {
                                expect(result) == 0
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 0
                            }
                        }

                        context("when original value is less then 0") {
                            beforeEach {
                                subject.complete(-1)
                            }

                            it("should be receive mapped result") {
                                expect(result) == -1
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == -1
                            }
                        }

                        context("when original value is greater then 0") {
                            beforeEach {
                                subject.complete(1)
                            }

                            it("should be receive mapped result") {
                                expect(result) == 1
                            }

                            it("should be receive original result") {
                                expect(originalResult.value) == 1
                            }
                        }

                        context("when received error .anyError1") {
                            beforeEach {
                                subject.complete(.anyError1)
                            }

                            it("should receive the same error as result") {
                                expect(result) == value
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError1
                            }
                        }

                        context("when received error .anyError2") {
                            beforeEach {
                                subject.complete(.anyError2)
                            }

                            it("should receive the same error as result") {
                                expect(result) == value
                            }

                            it("should receive the same error as original result") {
                                expect(originalResult.error) == .anyError2
                            }
                        }
                    }
                }

                describe("static succes with result") {
                    var result: Result<Int, TestError>!

                    beforeEach {
                        subject = .success(1)
                    }

                    describe("weakness") {
                        beforeEach {
                            subject.onComplete(options: .weakness) { result = $0 }
                        }

                        it("should receive result") {
                            expect(result.value) == 1
                        }

                        context("when destructed") {
                            beforeEach {
                                wrapper.value = nil
                            }

                            it("should be removed from memory") {
                                expect(wrapper.weakValue).to(beNil())
                            }
                        }
                    }
                }

                describe("static failure with error") {
                    var result: Result<Int, TestError>!

                    beforeEach {
                        subject = .failure(.anyError1)
                    }

                    describe("weakness") {
                        beforeEach {
                            subject.onComplete(options: .weakness) { result = $0 }
                        }

                        it("should receive result") {
                            expect(result.error) == .anyError1
                        }

                        context("when destructed") {
                            beforeEach {
                                wrapper.value = nil
                            }

                            it("should be removed from memory") {
                                expect(wrapper.weakValue).to(beNil())
                            }
                        }
                    }
                }
            }
        }
    }
}
