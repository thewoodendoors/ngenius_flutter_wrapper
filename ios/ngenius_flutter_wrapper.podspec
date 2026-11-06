#
# ngenius_flutter_wrapper: card payments and Apple Pay through the N-Genius Online iOS SDK (NISdk).
# Run `pod lib lint ngenius_flutter_wrapper.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ngenius_flutter_wrapper'
  s.version          = '0.1.0'
  s.summary          = 'N-Genius Online (Network International) card and Apple Pay payments for Flutter.'
  s.description      = <<-DESC
Flutter wrapper around the official N-Genius Online native payment SDK for iOS: card payments and
Apple Pay inside the app, driven by an order created on the merchant backend.
                       DESC
  s.homepage         = 'https://docs.ngenius-payments.com/reference#ios-sdk'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = 'thewoodendoors'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift'
  s.dependency 'Flutter'
  # Newest NISdk on the CocoaPods trunk; 7.x only exists as GitHub tags.
  s.dependency 'NISdk', '6.1.6'
  s.platform = :ios, '15.0'
  s.frameworks = 'PassKit'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
