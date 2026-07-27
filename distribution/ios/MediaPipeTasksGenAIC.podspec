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
  spec.source = {
    :http => "https://github.com/ryjen/mediapipe/releases/download/#{tag}/MediaPipeTasksGenAIC-#{spec.version}.tar.gz"
  }

  spec.vendored_frameworks = "frameworks/MediaPipeTasksGenAIC.xcframework"
  spec.vendored_libraries = "frameworks/genai_libraries/*.a"
  spec.libraries = "c++"
  spec.pod_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
  }
end
