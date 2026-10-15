-- EJEMPLO ILUSTRATIVO, datos ficticios. Versión reducida del esquema real.
-- Problema: el modelo de visión se equivoca con total seguridad. Si su lectura
-- entra directo a la tabla de precios, la base parece confiable y está mal.
-- Solución: dos tablas. `capturas` guarda TODO lo que llega (la evidencia);
-- `observaciones` solo lo confirmado por una persona. Lo exige la base, no el bot.

CREATE TABLE productos (id int PRIMARY KEY, descripcion text NOT NULL UNIQUE);
CREATE TABLE capturas (
    id               int   PRIMARY KEY,
    archivo_foto     text  NOT NULL,        -- para auditar cualquier fila contra su origen
    extraccion_cruda jsonb NOT NULL,        -- lo que dijo el modelo, completo
    precio_leido     numeric(12,2),         -- lo que leyó, SIN validar; no se pisa nunca
    precio_corregido numeric(12,2),         -- lo que dijo la persona, si corrigió
    producto_id      int REFERENCES productos(id),
    estado text NOT NULL DEFAULT 'esperando_confirmacion'
        CHECK (estado IN ('esperando_confirmacion', 'confirmada', 'descartada', 'sin_match')),
    CONSTRAINT confirmada_completa CHECK (estado <> 'confirmada'
        OR (producto_id IS NOT NULL AND coalesce(precio_corregido, precio_leido) IS NOT NULL))
);
CREATE TABLE observaciones (
    id             int PRIMARY KEY,
    captura_id     int NOT NULL UNIQUE REFERENCES capturas(id),  -- una foto, un precio
    producto_id    int NOT NULL REFERENCES productos(id),        -- solo catálogo cerrado
    precio         numeric(12,2) NOT NULL CHECK (precio > 0),
    confirmado_por text NOT NULL                                 -- siempre una persona
);
INSERT INTO productos VALUES (1, 'producto ficticio A');

-- El modelo no reconoció el producto y leyó "$12.900" como 12.90. La evidencia entra igual.
INSERT INTO capturas (id, archivo_foto, extraccion_cruda, precio_leido)
VALUES (1, 'foto-001', '{"descripcion_cartel": "PROD X", "precio": 12.90, "confianza": "media"}', 12.90);

-- Esperado: ERROR, viola "confirmada_completa" (falta el producto).
UPDATE capturas SET estado = 'confirmada' WHERE id = 1;
-- Esperado: ERROR, viola la FK (el producto 99 no existe en el catálogo).
INSERT INTO observaciones VALUES (1, 1, 99, 12900, 'operador-1');

-- La persona elige el producto y corrige el precio. Ahora sí entra.
UPDATE capturas SET producto_id = 1, precio_corregido = 12900, estado = 'confirmada' WHERE id = 1;
INSERT INTO observaciones VALUES (1, 1, 1, 12900, 'operador-1');
-- Esperado: leyo_el_modelo 12.90 | registrado 12900.00 (la evidencia del error queda guardada).
SELECT c.precio_leido AS leyo_el_modelo, o.precio AS registrado FROM observaciones o JOIN capturas c ON c.id = o.captura_id;
