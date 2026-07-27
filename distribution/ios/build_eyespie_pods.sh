#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.10.26.1}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
WORK_ROOT="${RUNNER_TEMP:-/tmp}/mediapipe-ios-pods"
DIST_DIR="${REPO_ROOT}/dist/ios-pods"

rm -rf "${WORK_ROOT}" "${DIST_DIR}"
mkdir -p "${WORK_ROOT}" "${DIST_DIR}"

build_framework() {
  local framework="$1"
  local destination="${WORK_ROOT}/${framework}"
  mkdir -p "${destination}"

  local -a env_args=(
    "FRAMEWORK_NAME=${framework}"
    "MPP_BUILD_VERSION=${VERSION}"
    "IS_RELEASE_BUILD=true"
    "ARCHIVE_FRAMEWORK=true"
    "DEST_DIR=${destination}"
  )

  if [[ "${framework}" == "MediaPipeTasksGenAIC" || "${framework}" == "MediaPipeTasksGenAI" ]]; then
    env_args+=("ENABLE_ODML_COCOAPODS_BUILD=1")
  fi

  env "${env_args[@]}" \
    "${REPO_ROOT}/mediapipe/tasks/ios/build_ios_framework.sh"

  local archive
  archive="$(find "${destination}" -type f -name "${framework}-${VERSION}.tar.gz" -print -quit)"
  if [[ -z "${archive}" ]]; then
    echo "Missing archive for ${framework}" >&2
    find "${destination}" -maxdepth 8 -print >&2 || true
    exit 1
  fi

  cp "${archive}" "${DIST_DIR}/${framework}-${VERSION}.tar.gz"
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

cat > "${DIST_DIR}/provenance.txt" <<EOF
source_repository=https://github.com/google-ai-edge/mediapipe
upstream_tag=v0.10.26
distribution_commit=$(git rev-parse HEAD)
upstream_commit=$(git rev-list -n 1 v0.10.26)
distribution_version=${VERSION}
bazel_version=$(bazelisk version 2>/dev/null | tail -n 1 || true)
xcode_version=$(xcodebuild -version | tr '\n' ' ')
EOF

for archive in "${DIST_DIR}"/*.tar.gz; do
  echo "==> ${archive}"
  tar -tzf "${archive}"
done
