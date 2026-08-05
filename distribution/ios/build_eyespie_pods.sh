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

capability_contract = """
#if defined(__APPLE__)
ODML_EXPORT int EyespieMediaPipeGenAI_CapabilitySchemaVersion(void) {
  return 1;
}

ODML_EXPORT const char* EyespieMediaPipeGenAI_Backend(void) {
  return "public_cpu_only";
}

ODML_EXPORT int EyespieMediaPipeGenAI_SupportsTextGeneration(void) {
  return 1;
}

ODML_EXPORT int EyespieMediaPipeGenAI_SupportsCgImageInput(void) {
  return 0;
}

ODML_EXPORT int EyespieMediaPipeGenAI_SupportsGpuAcceleration(void) {
  return 0;
}
#endif
"""
if capability_contract not in text:
    if text.count(add_cg_image) != 1:
        raise SystemExit("Unexpected public GenAI CPU CGImage compatibility implementation")
    text = text.replace(add_cg_image, add_cg_image + capability_contract)
    changed = True

if changed:
    path.write_text(text, encoding="utf-8")
PY
}

prepare_shared_tflite_runtime_boundary() {
  local build_file="${REPO_ROOT}/mediapipe/tasks/ios/BUILD"

  python3 - "${build_file}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = '''apple_static_xcframework(
    name = "MediaPipeTasksGenAIC_framework",
    bundle_name = "MediaPipeTasksGenAIC",
'''
new = '''apple_static_xcframework(
    name = "MediaPipeTasksGenAIC_framework",
    # Common is the single owner of the TensorFlow Lite C runtime. Excluding
    # these transitive objects prevents duplicate Objective-C and C symbols
    # when Vision/Common and GenAI/GenAIC are linked into the same app.
    avoid_deps = TENSORFLOW_LITE_C_DEPS,
    bundle_name = "MediaPipeTasksGenAIC",
'''
old_deps = '''    # Including here the deps that were in avoid_deps in MediaPipeTasksGenAI_library.
    deps = TENSORFLOW_LITE_C_DEPS + [
        "//mediapipe/tasks/cc/genai/inference/c:libllm_inference_engine_cpu",
    ],
'''
new_deps = '''    deps = [
        "//mediapipe/tasks/cc/genai/inference/c:libllm_inference_engine_cpu",
    ],
'''

if text.count(old) != 1:
    raise SystemExit("Unexpected MediaPipeTasksGenAIC framework declaration")
if text.count(old_deps) != 1:
    raise SystemExit("Unexpected MediaPipeTasksGenAIC dependency declaration")

text = text.replace(old, new).replace(old_deps, new_deps)
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

package_genai_capabilities() {
  local archive="${DIST_DIR}/MediaPipeTasksGenAI-${VERSION}.tar.gz"
  local root="${WORK_ROOT}/MediaPipeTasksGenAI-capabilities"
  local manifest="${root}/capabilities/EyespieMediaPipeGenAICapabilities.json"
  local repacked="${archive}.tmp"

  rm -rf "${root}"
  mkdir -p "${root}/capabilities"
  tar -xzf "${archive}" -C "${root}"

  python3 - \
    "${manifest}" \
    "${VERSION}" \
    "$(git rev-parse HEAD)" \
    "$(git rev-list -n 1 v0.10.26)" <<'PY'
import json
from pathlib import Path
import sys

manifest = Path(sys.argv[1])
version = sys.argv[2]
distribution_commit = sys.argv[3]
upstream_commit = sys.argv[4]

payload = {
    "schema_version": 1,
    "distribution": {
        "name": "EyespieMediaPipeTasksGenAI",
        "version": version,
        "distribution_commit": distribution_commit,
        "upstream_tag": "v0.10.26",
        "upstream_commit": upstream_commit,
    },
    "platform": {
        "minimum_ios": "15.0",
        "device_architectures": ["arm64"],
        "simulator_architectures": ["arm64", "x86_64"],
    },
    "backend": {
        "identifier": "public_cpu_only",
        "gpu_acceleration": False,
    },
    "features": {
        "text_generation": {
            "api_supported": True,
            "tested_model_families": [],
            "qualification": "pending_device_benchmarks",
        },
        "cgimage_input": {
            "supported": False,
            "error_code": "kUnimplemented",
            "state_mutation_on_failure": False,
        },
    },
    "upstream_references": [
        "google-ai-edge/mediapipe#6234",
        "google-ai-edge/mediapipe#6246",
    ],
}

manifest.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

  tar -czf "${repacked}" -C "${root}" .
  mv "${repacked}" "${archive}"
}

validate_genai_capability_contract() {
  local root="${WORK_ROOT}/capability-validation"
  rm -rf "${root}"
  mkdir -p "${root}/GenAIC" "${root}/GenAI"
  tar -xzf "${DIST_DIR}/MediaPipeTasksGenAIC-${VERSION}.tar.gz" -C "${root}/GenAIC"
  tar -xzf "${DIST_DIR}/MediaPipeTasksGenAI-${VERSION}.tar.gz" -C "${root}/GenAI"

  python3 - "${root}" "${VERSION}" "$(git rev-parse HEAD)" <<'PY'
import json
from pathlib import Path
import plistlib
import subprocess
import sys

root = Path(sys.argv[1])
version = sys.argv[2]
distribution_commit = sys.argv[3]

manifest_path = root / "GenAI" / "capabilities" / "EyespieMediaPipeGenAICapabilities.json"
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
assert manifest["schema_version"] == 1
assert manifest["distribution"]["name"] == "EyespieMediaPipeTasksGenAI"
assert manifest["distribution"]["version"] == version
assert manifest["distribution"]["distribution_commit"] == distribution_commit
assert manifest["backend"] == {
    "gpu_acceleration": False,
    "identifier": "public_cpu_only",
}
assert manifest["features"]["text_generation"]["api_supported"] is True
assert manifest["features"]["text_generation"]["tested_model_families"] == []
assert manifest["features"]["cgimage_input"]["supported"] is False
assert manifest["features"]["cgimage_input"]["error_code"] == "kUnimplemented"

xcframework = root / "GenAIC" / "frameworks" / "MediaPipeTasksGenAIC.xcframework"
with (xcframework / "Info.plist").open("rb") as handle:
    metadata = plistlib.load(handle)

required_symbols = (
    "EyespieMediaPipeGenAI_CapabilitySchemaVersion",
    "EyespieMediaPipeGenAI_Backend",
    "EyespieMediaPipeGenAI_SupportsTextGeneration",
    "EyespieMediaPipeGenAI_SupportsCgImageInput",
    "EyespieMediaPipeGenAI_SupportsGpuAcceleration",
)

for entry in metadata.get("AvailableLibraries", []):
    library = xcframework / entry["LibraryIdentifier"] / entry["LibraryPath"]
    binary = library / "MediaPipeTasksGenAIC" if library.is_dir() else library
    output = subprocess.check_output(["nm", "-gU", str(binary)], text=True)
    for symbol in required_symbols:
        assert f"_{symbol}" in output, f"{binary}: missing exported capability symbol {symbol}"

    if library.is_dir():
        header = library / "Headers" / "llm_inference_engine_ios.h"
        header_text = header.read_text(encoding="utf-8")
        for symbol in required_symbols:
            assert symbol in header_text, f"{header}: missing capability declaration {symbol}"
PY
}

cd "${REPO_ROOT}"
prepare_public_genai_cpu_source
prepare_shared_tflite_runtime_boundary

for framework in \
  MediaPipeTasksCommon \
  MediaPipeTasksVision \
  MediaPipeTasksGenAIC \
  MediaPipeTasksGenAI; do
  build_framework "${framework}"
done

package_genai_capabilities
validate_genai_capability_contract

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
genai_capability_schema_version=1
genai_capability_manifest=capabilities/EyespieMediaPipeGenAICapabilities.json
tflite_runtime_owner=MediaPipeTasksCommon
genaic_tflite_runtime=external_common_dependency
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
