#!/bin/sh
# Sashimono may append "run /contract". This standalone image starts its own services.
set -eu

# Configure application ports independently of host metadata. Some EverPanel installers
# advertise INTERNAL_GPTCP2_PORT as GPTCP1 + 1 even when gptcp2 maps somewhere else.
HTTP_PORT=${HTTP_PORT:-8080}
SSH_PORT=${SSH_PORT:-2222}
for port in "$HTTP_PORT" "$SSH_PORT"; do
    case "$port" in ''|*[!0-9]*) echo "Invalid listen port: $port" >&2; exit 1 ;; esac
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Listen port must be 1–65535" >&2; exit 1
    fi
done
if [ "$HTTP_PORT" = "$SSH_PORT" ]; then
    echo 'HTTP and SSH need different listen ports' >&2; exit 1
fi
export HTTP_PORT SSH_PORT

# /contract is the host-mounted instance directory; keep app files outside HotPocket's state mount.
install -d -m 0755 /contract/everweb /run/sshd
# Keep the convenient /http path backed by the host-mounted contract directory.
# If an older volume is reused, copy its site once without changing the original.
if [ ! -e /contract/http ] && [ -d /contract/everweb/www ]; then
    cp -a /contract/everweb/www /contract/http
fi
install -d -o deploy -g deploy -m 0755 /contract/http
install -d -m 0700 /contract/everweb/ssh
if [ ! -f /http/index.html ]; then
    cp /opt/everweb/html/index.html /http/index.html
    chown deploy:deploy /http/index.html
fi
if [ ! -f /contract/everweb/ssh/ssh_host_ed25519_key ]; then
    ssh-keygen -q -t ed25519 -N '' -f /contract/everweb/ssh/ssh_host_ed25519_key
fi
envsubst '${HTTP_PORT}' < /etc/everweb/nginx.conf.template > /etc/nginx/nginx.conf
envsubst '${SSH_PORT}' < /etc/everweb/sshd_config.template > /etc/ssh/sshd_config
nginx -t
/usr/sbin/sshd -t
echo "Evernode services: HTTP=$HTTP_PORT root=/http SSH=$SSH_PORT user=deploy (sudo enabled)"
ssh-keygen -lf /contract/everweb/ssh/ssh_host_ed25519_key.pub
exec /usr/bin/supervisord -n -c /etc/supervisor/everweb.conf
