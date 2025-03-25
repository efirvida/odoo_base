FROM ubuntu:jammy

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Set environment for UTF-8 and non-interactive installs
ARG ODOO_VERSION=16.0 \
    USER_ID=1000 \
    GROUP_ID=1000

ENV LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HOME=/home/odoo \
    ODOO_RC=/etc/odoo/odoo.conf

# Create odoo user with host-matching UID/GID for volume permissions
RUN addgroup --gid ${GROUP_ID} odoo \
    && useradd -m -d ${HOME} --uid ${USER_ID} --gid ${GROUP_ID} --shell /bin/bash odoo \
    && mkdir -p ${HOME} && chown odoo:odoo ${HOME} \
    && mkdir -p /workspace \
    && chown -R odoo:odoo /workspace \
    && mkdir -p /var/lib/odoo \
    && chown -R odoo:odoo /var/lib/odoo

# Install system dependencies and wkhtmltopdf
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
            build-essential \
            curl \
            git \
            gnupg \
            libev-dev \
            libldap2-dev \
            libpq-dev \
            libsasl2-dev \
            libssl-dev \
            linux-headers-virtual \
            nodejs \
            npm \
            python-dev-is-python3 \
            python-is-python3 \
            python3-dev \
            python3-pip \
        && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb \
        && dpkg -i ./wkhtmltox.deb || true \
        && apt-get install -f -y \
        && dpkg -i ./wkhtmltox.deb \
        && rm -rf /var/lib/apt/lists/* wkhtmltox.deb \
        && rm -rf /tmp/wkhtmltox.deb /var/lib/apt/lists/*
    
# Install PostgreSQL client for 
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client libpq-dev \
    && rm -rf "$GNUPGHOME" /etc/apt/sources.list.d/pgdg.list /var/lib/apt/lists/*

# Setup Python
RUN MAJOR_VERSION=$(echo "${ODOO_VERSION}" | cut -d. -f1) && \
    if [ "${MAJOR_VERSION}" -ge 17 ]; then \
        echo "Installing Python 3.12 for Odoo ${ODOO_VERSION}"; \
        apt-get update && \
        apt-get install -y software-properties-common && \
        add-apt-repository -y ppa:deadsnakes/ppa && \
        apt-get update && \
        apt-get install -y python3.12 python3.12-dev python3.12-venv && \
        python3.12 -m ensurepip --upgrade && \
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 2 && \
        update-alternatives --install /usr/bin/pip3 pip3 /usr/local/bin/pip3.12 2; \
    elif [ "${MAJOR_VERSION}" -le 14 ]; then \
        echo "Installing Python 3.8 for Odoo ${ODOO_VERSION}"; \
        apt-get update && \
        apt-get install -y software-properties-common && \
        add-apt-repository -y ppa:deadsnakes/ppa && \
        apt-get update && \
        apt-get install -y python3.8 python3.8-dev python3.8-venv && \
        python3.8 -m ensurepip --upgrade && \
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 1 && \
        update-alternatives --install /usr/bin/pip3 pip3 /usr/local/bin/pip3.8 1; \
    fi && \
    rm -rf /var/lib/apt/lists/*

RUN MAJOR_VERSION=$(echo "${ODOO_VERSION}" | cut -d. -f1) && \
    if [ -f "/usr/lib/odoo_${ODOO_VERSION}.deb" ]; then \
        echo "Installing from local .deb package"; \
        apt-get update && apt-get install -y /usr/lib/odoo_${ODOO_VERSION}.deb; \
    else \
        echo "Cloning Odoo ${ODOO_VERSION} repository"; \
        git clone --depth 1 --branch ${ODOO_VERSION} https://github.com/odoo/odoo.git /usr/lib/odoo; \
        cd /usr/lib/odoo && \
        if [ "${MAJOR_VERSION}" -le 14 ]; then \
            echo "Installing dependencies for Odoo ${ODOO_VERSION}"; \
            if [ -f "debian/control" ]; then \
                pip3 --no-cache-dir install setuptools==57.5.0; \
                echo "Using official dependency detection method"; \
                sed -n -e '/^Depends:/,/^Pre/ s/ python3-\(.*\),/python3-\1/p' debian/control | xargs apt-get install -y || \
                { echo "Failed to install some dependencies via apt, trying pip fallback"; \
                sed -n -e '/^Depends:/,/^Pre/ s/ python3-\(.*\),/\1/p' debian/control | \
                while read dep; do \
                    case "$dep" in \
                    "pil") pip_pkg="Pillow" ;; \
                    "ldap") pip_pkg="python-ldap" ;; \
                    "dateutil") pip_pkg="python-dateutil" ;; \
                    "renderpm") pip_pkg="rl-renderPM rlPyCairo" ;; \
                    *) pip_pkg="$dep" ;; \
                    esac && \
                    pip3 install --no-cache-dir "$pip_pkg" || { echo "Failed to install $pip_pkg"; exit 1; }; \
                done; \
                }; \
            else \
                echo "ERROR: debian/control not found!"; \
                exit 1; \
            fi; \
        else \
            echo "Running debinstall.sh"; \
            if [ -f "./setup/debinstall.sh" ]; then \
                ./setup/debinstall.sh; \
            else \
                echo "ERROR: debinstall.sh not found!"; \
                exit 1; \
            fi; \
            pip3 install --no-cache-dir --upgrade pip setuptools; \
        fi; \
        pip3 install --no-cache-dir --upgrade lxml lxml_html_clean psycopg2-binary; \
        pip3 install . ; \
        mv odoo-bin /usr/bin/; \
        chmod +x /usr/bin/odoo-bin; \
        rm -rf /var/lib/apt/lists/*; \
    fi;

# Install Python dependencies
COPY ./config/requirements.txt /tmp/

RUN pip3 install --upgrade --no-cache-dir pip setuptools \
    && pip3 install --upgrade --no-cache-dir --ignore-installed reportlab fonttools ipdb pytest pytest-cov pytest-odoo coverage debugpy ipython ruff \
    && pip3 install --upgrade --no-cache-dir --ignore-installed -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# Configure Odoo
COPY ./config/odoo.conf /etc/odoo/
RUN chown odoo:odoo /etc/odoo/odoo.conf \
    && chmod 644 /etc/odoo/odoo.conf

# Install utilities
RUN curl -sSL https://github.com/vishnubob/wait-for-it/raw/master/wait-for-it.sh -o /usr/local/bin/wait-for-it \
    && chmod +x /usr/local/bin/wait-for-it \
    && npm install -g rtlcss \
    && npm cache clean --force

# Final setup
VOLUME ["/var/lib/odoo", "/workspace"]
EXPOSE 8069 8071 8072
WORKDIR /workspace
USER odoo
RUN mkdir -p /workspace/extra-addons

CMD ["/bin/bash"]