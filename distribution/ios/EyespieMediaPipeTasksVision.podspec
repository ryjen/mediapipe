Pod::Spec.new do |spec|
  spec.name = "EyespieMediaPipeTasksVision"
  spec.version = ENV.fetch("POD_VERSION", "0.10.26.2")
  spec.authors = "Google Inc."
  spec.license = { :type => "Apache", :file => "LICENSE" }
  spec.homepage = "https://github.com/ryjen/mediapipe"
  spec.summary = "MediaPipe Task Library - Vision"
  spec.description = "The Vision APIs of the MediaPipe Task Library, built from upstream v0.10.26."
  spec.ios.deployment_target = "15.0"
  spec.module_name = "MediaPipeTasksVision"
  spec.static_framework = true

  tag = ENV.fetch("POD_RELEASE_TAG", "eyespie-ios-v0.10.26.2")
  base_url = ENV["POD_SOURCE_BASE_URL"]
  archive = "MediaPipeTasksVision-#{spec.version}.tar.gz"
  spec.source = {
    :http => base_url ? "#{base_url}/#{archive}" : "https://github.com/ryjen/mediapipe/releases/download/#{tag}/#{archive}"
  }

  spec.dependency "EyespieMediaPipeTasksCommon", "= #{spec.version}"
  spec.library = "c++"
  spec.vendored_frameworks = "frameworks/MediaPipeTasksVision.xcframework"
end