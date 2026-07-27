#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.10.26.1}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
DIST_DIR="${REPO_ROOT}/dist/ios-pods"
PODSPEC_DIR="${REPO_ROOT}/distribution/ios"
WORK_DIR="$(mktemp -d)"
SERVER_LOG="${WORK_DIR}/http-server.log"

cleanup() {
  if [[ -n "${server_pid:-}" ]]; then
    kill "${server_pid}" 2>/dev/null || true
  fi
  cat "${SERVER_LOG}" 2>/dev/null || true
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

for archive in \
  MediaPipeTasksCommon \
  MediaPipeTasksVision \
  MediaPipeTasksGenAIC \
  MediaPipeTasksGenAI; do
  test -f "${DIST_DIR}/${archive}-${VERSION}.tar.gz"
done

python3 -m http.server 8765 --bind 127.0.0.1 --directory "${DIST_DIR}" \
  >"${SERVER_LOG}" 2>&1 &
server_pid=$!
base_url="http://127.0.0.1:8765"

curl --fail --silent --show-error \
  --retry 10 --retry-connrefused --retry-delay 1 \
  "${base_url}/MediaPipeTasksCommon-${VERSION}.tar.gz" >/dev/null

common="${PODSPEC_DIR}/MediaPipeTasksCommon.podspec"
vision="${PODSPEC_DIR}/MediaPipeTasksVision.podspec"
genaic="${PODSPEC_DIR}/MediaPipeTasksGenAIC.podspec"
genai="${PODSPEC_DIR}/MediaPipeTasksGenAI.podspec"

lint() {
  local name="$1"
  shift
  local log="${WORK_DIR}/${name}.log"

  POD_VERSION="${VERSION}" \
  POD_RELEASE_TAG="eyespie-ios-v${VERSION}" \
  POD_SOURCE_BASE_URL="${base_url}" \
    pod spec lint "$@" --verbose 2>&1 | tee "${log}"
}

lint common "${common}"
lint vision "${vision}" --include-podspecs="${common}"
lint genaic "${genaic}"
lint genai "${genai}" --include-podspecs="${genaic}"

smoke_payload="${WORK_DIR}/smoke-payload"
mkdir -p "${smoke_payload}/Sources"
cp "${REPO_ROOT}/LICENSE" "${smoke_payload}/LICENSE"
cat > "${smoke_payload}/Sources/MediaPipeIntegrationSmoke.swift" <<'SWIFT'
import Foundation
import MediaPipeTasksVision
import MediaPipeTasksGenAI

public enum MediaPipeIntegrationSmoke {
  public static func verifyModulesLink() {}
}
SWIFT

tar -czf "${DIST_DIR}/EyespieMediaPipeIntegrationSmoke-${VERSION}.tar.gz" \
  -C "${smoke_payload}" .

smoke_podspec="${WORK_DIR}/EyespieMediaPipeIntegrationSmoke.podspec"
cat > "${smoke_podspec}" <<RUBY
Pod::Spec.new do |spec|
  spec.name = "EyespieMediaPipeIntegrationSmoke"
  spec.version = "${VERSION}"
  spec.summary = "Combined Vision and GenAI link smoke test"
  spec.description = "Build-only CocoaPods fixture that imports Vision and GenAI in one static target."
  spec.homepage = "https://github.com/ryjen/mediapipe"
  spec.authors = "Eyespie CI"
  spec.license = { :type => "Apache", :file => "LICENSE" }
  spec.source = { :http => "${base_url}/EyespieMediaPipeIntegrationSmoke-${VERSION}.tar.gz" }
  spec.ios.deployment_target = "15.0"
  spec.swift_version = "6.0"
  spec.static_framework = true
  spec.source_files = "Sources/**/*.swift"
  spec.dependency "EyespieMediaPipeTasksCommon", "= ${VERSION}"
  spec.dependency "EyespieMediaPipeTasksVision", "= ${VERSION}"
  spec.dependency "EyespieMediaPipeTasksGenAIC", "= ${VERSION}"
  spec.dependency "EyespieMediaPipeTasksGenAI", "= ${VERSION}"
end
RUBY

lint combined "${smoke_podspec}" \
  --include-podspecs="${common},${vision},${genaic},${genai}"
