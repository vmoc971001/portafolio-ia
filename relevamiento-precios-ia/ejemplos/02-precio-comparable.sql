-- EJEMPLO ILUSTRATIVO, datos ficticios. Versión reducida del esquema real.
-- Problema: los carteles venden por 500 g, por libra o por kilo. Un precio sin
-- su cantidad no se puede comparar entre tiendas. Y si el precio por kilo lo
-- calcula el bot y después alguien corrige el precio, el kilo queda viejo.
-- Solución: el precio por kilo es una columna GENERADA. La calcula el motor y se
-- rehace sola al corregir. Corregir guarda el valor original; anular no borra.

CREATE TABLE observaciones (
    id              int PRIMARY KEY,
    precio_vigente  numeric(12,2) NOT NULL CHECK (precio_vigente > 0),
    precio_regular  numeric(12,2),                 -- el precio "antes" de una promoción
    cantidad_gramos numeric(10,2) NOT NULL CHECK (cantidad_gramos > 0),
    precio_vigente_original numeric(12,2),         -- se llena solo al corregir
    anulada_en      timestamptz,                   -- anular = marcar, nunca DELETE
    precio_vigente_por_kg numeric(12,2)
        GENERATED ALWAYS AS (round(precio_vigente / cantidad_gramos * 1000, 2)) STORED,
    CONSTRAINT promocion_mas_barata CHECK (precio_regular IS NULL OR precio_regular > precio_vigente),
    CONSTRAINT correccion_cambia_algo CHECK (precio_vigente_original IS NULL OR precio_vigente_original <> precio_vigente)
);

-- Cartel ficticio: $7.450 por 500 g, antes $8.900.
INSERT INTO observaciones (id, precio_vigente, precio_regular, cantidad_gramos) VALUES (1, 7450, 8900, 500);
-- Esperado: 14900.00
SELECT precio_vigente_por_kg FROM observaciones WHERE id = 1;

-- Se había tecleado mal: era $7.540. Nadie toca la columna por kilo.
UPDATE observaciones SET precio_vigente_original = precio_vigente, precio_vigente = 7540 WHERE id = 1;
-- Esperado: 7450.00 | 7540.00 | 15080.00
SELECT precio_vigente_original, precio_vigente, precio_vigente_por_kg FROM observaciones WHERE id = 1;

-- Esperado: ERROR, viola "promocion_mas_barata" (el "antes" no puede ser menor que el vigente).
INSERT INTO observaciones (id, precio_vigente, precio_regular, cantidad_gramos) VALUES (2, 9000, 8000, 500);
-- Esperado: ERROR "division by zero". La fila se rechaza, pero NO por el CHECK de
-- cantidad_gramos: la columna generada se calcula antes. Una prueba negativa tiene que
-- comprobar QUÉ regla la rechazó; por eso las pruebas reales usan -500, no 0.
INSERT INTO observaciones (id, precio_vigente, cantidad_gramos) VALUES (3, 9000, 0);

-- Anular deja la fila para auditoría, pero ya no cuenta. Esperado: filas 1 | vivas 0
UPDATE observaciones SET anulada_en = now() WHERE id = 1;
SELECT count(*) AS filas, count(*) FILTER (WHERE anulada_en IS NULL) AS vivas FROM observaciones;
