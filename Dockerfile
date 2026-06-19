FROM odoo:19.0

USER root

# ── Dev tools: system packages ─────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git && \
    rm -rf /var/lib/apt/lists/*

# ── Dev tools: pip ─────────────────────────────────────────────────
COPY ./config/requirements.txt /tmp/
RUN pip3 install --break-system-packages --no-cache-dir --ignore-installed \
        ipdb pytest pytest-cov pytest-odoo coverage debugpy ipython ruff && \
    pip3 install --break-system-packages --no-cache-dir --ignore-installed \
        -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# ── Our configs (override official) ─────────────────────────────────
COPY ./config/odoo.conf /etc/odoo/odoo.conf
COPY ./config/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    mkdir -p /workspace/extra-addons && \
    chown -R odoo:odoo /workspace

USER odoo
WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
