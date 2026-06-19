#!/bin/bash
set -e

# ── 1. Resolve DB connection params from env vars ──────────────────
#    Priority: PGHOST/PGPORT/PGUSER/PGPASSWORD > DB_HOST/DB_PORT/DB_USER/DB_PASSWORD > defaults
: "${DB_HOST:=${PGHOST:=db}}"
: "${DB_PORT:=${PGPORT:=5432}}"
: "${DB_USER:=${PGUSER:=odoo}}"
: "${DB_PASSWORD:=${PGPASSWORD:=odoo}}"

# ── 2. Resolve Odoo database name ─────────────────────────────────
DB="${ODOO_DB:-odoo-${ODOO_VERSION:-19.0}}"

# ── 3. Wait for PostgreSQL ────────────────────────────────────────
echo ">>> Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT} ..."
until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -t 5 > /dev/null 2>&1; do
    sleep 2
done
echo ">>> PostgreSQL is ready"

# ── 4. Auto-initialize / install modules ──────────────────────────
EXTRA=$(ls -A /mnt/extra-addons/ 2>/dev/null | paste -sd, -)

# Check if the database has been initialized
DB_READY=$(psql \
    "postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB}" \
    -tAc "SELECT 1 FROM information_schema.tables \
          WHERE table_name='ir_module_module'" 2>/dev/null || true)

# Build module list: always base+web, plus DEFAULT_MODULES from env, plus workspace extras
ALL_MODULES="base,web"
[ -n "${DEFAULT_MODULES}" ] && ALL_MODULES="${ALL_MODULES},${DEFAULT_MODULES}"
[ -n "${EXTRA}" ]           && ALL_MODULES="${ALL_MODULES},${EXTRA}"

if [ "$DB_READY" != "1" ]; then
    echo ">>> Initializing database '$DB' with modules: $ALL_MODULES"
    odoo -i "$ALL_MODULES" \
        --database "$DB" \
        --db_host "$DB_HOST" \
        --db_port "$DB_PORT" \
        --db_user "$DB_USER" \
        --db_password "$DB_PASSWORD" \
        --stop-after-init
elif [ -n "${DEFAULT_MODULES}${EXTRA}" ]; then
    INSTALL="${DEFAULT_MODULES:+${DEFAULT_MODULES}}${DEFAULT_MODULES:+${EXTRA:+,}}${EXTRA}"
    echo ">>> Installing modules in '$DB': $INSTALL"
    odoo -i "$INSTALL" \
        --database "$DB" \
        --db_host "$DB_HOST" \
        --db_port "$DB_PORT" \
        --db_user "$DB_USER" \
        --db_password "$DB_PASSWORD" \
        --stop-after-init
fi

# ── 5. Build DB args for Odoo CLI (only if not already in odoo.conf) ──
#    This mirrors the official entrypoint pattern: pass DB params
#    as CLI args only when they are NOT set in odoo.conf
DB_ARGS=()
if ! grep -qE "^\s*db_host\s*=" "$ODOO_RC" 2>/dev/null; then
    DB_ARGS+=(--db_host "$DB_HOST")
fi
if ! grep -qE "^\s*db_port\s*=" "$ODOO_RC" 2>/dev/null; then
    DB_ARGS+=(--db_port "$DB_PORT")
fi
if ! grep -qE "^\s*db_user\s*=" "$ODOO_RC" 2>/dev/null; then
    DB_ARGS+=(--db_user "$DB_USER")
fi
if ! grep -qE "^\s*db_password\s*=" "$ODOO_RC" 2>/dev/null; then
    DB_ARGS+=(--db_password "$DB_PASSWORD")
fi

exec "$@" "${DB_ARGS[@]}"
