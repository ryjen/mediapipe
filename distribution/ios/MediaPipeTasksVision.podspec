Pod::Spec.new do |spec|
  spec.name = "EyespieMediaPipeTasksVision"
  spec.module_name = "MediaPipeTasksVision"
  spec.version = ENV.fetch("POD_VERSION", "0.10.26.1")
  spec.summary = "MediaPipe Tasks Vision built from upstream v0.10.26"
  spec.homepage = "https://github.com/ryjen/mediapipe"
  spec.license = { :type => "Apache-2.0", :file => "LICENSE" }
  spec.authors = { "MediaPipe Authors" => "mediapipe@google.com" }
  spec.platform = :ios, "15.0"

  tag = ENV.fetch("POD_RELEASE_TAG", "eyespie-ios-v0.10.26.1")
  base_url = ENV["POD_SOURCE_BASE_URL"]
  archive = "MediaPipeTasksVision-#{spec.version}.tar.gz"
  spec.source = {
    :http => base_url ? "#{base_url}/#{archive}" : "https://github.com/ryjen/mediapipe/releases/download/#{tag}/#{archive}"
  }

  spec.vendored_frameworks = "frameworks/MediaPipeTasksVision.xcframework"
  spec.dependency "EyespieMediaPipeTasksCommon", "= #{spec.version}"
  spec.libraries = "c++"
  spec.pod_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
  }
end
