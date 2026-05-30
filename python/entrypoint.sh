#!/bin/bash
set -e

# /paperclip is a host bind mount — fix ownership at runtime so the
# paperclip user (uid 1000) can write to it.
if [ -d /paperclip ]; then
    chown paperclip:paperclip /paperclip 2>/dev/null || true
    find /paperclip -maxdepth 1 -mindepth 1 -exec chown -R paperclip:paperclip {} + 2>/dev/null || true
fi

# Supervisor log dir lives under the bind-mounted /var/www
mkdir -p /var/www/logs
chown -R paperclip:paperclip /var/www/logs 2>/dev/null || true

# Set up bash profile for paperclip user.
if [ ! -f /paperclip/.bashrc ]; then
    cat > /paperclip/.bashrc << 'BASHRC'
[ -f /etc/bashrc ] && . /etc/bashrc

export PATH="/usr/local/share/pnpm:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias activate-paperclip='source /var/python3.12/paperclip/env/bin/activate'

PS1='[\u@\h \W]\$ '
BASHRC
    chown paperclip:paperclip /paperclip/.bashrc
fi

if [ ! -f /paperclip/.bash_profile ]; then
    cat > /paperclip/.bash_profile << 'PROFILE'
[ -f ~/.bashrc ] && . ~/.bashrc
PROFILE
    chown paperclip:paperclip /paperclip/.bash_profile
fi

exec "$@"
