#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
builder_name=ever-dockers-bk-0312
builder_image='moby/buildkit:v0.31.2@sha256:2f5adac4ecd194d9f8c10b7b5d7bceb5186853db1b26e5abd3a657af0b7e26ec'
usage() {
    echo 'Usage: ./docker.sh build|verify|publish|deploy IMAGE_TYPE [--tag VERSION] [--namespace USER] [--ssh-key FILE.pub] [--no-cache]'
    echo 'deploy is an alias for publish to Docker Hub; this script never rents Evernode hosts.'
}
action="${1:-}"
image_type="${2:-}"
if [[ "$action" == --help || "$action" == -h ]]; then usage; exit 0; fi
case "$action" in build|verify|publish|deploy) ;; *) usage >&2; exit 1 ;; esac
[[ "$image_type" =~ ^[a-z0-9][a-z0-9-]*$ && -f "$repo_root/$image_type/Dockerfile" ]] || { echo 'Unknown image type' >&2; exit 1; }
shift 2
version="$(<"$repo_root/$image_type/VERSION")"
namespace=wietsewind
public_key="$repo_root/$image_type/authorized_keys.pub"
no_cache=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag) version="${2:?Missing version}"; shift 2 ;;
        --namespace) namespace="${2:?Missing namespace}"; shift 2 ;;
        --ssh-key) public_key="${2:?Missing public key}"; shift 2 ;;
        --no-cache) no_cache=1; shift ;;
        *) usage >&2; exit 1 ;;
    esac
done
[[ "$version" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$ && "$version" != latest ]] || { echo 'Use an explicit version, not latest' >&2; exit 1; }
[[ "$namespace" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo 'Invalid Docker Hub namespace' >&2; exit 1; }
[[ "$public_key" == *.pub ]] || { echo 'Only a PUBLIC .pub key is allowed' >&2; exit 1; }
awk 'NF && $1 !~ /^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))$/ { exit 1 }' "$public_key" || { echo 'The file must contain only SSH public keys, never a private key' >&2; exit 1; }
ssh-keygen -lf "$public_key"
key_hash="$(shasum -a 256 "$public_key" | cut -d ' ' -f 1)"
revision="$(git -C "$repo_root" rev-parse HEAD)"
epoch="$(git -C "$repo_root" log -1 --format=%ct)"
[[ -z "$(git -C "$repo_root" status --porcelain)" ]] || { echo 'Commit source changes before building; the image must identify an exact clean source commit.' >&2; exit 1; }
image_ref="$namespace/$image_type:$version"
mkdir -p "$repo_root/.build"
prefix="$repo_root/.build/$image_type-$version"
if ! docker buildx inspect "$builder_name" >/dev/null 2>&1; then
    docker buildx create --name "$builder_name" --driver docker-container --driver-opt "image=$builder_image"
fi
docker buildx inspect "$builder_name" --bootstrap >/dev/null
actual_builder="$(docker inspect "buildx_buildkit_${builder_name}0" --format '{{.Config.Image}}')"
[[ "$actual_builder" == "$builder_image" ]] || { echo 'The named builder does not match the pinned engine image' >&2; exit 1; }

build_image() {
    local output="$1" metadata="$2"
    shift 2
    docker buildx build --builder "$builder_name" --platform linux/amd64 \
        --provenance=false --sbom=false --tag "$image_ref" \
        --build-arg "SOURCE_DATE_EPOCH=$epoch" --build-arg "VCS_REF=$revision" \
        --build-arg "IMAGE_VERSION=$version" --build-arg "AUTHORIZED_KEYS_SHA256=$key_hash" \
        --build-arg "IMAGE_REPOSITORY=$namespace/$image_type" \
        --secret "id=authorized_keys,src=$public_key" --metadata-file "$metadata" \
        --output "$output,rewrite-timestamp=true,oci-mediatypes=false,compression=gzip,compression-level=6,force-compression=true" \
        "$@" "$repo_root/$image_type"
}
image_output="type=image,name=$image_ref,push=false"
verify_image() {
    build_image "$image_output" "$prefix.first.json" --no-cache
    build_image "$image_output" "$prefix.second.json" --no-cache
    local first second
    first="$(jq -er '.["containerimage.digest"]' "$prefix.first.json")"
    second="$(jq -er '.["containerimage.digest"]' "$prefix.second.json")"
    [[ "$first" == "$second" ]] || { echo "Reproducibility failed: $first != $second" >&2; exit 1; }
    jq -n --arg revision "$revision" --arg epoch "$epoch" --arg key "$key_hash" --arg digest "$first" --arg engine "$builder_image" \
        '{revision:$revision,sourceDateEpoch:$epoch,publicKeySha256:$key,digest:$digest,builder:$engine,platform:"linux/amd64",noCacheBuilds:2}' > "$prefix.verified.json"
    echo "Two no-cache builds match: $first"
}
case "$action" in
    build)
        if [[ "$no_cache" == 1 ]]; then build_image 'type=docker' "$prefix.local.json" --no-cache;
        else build_image 'type=docker' "$prefix.local.json"; fi
        ;;
    verify) verify_image ;;
    publish|deploy)
        published_status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "https://hub.docker.com/v2/repositories/$namespace/$image_type/tags/$version")"
        [[ "$published_status" == 404 ]] || { echo "Refusing to overwrite or assume a tag is free (HTTP $published_status). Use a new version." >&2; exit 1; }
        git -C "$repo_root" fetch origin
        git -C "$repo_root" merge-base --is-ancestor "$revision" origin/main || { echo 'Push this source commit to origin/main first.' >&2; exit 1; }
        if [[ ! -f "$prefix.verified.json" ]] || ! jq -e --arg revision "$revision" --arg key "$key_hash" '.revision == $revision and .publicKeySha256 == $key' "$prefix.verified.json" >/dev/null; then verify_image; fi
        build_image "$image_output" "$prefix.prepublish.json"
        expected="$(jq -r .digest "$prefix.verified.json")"
        [[ "$(jq -r '.["containerimage.digest"]' "$prefix.prepublish.json")" == "$expected" ]] || { echo 'Pre-publish digest differs from verified digest' >&2; exit 1; }
        build_image "type=image,name=$image_ref,push=true" "$prefix.published.json"
        [[ "$(jq -r '.["containerimage.digest"]' "$prefix.published.json")" == "$expected" ]] || { echo 'Published digest differs; investigate before announcing a release' >&2; exit 1; }
        echo "Published $image_ref@$expected from $revision"
        node "$repo_root/scripts/update-overview.mjs" "$image_type" "$namespace"
        echo 'Finish the release record and Git tag as documented in PUBLISHING.md.'
        ;;
esac
