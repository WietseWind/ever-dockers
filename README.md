# ever-dockers

Docker image sources for the `ever` Evernode tenant CLI. This is **not** the CLI repository and contains no wallet data or private keys.

| Image | Source | Registry |
| --- | --- | --- |
| Ubuntu nginx + SSH + sudo | [evernode-ssh-nginx](evernode-ssh-nginx/) | [Docker Hub](https://hub.docker.com/r/wietsewind/evernode-ssh-nginx) |

## Layout

```text
docker.sh                   # build, verify, publish (deploy = publish)
PUBLISHING.md               # release and reproducibility requirements
evernode-ssh-nginx/
  Dockerfile
  VERSION
  packages.lock             # explicit direct package versions
  ubuntu-build.sources      # immutable Ubuntu snapshot used during builds
  ubuntu.sources            # repositories for user-initiated apt at runtime
  authorized_keys.pub       # public login key; never a private key
  start.sh, *.template, ... # runtime files belonging to this image
  html/                     # default website
  releases/                 # source commit ↔ published digest records
.build/                     # ignored local build/verification artifacts
```

## Build and publish

Requirements: Git, Bash, Docker with Buildx, `jq`, `curl`, `ssh-keygen`, `shasum`; Node.js for the Docker Hub overview update. Docker Desktop on Apple Silicon can build the `linux/amd64` image using emulation. Native Linux builders need amd64 execution or appropriately configured emulation. The script creates a dedicated digest-pinned BuildKit builder without changing the default builder.

```bash
./docker.sh build evernode-ssh-nginx
./docker.sh verify evernode-ssh-nginx   # TWO no-cache builds; compare manifest digests

docker login
git push origin main                 # publish the exact build source first
./docker.sh publish evernode-ssh-nginx # also available as `deploy`
```

The default key is the committed **public** maintainer key. Pulling our published image does not give you its private key. For your own image, supply your public key and a new version/namespace:

```bash
./docker.sh build evernode-ssh-nginx --namespace YOURUSER --tag YOURVERSION --ssh-key /path/to/your/key.pub
```

Read [PUBLISHING.md](PUBLISHING.md) before publishing. Version tags are never intentionally overwritten. To inspect exactly what was released, follow the per-version release record and Git tag, then rebuild that **source commit** with the recorded inputs. Merely building current `main` is not necessarily a reproduction of an older release.

## Reproducibility

The recipe pins Ubuntu by digest, package snapshot and direct versions, public-key bytes/hash, Dockerfile frontend, BuildKit engine, platform, timestamp epoch and compression settings. The build context is a Git archive of the commit with fixed permissions/timestamps, independent of the local checkout. Build-time clock-dependent logs/cache files and account dates are normalized. Two no-cache builds must have the same image manifest digest before publishing.

This is a measured release property, not an unconditional promise about every future machine. Exact release records state what was verified. Build attestation timestamps are excluded from the deterministic artifact; source labels alone are not a cryptographic proof of trustworthy provenance. Independently reproduce and compare the digest when assurance matters.

Ubuntu only guarantees snapshot availability for a limited retention period; archive dependencies separately if long-term offline reproduction is required. See [Ubuntu snapshots](https://snapshot.ubuntu.com/), [BuildKit reproducibility](https://github.com/moby/buildkit/blob/master/docs/build-repro.md), and [Docker timestamp controls](https://docs.docker.com/build/ci/github-actions/reproducible-builds/).
