FROM almalinux/10-base

# Build arguments
ARG PIP_INDEX_URL
ARG PYTHON=python3.12
ARG NODE_VERSION=22
ARG PAPERCLIP_REPO=https://github.com/paperclipai/paperclip.git
ARG PAPERCLIP_BRANCH=master
ARG HERMES_REPO=https://github.com/NousResearch/hermes-agent.git
ARG HERMES_BRANCH=main

ENV PIP_INDEX_URL=${PIP_INDEX_URL}
ENV PYTHON=${PYTHON}
ENV NODE_VERSION=${NODE_VERSION}

# Base OS packages
RUN dnf -y upgrade && \
    dnf -y install epel-release && \
    dnf -y install \
        supervisor \
        git \
        gcc \
        gcc-c++ \
        make \
        zip \
        unzip \
        tar \
        wget \
        curl \
        shadow-utils \
        openssl-devel \
        bzip2-devel \
        libffi-devel \
        libxml2-devel \
        libxslt-devel \
        python3 \
        python3-pip \
        python3-devel \
        ripgrep && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Create paperclip user (uid/gid 1000) with /paperclip as home.
# -M: don't create the home dir now (it will be a bind-mounted volume at runtime).
RUN groupadd -g 1000 paperclip && \
    useradd -u 1000 -g 1000 -d /paperclip -s /bin/bash -M paperclip

# Install Node.js
RUN curl -fsSL https://rpm.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    dnf -y install nodejs && \
    dnf clean all

# Install pnpm and global AI coding tools into a system-wide location
# so the paperclip user can read/execute them (root's home is 0550).
ENV PNPM_HOME="/usr/local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN npm install -g pnpm@latest && \
    mkdir -p $PNPM_HOME && \
    pnpm add -g @anthropic-ai/claude-code@latest && \
    pnpm add -g @openai/codex@latest && \
    pnpm add -g opencode-ai@latest && \
    chmod -R a+rX $PNPM_HOME

# Clone and build Paperclip
WORKDIR /app
RUN git clone --depth 1 --branch ${PAPERCLIP_BRANCH} ${PAPERCLIP_REPO} /app && \
    pnpm install --frozen-lockfile && \
    pnpm --filter @paperclipai/ui build && \
    pnpm --filter @paperclipai/plugin-sdk build && \
    pnpm --filter @paperclipai/server build && \
    test -f server/dist/index.js || (echo "ERROR: server build output missing" && exit 1) && \
    chown -R paperclip:paperclip /app

# Python virtual environment
COPY requirements.txt /tmp/requirements.txt
RUN $PYTHON -m venv /var/$PYTHON/paperclip/env && \
    source /var/$PYTHON/paperclip/env/bin/activate && \
    pip install --upgrade pip -i "$PIP_INDEX_URL" && \
    pip install -r /tmp/requirements.txt -i "$PIP_INDEX_URL" && \
    chmod -R a+rX /var/$PYTHON/paperclip

# Install Hermes Agent (NousResearch) via pip
# HERMES_SRC is the source checkout — NOT HERMES_HOME, which hermes uses as its config dir.
RUN git clone --recurse-submodules --branch ${HERMES_BRANCH} ${HERMES_REPO} /opt/hermes-agent && \
    $PYTHON -m venv /var/$PYTHON/hermes/env && \
    source /var/$PYTHON/hermes/env/bin/activate && \
    pip install --upgrade pip -i "$PIP_INDEX_URL" && \
    pip install -e "/opt/hermes-agent[all]" -i "$PIP_INDEX_URL" && \
    cd /opt/hermes-agent && npm install && \
    ln -sf /var/$PYTHON/hermes/env/bin/hermes /usr/local/bin/hermes && \
    chown -R paperclip:paperclip /opt/hermes-agent && \
    chmod -R a+rX /var/$PYTHON/hermes

# Supervisor config for Paperclip
ADD paperclip.ini /etc/supervisord.d/paperclip.ini
RUN chmod 755 /etc/supervisord.d/paperclip.ini

# Entrypoint: chowns the bind-mounted /paperclip to the paperclip user
# at runtime, then execs supervisord (still as root, which then drops
# privileges via the user= directive in paperclip.ini).
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# Paperclip data directory (placeholder; overlaid by host bind mount at runtime)
RUN mkdir -p /paperclip && chown paperclip:paperclip /paperclip

ENV NODE_ENV=production \
    HOME=/paperclip \
    HOST=0.0.0.0 \
    PORT=3100 \
    SERVE_UI=true \
    PAPERCLIP_HOME=/paperclip \
    PAPERCLIP_INSTANCE_ID=default \
    PAPERCLIP_CONFIG=/paperclip/instances/default/config.json \
    PAPERCLIP_DEPLOYMENT_MODE=local_trusted \
    PAPERCLIP_DEPLOYMENT_EXPOSURE=private \
    OPENCODE_ALLOW_ALL_MODELS=true

VOLUME ["/paperclip"]
EXPOSE 3100
WORKDIR /app

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["supervisord", "-n"]
