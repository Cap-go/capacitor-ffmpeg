require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name = 'CapgoCapacitorFfmpeg'
  s.version = package['version']
  s.summary = package['description']
  s.license = package['license']
  s.homepage = package['repository']['url']
  s.author = package['author']
  s.source = { :git => package['repository']['url'], :tag => s.version.to_s }
  s.source_files = 'ios/Sources/**/*.{swift,h,m,c,cc,mm,cpp}'
  s.static_framework = true
  s.preserve_paths = 'ios/CapacitorFFmpegNativeCore.xcframework'
  s.vendored_frameworks = 'ios/CapacitorFFmpegNativeCore.xcframework'
  s.frameworks = ['AVFoundation', 'AudioToolbox', 'CoreFoundation', 'CoreGraphics', 'CoreMedia', 'CoreServices', 'CoreVideo', 'QuartzCore', 'Security', 'VideoToolbox']
  s.libraries = ['c++']
  s.ios.deployment_target = '15.0'
  s.dependency 'Capacitor'
  s.swift_version = '5.1'
end
