#!/bin/bash
set -e

# /paperclip is a host bind mount — fix ownership at runtime so the
# paperclip user (uid 1000) can write to it.
if [ -d /paperclip ]; then
    chown paperclip:paperclip /paperclip 2>/dev/null || true
    # Only descend into subdirs that exist to keep first-start cheap.
    find /paperclip -maxdepth 1 -mindepth 1 -exec chown -R paperclip:paperclip {} + 2>/dev/null || true
fi

# Supervisor log dir lives under the bind-mounted /var/www
mkdir -p /var/www/logs
chown -R paperclip:paperclip /var/www/logs 2>/dev/null || true

# Set up bash profile for paperclip user (same as root's shell experience).
# Only written once; user edits persist via the /paperclip bind mount.
if [ ! -f /paperclip/.bashrc ]; then
    cat > /paperclip/.bashrc << 'BASHRC'
# .bashrc for paperclip user
[ -f /etc/bashrc ] && . /etc/bashrc

export PATH="/usr/local/share/pnpm:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Python venvs
alias activate-paperclip='source /var/python3.12/paperclip/env/bin/activate'
alias activate-hermes='source /var/python3.12/hermes/env/bin/activate'

PS1='[\u@\h \W]\$ '
BASHRC
    chown paperclip:paperclip /paperclip/.bashrc
fi

if [ ! -f /paperclip/.bash_profile ]; then
    cat > /paperclip/.bash_profile << 'PROFILE'
# .bash_profile for paperclip user
[ -f ~/.bashrc ] && . ~/.bashrc
PROFILE
    chown paperclip:paperclip /paperclip/.bash_profile
fi

# Initialize Hermes config directory on first start.
# HOME=/paperclip, so ~/.hermes = /paperclip/.hermes (persisted via bind mount).
HERMES_DIR="/paperclip/.hermes"
if [ ! -d "$HERMES_DIR/sessions" ]; then
    mkdir -p "$HERMES_DIR"/{cron,sessions,logs,memories,skills,pairing,hooks,image_cache,audio_cache,whatsapp/session}

    # Copy example config if the source repo has one and user hasn't configured yet
    if [ ! -f "$HERMES_DIR/config.yaml" ] && [ -f /opt/hermes-agent/cli-config.yaml.example ]; then
        cp /opt/hermes-agent/cli-config.yaml.example "$HERMES_DIR/config.yaml"
    fi

    # Create .env for API keys if not present
    if [ ! -f "$HERMES_DIR/.env" ]; then
        touch "$HERMES_DIR/.env"
    fi

    chown -R paperclip:paperclip "$HERMES_DIR"
fi

# Sync OLLAMA_API_KEY from container env into hermes .env (on every start,
# so it stays current if the key changes in docker-compose).
if [ -n "$OLLAMA_API_KEY" ]; then
    if grep -q '^OLLAMA_API_KEY=' "$HERMES_DIR/.env" 2>/dev/null; then
        sed -i "s|^OLLAMA_API_KEY=.*|OLLAMA_API_KEY=${OLLAMA_API_KEY}|" "$HERMES_DIR/.env"
    else
        echo "OLLAMA_API_KEY=${OLLAMA_API_KEY}" >> "$HERMES_DIR/.env"
    fi
    chown paperclip:paperclip "$HERMES_DIR/.env"
fi

exec "$@"
