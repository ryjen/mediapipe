#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.10.26.2}"
SOURCE_VERSION="${SOURCE_VERSION:-0.10.26.1}"
SOURCE_TAG="${SOURCE_TAG:-eyespie-ios-v0.10.26.1}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
DIST_DIR="${REPO_ROOT}/dist/ios-pods"
WORK_ROOT="${RUNNER_TEMP:-/tmp}/mediapipe-ios-repackage"

rm -rf "${WORK_ROOT}" "${DIST_DIR}"
mkdir -p "${WORK_ROOT}" "${DIST_DIR}"

expected_source_sha256() {
  case "$1" in
    MediaPipeTasksCommon) printf '%s\n' 'f884a5f47e0bbc4c53a7c1b440fb2b21966d0977b2f60ac15f2ce26eadfd8b88' ;;
    MediaPipeTasksVision) printf '%s\n' '235352827426693098163a3c95116d78874181f40c57dd6084a6e425d085e087' ;;
    MediaPipeTasksGenAIC) printf '%s\n' '4fcc412d63b2da9e8e67188bccede6561b7f114dfa6b75171918b3b4cc10887e' ;;
    MediaPipeTasksGenAI) printf '%s\n' '55c866f8c878e3e3fc302218a346fd4fbf8921d0f305ee505e0aa73ffe96bebe' ;;
    *) echo "Unknown framework: $1" >&2; return 1 ;;
  esac
}

payload_digest() {
  local root="$1"
  python3 - "$root" <<'PY'
from hashlib import sha256
from pathlib import Path
import sys

root = Path(sys.argv[1])
digest = sha256()
for path in sorted(p for p in root.rglob('*') if p.is_file()):
    relative = path.relative_to(root).as_posix()
    if relative.endswith('/Modules/module.modulemap'):
        continue
    digest.update(relative.encode('utf-8'))
    digest.update(b'\0')
    digest.update(path.read_bytes())
    digest.update(b'\0')
print(digest.hexdigest())
PY
}

normalize_framework_modulemaps() {
  local root="$1"
  local modulemap_count=0

  while IFS= read -r modulemap; do
    modulemap_count=$((modulemap_count + 1))
    python3 - "${modulemap}" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')

pattern = re.compile(r'\n\s*module\s+\*\s*\{\s*export\s+\*\s*\}\s*', re.MULTILINE)
matches = pattern.findall(text)
if len(matches) > 1:
    raise SystemExit(f'{path}: expected at most one simple inferred-submodule stanza, found {len(matches)}')
if len(matches) == 1:
    path.write_text(pattern.sub('\n', text, count=1), encoding='utf-8')
    print(f'{path}: removed inferred-submodule stanza')
else:
    print(f'{path}: no inferred-submodule stanza; unchanged')
PY
  done < <(find "${root}/frameworks" -path '*.framework/Modules/module.modulemap' -type f -print | sort)

  if (( modulemap_count == 0 )); then
    echo "No framework module maps found under ${root}" >&2
    return 1
  fi
}

repackage_framework() {
  local framework="$1"
  local source_archive="${WORK_ROOT}/${framework}-${SOURCE_VERSION}.tar.gz"
  local unpacked="${WORK_ROOT}/${framework}"
  local output_archive="${DIST_DIR}/${framework}-${VERSION}.tar.gz"
  local source_url="https://github.com/ryjen/mediapipe/releases/download/${SOURCE_TAG}/${framework}-${SOURCE_VERSION}.tar.gz"
  local expected
  expected="$(expected_source_sha256 "${framework}")"

  echo "==> Fetching validated ${framework} ${SOURCE_VERSION}"
  curl --fail --location --retry 4 --retry-all-errors --silent --show-error \
    "${source_url}" -o "${source_archive}"
  printf '%s  %s\n' "${expected}" "${source_archive}" | shasum -a 256 --check -

  mkdir -p "${unpacked}"
  tar -xzf "${source_archive}" -C "${unpacked}"

  local before_payload after_payload
  before_payload="$(payload_digest "${unpacked}")"
  normalize_framework_modulemaps "${unpacked}"
  after_payload="$(payload_digest "${unpacked}")"
  if [[ "${before_payload}" != "${after_payload}" ]]; then
    echo "Non-module-map payload changed while repackaging ${framework}" >&2
    return 1
  fi

  tar -czf "${output_archive}" -C "${unpacked}" .
  echo "${framework}: payload_sha256=${after_payload}"
}

for framework in \
  MediaPipeTasksCommon \
  MediaPipeTasksVision \
  MediaPipeTasksGenAIC \
  MediaPipeTasksGenAI; do
  repackage_framework "${framework}"
done

(
  cd "${DIST_DIR}"
  shasum -a 256 ./*.tar.gz > SHA256SUMS
)

cat > "${DIST_DIR}/provenance.txt" <<EOF
source_repository=https://github.com/ryjen/mediapipe
source_release_tag=${SOURCE_TAG}
source_distribution_version=${SOURCE_VERSION}
distribution_commit=$(git rev-parse HEAD)
distribution_version=${VERSION}
packaging_change=remove_inferred_submodule_stanzas_for_kotlin_cinterop
binary_payload=identical_to_source_release
source_common_sha256=f884a5f47e0bbc4c53a7c1b440fb2b21966d0977b2f60ac15f2ce26eadfd8b88
source_vision_sha256=235352827426693098163a3c95116d78874181f40c57dd6084a6e425d085e087
source_genaic_sha256=4fcc412d63b2da9e8e67188bccede6561b7f114dfa6b75171918b3b4cc10887e
source_genai_sha256=55c866f8c878e3e3fc302218a346fd4fbf8921d0f305ee505e0aa73ffe96bebe
EOF

cat "${DIST_DIR}/SHA256SUMS"
