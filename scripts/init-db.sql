-- scripts/init-db.sql
-- Se ejecuta automáticamente al crear el container de Postgres local

-- Habilitar extensiones
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verificar que todo está listo
SELECT 'PostGIS version: ' || postgis_version() AS status;
SELECT 'UUID generation test: ' || uuid_generate_v4() AS status;
