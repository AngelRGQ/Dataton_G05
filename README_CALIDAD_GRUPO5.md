# INEC G5 — Calidad de datos y validaciones DQ

**Proyecto:** Análisis de pobreza multidimensional en Ecuador (CPV 2022 / fuentes INEC)  
**Arquitectura:** Talend → SingleStore (`DWHDEV`) → Tableau (`respaldo_2`) → OpenMetadata.  
**Tabla principal auditada:** `DWHDEV.fact_hogares_g5`.

## 1. Objetivo y criterio de aceptación

Se exige un mínimo de **5 reglas DQ activas** y un reporte de **completitud, unicidad y rango** para los campos clave. Se propone como **umbral de aprobación ≥ 99 %** para completitud y unicidad, y **100 %** para validez de dominio/rango en registros evaluables. Estos son **umbrales propuestos**, no valores medidos ni requisitos numéricos confirmados del evaluador.

**Estado actual:** se identificaron ocho pruebas DQ en OpenMetadata, pero con la evidencia disponible **no es posible confirmar que estén activas, su última ejecución ni sus porcentajes de cumplimiento**. Para cerrar el criterio de evaluación se debe ejecutar el SQL adjunto, registrar sus resultados y capturar la evidencia de las ejecuciones de OpenMetadata.

## 2. Inventario de reglas de calidad identificadas

| Regla OpenMetadata | Campo / control | Condición de aceptación | Activación y última ejecución |
|---|---|---|---|
| `DQ_F01_Hogar_NoNulo` | `id_hogar` | No nulo ni vacío | Por verificar |
| `DQ_F02_Vivienda_NoNulo` | `id_vivienda` | No nulo ni vacío | Por verificar |
| `DQ_F03_Geografia_NoNulo` | `id_geografia` | No nulo | Por verificar |
| `DQ_F04_Fecha_NoNulo` | `fecha` | No nula | Por verificar |
| `DQ_F05_Fuente_CPV` | `fuente_datos` | Valor `CPV` para el subconjunto censal | Por verificar |
| `DQ_F06_Indicador_Valido` | `id_indicador` | Código existente en `dim_indicadores_g5` | Por verificar |
| `DQ_F07_Privacion_Binaria` | `es_privacion` | 0, 1 o NULL (no evaluable) | Por verificar |
| `DQ_F08_Geografia_Existe` | `id_geografia` | Clave presente en `dim_geografia_g5` | Por verificar |

> La existencia de las pruebas en el catálogo no acredita que estén programadas, activas o aprobadas. Verificar estado de test suite, historial de ejecución y resultados en OpenMetadata.

## 3. Reporte de métricas — completar con mediciones reales

Ejecutar `INEC_G5_Medicion_Calidad.sql` en DBeaver y copiar los porcentajes calculados en esta tabla. La granularidad de la tabla de hechos es **hogar × indicador × fecha × fuente**, por lo que `id_hogar` se repite legítimamente: **no** debe exigirse unicidad de `id_hogar` aislado.

| Métrica | Campo / regla | Umbral propuesto | Resultado medido | Estado |
|---|---|---:|---:|---|
| Completitud | `id_hogar` | ≥ 99 % | Pendiente | Sin medir |
| Completitud | `id_vivienda` | ≥ 99 % | Pendiente | Sin medir |
| Completitud | `id_geografia` | ≥ 99 % | Pendiente | Sin medir |
| Completitud | `fecha` | ≥ 99 % | Pendiente | Sin medir |
| Completitud | `id_indicador` | ≥ 99 % | Pendiente | Sin medir |
| Unicidad | (`id_hogar`, `id_indicador`, `fecha`, `fuente_datos`) | ≥ 99 % | Pendiente | Sin medir |
| Rango/dominio | `es_privacion IN (0,1)` o NULL no evaluable | 100 % | Pendiente | Sin medir |
| Rango/dominio | `fecha` dentro del período censal esperado | 100 % | Pendiente | Sin medir |
| Integridad referencial | `id_geografia` en dimensión | 100 % | Pendiente | Sin medir |
| Integridad referencial | `id_indicador` en dimensión | 100 % | Pendiente | Sin medir |

**Fórmulas:** completitud = registros con valor / registros totales × 100; unicidad = combinaciones únicas / registros totales × 100; validez = registros con valor admitido / registros evaluados × 100. La regla de fecha se debe fijar según el alcance temporal efectivo de la carga; el SQL de ejemplo comprueba el año 2022, que puede necesitar ajuste si existen otros períodos legítimos.

## 4. Evidencias necesarias para demostrar cumplimiento

- Captura de OpenMetadata mostrando **al menos cinco pruebas habilitadas** y con ejecuciones recientes.
- Resultado de las consultas de medición de DBeaver, con fecha de ejecución y cantidad de registros.
- Tabla de métricas anterior rellenada con porcentajes reales y estado `APROBADO`/`NO APROBADO` según los umbrales.
- Evidencia de tratamiento de registros rechazados o no evaluables en Talend cuando corresponda.

## 5. Consideraciones metodológicas

- `es_privacion = NULL` puede significar **no evaluable** y no necesariamente un error de calidad. Se informa su porcentaje por separado.
- `fuente_datos = 'CPV'` aplica al subconjunto censal; no se debe marcar como error otra fuente legítima si la tabla integra múltiples fuentes.
- La unicidad se evalúa sobre la **clave compuesta**, no sobre `id_hogar` por separado.
- No se ejecutan operaciones destructivas en el script de medición.

## 6. Ejecución en DBeaver

1. Abrir `INEC_G5_Medicion_Calidad.sql` en una conexión SingleStore con acceso a `DWHDEV`.
2. Ejecutar las consultas individualmente (`Ctrl + Enter`).
3. Guardar los resultados o capturas e incorporarlos a la sección 3.
4. Confirmar en OpenMetadata que al menos cinco pruebas estén activas y con resultado reciente.

## 7. DQ Score inicial y justificación de los umbrales

### 7.1 Línea base (DQ Score inicial)

**DQ Score inicial: pendiente de recuperar de la primera ejecución registrada.** En las evidencias consultadas no aparece un valor numérico inicial verificable. No se debe presentar el umbral objetivo como si fuera el puntaje inicial, ni inventar un resultado.

**Cómo documentarlo:** consultar en OpenMetadata la primera ejecución del conjunto de pruebas de `DWHDEV.fact_hogares_g5` o la primera medición equivalente en DBeaver; registrar fecha, número de pruebas aprobadas, fallidas y el porcentaje calculado. Si se usa el porcentaje de pruebas aprobadas, declarar explícitamente la fórmula: `DQ Score = (pruebas aprobadas / pruebas ejecutadas) × 100`. No mezclar ese puntaje con el porcentaje de filas válidas: son métricas distintas.

| Indicador de seguimiento | Valor | Evidencia |
|---|---|---|
| DQ Score inicial | Pendiente de confirmar | Primera ejecución de OpenMetadata o medición inicial registrada |
| Umbral de completitud | ≥ 99 % | Criterio interno propuesto por el Grupo 5 |
| Umbral de unicidad de clave compuesta | ≥ 99 % | Criterio interno propuesto por el Grupo 5 |
| Umbral de validez de rango/dominio | 100 % en registros evaluables | Criterio interno propuesto por el Grupo 5 |
| DQ Score final medido | Pendiente de confirmar | Última ejecución de reglas DQ |

### 7.2 ¿Por qué elegimos esos umbrales según nuestras fuentes?

Las fuentes del proyecto son el **Censo de Población y Vivienda 2022 (CPV)** y tablas oficiales de **Necesidades Básicas Insatisfechas (NBI) del INEC**, integradas en SingleStore. Para elaborar indicadores por cantón se necesita que los identificadores de hogar, vivienda, geografía e indicador estén presentes y sean consistentes. Un código geográfico incorrecto puede asignar hogares al cantón equivocado; un indicador fuera de dominio puede distorsionar los cálculos de privación.

- **Completitud ≥ 99 %:** tolerancia operativa interna de hasta 1 % de ausencias en campos críticos, con registro y seguimiento de excepciones. No implica que ese porcentaje de ausencia sea metodológicamente aceptable para cualquier indicador.
- **Unicidad ≥ 99 %:** control de duplicados sobre la clave compuesta `id_hogar + id_indicador + fecha + fuente_datos`. `id_hogar` individualmente puede repetirse legítimamente.
- **Rango/dominio = 100 %:** los valores evaluables de `es_privacion` deben pertenecer al dominio `{0, 1}` y las referencias geográficas y de indicadores deben corresponder a dimensiones válidas. Los valores `NULL` que representen «no evaluable» se reportan por separado, no se convierten automáticamente en cero.

**Nota de trazabilidad:** los umbrales 99 % y 100 % son **decisiones de control del proyecto G5**, justificadas por la necesidad de consistencia de los datos censales y las agregaciones territoriales; **no se atribuyen como umbrales oficiales publicados por el INEC**. El resultado final solo podrá declararse «cumple» después de medir las reglas y verificar al menos cinco reglas activas con evidencia de ejecución.
