

USE DWHDEV; 
USE DSADEV;


-- ============================================================================
-- 01. INVENTARIO Y ESTRUCTURA DE TABLAS
-- ============================================================================

-- Consulta 001
SELECT TABLE_NAME

FROM INFORMATION_SCHEMA.TABLES

WHERE TABLE_SCHEMA = DATABASE()

  AND (

      LOWER(TABLE_NAME) LIKE '%geo%'

      OR LOWER(TABLE_NAME) LIKE '%canton%'

      OR LOWER(TABLE_NAME) LIKE '%provincia%'

  )

ORDER BY TABLE_NAME;

-- Consulta 002
DESCRIBE tb_Clasificador_Geografico_g5;

-- Consulta 003
--

DESCRIBE BDDenemdu_personas_2022_anual_g5;

-- Consulta 004
DESCRIBE CPV_2022_Vivienda_Canton_g5;

-- Consulta 005
DESCRIBE CPV_2022_Hogar_Canton_g5;

-- Consulta 006
DESCRIBE raw_inec_nbi_10_1_pobreza_por_canton_NBI_g5;

-- Consulta 007
describe CPV_2022_Hogar_Canton_g5

describe CPV_2022_Vivienda_Canton_g5

describe CPV_2022_Poblacion_Canton_g5

ALTER TABLE CPV_2022_Vivienda_Canton_g5

ADD COLUMN load_ts DATETIME NULL,

ADD COLUMN load_source VARCHAR(200) NULL;

-- Consulta 008
DESCRIBE DWHDEV.dim_geografia_g5;

-- Consulta 009
DESCRIBE DWHDEV.dim_geografia_g5;

-- Consulta 010
DESCRIBE DWHDEV.dim_geografia_g5;

-- Consulta 011
DESCRIBE DWHDEV.fact_hogares_g5;

-- Consulta 012
DESCRIBE DWHDEV.dim_tiempo_g5

SELECT *

FROM DWHDEV.dim_tiempo_g5;

-- Consulta 013
DESCRIBE DWHDEV.dim_indicadores_g5;

-- Consulta 014
SHOW TABLES FROM DWHDEV LIKE 'fact_hogares_g5';

-- Consulta 015
SHOW TABLES FROM DWHDEV

LIKE '%Hogar%Canton%';

-- Consulta 016
SELECT

    TABLE_SCHEMA,

    TABLE_NAME,

    COLUMN_NAME

FROM INFORMATION_SCHEMA.COLUMNS

WHERE TABLE_SCHEMA = 'DSADEV'

  AND UPPER(COLUMN_NAME) = 'IMP_VOPA';

-- Consulta 017
SHOW TABLES FROM DWHDEV LIKE 'kpi_privaciones_canton_g5';

-- Consulta 018
DESCRIBE DWHDEV.kpi_privaciones_canton_g5

SELECT

    \`Nombre Provincia\`,

    \`Nombre Canton\`,

    \`Nombre Indicador\`,

    \`Hogares Con Privacion\`,

    \`Hogares Sin Privacion\`,

    \`Hogares No Evaluables\`,

    \`Hogares Pobres Analizados\`,

    (\`Hogares Con Privacion\` + \`Hogares Sin Privacion\`)

        AS hogares_evaluables,

    (\`Hogares Con Privacion\` + \`Hogares Sin Privacion\`

       \+ \`Hogares No Evaluables\`)

        AS total_clasificado

FROM DWHDEV.kpi_privaciones_canton_g5

LIMIT 20;


-- ============================================================================
-- 02. FUENTES INEC Y CONTROL DE CALIDAD
-- ============================================================================

-- Consulta 001
SELECT 'CENSO_HOGAR' AS tabla, COUNT(*) AS registros

FROM CPV_2022_Hogar_Canton_g5

UNION ALL

SELECT 'CENSO_POBLACION', COUNT(*)

FROM CPV_2022_Poblacion_Canton_g5

DESCRIBE CPV_2022_Poblacion_Canton_g5;

-- Consulta 002
ALTER TABLE CPV_2022_Poblacion_Canton_g5

ADD COLUMN load_ts DATETIME NULL,

ADD COLUMN load_source VARCHAR(200) NULL;

-- Consulta 003
ALTER TABLE CPV_2022_Hogar_Canton_g5

ADD COLUMN load_ts DATETIME NULL,

ADD COLUMN load_source VARCHAR(200) NULL;

-- Consulta 004
UPDATE CPV_2022_Poblacion_Canton_g5

SET

    load_ts = NOW(),

    load_source = 'dataton_grupo5'

WHERE load_ts IS NULL;

-- Consulta 005
UPDATE CPV_2022_Hogar_Canton_g5

SET

    load_ts = NOW(),

    load_source = 'dataton_grupo5'

WHERE load_ts IS NULL;


-- ============================================================================
-- 03. GEOGRAFÍA Y CÓDIGOS TERRITORIALES
-- ============================================================================

-- Consulta 001
SELECT

    DPA_PROVIN,

    DPA_DESPRO,

    DPA_CANTON,

    DPA_DESCAN,

    COUNT(*) AS registros

FROM tb_Clasificador_Geografico_g5

WHERE DPA_CANTON IN ('1409', '0916', '1209')

GROUP BY

    DPA_PROVIN,

    DPA_DESPRO,

    DPA_CANTON,

    DPA_DESCAN

ORDER BY DPA_CANTON;

-- Consulta 002
SELECT DISTINCT

    DPA_CANTON AS codigo_canton,

    DPA_DESPRO AS provincia,

    DPA_DESCAN AS canton

FROM tb_Clasificador_Geografico_g5

WHERE DPA_CANTON IN ('1409', '0916', '1209')

ORDER BY codigo_canton;

-- Consulta 003
WITH personas AS (

    SELECT

        CANTON,

        COUNT(*) AS total_personas,

        SUM(CASE WHEN DFUNC = 1 THEN 1 ELSE 0 END) AS con_dificultad,

        SUM(CASE WHEN DFUNC = 9 OR DFUNC IS NULL THEN 1 ELSE 0 END) AS sin_informacion

    FROM CPV_2022_Poblacion_Canton_g5

    WHERE CANTON IS NOT NULL

    GROUP BY CANTON

),

geografia AS (

    SELECT

        DPA_CANTON,

        MAX(DPA_DESPRO) AS provincia,

        MAX(DPA_DESCAN) AS canton

    FROM tb_Clasificador_Geografico_g5

    GROUP BY DPA_CANTON

)

SELECT

    g.provincia,

    g.canton,

    p.CANTON AS codigo_canton,

    p.total_personas,

    p.con_dificultad,

    p.sin_informacion,

    ROUND(

        100.0 * p.con_dificultad /

        NULLIF(p.total_personas - p.sin_informacion, 0),

        2

    ) AS porcentaje_dificultad

FROM personas p

LEFT JOIN geografia g

    ON p.CANTON = g.DPA_CANTON

ORDER BY porcentaje_dificultad DESC;

-- Consulta 004
WITH personas AS (

    SELECT

        CANTON,

        CASE

            WHEN P0701 IN ('3','4')

              OR P0702 IN ('3','4')

              OR P0703 IN ('3','4')

              OR P0704 IN ('3','4')

              OR P0705 IN ('3','4')

              OR P0706 IN ('3','4')

            THEN 1

            ELSE 0

        END AS dificultad_grave

    FROM CPV_2022_Poblacion_Canton_g5

    WHERE CANTON IS NOT NULL

      AND DFUNC IN ('1','2')

),

conteo AS (

    SELECT

        CANTON,

        COUNT(*) AS personas_evaluadas,

        SUM(dificultad_grave) AS personas_dificultad_grave

    FROM personas

    GROUP BY CANTON

),

geografia AS (

    SELECT DISTINCT

        DPA_CANTON,

        DPA_DESPRO,

        DPA_DESCAN

    FROM tb_Clasificador_Geografico_g5

)

SELECT

    g.DPA_DESPRO AS provincia,

    g.DPA_DESCAN AS canton,

    c.CANTON AS codigo_canton,

    c.personas_evaluadas,

    c.personas_dificultad_grave,

    ROUND(

        100.0 * c.personas_dificultad_grave

        / NULLIF(c.personas_evaluadas, 0),

        2

    ) AS porcentaje_dificultad_grave

FROM conteo c

LEFT JOIN geografia g

    ON c.CANTON = g.DPA_CANTON

ORDER BY porcentaje_dificultad_grave DESC;


-- ============================================================================
-- 04. EDUCACIÓN Y ESCOLARIDAD
-- ============================================================================

-- Consulta 001
SELECT

    P15 AS codigo_asistencia,

    COUNT(*) AS total_personas

FROM CPV_2022_Poblacion_Canton_g5

WHERE P03 BETWEEN 5 AND 17

GROUP BY P15

ORDER BY P15;

-- Consulta 002
SELECT

    COUNT(*) AS hogares_con_ninos_5_17,

    SUM(privacion_educativa) AS hogares_con_privacion

FROM (

    SELECT

        ID_HOG,

        MAX(

            CASE

                WHEN P15 = 2 THEN 1

                ELSE 0

            END

        ) AS privacion_educativa

    FROM CPV_2022_Poblacion_Canton_g5

    WHERE P03 BETWEEN 5 AND 17

      AND ID_HOG IS NOT NULL

    GROUP BY ID_HOG

) AS hogares;

-- Consulta 003
SELECT

    CANTON,

    COUNT(*) AS hogares_con_ninos_5_17,

    SUM(privacion_educativa) AS hogares_con_privacion,

    ROUND(

        100.0 * SUM(privacion_educativa) / COUNT(*),

        2

    ) AS porcentaje_inasistencia

FROM (

    SELECT

        CANTON,

        ID_HOG,

        MAX(

            CASE

                WHEN P15 = 2 THEN 1

                ELSE 0

            END

        ) AS privacion_educativa

    FROM CPV_2022_Poblacion_Canton_g5

    WHERE P03 BETWEEN 5 AND 17

      AND ID_HOG IS NOT NULL

      AND CANTON IS NOT NULL

    GROUP BY CANTON, ID_HOG

) AS hogares

GROUP BY CANTON

ORDER BY porcentaje_inasistencia DESC;

-- Consulta 004
-- POSIBLE INDICADOR 1 EDUCACION

WITH hogares AS (

    SELECT

        CANTON,

        ID_HOG,

        MAX(

            CASE

                WHEN P03 BETWEEN 5 AND 17

                     AND P15 = 2 THEN 1

                ELSE 0

            END

        ) AS privacion_educativa

    FROM CPV_2022_Poblacion_Canton_g5

    WHERE P03 BETWEEN 5 AND 17

      AND ID_HOG IS NOT NULL

      AND CANTON IS NOT NULL

    GROUP BY CANTON, ID_HOG

),

geografia AS (

    SELECT DISTINCT

        DPA_CANTON,

        DPA_DESPRO,

        DPA_DESCAN

    FROM tb_Clasificador_Geografico_g5

)

SELECT

    g.DPA_DESPRO AS provincia,

    g.DPA_DESCAN AS canton,

    h.CANTON AS codigo_canton,

    COUNT(*) AS hogares_evaluados,

    SUM(h.privacion_educativa) AS hogares_con_privacion,

    ROUND(

        100.0 * SUM(h.privacion_educativa)

        / NULLIF(COUNT(*), 0),

        2

    ) AS porcentaje_inasistencia

FROM hogares h

LEFT JOIN geografia g

    ON h.CANTON = g.DPA_CANTON

GROUP BY

    g.DPA_DESPRO,

    g.DPA_DESCAN,

    h.CANTON

ORDER BY porcentaje_inasistencia DESC;

-- Consulta 005
----

SELECT

    ESCOLA AS anios_escolaridad,

    COUNT(*) AS total_personas

FROM CPV_2022_Poblacion_Canton_g5

WHERE P03 >= 18

GROUP BY ESCOLA

ORDER BY ESCOLA;

-- Consulta 006
SELECT

    COUNT(*) AS total_adultos,

    SUM(

        CASE

            WHEN ESCOLA < 7 THEN 1

            ELSE 0

        END

    ) AS adultos_baja_escolaridad,

    SUM(

        CASE

            WHEN ESCOLA >= 7 THEN 1

            ELSE 0

        END

    ) AS adultos_otros_niveles,

    SUM(

        CASE

            WHEN ESCOLA IS NULL THEN 1

            ELSE 0

        END

    ) AS adultos_sin_dato

FROM CPV_2022_Poblacion_Canton_g5

WHERE P03 >= 18;

-- Consulta 007
SELECT

    COUNT(*) AS hogares_con_adultos,

    SUM(privacion_bajo_logro) AS hogares_con_privacion,

    ROUND(

        100.0 * SUM(privacion_bajo_logro)

        / NULLIF(COUNT(*), 0),

        2

    ) AS porcentaje_privacion

FROM (

    SELECT

        ID_HOG,

        MAX(

            CASE

                WHEN ESCOLA < 7 THEN 1

                ELSE 0

            END

        ) AS privacion_bajo_logro

    FROM CPV_2022_Poblacion_Canton_g5

    WHERE P03 >= 18

      AND ID_HOG IS NOT NULL

    GROUP BY ID_HOG

) AS hogares;

-- Consulta 008
-- INDICADIR DOS EDUCACION

WITH hogares AS (

    SELECT

        CANTON,

        ID_HOG,

        MAX(

            CASE

                WHEN ESCOLA < 7 THEN 1

                ELSE 0

            END

        ) AS privacion_bajo_logro

    FROM CPV_2022_Poblacion_Canton_g5

    WHERE P03 >= 18

      AND ID_HOG IS NOT NULL

      AND CANTON IS NOT NULL

    GROUP BY CANTON, ID_HOG

),

geografia AS (

    SELECT DISTINCT

        DPA_CANTON,

        DPA_DESPRO,

        DPA_DESCAN

    FROM tb_Clasificador_Geografico_g5

)

SELECT

    g.DPA_DESPRO AS provincia,

    g.DPA_DESCAN AS canton,

    h.CANTON AS codigo_canton,

    COUNT(*) AS hogares_evaluados,

    SUM(h.privacion_bajo_logro) AS hogares_con_privacion,

    ROUND(

        100.0 * SUM(h.privacion_bajo_logro)

        / NULLIF(COUNT(*), 0),

        2

    ) AS porcentaje_bajo_logro

FROM hogares h

LEFT JOIN geografia g

    ON h.CANTON = g.DPA_CANTON

GROUP BY

    g.DPA_DESPRO,

    g.DPA_DESCAN,

    h.CANTON

ORDER BY porcentaje_bajo_logro DESC;

-- Consulta 009
-- 

WITH estudiantes AS (

    SELECT

        CANTON,

        ID_HOG,

        P03 AS edad,

        P15 AS asistencia,

        P17 AS nivel_educativo,

        P18 AS anio_aprobado

    FROM CPV_2022_Poblacion_Canton_g5

    WHERE P03 BETWEEN 5 AND 17

      AND ID_HOG IS NOT NULL

      AND CANTON IS NOT NULL

),

geografia AS (

    SELECT DISTINCT

        DPA_CANTON,

        DPA_DESPRO,

        DPA_DESCAN

    FROM tb_Clasificador_Geografico_g5

)

SELECT

    g.DPA_DESPRO AS provincia,

    g.DPA_DESCAN AS canton,

    e.CANTON AS codigo_canton,

    COUNT(*) AS personas_5_17,

    SUM(

        CASE

            WHEN e.nivel_educativo IS NOT NULL

             AND e.anio_aprobado IS NOT NULL

            THEN 1 ELSE 0

        END

    ) AS personas_con_datos_educativos,

    SUM(

        CASE

            WHEN e.nivel_educativo IS NULL

              OR e.anio_aprobado IS NULL

            THEN 1 ELSE 0

        END

    ) AS personas_sin_datos_educativos

FROM estudiantes e

LEFT JOIN geografia g

    ON e.CANTON = g.DPA_CANTON

GROUP BY

    g.DPA_DESPRO,

    g.DPA_DESCAN,

    e.CANTON

ORDER BY personas_sin_datos_educativos DESC;

-- Consulta 010
SELECT

    P17 AS nivel_educativo,

    P18 AS anio_aprobado,

    COUNT(*) AS total_personas

FROM CPV_2022_Poblacion_Canton_g5

WHERE P03 BETWEEN 5 AND 17

GROUP BY P17, P18

ORDER BY P17, P18;

-- Consulta 011
SELECT

    P03 AS edad,

    COUNT(*) AS estudiantes,

    MIN(ESCOLA) AS escolaridad_minima,

    ROUND(AVG(ESCOLA), 2) AS escolaridad_promedio,

    MAX(ESCOLA) AS escolaridad_maxima

FROM CPV_2022_Poblacion_Canton_g5

WHERE P03 BETWEEN 8 AND 17

  AND P15 = 1

  AND ESCOLA IS NOT NULL

GROUP BY P03

ORDER BY P03;

-- Consulta 012
-- INDICADOR 3 EDUCACION

WITH estudiantes AS (

    SELECT

        CANTON,

        ID_HOG,

        P03 AS edad,

        ESCOLA AS escolaridad,

        CASE

            WHEN ESCOLA <= P03 - 7 THEN 1

            ELSE 0

        END AS tiene_rezago

    FROM CPV_2022_Poblacion_Canton_g5

    WHERE P03 BETWEEN 8 AND 17

      AND P15 = 1

      AND ESCOLA IS NOT NULL

      AND ID_HOG IS NOT NULL

      AND CANTON IS NOT NULL

),

hogares AS (

    SELECT

        CANTON,

        ID_HOG,

        MAX(tiene_rezago) AS privacion_rezago

    FROM estudiantes

    GROUP BY CANTON, ID_HOG

),

geografia AS (

    SELECT DISTINCT

        DPA_CANTON,

        DPA_DESPRO,

        DPA_DESCAN

    FROM tb_Clasificador_Geografico_g5

)

SELECT

    g.DPA_DESPRO AS provincia,

    g.DPA_DESCAN AS canton,

    h.CANTON AS codigo_canton,

    COUNT(*) AS hogares_evaluados,

    SUM(h.privacion_rezago) AS hogares_con_rezago,

    ROUND(

        100.0 * SUM(h.privacion_rezago)

        / NULLIF(COUNT(*), 0),

        2

    ) AS porcentaje_rezago

FROM hogares h

LEFT JOIN geografia g

    ON h.CANTON = g.DPA_CANTON

GROUP BY

    g.DPA_DESPRO,

    g.DPA_DESCAN,

    h.CANTON

ORDER BY porcentaje_rezago DESC;


-- ============================================================================
-- 05. VIVIENDA, AGUA Y SANEAMIENTO
-- ============================================================================

-- Consulta 001
SELECT

    V07 AS codigo_agua,

    COUNT(*) AS total_viviendas

FROM CPV_2022_Vivienda_Canton_g5

GROUP BY V07

ORDER BY V07;

-- Consulta 002
SELECT

    V09 AS forma_recepcion_agua,

    V10 AS fuente_agua,

    COUNT(*) AS total_viviendas

FROM CPV_2022_Vivienda_Canton_g5

GROUP BY V09, V10

ORDER BY V09, V10;

-- Consulta 003
SELECT

    CASE

        WHEN V09 IS NULL THEN 'NULL'

        WHEN TRIM(V09) = '' THEN 'VACIO'

        ELSE 'CON DATO'

    END AS estado_v09,

    CASE

        WHEN V10 IS NULL THEN 'NULL'

        WHEN TRIM(V10) = '' THEN 'VACIO'

        ELSE 'CON DATO'

    END AS estado_v10,

    COUNT(*) AS total_viviendas

FROM CPV_2022_Vivienda_Canton_g5

GROUP BY

    estado_v09,

    estado_v10

ORDER BY total_viviendas DESC;

-- Consulta 004
SELECT

    V0201 AS codigo_ocupacion,

    COUNT(*) AS total_viviendas,

    SUM(

        CASE

            WHEN TRIM(COALESCE(V09, '')) = ''

             AND TRIM(COALESCE(V10, '')) = ''

            THEN 1 ELSE 0

        END

    ) AS viviendas_sin_datos_agua,

    SUM(

        CASE

            WHEN TRIM(COALESCE(V09, '')) <> ''

             AND TRIM(COALESCE(V10, '')) <> ''

            THEN 1 ELSE 0

        END

    ) AS viviendas_con_datos_agua

FROM CPV_2022_Vivienda_Canton_g5

GROUP BY V0201

ORDER BY V0201;

-- Consulta 005
-- indicador

WITH viviendas AS (

    SELECT

        ID_VIV,

        CANTON,

        CASE

            WHEN TRIM(V09) = '4'

              OR TRIM(V10) IN ('3', '4', '5')

            THEN 1

            ELSE 0

        END AS privacion_agua

    FROM CPV_2022_Vivienda_Canton_g5

    WHERE V0201 = 1

      AND TRIM(COALESCE(V09, '')) <> ''

      AND TRIM(COALESCE(V10, '')) <> ''

),

hogares AS (

    SELECT DISTINCT

        h.ID_HOG,

        h.ID_VIV,

        h.CANTON,

        v.privacion_agua

    FROM CPV_2022_Hogar_Canton_g5 h

    INNER JOIN viviendas v

        ON h.ID_VIV = v.ID_VIV

       AND h.CANTON = v.CANTON

    WHERE h.ID_HOG IS NOT NULL

),

geografia AS (

    SELECT

        DPA_CANTON,

        MAX(DPA_DESPRO) AS provincia,

        MAX(DPA_DESCAN) AS canton

    FROM tb_Clasificador_Geografico_g5

    GROUP BY DPA_CANTON

)

SELECT

    g.provincia,

    g.canton,

    h.CANTON AS codigo_canton,

    COUNT(*) AS hogares_evaluados,

    SUM(h.privacion_agua) AS hogares_sin_agua_adecuada,

    ROUND(

        100.0 * SUM(h.privacion_agua)

        / NULLIF(COUNT(*), 0),

        2

    ) AS porcentaje_privacion_agua

FROM hogares h

LEFT JOIN geografia g

    ON h.CANTON = g.DPA_CANTON

GROUP BY

    g.provincia,

    g.canton,

    h.CANTON

ORDER BY porcentaje_privacion_agua DESC;

-- Consulta 006
SELECT

    V11 AS codigo_saneamiento,

    COUNT(*) AS total_viviendas

FROM CPV_2022_Vivienda_Canton_g5

WHERE V0201 = 1

GROUP BY V11

ORDER BY V11;

-- Consulta 007
--indicador vida

WITH viviendas AS (

    SELECT

        ID_VIV,

        CANTON,

        CASE

            WHEN TRIM(V11) IN ('4', '5', '6', '7')

            THEN 1

            ELSE 0

        END AS privacion_saneamiento

    FROM CPV_2022_Vivienda_Canton_g5

    WHERE V0201 = 1

      AND TRIM(COALESCE(V11, '')) <> ''

),

hogares AS (

    SELECT DISTINCT

        h.ID_HOG,

        h.CANTON,

        v.privacion_saneamiento

    FROM CPV_2022_Hogar_Canton_g5 h

    INNER JOIN viviendas v

        ON h.ID_VIV = v.ID_VIV

       AND h.CANTON = v.CANTON

    WHERE h.ID_HOG IS NOT NULL

),

geografia AS (

    SELECT

        DPA_CANTON,

        MAX(DPA_DESPRO) AS provincia,

        MAX(DPA_DESCAN) AS canton

    FROM tb_Clasificador_Geografico_g5

    GROUP BY DPA_CANTON

)

SELECT

    g.provincia,

    g.canton,

    h.CANTON AS codigo_canton,

    COUNT(*) AS hogares_evaluados,

    SUM(h.privacion_saneamiento)

        AS hogares_saneamiento_inadecuado,

    ROUND(

        100.0 * SUM(h.privacion_saneamiento)

        / NULLIF(COUNT(*), 0),

        2

    ) AS porcentaje_privacion_saneamiento

FROM hogares h

LEFT JOIN geografia g

    ON h.CANTON = g.DPA_CANTON

GROUP BY

    g.provincia,

    g.canton,

    h.CANTON

ORDER BY porcentaje_privacion_saneamiento DESC;

-- Consulta 008
WITH viviendas AS (

    SELECT

        ID_VIV,

        CANTON,

        CASE

            WHEN TRIM(V07) IN ('5', '6', '7')

            THEN 1

            ELSE 0

        END AS privacion_piso

    FROM CPV_2022_Vivienda_Canton_g5

    WHERE V0201 = 1

      AND TRIM(COALESCE(V07, '')) <> ''

),

hogares AS (

    SELECT DISTINCT

        h.ID_HOG,

        h.CANTON,

        v.privacion_piso

    FROM CPV_2022_Hogar_Canton_g5 h

    INNER JOIN viviendas v

        ON h.ID_VIV = v.ID_VIV

       AND h.CANTON = v.CANTON

    WHERE h.ID_HOG IS NOT NULL

),

geografia AS (

    SELECT

        DPA_CANTON,

        MAX(DPA_DESPRO) AS provincia,

        MAX(DPA_DESCAN) AS canton

    FROM tb_Clasificador_Geografico_g5

    GROUP BY DPA_CANTON

)

SELECT

    g.provincia,

    g.canton,

    h.CANTON AS codigo_canton,

    COUNT(*) AS hogares_evaluados,

    SUM(h.privacion_piso) AS hogares_piso_inadecuado,

    ROUND(

        100.0 * SUM(h.privacion_piso)

        / NULLIF(COUNT(*), 0),

        2

    ) AS porcentaje_privacion_piso

FROM hogares h

LEFT JOIN geografia g

    ON h.CANTON = g.DPA_CANTON

GROUP BY

    g.provincia,

    g.canton,

    h.CANTON

ORDER BY porcentaje_privacion_piso DESC;

-- Consulta 009
WITH hogares AS (

    SELECT

        CANTON,

        ID_HOG,

        HAC,

        CASE

            WHEN HAC = 1 THEN 1

            ELSE 0

        END AS privacion_hacinamiento

    FROM CPV_2022_Hogar_Canton_g5

    WHERE HAC IN (1, 2)

      AND ID_HOG IS NOT NULL

      AND CANTON IS NOT NULL

),

geografia AS (

    SELECT DISTINCT

        DPA_CANTON,

        DPA_DESPRO,

        DPA_DESCAN

    FROM tb_Clasificador_Geografico_g5

)

SELECT

    g.DPA_DESPRO AS provincia,

    g.DPA_DESCAN AS canton,

    h.CANTON AS codigo_canton,

    COUNT(*) AS hogares_evaluados,

    SUM(h.privacion_hacinamiento)

        AS hogares_con_hacinamiento,

    ROUND(

        100.0 * SUM(h.privacion_hacinamiento)

        / NULLIF(COUNT(*), 0),

        2

    ) AS porcentaje_hacinamiento

FROM hogares h

LEFT JOIN geografia g

    ON h.CANTON = g.DPA_CANTON

GROUP BY

    g.DPA_DESPRO,

    g.DPA_DESCAN,

    h.CANTON

ORDER BY porcentaje_hacinamiento DESC;

-- Consulta 010
WITH hogares AS (

    SELECT

        h.ID_HOG,

        h.ID_VIV,

        h.CANTON,

        h.HAC

    FROM CPV_2022_Hogar_Canton_g5 h

),

verificacion AS (

    SELECT

        h.ID_HOG,

        h.CANTON,

        v.ID_VIV AS vivienda_encontrada,

        v.V0201

    FROM hogares h

    LEFT JOIN CPV_2022_Vivienda_Canton_g5 v

        ON h.ID_VIV = v.ID_VIV

       AND h.CANTON = v.CANTON

)

SELECT

    COUNT(*) AS total_hogares,

    SUM(CASE WHEN vivienda_encontrada IS NOT NULL

             THEN 1 ELSE 0 END) AS hogares_con_vivienda,

    SUM(CASE WHEN V0201 = 1

             THEN 1 ELSE 0 END) AS hogares_vivienda_ocupada,

    SUM(CASE WHEN vivienda_encontrada IS NULL

             THEN 1 ELSE 0 END) AS hogares_sin_vivienda

FROM verificacion;

-- Consulta 011
WITH verificacion AS (

    SELECT

        h.ID_HOG,

        h.HAC,

        v.V0201

    FROM CPV_2022_Hogar_Canton_g5 h

    INNER JOIN CPV_2022_Vivienda_Canton_g5 v

        ON h.ID_VIV = v.ID_VIV

       AND h.CANTON = v.CANTON

)

SELECT

    V0201 AS codigo_ocupacion,

    COUNT(*) AS total_hogares,

    SUM(

        CASE WHEN HAC IN (1, 2)

        THEN 1 ELSE 0 END

    ) AS hogares_con_datos_hacinamiento,

    SUM(

        CASE WHEN HAC NOT IN (1, 2)

               OR HAC IS NULL

        THEN 1 ELSE 0 END

    ) AS hogares_sin_datos_hacinamiento

FROM verificacion

GROUP BY V0201

ORDER BY V0201;

-- Consulta 012
WITH hogares AS (

    SELECT

        h.ID_HOG,

        h.CANTON,

        CASE

            WHEN h.HAC = 1 THEN 1

            ELSE 0

        END AS privacion_hacinamiento

    FROM CPV_2022_Hogar_Canton_g5 h

    INNER JOIN CPV_2022_Vivienda_Canton_g5 v

        ON h.ID_VIV = v.ID_VIV

       AND h.CANTON = v.CANTON

    WHERE v.V0201 = 1

      AND h.HAC IN (1, 2)

),

geografia AS (

    SELECT DISTINCT

        DPA_CANTON,

        DPA_DESPRO,

        DPA_DESCAN

    FROM tb_Clasificador_Geografico_g5

)

SELECT

    g.DPA_DESPRO AS provincia,

    g.DPA_DESCAN AS canton,

    h.CANTON AS codigo_canton,

    COUNT(*) AS hogares_evaluados,

    SUM(h.privacion_hacinamiento)

        AS hogares_con_hacinamiento,

    ROUND(

        100.0 * SUM(h.privacion_hacinamiento)

        / NULLIF(COUNT(*), 0),

        2

    ) AS porcentaje_hacinamiento

FROM hogares h

LEFT JOIN geografia g

    ON h.CANTON = g.DPA_CANTON

GROUP BY

    g.DPA_DESPRO,

    g.DPA_DESCAN,

    h.CANTON

ORDER BY porcentaje_hacinamiento DESC;

-- Consulta 013
WITH hogares_base AS (

    SELECT

        h.ID_HOG,

        h.CANTON,

        h.HAC,

        v.V09,

        v.V10,

        v.V11,

        v.V07

    FROM CPV_2022_Hogar_Canton_g5 h

    INNER JOIN CPV_2022_Vivienda_Canton_g5 v

        ON h.ID_VIV = v.ID_VIV

       AND h.CANTON = v.CANTON

    WHERE v.V0201 = 1

)

SELECT

    COUNT(*) AS total_hogares,

    SUM(

        CASE WHEN TRIM(COALESCE(V09, '')) <> ''

              AND TRIM(COALESCE(V10, '')) <> ''

        THEN 1 ELSE 0 END

    ) AS hogares_con_datos_agua,

    SUM(

        CASE WHEN TRIM(COALESCE(V11, '')) <> ''

        THEN 1 ELSE 0 END

    ) AS hogares_con_datos_saneamiento,

    SUM(

        CASE WHEN TRIM(COALESCE(V07, '')) <> ''

        THEN 1 ELSE 0 END

    ) AS hogares_con_datos_piso,

    SUM(

        CASE WHEN HAC IN (1, 2)

        THEN 1 ELSE 0 END

    ) AS hogares_con_datos_hacinamiento

FROM hogares_base;

-- Consulta 014
UPDATE CPV_2022_Vivienda_Canton_g5

SET

    load_ts = NOW(),

    load_source = 'dataton_grupo5'

WHERE load_ts IS NULL;


-- ============================================================================
-- 06. SALUD, DISCAPACIDAD Y SEGURIDAD SOCIAL
-- ============================================================================

-- Consulta 001
SELECT

    DFUNC AS codigo_dificultad_funcional,

    COUNT(*) AS total_personas

FROM CPV_2022_Poblacion_Canton_g5

GROUP BY DFUNC

ORDER BY DFUNC;

-- Consulta 002
SELECT

    P30 AS codigo_seguridad_social,

    COUNT(*) AS total_personas

FROM CPV_2022_Poblacion_Canton_g5

GROUP BY P30

ORDER BY P30;

-- Consulta 003
WITH personas AS (

    SELECT

        CASE

            WHEN P03 < 15 THEN 'Menores de 15'

            WHEN P03 BETWEEN 15 AND 17 THEN '15 a 17 años'

            WHEN P03 >= 18 THEN '18 años o más'

            ELSE 'Edad sin información'

        END AS grupo_edad,

        CASE

            WHEN P30 IS NULL THEN 'NULL'

            WHEN TRIM(P30) = '' THEN 'VACIO'

            ELSE 'CON DATO'

        END AS estado_p30

    FROM CPV_2022_Poblacion_Canton_g5

)

SELECT

    grupo_edad,

    estado_p30,

    COUNT(*) AS total_personas

FROM personas

GROUP BY grupo_edad, estado_p30

ORDER BY grupo_edad, estado_p30;

-- Consulta 004
SELECT

    P30 AS codigo_seguridad_social,

    COUNT(*) AS total_personas

FROM CPV_2022_Poblacion_Canton_g5

WHERE P03 >= 15

GROUP BY P30

ORDER BY P30;

-- Consulta 005
.. indicador

WITH personas AS (

    SELECT

        CANTON,

        COUNT(*) AS personas_evaluadas,

        SUM(

            CASE WHEN P30 = '7'

            THEN 1 ELSE 0 END

        ) AS personas_no_aportan

    FROM CPV_2022_Poblacion_Canton_g5

    WHERE P03 >= 15

      AND TRIM(COALESCE(P30, '')) IN

          ('1','2','3','4','5','6','7')

      AND CANTON IS NOT NULL

    GROUP BY CANTON

),

geografia AS (

    SELECT DISTINCT

        DPA_CANTON,

        DPA_DESPRO,

        DPA_DESCAN

    FROM tb_Clasificador_Geografico_g5

)

SELECT

    g.DPA_DESPRO AS provincia,

    g.DPA_DESCAN AS canton,

    p.CANTON AS codigo_canton,

    p.personas_evaluadas,

    p.personas_no_aportan,

    ROUND(

        100.0 * p.personas_no_aportan /

        NULLIF(p.personas_evaluadas, 0),

        2

    ) AS porcentaje_no_aportan

FROM personas p

LEFT JOIN geografia g

    ON p.CANTON = g.DPA_CANTON

ORDER BY porcentaje_no_aportan DESC;


-- ============================================================================
-- 07. INDICADORES Y PRIVACIONES DE HOGARES
-- ============================================================================

-- Consulta 001
SELECT COUNT(*) AS registros

FROM dim_indicadores_g5;

-- Consulta 002
CREATE TABLE IF NOT EXISTS reject_dim_indicadores_g5 (

    id_indicador VARCHAR(3),

    dimension VARCHAR(80),

    nombre VARCHAR(150),

    peso DECIMAL(12,10),

    load_source VARCHAR(100),

    motivo_rechazo VARCHAR(255),

    load_ts DATETIME DEFAULT CURRENT_TIMESTAMP

);


-- ============================================================================
-- 08. POBREZA NBI OFICIAL Y COMPARACIÓN
-- ============================================================================

-- Consulta 001
SELECT

    provincia,

    canton,

    area,

    total_hogares,

    hogares_no_pobres,

    pobre_solo_dependencia_economica,

    pobre_solo_inasistencia_escolar,

    pobre_solo_vivienda_inadecuada,

    pobre_solo_sin_servicios_basicos,

    pobre_solo_hacinamiento,

    pobre_dos_o_mas_componentes

FROM raw_inec_nbi_10_1_pobreza_por_canton_NBI_g5

LIMIT 15;

-- Consulta 002
SELECT

    CASE

        WHEN TRIM(provincia) LIKE 'Total%'

          OR TRIM(canton) LIKE 'Total%'

        THEN 'TOTAL PROVINCIAL O SUPERIOR'

        WHEN TRIM(area) LIKE 'Total%'

        THEN 'TOTAL CANTONAL'

        WHEN TRIM(area) IN ('Urbana', 'Rural')

        THEN 'AREA URBANA O RURAL'

        ELSE 'REVISAR'

    END AS tipo_registro,

    COUNT(*) AS cantidad_filas,

    SUM(total_hogares) AS suma_hogares

FROM raw_inec_nbi_10_1_pobreza_por_canton_NBI_g5

GROUP BY tipo_registro

ORDER BY tipo_registro;

-- Consulta 003
WITH nbi_cantonal AS (

    SELECT

        provincia,

        canton,

        total_hogares,

        hogares_no_pobres,

        total_hogares - hogares_no_pobres

            AS hogares_pobres_nbi

    FROM raw_inec_nbi_10_1_pobreza_por_canton_NBI_g5

    WHERE TRIM(area) LIKE 'Total%'

      AND TRIM(canton) NOT LIKE 'Total%'

)

SELECT

    provincia,

    canton,

    total_hogares,

    hogares_no_pobres,

    hogares_pobres_nbi,

    ROUND(

        100.0 * hogares_pobres_nbi

        / NULLIF(total_hogares, 0),

        2

    ) AS porcentaje_pobreza_nbi

FROM nbi_cantonal

ORDER BY porcentaje_pobreza_nbi DESC;

-- Consulta 004
WITH nbi AS (

    SELECT

        provincia,

        canton,

        total_hogares,

        hogares_no_pobres,

        pobre_solo_dependencia_economica,

        CAST(

            NULLIF(TRIM(pobre_solo_inasistencia_escolar), '')

            AS UNSIGNED

        ) AS solo_inasistencia,

        CAST(

            NULLIF(TRIM(pobre_solo_vivienda_inadecuada), '')

            AS UNSIGNED

        ) AS solo_vivienda,

        pobre_solo_sin_servicios_basicos,

        pobre_solo_hacinamiento,

        CAST(

            NULLIF(TRIM(pobre_dos_o_mas_componentes), '')

            AS UNSIGNED

        ) AS dos_o_mas

    FROM raw_inec_nbi_10_1_pobreza_por_canton_NBI_g5

    WHERE TRIM(area) LIKE 'Total%'

      AND TRIM(canton) NOT LIKE 'Total%'

)

SELECT

    provincia,

    canton,

    total_hogares - hogares_no_pobres AS hogares_pobres_nbi,

    pobre_solo_dependencia_economica,

    solo_inasistencia,

    solo_vivienda,

    pobre_solo_sin_servicios_basicos,

    pobre_solo_hacinamiento,

    dos_o_mas

FROM nbi

ORDER BY

    (total_hogares - hogares_no_pobres) /

    NULLIF(total_hogares, 0) DESC

LIMIT 5;

-- Consulta 005
SELECT

    COUNT(*) AS total_cantones,

    COUNT(DISTINCT cod_canton) AS cantones_unicos,

    SUM(

        CASE

            WHEN pobreza_nbi_oficial IS NULL THEN 1

            ELSE 0

        END

    ) AS cantones_sin_nbi

FROM DWHDEV.v_comparacion_nbi_g5;

-- Consulta 006
SELECT

    nombre_provincia,

    nombre_canton,

    pobreza_multidimensional_g5,

    pobreza_nbi_oficial,

    diferencia_puntos_porcentuales,

    cobertura_evaluable

FROM DWHDEV.v_comparacion_nbi_g5

ORDER BY ABS(diferencia_puntos_porcentuales) DESC

LIMIT 10;

-- Consulta 007
SELECT

    cod_provincia,

    cod_canton,

    COUNT(*) AS cantidad_registros

FROM DWHDEV.v_comparacion_nbi_g5

GROUP BY cod_provincia, cod_canton

HAVING COUNT(*) > 1

ORDER BY cantidad_registros DESC;

-- Consulta 008
SELECT

    COUNT(*) AS total_registros,

    SUM(CASE

        WHEN hogares_pobres > hogares_evaluables

        THEN 1 ELSE 0

    END) AS pobres_superan_evaluables,

    SUM(CASE

        WHEN hogares_pobres < 0

          OR hogares_evaluables < 0

          OR hogares_indeterminados < 0

        THEN 1 ELSE 0

    END) AS registros_negativos,

    SUM(CASE

        WHEN hogares_pobres IS NULL

          OR hogares_evaluables IS NULL

          OR hogares_indeterminados IS NULL

        THEN 1 ELSE 0

    END) AS registros_nulos

FROM DWHDEV.v_comparacion_nbi_g5

DESCRIBE DWHDEV.v_comparacion_nbi_g5;

-- Consulta 009
SELECT

    nombre_provincia,

    SUM(hogares_pobres) AS hogares_pobres,

    SUM(hogares_evaluables) AS hogares_evaluables,

    ROUND(

        100.0 * SUM(hogares_pobres)

        / NULLIF(SUM(hogares_evaluables), 0),

        2

    ) AS pobreza_g5_pct

FROM DWHDEV.v_comparacion_nbi_g5

GROUP BY nombre_provincia

ORDER BY pobreza_g5_pct DESC;

-- Consulta 010
SELECT

    COUNT(*) AS total_cantones,

    SUM(

        CASE

            WHEN ABS(

                pobreza_multidimensional_g5 -

                ROUND(

                    100.0 * hogares_pobres /

                    NULLIF(hogares_evaluables, 0),

                    2

                )

            ) > 0.01

            THEN 1 ELSE 0

        END

    ) AS cantones_con_diferencias

FROM DWHDEV.v_comparacion_nbi_g5

WHERE hogares_evaluables > 0;


-- ============================================================================
-- 09. MODELO ANALÍTICO DWH Y TABLAS KPI
-- ============================================================================

-- Consulta 001
select * from  DWHDEV.dim_indicadores_g5;

-- Consulta 002
CREATE TABLE IF NOT EXISTS DWHDEV.reject_dim_indicadores_g5 (

    id_indicador VARCHAR(3),

    dimension VARCHAR(80),

    nombre VARCHAR(150),

    peso DECIMAL(12,10),

    load_source VARCHAR(100),

    motivo_rechazo VARCHAR(255),

    load_ts DATETIME DEFAULT CURRENT_TIMESTAMP

);

-- Consulta 003
SELECT

    COUNT(*) AS total_registros,

    COUNT(DISTINCT id_geografia) AS ids_unicos,

    COUNT(DISTINCT cod_canton) AS cantones_unicos,

    COUNT(DISTINCT cod_provincia) AS provincias_unicas

FROM DWHDEV.dim_geografia_g5;

-- Consulta 004
SELECT

    COUNT(*) AS total,

    COUNT(DISTINCT id_geografia) AS codigos_unicos,

    SUM(

        CASE

            WHEN id_geografia IS NULL

              OR id_geografia NOT REGEXP '^[0-9]{4}$'

              OR cod_provincia IS NULL

              OR cod_provincia <> LEFT(id_geografia, 2)

              OR cod_canton IS NULL

              OR cod_canton <> id_geografia

            THEN 1 ELSE 0

        END

    ) AS errores

FROM DWHDEV.dim_geografia_g5;

-- Consulta 005
SELECT *

FROM DWHDEV.dim_geografia_g5

LIMIT 20;

-- Consulta 006
SELECT

    id_geografia,

    cod_provincia,

    cod_canton

FROM DWHDEV.dim_geografia_g5

LIMIT 20;

-- Consulta 007
SELECT

    COUNT(DISTINCT h.canton) AS cantones_censo,

    COUNT(DISTINCT g.cod_canton) AS cantones_clasificador,

    COUNT(DISTINCT CASE

        WHEN g.cod_canton IS NULL THEN h.canton

    END) AS cantones_sin_correspondencia

FROM (

    SELECT DISTINCT canton

    FROM stg_CPV_2022_Hogar_Canton_g5

) h

LEFT JOIN DWHDEV.dim_geografia_g5 g

    ON h.canton = g.cod_canton;

-- Consulta 008
SELECT

    cod_canton,

    COUNT(DISTINCT nombre_canton) AS nombres_canton,

    COUNT(DISTINCT nombre_provincia) AS nombres_provincia

FROM DWHDEV.dim_geografia_g5

GROUP BY cod_canton

HAVING COUNT(DISTINCT nombre_canton) > 1

    OR COUNT(DISTINCT nombre_provincia) > 1;

-- Consulta 009
SELECT

    COUNT(*) AS total_cantones,

    COUNT(DISTINCT id_geografia) AS codigos_unicos,

    SUM(

        CASE

            WHEN id_geografia NOT REGEXP '^[0-9]{4}$'

              OR cod_provincia NOT REGEXP '^[0-9]{2}$'

              OR cod_canton <> id_geografia

              OR cod_provincia <> LEFT(id_geografia, 2)

            THEN 1 ELSE 0

        END

    ) AS errores

FROM DWHDEV.dim_geografia_g5;

-- Consulta 010
SELECT

    COUNT(*) AS total_cantones,

    COUNT(DISTINCT id_geografia) AS ids_unicos,

    COUNT(DISTINCT cod_canton) AS cantones_unicos,

    COALESCE(SUM(

        CASE

            WHEN cod_canton IS NULL

              OR cod_canton NOT REGEXP '^[0-9]{4}$'

              OR cod_provincia IS NULL

              OR cod_provincia NOT REGEXP '^[0-9]{2}$'

              OR cod_provincia <> LEFT(cod_canton, 2)

              OR nombre_canton IS NULL

              OR TRIM(nombre_canton) = ''

              OR nombre_provincia IS NULL

              OR TRIM(nombre_provincia) = ''

            THEN 1

            ELSE 0

        END

    ), 0) AS errores_calidad

FROM DWHDEV.dim_geografia_g5;

-- Consulta 011
SELECT

    h.id_hog,

    g.id_geografia,

    h.canton

FROM stg_CPV_2022_Hogar_Canton_g5 h

JOIN DWHDEV.dim_geografia_g5 g

    ON TRIM(h.canton) = TRIM(g.cod_canton)

LIMIT 20;

-- Consulta 012
SELECT

    fecha,

    anio,

    trimestre,

    mes,

    dia

FROM DWHDEV.dim_tiempo_g5

WHERE fecha = '2022-01-01';

-- Consulta 013
CREATE TABLE IF NOT EXISTS DWHDEV.fact_hogares_g5 (

    id_hogar VARCHAR(100) NOT NULL,

    id_vivienda VARCHAR(100),

    id_geografia BIGINT NOT NULL,

    fecha DATE NOT NULL,

    id_indicador VARCHAR(3) NOT NULL,

    es_privacion TINYINT NULL,

    fuente_datos VARCHAR(20) NOT NULL,

    load_ts DATETIME DEFAULT CURRENT_TIMESTAMP,

    load_source VARCHAR(100),

    SHARD KEY (id_hogar)

);

-- Consulta 014
SELECT fecha

FROM DWHDEV.dim_tiempo_g5

WHERE fecha = '2022-01-01';

-- Consulta 015
SELECT

    id_indicador,

    COUNT(*) AS total,

    SUM(CASE WHEN es_privacion = 1 THEN 1 ELSE 0 END) AS con_privacion,

    SUM(CASE WHEN es_privacion = 0 THEN 1 ELSE 0 END) AS sin_privacion,

    SUM(CASE WHEN es_privacion IS NULL THEN 1 ELSE 0 END) AS no_evaluables

FROM DWHDEV.fact_hogares_g5

GROUP BY id_indicador

ORDER BY id_indicador;

-- Consulta 016
SELECT

    id_hogar,

    fecha,

    fuente_datos,

    id_indicador,

    COUNT(*) AS repeticiones

FROM DWHDEV.fact_hogares_g5

GROUP BY

    id_hogar,

    fecha,

    fuente_datos,

    id_indicador

HAVING COUNT(*) > 1;

-- Consulta 017
SELECT

    situacion,

    COUNT(*) AS hogares

FROM (

    SELECT

        id_hogar,

        CASE

            WHEN SUM(

                CASE WHEN es_privacion = 1 THEN 1 ELSE 0 END

            ) >= 3

            THEN 'POBRE_CONFIRMADO'

            WHEN SUM(

                CASE WHEN es_privacion = 1 THEN 1 ELSE 0 END

            ) +

            SUM(

                CASE WHEN es_privacion IS NULL THEN 1 ELSE 0 END

            ) < 3

            THEN 'NO_POBRE_CONFIRMADO'

            ELSE 'INDETERMINADO'

        END AS situacion

    FROM DWHDEV.fact_hogares_g5

    WHERE fuente_datos = 'CPV'

    GROUP BY id_hogar

    HAVING COUNT(DISTINCT id_indicador) = 9

) x

GROUP BY situacion;

-- Consulta 018
SELECT COUNT(*) AS total_registros

FROM DWHDEV.fact_hogares_g5;

-- Consulta 019
SELECT

    COUNT(*) AS total_registros,

    COUNT(DISTINCT id_hogar) AS hogares_unicos,

    COUNT(DISTINCT id_indicador) AS indicadores

FROM DWHDEV.fact_hogares_g5

WHERE fuente_datos = 'CPV';

-- Consulta 020
SELECT

    id_hogar,

    fecha,

    fuente_datos,

    COUNT(*) AS total_filas,

    COUNT(DISTINCT id_indicador) AS indicadores_distintos

FROM DWHDEV.fact_hogares_g5

WHERE fuente_datos = 'CPV'

GROUP BY id_hogar, fecha, fuente_datos

HAVING COUNT(*) <> 9

    OR COUNT(DISTINCT id_indicador) <> 9

LIMIT 20;

-- Consulta 021
SELECT

    id_hogar,

    fecha,

    fuente_datos,

    id_indicador,

    COUNT(*) AS repeticiones

FROM DWHDEV.fact_hogares_g5

WHERE fuente_datos = 'CPV'

GROUP BY

    id_hogar,

    fecha,

    fuente_datos,

    id_indicador

HAVING COUNT(*) > 1

LIMIT 20;

-- Consulta 022
SELECT

    COUNT(*) AS total_fechas,

    MIN(fecha) AS primera_fecha,

    MAX(fecha) AS ultima_fecha,

    COUNT(DISTINCT fecha) AS fechas_unicas

FROM DWHDEV.dim_tiempo_g5;

-- Consulta 023
SELECT 'dim_geografia_g5' AS tabla, COUNT(*) AS registros

FROM DWHDEV.dim_geografia_g5

UNION ALL

SELECT 'dim_tiempo_g5', COUNT(*)

FROM DWHDEV.dim_tiempo_g5

UNION ALL

SELECT 'dim_indicadores_g5', COUNT(*)

FROM DWHDEV.dim_indicadores_g5

UNION ALL

SELECT 'fact_hogares_g5', COUNT(*)

FROM DWHDEV.fact_hogares_g5;

-- Consulta 024
CREATE TABLE IF NOT EXISTS DWHDEV.audit_pipeline_g5 (

    run_id VARCHAR(100) NOT NULL,

    pipeline_name VARCHAR(100) NOT NULL,

    modo_ejecucion VARCHAR(20) NOT NULL,

    estado VARCHAR(20) NOT NULL,

    fecha_inicio DATETIME NOT NULL,

    fecha_fin DATETIME NULL,

    total_geografia BIGINT NULL,

    total_tiempo BIGINT NULL,

    total_indicadores BIGINT NULL,

    total_fact BIGINT NULL,

    mensaje VARCHAR(500) NULL,

    PRIMARY KEY (run_id)

);

-- Consulta 025
SELECT

    run_id,

    pipeline_name,

    modo_ejecucion,

    estado,

    fecha_inicio,

    fecha_fin,

    total_geografia,

    total_tiempo,

    total_indicadores,

    total_fact,

    mensaje

FROM DWHDEV.audit_pipeline_g5

WHERE run_id = 'G5_ff3984dc-7ec9-4ef7-baef-8842217d2669';

-- Consulta 026
SELECT

    run_id,

    estado,

    fecha_inicio,

    fecha_fin,

    total_geografia,

    total_tiempo,

    total_indicadores,

    total_fact

FROM DWHDEV.audit_pipeline_g5

ORDER BY fecha_inicio DESC

LIMIT 5;

-- Consulta 027
SELECT

    r.id_hogar,

    r.id_vivienda,

    r.id_geografia,

    r.fecha,

    r.fuente_datos,

    r.total_indicadores,

    r.num_privaciones,

    r.num_no_privaciones,

    r.num_no_evaluables,

    CASE

        WHEN r.num_privaciones >= 3

            THEN 'POBRE_CONFIRMADO'

        WHEN r.num_privaciones + r.num_no_evaluables < 3

            THEN 'NO_POBRE_CONFIRMADO'

        ELSE 'INDETERMINADO'

    END AS situacion,

    CASE

        WHEN r.num_privaciones >= 3 THEN 1

        WHEN r.num_privaciones + r.num_no_evaluables < 3 THEN 0

        ELSE NULL

    END AS es_pobre

FROM (

    SELECT

        id_hogar,

        MAX(id_vivienda) AS id_vivienda,

        id_geografia,

        fecha,

        fuente_datos,

        COUNT(*) AS total_indicadores,

        SUM(

            CASE WHEN es_privacion = 1

            THEN 1 ELSE 0 END

        ) AS num_privaciones,

        SUM(

            CASE WHEN es_privacion = 0

            THEN 1 ELSE 0 END

        ) AS num_no_privaciones,

        SUM(

            CASE WHEN es_privacion IS NULL

            THEN 1 ELSE 0 END

        ) AS num_no_evaluables

    FROM DWHDEV.fact_hogares_g5

    WHERE fuente_datos = 'CPV'

      AND fecha = '2022-01-01'

    GROUP BY

        id_hogar,

        id_geografia,

        fecha,

        fuente_datos

) as r

describe DWHDEV.fact_hogares_g5

CREATE VIEW DWHDEV.v_pobreza_hogar_g5 AS

SELECT

    r.id_hogar,

    r.id_vivienda,

    r.id_geografia,

    r.fecha,

    r.fuente_datos,

    r.total_indicadores,

    r.num_privaciones,

    r.num_no_privaciones,

    r.num_no_evaluables,

    CASE

        WHEN r.num_privaciones >= 3

            THEN 'POBRE_CONFIRMADO'

        WHEN r.num_privaciones + r.num_no_evaluables < 3

            THEN 'NO_POBRE_CONFIRMADO'

        ELSE 'INDETERMINADO'

    END AS situacion,

    CASE

        WHEN r.num_privaciones >= 3 THEN 1

        WHEN r.num_privaciones + r.num_no_evaluables < 3 THEN 0

        ELSE NULL

    END AS es_pobre

FROM (

    SELECT

        id_hogar,

        MAX(id_vivienda) AS id_vivienda,

        id_geografia,

        fecha,

        fuente_datos,

        COUNT(*) AS total_indicadores,

        SUM(

            CASE WHEN es_privacion = 1

            THEN 1 ELSE 0 END

        ) AS num_privaciones,

        SUM(

            CASE WHEN es_privacion = 0

            THEN 1 ELSE 0 END

        ) AS num_no_privaciones,

        SUM(

            CASE WHEN es_privacion IS NULL

            THEN 1 ELSE 0 END

        ) AS num_no_evaluables

    FROM DWHDEV.fact_hogares_g5

    WHERE fuente_datos = 'CPV'

      AND fecha = '2022-01-01'

    GROUP BY

        id_hogar,

        id_geografia,

        fecha,

        fuente_datos

) r;

-- Consulta 028
SELECT

    id_hogar,

    id_geografia,

    num_privaciones,

    num_no_evaluables,

    situacion,

    es_pobre

FROM DWHDEV.v_pobreza_hogar_g5

LIMIT 20;

-- Consulta 029
SELECT

    g.cod_provincia,

    g.nombre_provincia,

    g.cod_canton,

    g.nombre_canton,

    COUNT(*) AS total_hogares,

    SUM(CASE

        WHEN p.situacion = 'POBRE_CONFIRMADO'

        THEN 1 ELSE 0

    END) AS hogares_pobres,

    SUM(CASE

        WHEN p.situacion = 'NO_POBRE_CONFIRMADO'

        THEN 1 ELSE 0

    END) AS hogares_no_pobres,

    SUM(CASE

        WHEN p.situacion = 'INDETERMINADO'

        THEN 1 ELSE 0

    END) AS hogares_indeterminados,

    SUM(CASE

        WHEN p.es_pobre IS NOT NULL

        THEN 1 ELSE 0

    END) AS hogares_evaluables,

    ROUND(

        100.0 * SUM(CASE

            WHEN p.es_pobre = 1 THEN 1 ELSE 0

        END)

        / NULLIF(SUM(CASE

            WHEN p.es_pobre IS NOT NULL THEN 1 ELSE 0

        END), 0),

        2

    ) AS porcentaje_pobreza,

    ROUND(

        100.0 * SUM(CASE

            WHEN p.es_pobre IS NOT NULL THEN 1 ELSE 0

        END) / NULLIF(COUNT(*), 0),

        2

    ) AS cobertura_evaluable

FROM DWHDEV.v_pobreza_hogar_g5 p

JOIN DWHDEV.dim_geografia_g5 g

    ON p.id_geografia = g.id_geografia

GROUP BY

    g.cod_provincia,

    g.nombre_provincia,

    g.cod_canton,

    g.nombre_canton;

-- Consulta 030
DWHDEV.dim_geografia_g5

DWHDEV.dim_indicadores_g5

DWHDEV.dim_tiempo_g5

DWHDEV.fact_hogares_g5

CREATE TABLE DWHDEV.kpi_pobreza_provincia_g5 AS

SELECT

    cod_provincia,

    nombre_provincia,

    SUM(total_hogares) AS total_hogares,

    SUM(hogares_pobres) AS hogares_pobres,

    SUM(hogares_no_pobres) AS hogares_no_pobres,

    SUM(hogares_indeterminados) AS hogares_indeterminados,

    SUM(hogares_evaluables) AS hogares_evaluables,

    ROUND(

        100.0 * SUM(hogares_pobres)

        / NULLIF(SUM(hogares_evaluables), 0),

        2

    ) AS porcentaje_pobreza,

    ROUND(

        100.0 * SUM(hogares_evaluables)

        / NULLIF(SUM(total_hogares), 0),

        2

    ) AS cobertura_evaluable

FROM DWHDEV.kpi_pobreza_canton_g5

GROUP BY

    cod_provincia,

    nombre_provincia;

-- Consulta 031
SELECT *

FROM DWHDEV.kpi_pobreza_provincia_g5

ORDER BY porcentaje_pobreza DESC;

-- Consulta 032
SELECT

    COUNT(*) AS cantones,

    SUM(total_hogares) AS total_hogares,

    SUM(hogares_pobres) AS pobres,

    SUM(hogares_no_pobres) AS no_pobres,

    SUM(hogares_indeterminados) AS indeterminados

FROM DWHDEV.kpi_pobreza_canton_g5;

-- Consulta 033
SELECT

    id_indicador,

    nombre,

    dimension,

    peso

FROM DWHDEV.dim_indicadores_g5

ORDER BY id_indicador;

-- Consulta 034
SELECT

    dimension,

    COUNT(*) AS total_indicadores,

    ROUND(SUM(peso), 4) AS peso_total

FROM DWHDEV.dim_indicadores_g5

GROUP BY dimension

ORDER BY dimension;

-- Consulta 035
SELECT

    id_hogar,

    id_indicador,

    fecha,

    fuente_datos,

    COUNT(*) AS veces

FROM DWHDEV.fact_hogares_g5

WHERE fuente_datos = 'CPV'

  AND fecha = '2022-01-01'

GROUP BY

    id_hogar,

    id_indicador,

    fecha,

    fuente_datos

HAVING COUNT(*) > 1

LIMIT 5;

-- Consulta 036
CREATE TABLE DWHDEV.kpi_privaciones_canton_g5 AS

SELECT

    g.cod_provincia,

    g.nombre_provincia,

    g.cod_canton,

    g.nombre_canton,

    i.id_indicador,

    i.nombre AS nombre_indicador,

    i.dimension,

    COUNT(*) AS hogares_pobres_analizados,

    SUM(CASE

        WHEN f.es_privacion = 1 THEN 1

        ELSE 0

    END) AS hogares_con_privacion,

    SUM(CASE

        WHEN f.es_privacion = 0 THEN 1

        ELSE 0

    END) AS hogares_sin_privacion,

    SUM(CASE

        WHEN f.es_privacion IS NULL THEN 1

        ELSE 0

    END) AS hogares_no_evaluables

FROM DWHDEV.fact_hogares_g5 f

INNER JOIN DWHDEV.v_pobreza_hogar_g5 p

    ON f.id_hogar = p.id_hogar

   AND f.id_geografia = p.id_geografia

   AND f.fecha = p.fecha

   AND f.fuente_datos = p.fuente_datos

INNER JOIN DWHDEV.dim_geografia_g5 g

    ON f.id_geografia = g.id_geografia

INNER JOIN DWHDEV.dim_indicadores_g5 i

    ON f.id_indicador = i.id_indicador

WHERE p.es_pobre = 1

  AND f.fuente_datos = 'CPV'

  AND f.fecha = '2022-01-01'

GROUP BY

    g.cod_provincia,

    g.nombre_provincia,

    g.cod_canton,

    g.nombre_canton,

    i.id_indicador,

    i.nombre,

    i.dimension;

-- Consulta 037
SELECT

    COUNT(*) AS total_filas,

    COUNT(DISTINCT cod_canton) AS total_cantones,

    COUNT(DISTINCT id_indicador) AS total_indicadores

FROM DWHDEV.kpi_privaciones_canton_g5;

-- Consulta 038
SELECT

    cod_canton,

    nombre_canton,

    id_indicador,

    hogares_pobres_analizados,

    hogares_con_privacion,

    hogares_sin_privacion,

    hogares_no_evaluables

FROM DWHDEV.kpi_privaciones_canton_g5

WHERE hogares_pobres_analizados <>

      hogares_con_privacion

    \+ hogares_sin_privacion

    \+ hogares_no_evaluables;

-- Consulta 039
SELECT

    p.cod_canton,

    p.nombre_canton,

    p.id_indicador,

    p.hogares_pobres_analizados,

    k.hogares_pobres

FROM DWHDEV.kpi_privaciones_canton_g5 p

INNER JOIN DWHDEV.kpi_pobreza_canton_g5 k

    ON p.cod_canton = k.cod_canton

WHERE p.hogares_pobres_analizados <> k.hogares_pobres

LIMIT 10;

-- Consulta 040
SELECT

    cod_canton,

    nombre_canton,

    nombre_provincia,

    id_indicador,

    nombre_indicador,

    dimension,

    hogares_con_privacion,

    hogares_no_evaluables,

    ROUND(

        100.0 * hogares_con_privacion

        / NULLIF(hogares_pobres_analizados, 0),

        2

    ) AS pct_sobre_pobres,

    ROUND(

        100.0 * hogares_con_privacion

        / NULLIF(

            hogares_con_privacion + hogares_sin_privacion,

            0

        ),

        2

    ) AS pct_sobre_evaluables

FROM DWHDEV.kpi_privaciones_canton_g5

ORDER BY

    cod_canton,

    pct_sobre_evaluables DESC

LIMIT 20;

-- Consulta 041
CREATE VIEW DWHDEV.v_dimension_pobreza_canton_g5 AS

SELECT

    a.cod_provincia,

    a.nombre_provincia,

    a.cod_canton,

    a.nombre_canton,

    a.dimension,

    a.aporte_ponderado,

    ROUND(

        100.0 * a.aporte_ponderado

        / NULLIF(

            SUM(a.aporte_ponderado)

                OVER (PARTITION BY a.cod_canton),

            0

        ),

        2

    ) AS contribucion_pct

FROM (

    SELECT

        p.cod_provincia,

        p.nombre_provincia,

        p.cod_canton,

        p.nombre_canton,

        p.dimension,

        SUM(

            p.hogares_con_privacion * i.peso

        ) AS aporte_ponderado

    FROM DWHDEV.kpi_privaciones_canton_g5 p

    INNER JOIN DWHDEV.dim_indicadores_g5 i

        ON p.id_indicador = i.id_indicador

    GROUP BY

        p.cod_provincia,

        p.nombre_provincia,

        p.cod_canton,

        p.nombre_canton,

        p.dimension

) a;

-- Consulta 042
SELECT

    cod_canton,

    nombre_canton,

    nombre_provincia,

    COUNT(*) AS total_dimensiones,

    ROUND(SUM(contribucion_pct), 2) AS suma_porcentajes

FROM DWHDEV.v_dimension_pobreza_canton_g5

GROUP BY

    cod_canton,

    nombre_canton,

    nombre_provincia

ORDER BY cod_canton

LIMIT 10;

-- Consulta 043
SELECT

    cod_canton,

    nombre_canton,

    nombre_provincia,

    dimension,

    ROUND(aporte_ponderado, 2) AS aporte_ponderado,

    contribucion_pct

FROM DWHDEV.v_dimension_pobreza_canton_g5

WHERE cod_canton = '0101'

ORDER BY contribucion_pct DESC;

-- Consulta 044
CREATE VIEW DWHDEV.v_dimension_pobreza_provincia_g5 AS

SELECT

    a.cod_provincia,

    a.nombre_provincia,

    a.dimension,

    a.aporte_ponderado,

    ROUND(

        100.0 * a.aporte_ponderado

        / NULLIF(

            SUM(a.aporte_ponderado)

                OVER (PARTITION BY a.cod_provincia),

            0

        ),

        2

    ) AS contribucion_pct

FROM (

    SELECT

        p.cod_provincia,

        p.nombre_provincia,

        p.dimension,

        SUM(

            p.hogares_con_privacion * i.peso

        ) AS aporte_ponderado

    FROM DWHDEV.kpi_privaciones_canton_g5 p

    INNER JOIN DWHDEV.dim_indicadores_g5 i

        ON p.id_indicador = i.id_indicador

    GROUP BY

        p.cod_provincia,

        p.nombre_provincia,

        p.dimension

) a;

-- Consulta 045
SELECT

    cod_provincia,

    nombre_provincia,

    COUNT(*) AS total_dimensiones,

    ROUND(SUM(contribucion_pct), 2) AS suma_porcentajes

FROM DWHDEV.v_dimension_pobreza_provincia_g5

GROUP BY

    cod_provincia,

    nombre_provincia

ORDER BY cod_provincia;

-- Consulta 046
SELECT

    nombre_provincia,

    dimension AS dimension_predominante,

    contribucion_pct

FROM (

    SELECT

        nombre_provincia,

        dimension,

        contribucion_pct,

        ROW_NUMBER() OVER (

            PARTITION BY cod_provincia

            ORDER BY aporte_ponderado DESC

        ) AS posicion

    FROM DWHDEV.v_dimension_pobreza_provincia_g5

) t

WHERE posicion = 1

ORDER BY nombre_provincia;

-- Consulta 047
SELECT

    id_indicador,

    nombre_indicador,

    dimension,

    SUM(hogares_pobres_analizados) AS total_hogares_pobres,

    SUM(hogares_no_evaluables) AS total_no_evaluables,

    ROUND(

        100.0 * (

            SUM(hogares_con_privacion)

            \+ SUM(hogares_sin_privacion)

        )

        / NULLIF(SUM(hogares_pobres_analizados), 0),

        2

    ) AS cobertura_pct

FROM DWHDEV.kpi_privaciones_canton_g5

GROUP BY

    id_indicador,

    nombre_indicador,

    dimension

ORDER BY cobertura_pct ASC;

-- Consulta 048
SELECT

    COUNT(*) AS total_cantones,

    COUNT(DISTINCT cod_canton) AS cantones_unicos

FROM (

    SELECT

        cod_canton,

        ROW_NUMBER() OVER (

            PARTITION BY cod_canton

            ORDER BY aporte_ponderado DESC

        ) AS posicion

    FROM DWHDEV.v_dimension_pobreza_canton_g5

) t

WHERE posicion = 1;

-- Consulta 049
SELECT

    dimension AS dimension_predominante,

    COUNT(*) AS total_cantones

FROM (

    SELECT

        cod_canton,

        dimension,

        ROW_NUMBER() OVER (

            PARTITION BY cod_canton

            ORDER BY aporte_ponderado DESC, dimension

        ) AS posicion

    FROM DWHDEV.v_dimension_pobreza_canton_g5

) t

WHERE posicion = 1

GROUP BY dimension

ORDER BY total_cantones DESC;

-- Consulta 050
SELECT

    cod_canton,

    nombre_canton,

    nombre_provincia,

    dimension,

    contribucion_pct

FROM (

    SELECT

        cod_canton,

        nombre_canton,

        nombre_provincia,

        dimension,

        contribucion_pct,

        ROW_NUMBER() OVER (

            PARTITION BY cod_canton

            ORDER BY aporte_ponderado DESC, dimension

        ) AS posicion

    FROM DWHDEV.v_dimension_pobreza_canton_g5

) t

WHERE posicion = 1

  AND dimension = 'Vivienda y ambiente';

-- Consulta 051
SELECT

    cod_canton,

    nombre_canton,

    nombre_provincia,

    dimension,

    ROUND(aporte_ponderado, 2) AS aporte_ponderado,

    contribucion_pct

FROM DWHDEV.v_dimension_pobreza_canton_g5

WHERE cod_canton = '2202'

ORDER BY aporte_ponderado DESC;

-- Consulta 052
SELECT

    cod_canton,

    nombre_canton,

    dimension,

    contribucion_pct

FROM DWHDEV.v_dimension_pobreza_canton_g5

WHERE contribucion_pct IS NULL

   OR contribucion_pct < 0

   OR contribucion_pct > 100;

-- Consulta 053
WITH validaciones AS (

    SELECT

        '01 - Cantones analizados' AS validacion,

        COUNT(DISTINCT cod_canton) AS obtenido,

        221 AS esperado,

        0 AS tolerancia

    FROM DWHDEV.v_dimension_pobreza_canton_g5

    UNION ALL

    SELECT

        '02 - Provincias analizadas',

        COUNT(DISTINCT cod_provincia),

        24,

        0

    FROM DWHDEV.v_dimension_pobreza_provincia_g5

    UNION ALL

    SELECT

        '03 - Filas canton-dimension',

        COUNT(*),

        663,

        0

    FROM DWHDEV.v_dimension_pobreza_canton_g5

    UNION ALL

    SELECT

        '04 - Filas provincia-dimension',

        COUNT(*),

        72,

        0

    FROM DWHDEV.v_dimension_pobreza_provincia_g5

    UNION ALL

    SELECT

        '05 - Porcentajes cantonales invalidos',

        COUNT(*),

        0,

        0

    FROM DWHDEV.v_dimension_pobreza_canton_g5

    WHERE contribucion_pct IS NULL

       OR contribucion_pct < 0

       OR contribucion_pct > 100

    UNION ALL

    SELECT

        '06 - Porcentajes provinciales invalidos',

        COUNT(*),

        0,

        0

    FROM DWHDEV.v_dimension_pobreza_provincia_g5

    WHERE contribucion_pct IS NULL

       OR contribucion_pct < 0

       OR contribucion_pct > 100

    UNION ALL

    SELECT

        '07 - Cantones con suma incorrecta',

        COUNT(*),

        0,

        0

    FROM (

        SELECT cod_canton

        FROM DWHDEV.v_dimension_pobreza_canton_g5

        GROUP BY cod_canton

        HAVING ABS(SUM(contribucion_pct) - 100) > 0.02

    ) x

    UNION ALL

    SELECT

        '08 - Provincias con suma incorrecta',

        COUNT(*),

        0,

        0

    FROM (

        SELECT cod_provincia

        FROM DWHDEV.v_dimension_pobreza_provincia_g5

        GROUP BY cod_provincia

        HAVING ABS(SUM(contribucion_pct) - 100) > 0.02

    ) x

    UNION ALL

    SELECT

        '09 - Filas KPI privaciones',

        COUNT(*),

        1989,

        0

    FROM DWHDEV.kpi_privaciones_canton_g5

    UNION ALL

    SELECT

        '10 - Conteos inconsistentes',

        COUNT(*),

        0,

        0

    FROM DWHDEV.kpi_privaciones_canton_g5

    WHERE hogares_pobres_analizados <>

          hogares_con_privacion

        \+ hogares_sin_privacion

        \+ hogares_no_evaluables

    UNION ALL

    SELECT

        '11 - Diferencias con KPI pobreza',

        COUNT(*),

        0,

        0

    FROM DWHDEV.kpi_privaciones_canton_g5 p

    JOIN DWHDEV.kpi_pobreza_canton_g5 k

      ON p.cod_canton = k.cod_canton

    WHERE p.hogares_pobres_analizados <> k.hogares_pobres

    UNION ALL

    SELECT

        '12 - Dimensiones con peso incorrecto',

        COUNT(*),

        0,

        0

    FROM (

        SELECT dimension

        FROM DWHDEV.dim_indicadores_g5

        GROUP BY dimension

        HAVING ABS(SUM(peso) - (1.0 / 3.0)) > 0.0001

    ) x

)

SELECT

    validacion,

    obtenido,

    esperado,

    CASE

        WHEN ABS(obtenido - esperado) <= tolerancia

        THEN 'OK'

        ELSE 'REVISAR'

    END AS estado

FROM validaciones

ORDER BY validacion;

-- Consulta 054
SELECT

    nombre_provincia,

    total_hogares,

    hogares_pobres,

    hogares_evaluables,

    porcentaje_pobreza

FROM DWHDEV.kpi_pobreza_provincia_g5

ORDER BY porcentaje_pobreza DESC;

-- Consulta 055
SELECT

    cod_provincia,

    nombre_provincia,

    cod_canton,

    nombre_canton,

    total_hogares,

    porcentaje_pobreza

FROM DWHDEV.kpi_pobreza_canton_g5

WHERE cod_provincia = '20'

ORDER BY cod_canton;

-- Consulta 056
SELECT

    MIN(contribucion_pct) AS porcentaje_minimo,

    MAX(contribucion_pct) AS porcentaje_maximo,

    COUNT(*) AS total_registros

FROM DWHDEV.v_dimension_pobreza_canton_g5;

-- Consulta 057
SELECT *

FROM DWHDEV.v_dimension_pobreza_canton_g5

ORDER BY contribucion_pct DESC

LIMIT 10;

-- Consulta 058
SELECT

    *

FROM DWHDEV.v_dimension_pobreza_canton_g5

WHERE nombre_provincia = 'AZUAY'

ORDER BY nombre_canton, dimension;

-- Consulta 059
SELECT

    cod_canton,

    id_indicador,

    COUNT(*) AS cantidad_registros

FROM DWHDEV.kpi_privaciones_canton_g5

GROUP BY

    cod_canton,

    id_indicador

HAVING COUNT(*) > 1

ORDER BY cantidad_registros DESC;

-- Consulta 060
select * from DWHDEV.kpi_privaciones_canton_g5

SELECT

    cod_provincia,

    cod_canton,

    id_indicador,

    COUNT(*) AS cantidad_registros

FROM DWHDEV.kpi_privaciones_canton_g5

GROUP BY

    cod_provincia,

    cod_canton,

    id_indicador

HAVING COUNT(*) > 1

ORDER BY cantidad_registros DESC;

-- Consulta 061
SELECT

    COUNT(*) AS total_registros,

    SUM(

        CASE

            WHEN hogares_con_privacion

               \+ hogares_sin_privacion

               \+ hogares_no_evaluables

               \= hogares_pobres_analizados

            THEN 0

            ELSE 1

        END

    ) AS registros_con_diferencias,

    SUM(

        CASE

            WHEN hogares_con_privacion IS NULL

              OR hogares_sin_privacion IS NULL

              OR hogares_no_evaluables IS NULL

              OR hogares_pobres_analizados IS NULL

            THEN 1

            ELSE 0

        END

    ) AS registros_con_nulos

FROM DWHDEV.kpi_privaciones_canton_g5

SELECT

    nombre_indicador,

    SUM(hogares_con_privacion) AS hogares_con_privacion,

    SUM(hogares_sin_privacion) AS hogares_sin_privacion,

    ROUND(

        100.0 * SUM(hogares_con_privacion)

        / NULLIF(

            SUM(hogares_con_privacion)

            \+ SUM(hogares_sin_privacion),

            0

        ),

        2

    ) AS porcentaje_privacion

FROM DWHDEV.kpi_privaciones_canton_g5

WHERE nombre_provincia = 'AZUAY'

GROUP BY nombre_indicador

ORDER BY porcentaje_privacion DESC;


-- ============================================================================
-- 10. VALIDACIONES Y CONSULTAS GENERALES
-- ============================================================================

-- Consulta 001
SELECT DATABASE() AS base_actual;


-- ============================================================================
-- ANEXO A. OPERACIONES DE BORRADO (DESACTIVADAS POR SEGURIDAD)
-- Estas sentencias estaban en el archivo original. NO se ejecutan.
-- ============================================================================

-- drop table CPV_2022_Vivienda_Canton_g5
--
--  drop table CPV_2022_Poblacion_Canton_g5
--
--  drop table CPV_2022_Hogar_Canton_g5
--
--  drop table BDDenemdu_personas_2022_anual_g5 _2022_anual_g5
--
--  drop table en
--
--  SELECT
--
--     TABLE_NAME,
--
--     COLUMN_NAME,
--
--     DATA_TYPE,
--
--     CHARACTER_MAXIMUM_LENGTH,
--
--     NUMERIC_PRECISION
--
-- FROM INFORMATION_SCHEMA.COLUMNS
--
-- WHERE TABLE_SCHEMA = DATABASE()
--
-- AND (
--
--     (TABLE_NAME = 'CPV_2022_Hogar_Canton_g5'
--
--         AND COLUMN_NAME IN ('H0801N', 'H0802N'))
--
--     OR
--
--     (TABLE_NAME = 'CPV_2022_Poblacion_Canton_g5'
--
--         AND COLUMN_NAME IN (
--
--             'P18R', 'P1001', 'P0602',
--
--             'P18', 'P1003', 'P1005', 'P0803A'
--
--         ))
--
--     OR
--
--     (TABLE_NAME = 'CPV_2022_Vivienda_Canton_g5'
--
--         AND COLUMN_NAME IN (
--
--             'V15', 'V0202', 'TOTPER'
--
--         ))
--
-- )
--
-- ORDER BY TABLE_NAME, COLUMN_NAME;

-- select * from BDDenemdu_personas_2022_anual_g5
--
-- drop table  raw_inec_nbi_8_1_pobreza_por_canton_provincia_g5
--
-- drop table raw_inec_nbi_8_2_pobreza_por_parroquia_g5
--
-- drop table raw_inec_nbi_10_1_pobreza_por_canton_NBI_g5
--
-- drop table raw_inec_nbi_10_2_pobreza_por_parroquia_NBI_g5
--
-- drop table raw_inec_nbi_1_1_pobreza_poblacion_por_canton_g5
--
-- drop table raw_inec_nbi_9_1_pobreza_extrema_por_nbi_g5
--
-- SELECT
--
--     TABLE_NAME,
--
--     TABLE_ROWS
--
-- FROM INFORMATION_SCHEMA.TABLES
--
-- WHERE TABLE_SCHEMA = DATABASE()
--
-- ORDER BY TABLE_NAME;

-- drop table stg_CPV_2022_Poblacion_Canton_g5
--
-- drop table stg_CPV_2022_Vivienda_Canton_g5
--
-- drop table stg_CPV_2022_Hogar_Canton_g5
--
-- select * from
--
-- stg_CPV_2022_Vivienda_Canton_g5
--
-- limit 10
--
-- drop table reject_CPV_2022_Poblacion_Canton_g5
--
-- drop table reject_CPV_2022_Vivienda_Canton_g5
--
-- drop table reject_CPV_2022_Hogar_Canton_g5
--
-- drop table stg_inec_nbi_8_1_pobreza_por_canton_provincia_g5
--
-- drop table stg_inec_nbi_8_2_pobreza_por_parroquia_g5
--
-- select * from stg_inec_nbi_10_2_pobreza_por_parroquia_NBI_g5
--
-- drop table stg_inec_nbi_10_1_pobreza_por_canton_NBI_g5
--
-- drop table stg_inec_nbi_10_2_pobreza_por_parroquia_NBI_g5
--
-- drop table stg_inec_nbi_1_1_pobreza_poblacion_por_canton_g5
--
-- drop table stg_inec_nbi_9_1_pobreza_extrema_por_nbi_g5
--
-- select * from  reject_inec_nbi_8_1_pobreza_por_canton_provincia_g5
--
-- drop table reject_inec_nbi_8_2_pobreza_por_parroquia_g5
--
-- drop table reject_inec_nbi_10_1_pobreza_por_canton_NBI_g5
--
-- drop table reject_inec_nbi_10_2_pobreza_por_parroquia_NBI_g5
--
-- drop table reject_inec_nbi_1_1_pobreza_poblacion_por_canton_g5
--
-- drop table reject_inec_nbi_9_1_pobreza_extrema_por_nbi_g5
--
-- describe dim_indicadores_g5;

-- drop table DWHDEV.reject_dim_indicadores_g5
--
-- CREATE TABLE IF NOT EXISTS DWHDEV.reject_dim_indicadores_g5 (
--
--     id_indicador VARCHAR(3),
--
--     dimension VARCHAR(80),
--
--     nombre VARCHAR(150),
--
--     peso DECIMAL(12,10),
--
--     load_source VARCHAR(100),
--
--     motivo_rechazo VARCHAR(255),
--
--     load_ts DATETIME DEFAULT CURRENT_TIMESTAMP
--
-- );

-- drop TABLE DWHDEV.dim_indicadores_g5
--
-- ADD COLUMN etl_timestamp DATETIME
--
-- DEFAULT CURRENT_TIMESTAMP;

-- truncate table DWHDEV.fact_hogares_g5
--
-- drop table DWHDEV.reject_fact_hogares_g5
--
-- SELECT
--
--     COUNT(*) AS total_registros,
--
--     COUNT(DISTINCT id_hogar) AS total_hogares,
--
--     COUNT(DISTINCT id_indicador) AS total_indicadores
--
-- FROM DWHDEV.fact_hogares_g5;

-- truncate table DWHDEV.fact_hogares_g5
--
-- describe DWHDEV.fact_hogares_g5
--
-- drop table DWHDEV.reject_fact_hogares_g5
--
-- SELECT
--
--     canton,
--
--     COUNT(*) AS total_hogares
--
-- FROM DSADEV.stg_CPV_2022_Hogar_Canton_g5
--
-- GROUP BY canton
--
-- ORDER BY total_hogares DESC;


-- ============================================================================
-- ANEXO B. CONSULTAS DE OTRO ESQUEMA (DSADEV)
-- Conservadas como referencia; no pertenecen al núcleo INEC G5.
-- ============================================================================

SELECT 'ORIGEN' AS tabla, COUNT(*) AS registros

FROM DSADEV.pedidos_origen_kch

UNION ALL

SELECT 'VALIDOS', COUNT(*)

FROM DSADEV.ventas_validas_kch

UNION ALL

SELECT 'RECHAZADOS', COUNT(*)

FROM DSADEV.pedidos_rechazados_kch;

SELECT pedido_id, estado_pedido, motivo_rechazo

FROM DSADEV.pedidos_rechazados_kch;

SELECT

    COUNT(DISTINCT f.id_hogar) AS hogares_sin_vivienda

FROM DWHDEV.fact_hogares_g5 f

LEFT JOIN DSADEV.stg_CPV_2022_Vivienda_Canton_g5 v

    ON f.id_vivienda = v.id_viv

WHERE f.fuente_datos = 'CPV'

  AND f.id_indicador = 'I03'

  AND v.id_viv IS NULL;

SELECT

    f.id_hogar,

    f.id_vivienda,

    v.privacion_agua,

    v.privacion_saneamiento,

    v.privacion_deficit_habitacional,

    v.privacion_basura,

    v.privacion_electricidad

FROM DWHDEV.fact_hogares_g5 f

JOIN DSADEV.stg_CPV_2022_Vivienda_Canton_g5 v

    ON f.id_vivienda = v.id_viv

WHERE f.fuente_datos = 'CPV'

  AND f.id_indicador = 'I03'

  AND f.es_privacion IS NULL

LIMIT 20;

SELECT

    v.id_viv,

    v.canton,

    v.aur,

    v.v0201,

    v.privacion_agua,

    v.privacion_saneamiento,

    v.privacion_deficit_habitacional,

    v.privacion_basura,

    v.privacion_electricidad

FROM DSADEV.stg_CPV_2022_Vivienda_Canton_g5 v

JOIN (

    SELECT DISTINCT id_vivienda

    FROM DWHDEV.fact_hogares_g5

    WHERE fuente_datos = 'CPV'

      AND id_indicador = 'I03'

      AND es_privacion IS NULL

) f

    ON v.id_viv = f.id_vivienda

LIMIT 20;

SELECT

    v.v0201,

    COUNT(*) AS total_viviendas,

    SUM(CASE

        WHEN v.privacion_agua IS NULL THEN 1

        ELSE 0

    END) AS agua_null,

    SUM(CASE

        WHEN v.privacion_saneamiento IS NULL THEN 1

        ELSE 0

    END) AS saneamiento_null,

    SUM(CASE

        WHEN v.privacion_electricidad IS NULL THEN 1

        ELSE 0

    END) AS electricidad_null

FROM DSADEV.stg_CPV_2022_Vivienda_Canton_g5 v

WHERE v.v0201 IN (1, 2)

GROUP BY v.v0201

ORDER BY v.v0201;

SELECT

    v0201,

    COUNT(*) AS total_viviendas,

    SUM(CASE WHEN privacion_agua IS NULL

        THEN 1 ELSE 0 END) AS agua_null,

    SUM(CASE WHEN privacion_saneamiento IS NULL

        THEN 1 ELSE 0 END) AS saneamiento_null,

    SUM(CASE WHEN privacion_deficit_habitacional IS NULL

        THEN 1 ELSE 0 END) AS deficit_null,

    SUM(CASE WHEN privacion_basura IS NULL

        THEN 1 ELSE 0 END) AS basura_null,

    SUM(CASE WHEN privacion_electricidad IS NULL

        THEN 1 ELSE 0 END) AS electricidad_null

FROM DSADEV.stg_CPV_2022_Vivienda_Canton_g5

GROUP BY v0201

ORDER BY v0201;

DESCRIBE DSADEV.stg_CPV_2022_Vivienda_Canton_g5;

SELECT

    v0201,

    COUNT(*) AS total,

    SUM(CASE

        WHEN v10 IS NOT NULL THEN 1 ELSE 0

    END) AS con_v10,

    SUM(CASE

        WHEN v11 IS NOT NULL THEN 1 ELSE 0

    END) AS con_v11,

    SUM(CASE

        WHEN v12 IS NOT NULL THEN 1 ELSE 0

    END) AS con_v12,

    SUM(CASE

        WHEN v14 IS NOT NULL THEN 1 ELSE 0

    END) AS con_v14,

    SUM(CASE

        WHEN def_hab IS NOT NULL THEN 1 ELSE 0

    END) AS con_def_hab

FROM DSADEV.stg_CPV_2022_Vivienda_Canton_g5

GROUP BY v0201

ORDER BY v0201;

SELECT

    v.v0201,

    COUNT(DISTINCT h.id_hog) AS hogares,

    COUNT(DISTINCT h.id_viv) AS viviendas

FROM DSADEV.stg_CPV_2022_Hogar_Canton_g5 h

JOIN DSADEV.stg_CPV_2022_Vivienda_Canton_g5 v

    ON h.id_viv = v.id_viv

GROUP BY v.v0201

ORDER BY v.v0201;

SELECT

    v0201,

    COUNT(*) AS total_viviendas,

    SUM(CASE

        WHEN v10 IS NULL OR TRIM(v10) = ''

        THEN 1 ELSE 0

    END) AS v10_vacios,

    SUM(CASE

        WHEN v11 IS NULL OR TRIM(v11) = ''

        THEN 1 ELSE 0

    END) AS v11_vacios,

    SUM(CASE

        WHEN v12 IS NULL OR TRIM(v12) = ''

        THEN 1 ELSE 0

    END) AS v12_vacios,

    SUM(CASE

        WHEN v14 IS NULL OR TRIM(v14) = ''

        THEN 1 ELSE 0

    END) AS v14_vacios,

    SUM(CASE

        WHEN def_hab IS NULL OR TRIM(def_hab) = ''

        THEN 1 ELSE 0

    END) AS def_hab_vacios

FROM DSADEV.stg_CPV_2022_Vivienda_Canton_g5

GROUP BY v0201

ORDER BY v0201;

SELECT

    id_viv,

    v0201,

    CONCAT('[', v10, ']') AS v10,

    CONCAT('[', v11, ']') AS v11,

    CONCAT('[', v12, ']') AS v12,

    CONCAT('[', v14, ']') AS v14,

    CONCAT('[', def_hab, ']') AS def_hab,

    privacion_agua,

    privacion_saneamiento,

    privacion_deficit_habitacional

FROM DSADEV.stg_CPV_2022_Vivienda_Canton_g5

WHERE v0201 = 2

LIMIT 20;

SELECT

    COUNT(*) AS hogares_sin_vivienda

FROM DSADEV.stg_CPV_2022_Hogar_Canton_g5 h

LEFT JOIN DSADEV.stg_CPV_2022_Vivienda_Canton_g5 v

    ON h.id_viv = v.id_viv

WHERE v.id_viv IS NULL;

SELECT

    v0201,

    v10,

    v11,

    v12,

    v14,

    def_hab,

    COUNT(*) AS total_viviendas

FROM DSADEV.stg_CPV_2022_Vivienda_Canton_g5

WHERE v0201 IN (1, 2)

GROUP BY

    v0201,

    v10,

    v11,

    v12,

    v14,

    def_hab

ORDER BY

    v0201,

    total_viviendas DESC

LIMIT 30;

SELECT

    COUNT(*) AS total_filas,

    COUNT(id_hog) AS hogares_con_id,

    COUNT(DISTINCT id_hog) AS hogares_unicos,

    SUM(CASE

        WHEN id_hog IS NULL OR TRIM(id_hog) = ''

        THEN 1 ELSE 0

    END) AS ids_nulos_o_vacios

FROM DSADEV.stg_CPV_2022_Hogar_Canton_g5;

SELECT

    v.v0201,

    h.imp_vopa,

    COUNT(DISTINCT h.id_hog) AS total_hogares,

    SUM(

        CASE

            WHEN v.privacion_agua IS NULL

            THEN 1 ELSE 0

        END

    ) AS agua_null,

    SUM(

        CASE

            WHEN v.privacion_saneamiento IS NULL

            THEN 1 ELSE 0

        END

    ) AS saneamiento_null,

    SUM(

        CASE

            WHEN v.privacion_deficit_habitacional IS NULL

            THEN 1 ELSE 0

        END

    ) AS deficit_null

FROM DSADEV.stg_CPV_2022_Hogar_Canton_g5 h

JOIN DSADEV.stg_CPV_2022_Vivienda_Canton_g5 v

    ON h.id_viv = v.id_viv

WHERE v.v0201 IN (1, 2)

GROUP BY

    v.v0201,

    h.imp_vopa

ORDER BY

    v.v0201,

    h.imp_vopa;

SELECT

    v.v0201,

    h.imp_vopa,

    COUNT(*) AS hogares

FROM DSADEV.stg_CPV_2022_Hogar_Canton_g5 h

JOIN DSADEV.stg_CPV_2022_Vivienda_Canton_g5 v

    ON h.id_viv = v.id_viv

GROUP BY

    v.v0201,

    h.imp_vopa

ORDER BY

    v.v0201,

    h.imp_vopa;

SELECT

    COUNT(*) AS total_hogares,

    SUM(CASE WHEN v.id_viv IS NULL THEN 1 ELSE 0 END)

        AS sin_vivienda,

    SUM(CASE WHEN v.v0201 IS NULL THEN 1 ELSE 0 END)

        AS ocupacion_null,

    SUM(CASE WHEN v.v0201 IN (1, 2) THEN 1 ELSE 0 END)

        AS ocupacion_1_2,

    SUM(CASE WHEN v.v0201 IN (3, 4, 5) THEN 1 ELSE 0 END)

        AS ocupacion_3_5

FROM DSADEV.stg_CPV_2022_Hogar_Canton_g5 h

LEFT JOIN DSADEV.stg_CPV_2022_Vivienda_Canton_g5 v

    ON h.id_viv = v.id_viv;

DSADEV.stg_enemdu_personas_gr5

DSADEV.stg_enemdu_vivienda_gr5

CREATE TABLE DWHDEV.kpi_pobreza_canton_g5 AS

SELECT

    g.cod_provincia,

    g.nombre_provincia,

    g.cod_canton,

    g.nombre_canton,

    COUNT(*) AS total_hogares,

    SUM(CASE

        WHEN p.situacion = 'POBRE_CONFIRMADO'

        THEN 1 ELSE 0

    END) AS hogares_pobres,

    SUM(CASE

        WHEN p.situacion = 'NO_POBRE_CONFIRMADO'

        THEN 1 ELSE 0

    END) AS hogares_no_pobres,

    SUM(CASE

        WHEN p.situacion = 'INDETERMINADO'

        THEN 1 ELSE 0

    END) AS hogares_indeterminados,

    SUM(CASE

        WHEN p.es_pobre IS NOT NULL

        THEN 1 ELSE 0

    END) AS hogares_evaluables,

    ROUND(

        100.0 * SUM(CASE

            WHEN p.es_pobre = 1 THEN 1 ELSE 0

        END)

        / NULLIF(SUM(CASE

            WHEN p.es_pobre IS NOT NULL THEN 1 ELSE 0

        END), 0),

        2

    ) AS porcentaje_pobreza,

    ROUND(

        100.0 * SUM(CASE

            WHEN p.es_pobre IS NOT NULL THEN 1 ELSE 0

        END) / NULLIF(COUNT(*), 0),

        2

    ) AS cobertura_evaluable

FROM DWHDEV.v_pobreza_hogar_g5 p

JOIN DWHDEV.dim_geografia_g5 g

    ON p.id_geografia = g.id_geografia

GROUP BY

    g.cod_provincia,

    g.nombre_provincia,

    g.cod_canton,

    g.nombre_canton;

CREATE VIEW DWHDEV.v_comparacion_nbi_g5 AS

SELECT

    k.cod_provincia,

    k.nombre_provincia,

    k.cod_canton,

    k.nombre_canton,

    -- Resultados del Grupo 5

    k.total_hogares,

    k.hogares_pobres,

    k.hogares_indeterminados,

    k.hogares_evaluables,

    k.porcentaje_pobreza

        AS pobreza_multidimensional_g5,

    k.cobertura_evaluable,

    -- Resultado oficial del INEC

    n.pct_pobreza_nbi

        AS pobreza_nbi_oficial,

    -- Diferencia en puntos porcentuales

    ROUND(

        k.porcentaje_pobreza - n.pct_pobreza_nbi,

        2

    ) AS diferencia_puntos_porcentuales

FROM DWHDEV.kpi_pobreza_canton_g5 k

LEFT JOIN (

    SELECT

        provincia,

        canton,

        pct_pobreza_nbi

    FROM DSADEV.stg_inec_nbi_8_1_pobreza_por_canton_provincia_g5

    WHERE canton NOT LIKE 'Total%'

      AND TRIM(area) = CONCAT('Total ', TRIM(canton))

) n

ON REPLACE(UPPER(TRIM(k.nombre_provincia)), ' ', '')

 \= REPLACE(UPPER(TRIM(n.provincia)), ' ', '')

AND REPLACE(UPPER(TRIM(k.nombre_canton)), ' ', '')

 \= REPLACE(UPPER(TRIM(n.canton)), ' ', '');

