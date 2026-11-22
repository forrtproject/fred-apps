#!/usr/bin/env bash
# Fetch and verify the latest validated FReD/FLoRA data bundle from the
# `data-latest` GitHub Release into <dest_dir> (default: ./data).
#
# Works unauthenticated for local development and uses GITHUB_TOKEN / GH_TOKEN
# automatically in CI. Tries completed bundle assets newest-first and verifies
# checksums and dataset integrity in a temp directory before installing.

set -euo pipefail

DEST_DIR="${1:-data}"
REPO="${FRED_DATA_REPO:-forrtproject/fred-apps}"
TAG="${FRED_DATA_TAG:-data-latest}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATOR="${SCRIPT_DIR}/validate-data.py"

TMP_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

AUTH_HEADER=()
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -n "$TOKEN" ]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${TOKEN}")
fi

API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
echo "Querying release '${TAG}' in ${REPO}..."
curl -fsSL --retry 3 --retry-delay 2 \
  -H "Accept: application/vnd.github+json" \
  "${AUTH_HEADER[@]}" \
  "$API_URL" -o "${TMP_ROOT}/release.json"

# List uploaded fred-data-*.tar.gz assets newest-first
mapfile -t ASSETS < <(python3 - "${TMP_ROOT}/release.json" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    rel = json.load(fh)
assets = [
    a for a in rel.get("assets", [])
    if a.get("state") == "uploaded"
    and a.get("name", "").startswith("fred-data-")
    and a.get("name", "").endswith(".tar.gz")
]
assets.sort(key=lambda a: (a.get("created_at") or "", a.get("id") or 0), reverse=True)
for a in assets:
    print(f"{a['name']}\t{a['browser_download_url']}")
PY
)

if [ "${#ASSETS[@]}" -eq 0 ]; then
  echo "ERROR: No uploaded fred-data-*.tar.gz assets found in release '${TAG}'." >&2
  exit 1
fi

INSTALLED=false
for entry in "${ASSETS[@]}"; do
  NAME="${entry%%$'\t'*}"
  URL="${entry#*$'\t'}"
  TRY_DIR="${TMP_ROOT}/try_${NAME%.tar.gz}"
  mkdir -p "$TRY_DIR/extracted"

  echo "Trying asset: ${NAME}"
  if ! curl -fsSL --retry 3 --retry-delay 2 "${AUTH_HEADER[@]}" "$URL" -o "${TRY_DIR}/${NAME}"; then
    echo "WARN: Failed to download ${NAME}; trying next asset." >&2
    continue
  fi

  if ! tar -xzf "${TRY_DIR}/${NAME}" -C "${TRY_DIR}/extracted"; then
    echo "WARN: Corrupt archive ${NAME}; trying next asset." >&2
    continue
  fi

  if [ -f "${TRY_DIR}/extracted/SHA256SUMS" ]; then
    if ! (cd "${TRY_DIR}/extracted" && sha256sum -c SHA256SUMS --quiet); then
      echo "WARN: Checksum verification failed for ${NAME}; trying next asset." >&2
      continue
    fi
  else
    echo "WARN: Missing SHA256SUMS in ${NAME}; trying next asset." >&2
    continue
  fi

  if [ -f "$VALIDATOR" ]; then
    if ! python3 "$VALIDATOR" validate "${TRY_DIR}/extracted"; then
      echo "WARN: Dataset validation failed for ${NAME}; trying next asset." >&2
      continue
    fi
  fi

  # Atomically install validated files into destination
  mkdir -p "$DEST_DIR"
  for f in explorer-data.json flora-data.json retraction-watch.csv.gz; do
    cp -f "${TRY_DIR}/extracted/${f}" "${DEST_DIR}/${f}.tmp"
    mv -f "${DEST_DIR}/${f}.tmp" "${DEST_DIR}/${f}"
  done

  echo "Installed validated data bundle '${NAME}' into ${DEST_DIR}/"
  INSTALLED=true
  break
done

if [ "$INSTALLED" != true ]; then
  echo "ERROR: All candidate data bundles failed verification." >&2
  exit 1
fi
