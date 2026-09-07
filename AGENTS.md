# Scope and mandatory publishing rules

This repository contains Docker image recipes only. Read README.md and PUBLISHING.md before modifying or publishing an image.

- Standing user instruction: requests to implement Docker behavior changes that affect the built image include documentation and end-to-end publication by default, for existing and new image types. Unless explicitly scoped as draft/local-only/do-not-publish, finish the tested, reproducibility-verified new image release, GitHub source/docs publication, source tag/digest record and bilateral links. Do not stop at local edits. Explanation/review requests and CLI-only or documentation-only edits do not themselves require an image release. Report blockers; never bypass release checks or replace live leases implicitly.
- One top-level folder per image type, named like its Docker Hub repository. Currently only `evernode-ssh-nginx/`.
- Never add the sibling tenant CLI, `.env`, wallets, seeds, SSH private keys, Docker credentials, or runtime data. The committed `authorized_keys.pub` is PUBLIC and is an intentional reproducible build input.
- The canonical image recipes live here, not in the sibling `evernode` checkout. That checkout may contain compatibility wrappers, never a competing maintained recipe.
- Every published image must link to this GitHub repo through OCI source/revision labels and the Docker Hub overview. Root and image READMEs must link back to Docker Hub. Keep both directions correct.
- Pin the base digest, Dockerfile frontend, BuildKit engine, Ubuntu build snapshot, direct package versions, platform and public-key input. Never silently replace pins with floating tags or live package indexes.
- Build from a clean, committed source tree. Push the source commit before publishing. Use a new explicit version; never overwrite a published version tag.
- `docker.sh verify` must compare two no-cache image-manifest digests before a release. If they differ, investigate; do not claim determinism because inputs are pinned or because cached builds match.
- After publishing, verify the registry digest, create a Git tag pointing at the actual build source commit, and publish a release record containing source commit, image digest, public-key hash, epoch, platform and exact builder. Commit the record under the image's `releases/` directory. Update Docker Hub's overview and both README links.
- Keep claims precise: record the environment and scope actually reproduced. Dependency availability and cross-machine reproduction are not guaranteed by a same-builder test. Runtime SSH keys are intentionally generated at startup, not embedded.
- Test HTTP, SSH-key login, `sudo -i`, an actual apt install, and persistence with the same volume after relevant changes. Never replace or terminate a user's live lease as part of an image-only release.

`deploy` in this repository means publish to Docker Hub. Host leasing and wallet operations belong exclusively to the tenant CLI.
