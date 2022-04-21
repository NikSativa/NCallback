Pod::Spec.new do |spec|
    spec.name         = "NCallbackTestHelpers"
    spec.version      = "2.10.9"
    spec.summary      = "NCallback - wrapped closures"

    spec.source       = { :git => "git@github.com:NikSativa/NCallback.git" }
    spec.homepage     = "https://github.com/NikSativa/NCallback"

    spec.license          = 'MIT'
    spec.author           = { "Nikita Konopelko" => "nik.sativa@gmail.com" }
    spec.social_media_url = "https://www.facebook.com/Nik.Sativa"

    spec.ios.deployment_target = '11.0'
    spec.swift_version = '5.5'

    spec.source_files = 'TestHelpers/**/*.swift'

    spec.dependency 'NSpry'
    spec.dependency 'NCallback'

    spec.frameworks = 'XCTest', 'Foundation'

#    spec.scheme = {
#      :code_coverage => true
#    }

    spec.test_spec 'Tests' do |tests|
        tests.dependency 'Nimble'
        tests.dependency 'Quick'
        tests.dependency 'NSpry_Nimble'

        tests.dependency 'NQueue'
        tests.dependency 'NQueueTestHelpers'

        tests.frameworks = 'XCTest', 'Foundation'

        tests.source_files = 'Tests/**/*.swift'
    end
end
