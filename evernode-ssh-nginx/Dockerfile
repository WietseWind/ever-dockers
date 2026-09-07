# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32
FROM scratch AS bootstrap-ca
# The minimal base has no CA bundle. BuildKit verifies this download's TLS and checksum.
# APT still verifies Ubuntu signatures and package hashes; TLS verification is never disabled.
ADD --checksum=sha256:6bac2a01979e210d9eac1d4d56747ec709ea60654744d66705dc3c36e7629e50 https://snapshot.ubuntu.com/ubuntu/20260907T000000Z/pool/main/c/ca-certificates/ca-certificates_20260601~24.04.1_all.deb /ca.deb

FROM ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517
ENV DEBIAN_FRONTEND=noninteractive HTTP_PORT=8080 SSH_PORT=2222
COPY --from=bootstrap-ca /ca.deb /tmp/bootstrap-ca.deb
COPY ubuntu-build.sources /etc/apt/sources.list.d/ubuntu.sources
COPY packages.lock /tmp/packages.lock
RUN dpkg-deb -x /tmp/bootstrap-ca.deb /tmp/bootstrap-ca \
    && mkdir -p /etc/ssl/certs \
    && cat /tmp/bootstrap-ca/usr/share/ca-certificates/mozilla/*.crt > /etc/ssl/certs/ca-certificates.crt \
    && apt-get update \
    && xargs apt-get install -y --no-install-recommends < /tmp/packages.lock \
    && useradd --uid 1001 --create-home --shell /bin/bash deploy \
    && passwd -d deploy \
    && chage -d 1970-01-02 -M 99999 deploy \
    && install -d -m 0755 /etc/ssh/authorized_keys \
    && ln -s /contract/http /http \
    && rm -rf /tmp/bootstrap-ca /tmp/bootstrap-ca.deb /tmp/packages.lock /var/lib/apt/lists/* \
    && rm -f /etc/ssh/ssh_host_* /var/cache/ldconfig/aux-cache \
    && find /var/log -type f -exec truncate -s 0 {} +

# Interactive apt commands use normal Ubuntu repositories. They modify that container only.
COPY ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources
COPY --chmod=0440 deploy.sudoers /etc/sudoers.d/deploy
RUN visudo -cf /etc/sudoers

# Public key is an explicit, hashed build input. No wallet or private key is ever copied.
ARG AUTHORIZED_KEYS_SHA256
RUN --mount=type=secret,id=authorized_keys,required=true \
    echo "$AUTHORIZED_KEYS_SHA256  /run/secrets/authorized_keys" | sha256sum -c - \
    && install -m 0644 /run/secrets/authorized_keys /etc/ssh/authorized_keys/deploy

COPY nginx.conf.template sshd_config.template /etc/everweb/
COPY supervisord.conf /etc/supervisor/everweb.conf
COPY html/ /opt/everweb/html/
COPY --chmod=0755 start.sh /usr/local/bin/everweb-start

ARG VCS_REF
ARG IMAGE_VERSION
ARG IMAGE_REPOSITORY=wietsewind/evernode-ssh-nginx
LABEL org.opencontainers.image.title="evernode-ssh-nginx" \
    org.opencontainers.image.description="Ubuntu nginx on /http and key-only SSH with container sudo" \
    org.opencontainers.image.source="https://github.com/WietseWind/ever-dockers" \
    org.opencontainers.image.url="https://hub.docker.com/r/$IMAGE_REPOSITORY" \
    org.opencontainers.image.revision="$VCS_REF" \
    org.opencontainers.image.version="$IMAGE_VERSION" \
    io.ever-dockers.authorized-keys-sha256="$AUTHORIZED_KEYS_SHA256"

EXPOSE 8080 2222
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/local/bin/everweb-start"]
