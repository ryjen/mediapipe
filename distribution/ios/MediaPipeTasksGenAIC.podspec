Pod::Spec.new do |spec|
  spec.name = "EyespieMediaPipeTasksGenAIC"
  spec.module_name = "MediaPipeTasksGenAIC"
  spec.version = ENV.fetch("POD_VERSION", "0.10.26.1")
  spec.summary = "MediaPipe Tasks GenAI C runtime built from upstream v0.10.26"
  spec.homepage = "https://github.com/ryjen/mediapipe"
  spec.license = { :type => "Apache-2.0", :file => "LICENSE" }
  spec.authors = { "MediaPipe Authors" => "mediapipe@google.com" }
  spec.platform = :ios, "15.0"

  tag = ENV.fetch("POD_RELEASE_TAG", "eyespie-ios-v0.10.26.1")
  base_url = ENV["POD_SOURCE_BASE_URL"]
  archive = "MediaPipeTasksGenAIC-#{spec.version}.tar.gz"
  spec.source = {
    :http => base_url ? "#{base_url}/#{archive}" : "https://github.com/ryjen/mediapipe/releases/download/#{tag}/#{archive}"
  }

  spec.vendored_frameworks = "frameworks/MediaPipeTasksGenAIC.xcframework"
  spec.preserve_paths = "frameworks/genai_libraries/*.a"
  spec.libraries = "c++"
  spec.pod_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
  }
  spec.user_target_xcconfig = {
    "OTHER_LDFLAGS[sdk=iphoneos*]" => "$(inherited) -force_load \"${PODS_TARGET_SRCROOT}/frameworks/genai_libraries/libMediaPipeTasksGenAIC_device.a\"",
    "OTHER_LDFLAGS[sdk=iphonesimulator*]" => "$(inherited) -force_load \"${PODS_TARGET_SRCROOT}/frameworks/genai_libraries/libMediaPipeTasksGenAIC_simulator.a\""
  }
end
