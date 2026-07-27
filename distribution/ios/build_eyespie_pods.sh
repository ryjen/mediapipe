#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.10.26.1}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
WORK_ROOT="${RUNNER_TEMP:-/tmp}/mediapipe-ios-pods"
DIST_DIR="${REPO_ROOT}/dist/ios-pods"
LOG_DIR="${DIST_DIR}/build-logs"

rm -rf "${WORK_ROOT}" "${DIST_DIR}"
mkdir -p "${WORK_ROOT}" "${DIST_DIR}" "${LOG_DIR}"

build_framework() {
  local framework="$1"
  local destination="${WORK_ROOT}/${framework}"
  local log_file="${LOG_DIR}/${framework}.log"
  mkdir -p "${destination}"

  local -a env_args=(
    "BAZEL=$(command -v bazelisk)"
    "FRAMEWORK_NAME=${framework}"
    "MPP_BUILD_VERSION=${VERSION}"
    "IS_RELEASE_BUILD=true"
    "ARCHIVE_FRAMEWORK=true"
    "DEST_DIR=${destination}"
  )

  if [[ "${framework}" == "MediaPipeTasksGenAIC" || "${framework}" == "MediaPipeTasksGenAI" ]]; then
    env_args+=("ENABLE_ODML_COCOAPODS_BUILD=1")
  fi

  echo "==> Building ${framework}"
  if ! env "${env_args[@]}" \
    "${REPO_ROOT}/mediapipe/tasks/ios/build_ios_framework.sh" \
    > >(tee "${log_file}") 2>&1; then
    echo "Build failed for ${framework}; final log follows." >&2
    tail -n 200 "${log_file}" >&2 || true
    return 1
  fi

  local archive
  archive="$(find "${destination}" -type f -name "${framework}-${VERSION}.tar.gz" -print -quit)"
  if [[ -z "${archive}" ]]; then
    echo "Missing archive for ${framework}" >&2
    find "${destination}" -maxdepth 8 -print >&2 || true
    return 1
  fi

  cp "${archive}" "${DIST_DIR}/${framework}-${VERSION}.tar.gz"
  df -h
  bazelisk info output_base 2>/dev/null | xargs -I{} du -sh {} 2>/dev/null || true
}

cd "${REPO_ROOT}"
for framework in \
  MediaPipeTasksCommon \
  MediaPipeTasksVision \
  MediaPipeTasksGenAIC \
  MediaPipeTasksGenAI; do
  build_framework "${framework}"
done

(
  cd "${DIST_DIR}"
  shasum -a 256 ./*.tar.gz > SHA256SUMS
)

SOURCE_PATCH_SHA256="$(git diff --binary v0.10.26...HEAD | shasum -a 256 | awk '{print $1}')"
CHANGED_PATHS_SHA256="$(git diff --name-only v0.10.26...HEAD | LC_ALL=C sort | shasum -a 256 | awk '{print $1}')"

cat > "${DIST_DIR}/provenance.txt" <<EOF
source_repository=https://github.com/google-ai-edge/mediapipe
upstream_tag=v0.10.26
distribution_commit=$(git rev-parse HEAD)
upstream_commit=$(git rev-list -n 1 v0.10.26)
source_patch_sha256=${SOURCE_PATCH_SHA256}
changed_paths_sha256=${CHANGED_PATHS_SHA256}
distribution_version=${VERSION}
runner_os=${RUNNER_OS:-unknown}
runner_arch=${RUNNER_ARCH:-unknown}
runner_image=${ImageOS:-unknown}
bazelisk_version=$(bazelisk version 2>/dev/null | head -n 1 || true)
bazel_version=$(bazelisk --version 2>/dev/null || true)
ruby_version=$(ruby --version 2>/dev/null || true)
cocoapods_version=$(pod --version 2>/dev/null || true)
clang_version=$(xcrun clang --version 2>/dev/null | head -n 1 || true)
xcode_version=$(xcodebuild -version | tr '\n' ' ')
iphoneos_sdk=$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null || true)
iphonesimulator_sdk=$(xcrun --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)
EOF

for archive in "${DIST_DIR}"/*.tar.gz; do
  echo "==> ${archive}"
  tar -tzf "${archive}"
done
