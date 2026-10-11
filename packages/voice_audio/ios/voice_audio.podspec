Pod::Spec.new do |s|
  s.name = 'voice_audio'
  s.version = '0.1.0'
  s.summary = 'Offline native audio feasibility engine.'
  s.description = 'AVAudioEngine with a native C++ render kernel; no PCM in Dart.'
  s.homepage = 'https://example.invalid/sajat-hang'
  s.license = { :type => 'Proprietary', :text => 'Private prototype. Not for redistribution.' }
  s.author = { 'Prototype' => 'prototype@example.invalid' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/SHAudioPlugin.h'
  s.preserve_paths = '../native/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'AVFoundation', 'AudioToolbox', 'UIKit'
  s.libraries = 'c++'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17' }
end
