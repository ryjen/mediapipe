#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.10.26.1}"
HERMETIC_PYTHON_VERSION="${HERMETIC_PYTHON_VERSION:-3.12}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
WORK_ROOT="${RUNNER_TEMP:-/tmp}/mediapipe-ios-pods"
DIST_DIR="${REPO_ROOT}/dist/ios-pods"
LOG_DIR="${DIST_DIR}/build-logs"

rm -rf "${WORK_ROOT}" "${DIST_DIR}"
mkdir -p "${WORK_ROOT}" "${DIST_DIR}" "${LOG_DIR}"

prepare_public_genai_cpu_source() {
  local source_file="${REPO_ROOT}/mediapipe/tasks/cc/genai/inference/c/llm_inference_engine_cpu.cc"

  python3 - "${source_file}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
changed = False
old = """int LlmInferenceEngine_CreateEngine(const LlmModelSettings* model_settings,
                                    LlmInferenceEngine_Session** engine_out,
                                    char** error_msg) {"""
new = """int LlmInferenceEngine_CreateEngine(const LlmModelSettings* model_settings,
                                    LlmInferenceEngine_Engine** engine_out,
                                    char** error_msg) {"""

if text.count(old) == 1 and new not in text:
    text = text.replace(old, new)
    changed = True
elif text.count(new) != 1 or old in text:
    raise SystemExit("Unexpected public GenAI CPU CreateEngine signature")

generic_header = '#include "mediapipe/tasks/cc/genai/inference/c/llm_inference_engine.h"\n'
ios_header = """#if defined(__APPLE__)
#include "mediapipe/tasks/cc/genai/inference/c/llm_inference_engine_ios.h"
#endif
"""
if ios_header not in text:
    if text.count(generic_header) != 1:
        raise SystemExit("Unexpected public GenAI CPU header include")
    text = text.replace(generic_header, generic_header + ios_header)
    changed = True

add_image = """ODML_EXPORT int LlmInferenceEngine_Session_AddImage(
    LlmInferenceEngine_Session* session, const void* sk_bitmap,
    char** error_msg) {
  *error_msg = strdup("Not implemented");
  return 12;
}
"""
add_cg_image = """
#if defined(__APPLE__)
ODML_EXPORT int LlmInferenceEngine_Session_AddCgImage(
    LlmInferenceEngine_Session* session, CGImageRef image, char** error_msg) {
  if (error_msg) {
    *error_msg = strdup(
        "CGImage input is unavailable in the public CPU-only iOS build.");
  }
  return static_cast<int>(absl::StatusCode::kUnimplemented);
}
#endif
"""
if add_cg_image not in text:
    if text.count(add_image) != 1:
        raise SystemExit("Unexpected public GenAI CPU AddImage implementation")
    text = text.replace(add_image, add_image + add_cg_image)
    changed = True

if changed:
    path.write_text(text, encoding="utf-8")
PY
}

build_framework() {
  local framework="$1"
  local destination="${WORK_ROOT}/${framework}"
  local log_file="${LOG_DIR}/${framework}.log"
  mkdir -p "${destination}"

  local -a env_args=(
    "BAZEL=$(command -v bazelisk)"
    "HERMETIC_PYTHON_VERSION=${HERMETIC_PYTHON_VERSION}"
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
prepare_public_genai_cpu_source

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
hermetic_python_version=${HERMETIC_PYTHON_VERSION}
genai_backend=public_cpu_only
genai_cgimage_input=unsupported
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
