-- EJEMPLO ILUSTRATIVO Y SIMPLIFICADO. Nombres genéricos, sin datos reales.
-- Muestra la forma del modelo de datos, no el esquema del cliente.

CREATE EXTENSION IF NOT EXISTS vector;

-- Quién escribe. El tipo lo fija la base (no el LLM) y decide a qué subagente va.
CREATE TABLE contactos (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  telefono         text UNIQUE NOT NULL,
  tipo             text NOT NULL DEFAULT 'lead'
                   CHECK (tipo IN ('lead', 'inquilino', 'propietario')),
  modo             text NOT NULL DEFAULT 'descubrimiento',  -- o 'agendamiento'
  modo_desde       timestamptz,          -- para que el modo venza (TTL)
  crm_id           bigint,               -- NULL hasta que se envía al CRM
  ultimos_horarios jsonb,                -- mapa número -> id, ver ejemplo 03
  horarios_en      timestamptz           -- frescura de ese mapa
);

-- Espejo del inventario del CRM, con embedding para búsqueda semántica.
CREATE TABLE inmuebles (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  crm_id      bigint UNIQUE NOT NULL,
  estado      text NOT NULL,             -- disponible / arrendado / inactivo
  barrio      text,
  canon       numeric,
  descripcion text,
  embedding   vector(1536)
);

-- Espejo local de los clientes del CRM: permite deduplicar sin llamar a la API.
CREATE TABLE crm_clientes (
  crm_id        bigint PRIMARY KEY,
  telefono_norm text NOT NULL            -- últimos 10 dígitos
);

-- Bitácora append-only: base de las métricas y de la depuración.
CREATE TABLE eventos (
  id        bigserial PRIMARY KEY,
  contacto  uuid REFERENCES contactos(id),
  tipo      text NOT NULL,               -- p. ej. 'tool_invocada', 'handoff'
  payload   jsonb,
  creado_en timestamptz NOT NULL DEFAULT now()
);

-- Deduplicación antes de crear un lead en el CRM:
-- se compara el teléfono normalizado contra el espejo local.
-- Si devuelve una fila, se enlaza; si no, se crea en el CRM y se espeja.
SELECT crm_id
FROM crm_clientes
WHERE telefono_norm = right(regexp_replace($1, '[^0-9]', '', 'g'), 10)
  AND telefono_norm <> ''
LIMIT 1;

-- Búsqueda semántica: el barrio filtra; la similitud solo ordena.
SELECT id, barrio, canon, 1 - (embedding <=> $2) AS similitud
FROM inmuebles
WHERE estado = 'disponible'
  AND ($3::text IS NULL OR barrio ILIKE '%' || $3 || '%')
ORDER BY embedding <=> $2
LIMIT 3;
