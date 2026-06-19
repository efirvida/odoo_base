#!/bin/bash

# ── 1. Export DB env vars in Odoo-native format (PGHOST, etc.) ─────
export PGHOST="${DB_HOST:-${PGHOST:-db}}"
export PGPORT="${DB_PORT:-${PGPORT:-5432}}"
export PGUSER="${DB_USER:-${POSTGRES_USER:-${PGUSER:-odoo}}}"
export PGPASSWORD="${DB_PASSWORD:-${POSTGRES_PASSWORD:-${PGPASSWORD:-odoo}}}"

# ── 2. Resolve Odoo database name ─────────────────────────────────
DB="${ODOO_DB:-odoo-${ODOO_VERSION:-19.0}}"

# ── 3. Ensure critical directories exist ──────────────────────────
mkdir -p /mnt/extra-addons

# ── 4. Wait for PostgreSQL ────────────────────────────────────────
echo ">>> Waiting for PostgreSQL at ${PGHOST}:${PGPORT} ..."
until pg_isready -t 5 > /dev/null 2>&1; do
    sleep 2
done
echo ">>> PostgreSQL is ready"

# ── 5. Auto-initialize / install modules (best-effort) ────────────
EXTRA=$(ls -A /mnt/extra-addons/ 2>/dev/null | paste -sd, -)

DB_READY=$(psql -d "$DB" -tAc \
    "SELECT 1 FROM information_schema.tables WHERE table_name='ir_module_module'" \
    2>/dev/null || true)

ALL_MODULES="base,web"
[ -n "${DEFAULT_MODULES}" ] && ALL_MODULES="${ALL_MODULES},${DEFAULT_MODULES}"
[ -n "${EXTRA}" ]           && ALL_MODULES="${ALL_MODULES},${EXTRA}"

if [ "$DB_READY" != "1" ]; then
    echo ">>> Initializing database '$DB' with modules: $ALL_MODULES"
    odoo -i "$ALL_MODULES" --database "$DB" --stop-after-init \
        || echo ">>> WARNING: DB init failed — check postgres credentials"
elif [ -n "${DEFAULT_MODULES}${EXTRA}" ]; then
    INSTALL="${DEFAULT_MODULES:+${DEFAULT_MODULES}}${DEFAULT_MODULES:+${EXTRA:+,}}${EXTRA}"
    echo ">>> Installing modules in '$DB': $INSTALL"
    odoo -i "$INSTALL" --database "$DB" --stop-after-init \
        || echo ">>> WARNING: Module install failed"
fi

# ── 6. Execute the requested command ──────────────────────────────
exec "$@"
