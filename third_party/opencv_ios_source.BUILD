# Description:
#   OpenCV xcframework for video/image processing on iOS.

load(
    "@//third_party:opencv_ios_source.bzl",
    "select_headers",
    "unzip_opencv_xcframework",
)
load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_xcframework_import",
)

licenses(["notice"])  # BSD license

exports_files(["LICENSE"])

# Build opencv2.xcframework from source using a convenience script provided in
# OPENCV sources and zip the xcframework. We only build the modules required by MediaPipe by specifying
# the modules to be ignored as command line arguments.
# We also specify the simulator and device architectures we are building for.
# Currently we only support iOS arm64 (M1 Macs) and x86_64(Intel Macs) simulators
# and arm64 iOS devices.
# Bitcode and Swift support. Swift support will be added in when the final binary
# for MediaPipe iOS Task libraries are built. Shipping with OPENCV built with
# Swift support throws linker errors when the MediaPipe framework is used from
# an iOS project.
#
# OpenCV 4.5.3 predates modern CMake/Xcode cross-compilation behavior, and its
# bundled zlib/libpng predates current Apple SDK headers. Patch an isolated
# source copy so probes compile as static libraries, zlib does not redefine
# fdopen, and libpng does not include removed classic-Mac fp.h. All edits are
# idempotent and fail closed against an unexpected third state.
genrule(
    name = "build_opencv_xcframework",
    srcs = glob(["opencv-4.5.3/**"]),
    outs = ["opencv2.xcframework.zip"],
    cmd = """
set -euo pipefail
source_root="$$(cd "$$(dirname "$(location opencv-4.5.3/platforms/apple/build_xcframework.py)")/../.." && pwd)"
patched_parent="$$(mktemp -d "$${TMPDIR:-/tmp}/opencv-4.5.3.XXXXXX")"
trap 'rm -rf "$$patched_parent"' EXIT
cp -R "$$source_root" "$$patched_parent/opencv-4.5.3"
chmod -R u+w "$$patched_parent/opencv-4.5.3"
python3 - \
  "$$patched_parent/opencv-4.5.3/platforms/ios/build_framework.py" \
  "$$patched_parent/opencv-4.5.3/3rdparty/zlib/zutil.h" \
  "$$patched_parent/opencv-4.5.3/3rdparty/libpng/pngpriv.h" <<'PY'
from pathlib import Path
import sys

build_script = Path(sys.argv[1])
lines = build_script.read_text(encoding="utf-8").splitlines(keepends=True)
function_starts = [
    index for index, line in enumerate(lines)
    if line.startswith("    def getCMakeArgs(")
]
if not function_starts:
    raise SystemExit("OpenCV getCMakeArgs definition is missing")
matches = []
for start in function_starts:
    end = next(
        (
            index for index in range(start + 1, len(lines))
            if lines[index].startswith("    def ") or lines[index].startswith("class ")
        ),
        len(lines),
    )
    matches.extend(
        index for index in range(start, end)
        if lines[index].strip() == '"-GXcode",'
    )
if len(matches) != 1:
    raise SystemExit(f"OpenCV getCMakeArgs -GXcode count: {len(matches)}")
index = matches[0]
static_arg = '"-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY",'
static_matches = [i for i, line in enumerate(lines) if line.strip() == static_arg]
if not static_matches:
    lines.insert(index + 1, lines[index].replace("-GXcode", "-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY"))
elif static_matches != [index + 1]:
    raise SystemExit(f"OpenCV static try-compile argument positions: {static_matches}")
build_script.write_text("".join(lines), encoding="utf-8")

zutil = Path(sys.argv[2])
zutil_lines = zutil.read_text(encoding="utf-8").splitlines(keepends=True)
os_code_candidates = [
    index for index in range(len(zutil_lines))
    if "OS_CODE" in zutil_lines[index] and "7" in zutil_lines[index]
]
if len(os_code_candidates) != 1 or os_code_candidates[0] == 0:
    raise SystemExit(f"OpenCV bundled zlib OS_CODE 7 candidates: {os_code_candidates}")
zutil_index = os_code_candidates[0] - 1
zutil_condition = zutil_lines[zutil_index].strip()
if zutil_condition == "#if defined(MACOS) || defined(TARGET_OS_MAC)":
    zutil_lines[zutil_index] = zutil_lines[zutil_index].replace(" || defined(TARGET_OS_MAC)", "")
elif zutil_condition != "#if defined(MACOS)":
    raise SystemExit(f"OpenCV bundled zlib Apple condition: {zutil_condition}")
zutil.write_text("".join(zutil_lines), encoding="utf-8")

pngpriv = Path(sys.argv[3])
pngpriv_lines = pngpriv.read_text(encoding="utf-8").splitlines(keepends=True)
png_matches = [
    index for index, line in enumerate(pngpriv_lines)
    if "defined(__SC__)" in line
]
if len(png_matches) != 1:
    raise SystemExit(f"OpenCV bundled libpng classic-Mac condition count: {len(png_matches)}")
png_index = png_matches[0]
if "defined(TARGET_OS_MAC)" in pngpriv_lines[png_index]:
    pngpriv_lines[png_index] = pngpriv_lines[png_index].replace(" || defined(TARGET_OS_MAC)", "")
elif pngpriv_lines[png_index].rstrip().endswith("||"):
    raise SystemExit("OpenCV bundled libpng condition ended unexpectedly")
pngpriv.write_text("".join(pngpriv_lines), encoding="utf-8")
PY
"$$patched_parent/opencv-4.5.3/platforms/apple/build_xcframework.py" \
  --iphonesimulator_archs arm64,x86_64 \
  --iphoneos_archs arm64 \
  --iphoneos_deployment_target 15.0 \
  --without dnn \
  --without ml \
  --without stitching \
  --without photo \
  --without objdetect \
  --without gapi \
  --without flann \
  --without highgui \
  --without videoio \
  --without objc \
  --disable PROTOBUF \
  --disable-bitcode \
  --disable-swift \
  --build_only_specified_archs \
  --out "$(@D)"
cd "$(@D)"
zip --symlinks -r opencv2.xcframework.zip opencv2.xcframework
""",
)

# Unzips `opencv2.xcframework.zip` built from source by `build_opencv_xcframework`
# genrule and returns an exhaustive list of all its files including symlinks.
unzip_opencv_xcframework(
    name = "opencv2_unzipped_xcframework_files",
    zip_file = "opencv2.xcframework.zip",
)

# Imports the files of the unzipped `opencv2.xcframework` as an apple static
# framework which can be linked to iOS targets.
apple_static_xcframework_import(
    name = "opencv_xcframework",
    visibility = ["//visibility:public"],
    xcframework_imports = [":opencv2_unzipped_xcframework_files"],
)

# Filters the headers for each platform in `opencv2.xcframework` which will be used as headers in a `cc_library` that can be linked to C++ targets.
select_headers(
    name = "opencv_xcframework_device_headers",
    srcs = [":opencv_xcframework"],
    platform = "ios-arm64",
)

select_headers(
    name = "opencv_xcframework_simulator_headers",
    srcs = [":opencv_xcframework"],
    platform = "ios-arm64_x86_64-simulator",
)

# `cc_library` that can be linked to C++ targets to import opencv headers.
cc_library(
    name = "opencv",
    hdrs = select({
        "@//mediapipe:ios_x86_64": [
            ":opencv_xcframework_simulator_headers",
        ],
        "@//mediapipe:ios_sim_arm64": [
            ":opencv_xcframework_simulator_headers",
        ],
        "@//mediapipe:ios_arm64": [
            ":opencv_xcframework_device_headers",
        ],
        # A value from above is chosen arbitrarily.
        "//conditions:default": [
            ":opencv_xcframework_simulator_headers",
        ],
    }),
    copts = [
        "-std=c++11",
        "-x objective-c++",
    ],
    include_prefix = "opencv2",
    linkopts = [
        "-framework AssetsLibrary",
        "-framework CoreFoundation",
        "-framework CoreGraphics",
        "-framework CoreMedia",
        "-framework Accelerate",
        "-framework CoreImage",
        "-framework AVFoundation",
        "-framework CoreVideo",
        "-framework QuartzCore",
    ],
    strip_include_prefix = select({
        "@//mediapipe:ios_x86_64": "opencv2.xcframework/ios-arm64_x86_64-simulator/opencv2.framework/Versions/A/Headers",
        "@//mediapipe:ios_sim_arm64": "opencv2.xcframework/ios-arm64_x86_64-simulator/opencv2.framework/Versions/A/Headers",
        "@//mediapipe:ios_arm64": "opencv2.xcframework/ios-arm64/opencv2.framework/Versions/A/Headers",
        # Random value is selected for default cases.
        "//conditions:default": "opencv2.xcframework/ios-arm64_x86_64-simulator/opencv2.framework/Versions/A/Headers",
    }),
    visibility = ["//visibility:public"],
    deps = [":opencv_xcframework"],
)
