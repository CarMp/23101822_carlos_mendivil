-- LAB-03 Actividad 1: Verificaciones de calidad de datos sobre public.clientes
-- Nota: Los dos registros de simulación (id 7 y 8) se insertaron una sola vez y no deben eliminarse.
/*
INSERT INTO clientes (nombre, correo, telefono, rfc, edad, ciudad, codigo_postal)
VALUES
('Ana Lopez', 'ANA.LOPEZ@example.test', '6671234567', 'LOAA850315AB', 41, 'Culiacan', '80000'),
('Jorge Díaz', 'sin-correo', '667', NULL, -3, 'Culiacán', '8000');
*/

-- 1. Posibles duplicados por correo (unicidad insensible a mayúsculas/minúsculas)
SELECT lower(correo) AS correo_normalizado,
       count(*) AS registros,
       string_agg(id::text, ', ' ORDER BY id) AS ids
FROM public.clientes
GROUP BY lower(correo)
HAVING count(*) > 1;

-- 2. RFC con formato no válido o ausente
SELECT id, nombre, rfc
FROM public.clientes
WHERE rfc IS NULL
   OR rfc !~ '^[A-ZÑ&]{3,4}[0-9]{6}[A-Z0-9]{3}$'
ORDER BY id;

-- 3. Correo con formato no válido
SELECT id, nombre, correo
FROM public.clientes
WHERE correo !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
ORDER BY id;

-- 4. Edad fuera de rango razonable (18 a 120)
SELECT id, nombre, edad
FROM public.clientes
WHERE edad IS NOT NULL AND (edad < 18 OR edad > 120)
ORDER BY id;

-- 5. Completitud de atributos clave
SELECT count(*) AS total,
       count(*) FILTER (WHERE telefono IS NULL) AS sin_telefono,
       count(*) FILTER (WHERE rfc IS NULL) AS sin_rfc
FROM public.clientes;

-- 6. Verificación adicional: teléfono o código postal fuera de formato esperado en México
SELECT id, nombre, telefono, codigo_postal
FROM public.clientes
WHERE telefono IS NULL OR telefono !~ '^[0-9]{10}$'
   OR codigo_postal IS NULL OR codigo_postal !~ '^[0-9]{5}$'
ORDER BY id;
