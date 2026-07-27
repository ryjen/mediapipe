#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.10.24.1}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
WORK_ROOT="${RUNNER_TEMP:-/tmp}/mediapipe-ios-pods"
DIST_DIR="${REPO_ROOT}/dist/ios-pods"

rm -rf "${WORK_ROOT}" "${DIST_DIR}"
mkdir -p "${WORK_ROOT}" "${DIST_DIR}"

build_framework() {
  local framework="$1"
  local destination="${WORK_ROOT}/${framework}"
  mkdir -p "${destination}"

  FRAMEWORK_NAME="${framework}" \
  MPP_BUILD_VERSION="${VERSION}" \
  IS_RELEASE_BUILD=true \
  ARCHIVE_FRAMEWORK=true \
  DEST_DIR="${destination}" \
    "${REPO_ROOT}/mediapipe/tasks/ios/build_ios_framework.sh"

  local archive
  archive="$(find "${destination}" -type f -name "${framework}-${VERSION}.tar.gz" -print -quit)"
  if [[ -z "${archive}" ]]; then
    echo "Missing archive for ${framework}" >&2
    find "${destination}" -maxdepth 6 -print >&2 || true
    exit 1
  fi

  cp "${archive}" "${DIST_DIR}/${framework}-${VERSION}.tar.gz"
}

cd "${REPO_ROOT}"
build_framework MediaPipeTasksCommon
build_framework MediaPipeTasksVision

(
  cd "${DIST_DIR}"
  shasum -a 256 ./*.tar.gz > SHA256SUMS
)

cat > "${DIST_DIR}/provenance.txt" <<EOF
source_repository=https://github.com/google-ai-edge/mediapipe
upstream_tag=v0.10.24
source_commit=$(git rev-parse HEAD)
upstream_commit=$(git rev-list -n 1 v0.10.24)
distribution_version=${VERSION}
EOF

for archive in "${DIST_DIR}"/*.tar.gz; do
  echo "==> ${archive}"
  tar -tzf "${archive}"
done
