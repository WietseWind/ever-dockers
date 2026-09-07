# Release contract: source, image and bilateral links

## Scope

Only image recipes and their build/release support files belong in this repository. Each image type gets one top-level folder named after its Docker Hub repository. Do not copy the `ever` tenant client, wallets, seeds, private SSH keys, credentials or running-container data into Git or any build context.

The public authorized key is intentionally included because it changes the image bytes and determines who may administer a deployed container. Never confuse it with the private login key. A custom public key is an additional input and must be preserved with the release if it differs from the committed key.

## Required links

1. Root README → Docker Hub repository and corresponding image folder.
2. Image README → Docker Hub repository and this GitHub repository/folder.
3. Docker Hub overview → this GitHub repository and image folder (with release records reachable).
4. Image OCI labels: `org.opencontainers.image.source`, `revision`, `version`, and `url`.
5. Per-version record: full source commit, immutable registry digest, public-key SHA-256, SOURCE_DATE_EPOCH, platform, pinned engine, and reproducibility result.

Do not claim a release is complete until both websites have the links. `scripts/update-overview.mjs` synchronizes an image README to Docker Hub using credentials held only in memory. Never print, commit or send those credentials to GitHub.

## Build inputs and verification

- Base Ubuntu image and Dockerfile frontend are pinned by digest in the Dockerfile.
- The builder is `moby/buildkit:v0.31.2` pinned by digest in `docker.sh`; output is `linux/amd64`.
- Build packages come from the dated Ubuntu snapshot in `ubuntu-build.sources`, with direct versions in `packages.lock`. Ubuntu archive signatures and package hashes remain enabled.
- A checksum-pinned Ubuntu CA package bootstraps TLS before apt. No insecure TLS option or unsigned repository is used.
- `SOURCE_DATE_EPOCH` is the source Git commit timestamp; image file timestamps are rewritten. Clock-dependent install logs/cache and password age are normalized.
- The public key's bytes and SHA-256 are part of the build inputs. Secret mounts here carry a PUBLIC key only.
- gzip level 6, forced compression and Docker media types are explicit. Build attestations/SBOM wrappers are disabled for deterministic manifest comparison; do not misrepresent source labels as signed provenance.
- Runtime SSH host keys are generated at startup and intentionally differ between new leases. They are not part of the published image digest.
- Normal Ubuntu apt repositories are restored for interactive administration. Packages users install after launch are outside the reproducible published artifact.

## Release checklist

1. Update the recipe and explicit VERSION. Review snapshot/package/base updates deliberately; never publish as `latest` or overwrite an existing version.
2. Check the staged file list for private material. Commit and push the recipe to `origin/main`.
3. Run `./docker.sh verify IMAGE_TYPE`. It runs two no-cache builds, compares full image manifest digests and records results under ignored `.build/`.
4. Run `./docker.sh build IMAGE_TYPE` and smoke-test HTTP, public-key SSH, root elevation, apt installation, and same-volume persistence. Use test containers, not a user's live lease.
5. Run `./docker.sh publish IMAGE_TYPE` (or `deploy`). It refuses existing tags, requires pushed source, checks/reuses matching verification results, compares the pre-publish digest and pushes the image.
6. Synchronize the image README to Docker Hub with `node scripts/update-overview.mjs IMAGE_TYPE`. Read it back anonymously and verify both directions of links.
7. Create Git tag `IMAGE_TYPE/VERSION` at the source commit recorded in `.build/*.verified.json`, not at a later documentation commit. Push this tag.
8. Commit `IMAGE_TYPE/releases/VERSION.json` with the verification record plus image reference and registry digest. A GitHub release may also attach this record and the public key for independent reproduction.
9. Verify `docker buildx imagetools inspect IMAGE:VERSION` matches the record and inspect the source/revision labels. Only then update the tenant CLI's default image.

Do not silently erase or republish a bad release. Use another version and explain the issue. Legacy tags `20260907-1`, `-2`, and `-3` predate this repository's locked-build workflow and are not covered by its reproducibility claim.

## Reproducing a release

Check out its source tag/commit, use the recorded public key and platform, then run `docker.sh verify`. Compare the manifest digest, not just the image name or an `IMAGE ID`. Compare the record's builder and epoch too. A cached repeat does not establish reproducibility. Different runtime host keys or later `apt install` modifications do not indicate a mismatch in the original published image.

Snapshot services and registries must still retain the pinned dependencies. Same-builder no-cache equality is the minimum release gate; cross-machine/architecture reproduction must be reported separately if tested.
