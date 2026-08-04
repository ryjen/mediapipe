#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.10.26.1}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
DIST_DIR="${REPO_ROOT}/dist/ios-pods"
PODSPEC_DIR="${REPO_ROOT}/distribution/ios"
LOG_DIR="${DIST_DIR}/consumer-logs"
WORK_DIR="$(mktemp -d)"
SERVER_LOG="${LOG_DIR}/http-server.log"

mkdir -p "${LOG_DIR}"

cleanup() {
  local status=$?
  if [[ -n "${server_pid:-}" ]]; then
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
  fi
  if ((status != 0)); then
    echo "CocoaPods fixture HTTP server log:" >&2
    tail -n 50 "${SERVER_LOG}" >&2 || true
  fi
  rm -rf "${WORK_DIR}"
  return "${status}"
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

if ! curl --fail --silent \
  --retry 10 --retry-connrefused --retry-delay 1 \
  "${base_url}/MediaPipeTasksCommon-${VERSION}.tar.gz" >/dev/null; then
  echo "CocoaPods fixture HTTP server failed to become ready." >&2
  exit 1
fi

common="${PODSPEC_DIR}/EyespieMediaPipeTasksCommon.podspec"
vision="${PODSPEC_DIR}/EyespieMediaPipeTasksVision.podspec"
genaic="${PODSPEC_DIR}/EyespieMediaPipeTasksGenAIC.podspec"
genai="${PODSPEC_DIR}/EyespieMediaPipeTasksGenAI.podspec"

stage_pod() {
  local archive="$1"
  local podspec="$2"
  local root="${WORK_DIR}/staged/${archive}"

  mkdir -p "${root}"
  tar -xzf "${DIST_DIR}/${archive}-${VERSION}.tar.gz" -C "${root}"
  cp "${podspec}" "${root}/$(basename "${podspec}")"
  printf '%s\n' "${root}/$(basename "${podspec}")"
}

lint() {
  local mode="$1"
  local name="$2"
  local podspec="$3"
  shift 3
  local log="${LOG_DIR}/${name}.log"
  local -a command=(pod "${mode}" lint "${podspec}")

  echo "==> Validating ${name} CocoaPods consumer"
  if ! env \
    POD_VERSION="${VERSION}" \
    POD_RELEASE_TAG="eyespie-ios-v${VERSION}" \
    POD_SOURCE_BASE_URL="${base_url}" \
      "${command[@]}" "$@" --allow-warnings --verbose >"${log}" 2>&1; then
    echo "CocoaPods validation failed for ${name}; final log follows." >&2
    tail -n 200 "${log}" >&2 || true
    return 1
  fi

  local unexpected_warnings
  unexpected_warnings="$(
    awk -v base_url="${base_url}" '
      /^[[:space:]]*-[[:space:]]+WARN[[:space:]]+\|/ {
        if (index($0, "user_target_xcconfig") != 0) next
        if (index($0, "| http:") != 0 && index($0, base_url "/") != 0) next
        print
      }
    ' "${log}"
  )"
  if [[ -n "${unexpected_warnings}" ]]; then
    echo "Unexpected CocoaPods lint warnings for ${name}:" >&2
    echo "${unexpected_warnings}" >&2
    echo "Final log follows." >&2
    tail -n 200 "${log}" >&2 || true
    return 1
  fi

  echo "CocoaPods validation passed for ${name}"
}

# Common is the sole owner of the TensorFlow Lite C runtime and retains the
# production-equivalent `pod spec lint` path because its graph linker flags point
# into $(PODS_ROOT). Dependent binary pods are staged as development pods so
# unpublished sibling podspecs can be supplied through `--external-podspecs`;
# their binary dependencies are still installed from the fixture HTTP server.
lint spec common "${common}"

vision_staged="$(stage_pod MediaPipeTasksVision "${vision}")"
genaic_staged="$(stage_pod MediaPipeTasksGenAIC "${genaic}")"
genai_staged="$(stage_pod MediaPipeTasksGenAI "${genai}")"

lint lib vision "${vision_staged}" --external-podspecs="${common}"
lint lib genaic "${genaic_staged}" --external-podspecs="${common}"
lint lib genai "${genai_staged}" \
  --external-podspecs="${PODSPEC_DIR}/*.podspec"

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

smoke_podspec="${smoke_payload}/EyespieMediaPipeIntegrationSmoke.podspec"
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

tar -czf "${DIST_DIR}/EyespieMediaPipeIntegrationSmoke-${VERSION}.tar.gz" \
  -C "${smoke_payload}" .

lint lib combined "${smoke_podspec}" \
  --external-podspecs="${PODSPEC_DIR}/*.podspec"
