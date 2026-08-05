Pod::Spec.new do |spec|
  spec.name = "EyespieMediaPipeTasksCommon"
  spec.version = ENV.fetch("POD_VERSION", "0.10.26.1")
  spec.authors = "Google Inc."
  spec.license = { :type => "Apache", :file => "LICENSE" }
  spec.homepage = "https://github.com/ryjen/mediapipe"
  spec.summary = "MediaPipe Task Library - Common"
  spec.description = "The common libraries of the MediaPipe Task Library, built from upstream v0.10.26."
  spec.ios.deployment_target = "15.0"
  spec.module_name = "MediaPipeTasksCommon"
  spec.static_framework = true

  tag = ENV.fetch("POD_RELEASE_TAG", "eyespie-ios-v0.10.26.1")
  base_url = ENV["POD_SOURCE_BASE_URL"]
  archive = "MediaPipeTasksCommon-#{spec.version}.tar.gz"
  spec.source = {
    :http => base_url ? "#{base_url}/#{archive}" : "https://github.com/ryjen/mediapipe/releases/download/#{tag}/#{archive}"
  }

  spec.user_target_xcconfig = {
    "OTHER_LDFLAGS[sdk=iphonesimulator*]" => "$(inherited) -force_load \"$(PODS_ROOT)/EyespieMediaPipeTasksCommon/frameworks/graph_libraries/libMediaPipeTasksCommon_simulator_graph.a\"",
    "OTHER_LDFLAGS[sdk=iphoneos*]" => "$(inherited) -force_load \"$(PODS_ROOT)/EyespieMediaPipeTasksCommon/frameworks/graph_libraries/libMediaPipeTasksCommon_device_graph.a\""
  }
  spec.frameworks = "Accelerate", "CoreMedia", "AssetsLibrary", "CoreFoundation", "CoreGraphics", "CoreImage", "QuartzCore", "AVFoundation", "CoreVideo", "UIKit"
  spec.preserve_paths = "frameworks/graph_libraries/*.a"
  spec.library = "c++"
  spec.vendored_frameworks = "frameworks/MediaPipeTasksCommon.xcframework"
end
