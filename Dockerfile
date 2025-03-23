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
            libldap2-dev \
            libsasl2-dev \
            libev-dev \
            libssl-dev \
            nodejs \
            npm \
            linux-headers-virtual \
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
        echo "Using Python 3.11 for Odoo ${ODOO_VERSION}"; \
        apt-get update && \
        apt-get install -y software-properties-common && \
        add-apt-repository -y ppa:deadsnakes/ppa && \
        apt-get update && \
        apt-get install -y python3.11 python3.11-dev python3.11-venv && \
        python3.11 -m ensurepip --upgrade && \
        update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
        update-alternatives --install /usr/bin/pip3 pip3 /usr/local/bin/pip3.11 1 && \
        update-alternatives --set python3 /usr/bin/python3.11 && \
        update-alternatives --set pip3 /usr/local/bin/pip3.11 && \
        curl -sSL "https://raw.githubusercontent.com/odoo/odoo/refs/heads/${ODOO_VERSION}/requirements.txt" -o /tmp/odoo_${ODOO_VERSION}_requirements.txt && \
        pip3 install --no-cache-dir --upgrade --ignore-installed -r /tmp/odoo_${ODOO_VERSION}_requirements.txt && \
        rm /tmp/odoo_${ODOO_VERSION}_requirements.txt && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        echo "Using system default Python for Odoo ${ODOO_VERSION}"; \
    fi
    
# Install Odoo from local .deb
COPY odoo_*.deb /tmp/

RUN if [ -f "/tmp/odoo_${ODOO_VERSION}.deb" ]; then \
        echo "Using local odoo_${ODOO_VERSION}.deb package"; \
    else \
        echo "Getting Odoo ${ODOO_VERSION} from odoo servers"; \
        curl -sSL http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb/odoo_${ODOO_VERSION}.latest_all.deb -o /tmp/odoo_${ODOO_VERSION}.deb; \
    fi && \
    apt-get update && \
    dpkg -i /tmp/odoo_${ODOO_VERSION}.deb || apt-get install -f -y && \
    dpkg -i /tmp/odoo_${ODOO_VERSION}.deb && \
    rm -rf /tmp/odoo_${ODOO_VERSION}.deb /var/lib/apt/lists/*

# Install Python dependencies
COPY ./config/requirements.txt /tmp/

RUN pip3 install --upgrade --no-cache-dir pip setuptools==65.5.0 \
    && pip3 install --no-cache-dir xlwt num2words ipdb pytest pytest-cov pytest-odoo coverage debugpy ipython ruff \
    && pip3 install --no-cache-dir -r /tmp/requirements.txt \
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