#!/bin/bash
set -e;


if [ -n "${POSTGRES_USER:-}" ] && [ -n "${POSTGRES_PASSWORD:-}" ]; then
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		ALTER USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
		-- Ensure database exists (usually created by POSTGRES_DB)
		GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};
		GRANT CREATE ON SCHEMA public TO ${POSTGRES_USER};
	EOSQL
else
	echo "SETUP INFO: No Environment variables given!"
fi