#!/bin/bash
set -e

# ── 1. Fix volume ownership (survives between docker compose down/up) ──────────
chown -R odoo:odoo /var/lib/odoo
chown -R odoo:odoo /workspace

# ── 2. Wait for PostgreSQL ────────────────────────────────────────────────────
wait-for-it "${DB_HOST:-db}:${DB_PORT:-5432}" --timeout=120

# ── 3. Auto-initialize / install modules ──────────────────────────────────────
DB="${ODOO_DB:-odoo-${ODOO_VERSION:-19.0}}"
EXTRA=$(ls -A /workspace/extra-addons/ 2>/dev/null | paste -sd, -)

# Check if the database has been initialized (ir_module_module table present)
DB_READY=$(gosu odoo psql \
    "postgresql://${POSTGRES_USER:-odoo}:${POSTGRES_PASSWORD:-odoo}@${DB_HOST:-db}:${DB_PORT:-5432}/$DB" \
    -tAc "SELECT 1 FROM information_schema.tables \
          WHERE table_name='ir_module_module'" 2>/dev/null || true)

# Build full module list: always base+web, plus DEFAULT_MODULES from .env, plus workspace extras
ALL_MODULES="base,web"
[ -n "${DEFAULT_MODULES}" ] && ALL_MODULES="${ALL_MODULES},${DEFAULT_MODULES}"
[ -n "${EXTRA}" ]           && ALL_MODULES="${ALL_MODULES},${EXTRA}"

if [ "$DB_READY" != "1" ]; then
    echo ">>> Initializing database '$DB' with modules: $ALL_MODULES"
    gosu odoo odoo-bin -i "$ALL_MODULES" --database "$DB" --stop-after-init
elif [ -n "${DEFAULT_MODULES}${EXTRA}" ]; then
    INSTALL="${DEFAULT_MODULES:+${DEFAULT_MODULES}}${DEFAULT_MODULES:+${EXTRA:+,}}${EXTRA}"
    echo ">>> Installing modules in '$DB': $INSTALL"
    gosu odoo odoo-bin -i "$INSTALL" --database "$DB" --stop-after-init
fi

# ── 4. Hand off to the requested command as the odoo user ─────────────────────
exec gosu odoo "$@"
