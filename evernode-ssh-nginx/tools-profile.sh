# nvm is a shell function, loaded for login, interactive and SSH-command Bash shells.
# The bundled Node 24 is shared and root-owned; additional nvm installs are per-user.
if [ -n "${BASH_VERSION:-}" ] && [ -s "$HOME/.nvm/nvm.sh" ]; then
    export NVM_DIR="$HOME/.nvm"
    . "$NVM_DIR/nvm.sh"
fi
