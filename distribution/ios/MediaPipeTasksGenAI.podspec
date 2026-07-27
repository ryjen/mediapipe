Pod::Spec.new do |spec|
  spec.name = "EyespieMediaPipeTasksGenAI"
  spec.module_name = "MediaPipeTasksGenAI"
  spec.version = ENV.fetch("POD_VERSION", "0.10.26.1")
  spec.summary = "MediaPipe Tasks GenAI built from upstream v0.10.26"
  spec.homepage = "https://github.com/ryjen/mediapipe"
  spec.license = { :type => "Apache-2.0", :file => "LICENSE" }
  spec.authors = { "MediaPipe Authors" => "mediapipe@google.com" }
  spec.platform = :ios, "15.0"

  tag = ENV.fetch("POD_RELEASE_TAG", "eyespie-ios-v0.10.26.1")
  base_url = ENV["POD_SOURCE_BASE_URL"]
  archive = "MediaPipeTasksGenAI-#{spec.version}.tar.gz"
  spec.source = {
    :http => base_url ? "#{base_url}/#{archive}" : "https://github.com/ryjen/mediapipe/releases/download/#{tag}/#{archive}"
  }

  spec.vendored_frameworks = "frameworks/MediaPipeTasksGenAI.xcframework"
  spec.dependency "EyespieMediaPipeTasksGenAIC", "= #{spec.version}"
  spec.libraries = "c++"
  spec.pod_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
  }
end
