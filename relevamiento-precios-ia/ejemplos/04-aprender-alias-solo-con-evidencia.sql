-- EJEMPLO ILUSTRATIVO, datos ficticios. Versión reducida de la consulta real.
-- Problema: cuando una persona confirma un producto, sirve guardar el texto del
-- cartel como alias para reconocerlo la próxima vez. Pero si el cartel NO decía
-- un dato (p. ej. refrigerado o congelado) y lo eligió la persona, el alias
-- congelaría esa elección en un índice global y equivocaría a todos después.
-- Solución: grabar el alias solo si el MODELO leyó los tres ejes en el cartel,
-- cada uno dentro del vocabulario cerrado del catálogo, y con confianza "alta".

CREATE TABLE vocabulario (eje text, valor text, PRIMARY KEY (eje, valor));
INSERT INTO vocabulario VALUES ('corte', 'pechuga'), ('tipo', 'blanco'), ('tipo', 'campesino'),
                               ('estado', 'refrigerado'), ('estado', 'congelado');
CREATE TABLE capturas (id int PRIMARY KEY, x jsonb NOT NULL);   -- x = la extracción cruda
INSERT INTO capturas VALUES
 (1, '{"descripcion_cartel": "PECHUGA BLANCA REFRIG X 500G", "corte": "pechuga", "tipo": "blanco", "estado": "refrigerado", "confianza": "alta"}'),
 (2, '{"descripcion_cartel": "PECHUGA BLANCA X 500G", "corte": "pechuga", "tipo": "blanco", "estado": null, "confianza": "alta"}'),
 (3, '{"descripcion_cartel": "PECHUGA X 500G", "corte": "pechuga", "tipo": "blanco", "estado": "", "confianza": "alta"}'),
 (4, '{"descripcion_cartel": "PECHUGA PROMO", "corte": "pechuga", "tipo": "blanco", "estado": "null", "confianza": "alta"}'),
 (5, '{"descripcion_cartel": "PECH CAMP CONG", "corte": "pechuga", "tipo": "campesino", "estado": "congelado", "confianza": "media"}');

-- La condición obvia. Esperado: 1, 3, 4, 5 (deja pasar "", el texto "null" y la lectura dudosa).
SELECT id FROM capturas WHERE x ->> 'estado' IS NOT NULL ORDER BY id;

-- La condición final. Esperado: solo 1.
SELECT c.id, c.x ->> 'descripcion_cartel' AS alias_a_grabar
FROM capturas c
WHERE nullif(btrim(coalesce(c.x ->> 'descripcion_cartel', '')), '') IS NOT NULL
  AND EXISTS (SELECT 1 FROM vocabulario v WHERE v.eje = 'corte'  AND v.valor = lower(btrim(c.x ->> 'corte')))
  AND EXISTS (SELECT 1 FROM vocabulario v WHERE v.eje = 'tipo'   AND v.valor = lower(btrim(c.x ->> 'tipo')))
  AND EXISTS (SELECT 1 FROM vocabulario v WHERE v.eje = 'estado' AND v.valor = lower(btrim(c.x ->> 'estado')))
  AND c.x ->> 'confianza' = 'alta'
ORDER BY c.id;
