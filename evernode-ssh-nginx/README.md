# evernode-ssh-nginx

[Source repository](https://github.com/WietseWind/ever-dockers) · [Image recipe](https://github.com/WietseWind/ever-dockers/tree/main/evernode-ssh-nginx) · [Docker Hub](https://hub.docker.com/r/wietsewind/evernode-ssh-nginx) · [Release records](https://github.com/WietseWind/ever-dockers/tree/main/evernode-ssh-nginx/releases)

Ubuntu 24.04 with nginx, OpenSSH and passwordless sudo for the SSH-key-authenticated `deploy` user. This is a standalone application container, not the HotPocket consensus engine and not an Evernode host installer.

## Services and access

- nginx serves `/http` on container port **8080**.
- SSH listens on container port **2222**, user **deploy**. Password and direct root SSH login are disabled.
- `sudo -i` gives root **inside the container**; `sudo apt update` and `sudo apt install nano` work.
- The published maintainer image authorizes the public key in `authorized_keys.pub`. You need its corresponding private key to log in. Rebuild with your own public key for your own deployments; never put a private key in a build context.
- `/http` is a symlink to `/contract/http`. `/contract` should be a persistent volume; SSH host keys live under `/contract/everweb/ssh` outside the document root. `everweb` is just our internal directory name, not a platform requirement.

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

Site files and SSH server keys survive restart or recreation with the **same** volume, not migration to another lease. If an old `/contract/everweb/www` directory exists and `/contract/http` does not, startup copies the old site once without changing the original.

Interactive apt changes survive only in that container's writable layer; put recurring requirements in the recipe and publish a new version. Root privilege is container-scoped. The host operator controls the underlying machine, so never put a wallet seed or valuable credentials in this container. Direct HTTP is unencrypted unless you arrange a TLS proxy.

## Source verification

Follow a version's [release record](https://github.com/WietseWind/ever-dockers/tree/main/evernode-ssh-nginx/releases) to its source commit, pinned inputs and immutable image digest. See [publishing/reproducibility rules](https://github.com/WietseWind/ever-dockers/blob/main/PUBLISHING.md). Historical tags `20260907-1`, `-2`, and `-3` predate the locked build workflow; `-1`/`-2` also lack sudo and `/http`.
