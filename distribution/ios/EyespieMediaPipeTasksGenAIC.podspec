Pod::Spec.new do |spec|
  spec.name = "EyespieMediaPipeTasksGenAIC"
  spec.version = ENV.fetch("POD_VERSION", "0.10.26.1")
  spec.authors = "Google Inc."
  spec.license = { :type => "Apache", :file => "LICENSE" }
  spec.homepage = "https://github.com/ryjen/mediapipe"
  spec.summary = "MediaPipe Task Library - Gen AI C API"
  spec.description = "The Gen AI C APIs of the MediaPipe Task Library, built from upstream v0.10.26."
  spec.ios.deployment_target = "15.0"
  spec.module_name = "MediaPipeTasksGenAIC"
  spec.static_framework = true

  tag = ENV.fetch("POD_RELEASE_TAG", "eyespie-ios-v0.10.26.1")
  base_url = ENV["POD_SOURCE_BASE_URL"]
  archive = "MediaPipeTasksGenAIC-#{spec.version}.tar.gz"
  spec.source = {
    :http => base_url ? "#{base_url}/#{archive}" : "https://github.com/ryjen/mediapipe/releases/download/#{tag}/#{archive}"
  }

  # Common owns the shared TensorFlow Lite C runtime. GenAIC excludes those
  # objects from its static XCFramework and resolves them through this pod.
  spec.dependency "EyespieMediaPipeTasksCommon", "= #{spec.version}"
  spec.frameworks = "Accelerate", "CoreVideo", "Metal", "OpenGLES"
  spec.library = "c++"
  spec.vendored_frameworks = "frameworks/MediaPipeTasksGenAIC.xcframework"
end
