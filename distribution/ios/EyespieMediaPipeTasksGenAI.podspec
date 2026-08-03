Pod::Spec.new do |spec|
  spec.name = "EyespieMediaPipeTasksGenAI"
  spec.version = ENV.fetch("POD_VERSION", "0.10.26.1")
  spec.authors = "Google Inc."
  spec.license = { :type => "Apache", :file => "LICENSE" }
  spec.homepage = "https://github.com/ryjen/mediapipe"
  spec.summary = "MediaPipe Task Library - Gen AI"
  spec.description = "The Gen AI APIs of the MediaPipe Task Library, built from upstream v0.10.26."
  spec.ios.deployment_target = "15.0"
  spec.swift_version = "6.0"
  spec.module_name = "MediaPipeTasksGenAI"
  spec.static_framework = true

  tag = ENV.fetch("POD_RELEASE_TAG", "eyespie-ios-v0.10.26.1")
  base_url = ENV["POD_SOURCE_BASE_URL"]
  archive = "MediaPipeTasksGenAI-#{spec.version}.tar.gz"
  spec.source = {
    :http => base_url ? "#{base_url}/#{archive}" : "https://github.com/ryjen/mediapipe/releases/download/#{tag}/#{archive}"
  }

  spec.dependency "EyespieMediaPipeTasksGenAIC", "= #{spec.version}"
  spec.vendored_frameworks = "frameworks/MediaPipeTasksGenAI.xcframework"
end
