#!/usr/bin/env bash
# Usage : PGHOST=/tmp/pg PGPORT=5433 ./supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB=ballal_test
psql -U postgres -qc "drop database if exists $DB" -c "create database $DB"
P="psql -U postgres -d $DB -v ON_ERROR_STOP=1 -q -o /dev/null"
$P -f tests/00_supabase_stub.sql
for f in migrations/*.sql; do echo "→ $f"; $P -f "$f"; done
$P -f seed.sql
echo "→ tests"
$P -f tests/10_rls_and_api.sql
echo "→ test d'intrusion"
psql -U postgres -d $DB -v ON_ERROR_STOP=1 -q -f tests/20_pentest.sql
