-- Gate L3 — FK/PK integrity (information_schema)
-- Ejecutar contra el stack local:  supabase db ... | psql "$DATABASE_URL" -f fk-audit.sql
-- Reporta violaciones C12-C16. Exit != 0 si hay filas.

-- C13: FK target table/column existe
SELECT 'C13' AS check_id,
       tc.table_schema || '.' || tc.table_name AS fk_table,
       kcu.column_name AS fk_column,
       ccu.table_schema || '.' || ccu.table_name AS ref_table,
       ccu.column_name AS ref_column,
       'FK referencia tabla/columna inexistente' AS problem
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.constraint_schema = kcu.constraint_schema
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
 AND tc.constraint_schema = ccu.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns c
    WHERE c.table_schema = ccu.table_schema
      AND c.table_name = ccu.table_name
      AND c.column_name = ccu.column_name
  );

-- C12: FK column type == PK type (catches Postgres 42804)
SELECT 'C12' AS check_id,
       tc.table_schema || '.' || tc.table_name AS fk_table,
       kcu.column_name AS fk_column,
       fk_col.data_type AS fk_type,
       ccu.table_schema || '.' || ccu.table_name AS pk_table,
       ccu.column_name AS pk_column,
       pk_col.data_type AS pk_type,
       'FK/PK type mismatch - runtime error 42804' AS problem
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.constraint_schema = kcu.constraint_schema
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
 AND tc.constraint_schema = ccu.constraint_schema
JOIN information_schema.columns fk_col
  ON fk_col.table_schema = tc.table_schema
 AND fk_col.table_name = tc.table_name
 AND fk_col.column_name = kcu.column_name
JOIN information_schema.columns pk_col
  ON pk_col.table_schema = ccu.table_schema
 AND pk_col.table_name = ccu.table_name
 AND pk_col.column_name = ccu.column_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND fk_col.data_type <> pk_col.data_type;

-- C16: PKs son unique/identity (insert retorna la row)
SELECT 'C16' AS check_id,
       tc.table_schema || '.' || tc.table_name AS table_name,
       kcu.column_name AS pk_column,
       'PK sin constraint UNIQUE/PRIMARY KEY real' AS problem
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.constraint_schema = kcu.constraint_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND NOT EXISTS (
    SELECT 1
    FROM information_schema.table_constraints tc2
    WHERE tc2.table_schema = tc.table_schema
      AND tc2.table_name = tc.table_name
      AND tc2.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
  );

-- C15: ON DELETE semantics — lista todas las FKs para revision humana
SELECT 'C15' AS check_id,
       tc.table_name AS fk_table,
       kcu.column_name AS fk_column,
       ccu.table_name AS ref_table,
       rc.delete_rule AS on_delete,
       'revisar: cascade/restrict/set-null segun expectativa de la app' AS problem
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.constraint_schema = kcu.constraint_schema
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
 AND tc.constraint_schema = ccu.constraint_schema
JOIN information_schema.referential_constraints rc
  ON rc.constraint_name = tc.constraint_name
 AND rc.constraint_schema = tc.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name;
