# evernode-ssh-nginx

[Source repository](https://github.com/WietseWind/ever-dockers) · [Image recipe](https://github.com/WietseWind/ever-dockers/tree/main/evernode-ssh-nginx) · [Docker Hub](https://hub.docker.com/r/wietsewind/evernode-ssh-nginx) · [Release records](https://github.com/WietseWind/ever-dockers/tree/main/evernode-ssh-nginx/releases)

Ubuntu 24.04 with nginx, OpenSSH and passwordless sudo for the SSH-key-authenticated `deploy` user. This is a standalone application container, not the HotPocket consensus engine and not an Evernode host installer.

Current verified release: `wietsewind/evernode-ssh-nginx:20260908-1`. [Exact source and verification record](https://github.com/WietseWind/ever-dockers/blob/main/evernode-ssh-nginx/releases/20260908-1.json). The published manifest is `sha256:06f4d0a9a9d7b30804b6805d63084d8e0b7edbfddc3026db44f306ea6a8b64d1`; two uncached builds matched on the recorded builder. Cross-machine image reproduction has not been tested. The exact image passed a separate [native x86-64 runtime smoke test](https://github.com/WietseWind/ever-dockers/actions/runs/34224031688).

## Services and access

- nginx serves `/html` on container port **8080**. `/var/www` and the older `/http` path point to the same folder, backed by `/contract/http`.
- SSH listens on container port **2222**, user **deploy**. Password and direct root SSH login are disabled.
- `sudo -i` gives root **inside the container**; `sudo apt update` and package installation work. Nano, jq, Python 3, rsync, Node **24.20.0** (with npm/npx), Bun **1.4.2** (baseline x64 build, with bunx), and nvm **0.40.7** are installed by default in recipe version `20260908-1`.
- The published maintainer image authorizes the public key in `authorized_keys.pub`. You need its corresponding private key to log in. Rebuild with your own public key for your own deployments; never put a private key in a build context.
- `/contract` should be a persistent volume; SSH host keys live under `/contract/everweb/ssh` outside the document root. Site publication backups go to `/contract/everweb/publish-backups` (private to `deploy` and root). `everweb` is just our internal directory name, not a platform requirement.

Node and Bun work in SSH commands, interactive shells and `sudo -i`. nvm is a Bash function, loaded automatically for `deploy` and root; use `command -v nvm`, `nvm --version` and `nvm use 24`. The bundled Node 24 installation is shared and root-owned, with per-user nvm version directories referencing it. Additional `nvm install` versions are per-user. Global npm installs into the bundled version require sudo; project-local npm installs do not. Runtime nvm/npm/Bun changes are not part of the reproducible image or persistent website volume.

Runtime target: native Linux x86-64 (Bun's baseline binary still requires SSE4.2). On the recorded Apple Silicon Docker/QEMU test environment, `bun --version` passed but JavaScript evaluation aborted with JavaScriptCore `MemoryExhaustion`; the exact same published image passed actual Node/Bun JavaScript execution on native Linux. Do not interpret a version-only check or successful cross-build as full emulated-runtime support.

## Static nginx hardening

The default site denies all dotfiles/dot-directories, including `.env`, `.git` and `.well-known`; blocks `node_modules`; hides common backup, key, database, server-script and package/config files; disables directory listings and symlinks within the document root; and accepts only GET/HEAD for static resources. The health endpoint is `/health`. The configuration limits request bodies and idle/header/body/send timeouts, runs workers as `www-data`, and omits nginx version disclosure.

Responses include `nosniff`, same-origin framing, a restrictive permissions policy, a referrer policy, and baseline CSP restrictions on objects, base URLs and framing. CSP intentionally does not restrict script/style/image origins because this is a general-purpose site container; apply a site-specific policy for stronger protection. No permissive CORS policy is added. TLS redirects and HSTS are not enabled on the host-assigned plain-HTTP port; configure them at a verified HTTPS endpoint/proxy. Serving hidden ACME challenges requires an explicit reviewed exception.

The tenant CLI's `ever publish CONTAINER PATH` uploads a built/static site to `/html` using SSH/rsync, with hidden files and `node_modules` excluded and backups outside the public root. This is different from this repository's `docker.sh publish`, which releases a Docker image. Never upload private application configuration or credentials as website assets. Review backups/storage usage periodically; backups are not automatically discarded.

Evernode image options:

```text
wietsewind/evernode-ssh-nginx:VERSION--gptcp1--8080--gptcp2--2222--proxyssl--false
```

The host assigns external ports. Use the actual acquisition reply, not assumed host port ranges. Some hosts do not support these custom image options. The image ignores incorrect `INTERNAL_GPTCP2_PORT` metadata; application ports are `HTTP_PORT=8080` and `SSH_PORT=2222`.

For local testing:

```bash
./docker.sh build evernode-ssh-nginx
docker run --platform linux/amd64 -p 127.0.0.1:8080:8080 -p 127.0.0.1:2222:2222 \
  -v everweb-test:/contract wietsewind/evernode-ssh-nginx:VERSION
ssh -i /path/to/private-key -p 2222 deploy@127.0.0.1
```

## Persistence and trust

Site files, publication backups and SSH server keys survive restart or recreation with the **same** volume, not migration to another lease. Existing `/contract/http` data from v4 is used directly by `/html`; if an old `/contract/everweb/www` directory exists and `/contract/http` does not, startup copies the old site once without changing the original. The default index is seeded only into an empty document root.

Interactive apt changes survive only in that container's writable layer; put recurring requirements in the recipe and publish a new version. Root privilege is container-scoped. The host operator controls the underlying machine, so never put a wallet seed or valuable credentials in this container. Direct HTTP is unencrypted unless you arrange a TLS proxy.

## Source verification

Follow a version's [release record](https://github.com/WietseWind/ever-dockers/tree/main/evernode-ssh-nginx/releases) to its source commit, pinned inputs and immutable image digest. See [publishing/reproducibility rules](https://github.com/WietseWind/ever-dockers/blob/main/PUBLISHING.md). Historical tags `20260907-1`, `-2`, and `-3` predate the locked build workflow; `-1`/`-2` also lack sudo and `/http`.
