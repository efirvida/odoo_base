FROM ubuntu:noble

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HOME=/home/odoo \
    ODOO_RC=/etc/odoo/odoo.conf \
    PATH="/home/odoo/.local/bin:${PATH}"

ARG ODOO_VERSION=19.0

# ── 1. System dependencies ───────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        git \
        gnupg \
        libldap2-dev \
        libpq-dev \
        libsasl2-dev \
        libssl-dev \
        node-less \
        npm \
        postgresql-client \
        python3-dev \
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-xlrd \
        python3-xlwt \
        python3-watchdog \
        xz-utils && \
    rm -rf /var/lib/apt/lists/*

# ── 2. Node tools ────────────────────────────────────────────────
RUN npm install -g rtlcss && npm cache clean --force

# ── 3. Create odoo user ──────────────────────────────────────────
ARG USER_ID=1000 GROUP_ID=1000
RUN groupadd --gid ${GROUP_ID} odoo && \
    useradd -m -d ${HOME} --uid ${USER_ID} --gid ${GROUP_ID} --shell /bin/bash odoo

# ── 4. Install Odoo from source ──────────────────────────────────
RUN git clone --depth 1 --branch ${ODOO_VERSION} \
        https://github.com/odoo/odoo.git /usr/lib/odoo && \
    pip3 install --break-system-packages --no-cache-dir \
        -r /usr/lib/odoo/requirements.txt && \
    pip3 install --break-system-packages --no-cache-dir -e /usr/lib/odoo && \
    # Work around PyPDF2 escape sequence warning (Python 3.12)
    pip3 install --break-system-packages --no-cache-dir --upgrade \
        lxml lxml_html_clean psycopg2-binary

# ── 5. Dev tools ─────────────────────────────────────────────────
COPY ./config/requirements.txt /tmp/
RUN pip3 install --break-system-packages --no-cache-dir --upgrade pip setuptools && \
    pip3 install --break-system-packages --no-cache-dir \
        ipdb pytest pytest-cov pytest-odoo coverage debugpy ipython ruff && \
    pip3 install --break-system-packages --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# ── 6. Odoo config ───────────────────────────────────────────────
COPY ./config/odoo.conf /etc/odoo/
RUN chown odoo:odoo /etc/odoo/odoo.conf && chmod 644 /etc/odoo/odoo.conf

# ── 7. Entrypoint ────────────────────────────────────────────────
COPY ./config/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── 8. Set up working directories ────────────────────────────────
RUN mkdir -p /mnt/extra-addons /workspace/extra-addons && \
    chown -R odoo:odoo /mnt/extra-addons /workspace /var/lib/odoo

VOLUME ["/var/lib/odoo", "/mnt/extra-addons", "/workspace"]
EXPOSE 8069 8071 8072
WORKDIR /workspace

USER odoo
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
