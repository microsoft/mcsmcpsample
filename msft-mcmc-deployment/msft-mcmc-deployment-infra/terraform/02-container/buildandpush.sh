#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FOUNDATION_DIR="${SCRIPT_DIR}/../01-foundation"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../../" && pwd)"
readonly SERVICE_DIR="${REPO_ROOT}/msft-mcmc-mcp/msft-mcmc-mcp-service"
readonly VERSION_FILE="${REPO_ROOT}/version"
readonly IMAGE_MANIFEST="${SCRIPT_DIR}/image.json"
readonly IMAGE_REPOSITORY="msft-mcmc-mcp-service"

if [[ $# -ne 0 ]]; then
  echo "Usage: $0" >&2
  exit 2
fi

declare -A VERSION_VALUES=()
while IFS='=' read -r key value; do
  if [[ ! "${key}" =~ ^VERSION_(MAJOR|MINOR|REVISION|BUILD)$ || ! "${value}" =~ ^[0-9]+$ ]]; then
    echo "Invalid version entry: ${key}=${value}" >&2
    exit 1
  fi
  if [[ -v "VERSION_VALUES[${key}]" ]]; then
    echo "Duplicate version entry: ${key}" >&2
    exit 1
  fi
  VERSION_VALUES["${key}"]="${value}"
done < "${VERSION_FILE}"

for key in VERSION_MAJOR VERSION_MINOR VERSION_REVISION VERSION_BUILD; do
  if [[ ! -v "VERSION_VALUES[${key}]" ]]; then
    echo "Missing version entry: ${key}" >&2
    exit 1
  fi
done

readonly VERSION_REVISION="$(git -C "${REPO_ROOT}" rev-list --count HEAD)"
readonly VERSION_BUILD="$((10#${VERSION_VALUES[VERSION_BUILD]} + 1))"
readonly IMAGE_TAG="${VERSION_VALUES[VERSION_MAJOR]}.${VERSION_VALUES[VERSION_MINOR]}.${VERSION_REVISION}.${VERSION_BUILD}"
readonly VERSION_TEMP="$(mktemp "${VERSION_FILE}.XXXXXX")"
trap 'rm -f "${VERSION_TEMP}"' EXIT

printf 'VERSION_MAJOR=%s\nVERSION_MINOR=%s\nVERSION_REVISION=%s\nVERSION_BUILD=%s\n' \
  "${VERSION_VALUES[VERSION_MAJOR]}" \
  "${VERSION_VALUES[VERSION_MINOR]}" \
  "${VERSION_REVISION}" \
  "${VERSION_BUILD}" > "${VERSION_TEMP}"
chmod --reference="${VERSION_FILE}" "${VERSION_TEMP}"
mv "${VERSION_TEMP}" "${VERSION_FILE}"

az account show --output none

readonly REGISTRY_NAME="$(cd "${FOUNDATION_DIR}" && terragrunt output -raw container_registry_name)"
readonly REGISTRY_LOGIN_SERVER="$(cd "${FOUNDATION_DIR}" && terragrunt output -raw container_registry_login_server)"
readonly IMAGE_NAME="${IMAGE_REPOSITORY}:${IMAGE_TAG}"

if az acr repository show \
  --name "${REGISTRY_NAME}" \
  --image "${IMAGE_NAME}" \
  --output none 2>/dev/null; then
  echo "Refusing to overwrite existing image tag ${REGISTRY_LOGIN_SERVER}/${IMAGE_NAME}." >&2
  exit 1
fi

(
  cd "${SERVICE_DIR}"
  az acr build \
    --registry "${REGISTRY_NAME}" \
    --image "${IMAGE_NAME}" \
    --file Dockerfile \
    --platform linux/amd64 \
    .
)

readonly IMAGE_DIGEST="$(az acr repository show \
  --name "${REGISTRY_NAME}" \
  --image "${IMAGE_NAME}" \
  --query digest \
  --output tsv)"

readonly IMAGE_MANIFEST_TEMP="$(mktemp "${IMAGE_MANIFEST}.XXXXXX")"
trap 'rm -f "${VERSION_TEMP}" "${IMAGE_MANIFEST_TEMP}"' EXIT
printf '{\n  "registry": "%s",\n  "repository": "%s",\n  "tag": "%s",\n  "digest": "%s"\n}\n' \
  "${REGISTRY_LOGIN_SERVER}" \
  "${IMAGE_REPOSITORY}" \
  "${IMAGE_TAG}" \
  "${IMAGE_DIGEST}" > "${IMAGE_MANIFEST_TEMP}"
mv "${IMAGE_MANIFEST_TEMP}" "${IMAGE_MANIFEST}"

printf 'Image: %s/%s@%s\n' "${REGISTRY_LOGIN_SERVER}" "${IMAGE_REPOSITORY}" "${IMAGE_DIGEST}"
