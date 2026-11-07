# Datatón Genius Lab IV — Grupo 5

## INEC: Pobreza multidimensional y tablero gubernamental

**Sector:** Público  
**Periodo de análisis:** 2022  
**Cobertura:** Ecuador, 24 provincias y 221 cantones

## 1. Descripción del proyecto

El proyecto tiene como objetivo analizar las condiciones de pobreza multidimensional de los hogares ecuatorianos mediante la integración de fuentes oficiales del INEC.

Se implementó un pipeline ETL con **Qlik Talend Studio** para la ingesta, transformación, validación y carga de información en **SingleStore**, complementado con **OpenMetadata** para el gobierno de datos y **Tableau** para la visualización de indicadores.

El análisis busca responder:

- ¿Qué cantones y provincias presentan mayores niveles de pobreza multidimensional?
- ¿Qué dimensiones e indicadores de privación predominan en cada territorio?
- ¿Cómo se comparan los resultados obtenidos con el NBI oficial del INEC?

## 2. Fuentes de datos

| Fuente | Información utilizada |
|---|---|
| Censo de Población y Vivienda 2022 | Personas, hogares, viviendas, educación y servicios básicos |
| ENEMDU 2022 | Ingresos, empleo y condiciones socioeconómicas |
| INEC — NBI 2022 | Pobreza por Necesidades Básicas Insatisfechas |
| Clasificador Geográfico 2022 | Códigos y nombres de provincias y cantones |

Los registros del Censo constituyen la fuente principal para el cálculo de privaciones por hogar. ENEMDU proporciona información complementaria.

## 3. Arquitectura y pipeline ETL

El procesamiento se organiza de la siguiente manera:

```text
Fuentes oficiales
       ↓
Talend — Ingesta
       ↓
SingleStore — RAW
       ↓
Talend — Limpieza y calidad
       ↓
SingleStore — STG / REJECT
       ↓
Talend — Job orquestador
       ↓
Dimensiones → FACT
       ↓
KPI cantonales y provinciales
       ↓
Tableau
```

**Capas de almacenamiento:**

- **RAW:** datos originales cargados.
- **STG:** datos transformados y validados.
- **REJECT:** registros que incumplen reglas de calidad.
- **DWH:** modelo dimensional e indicadores analíticos.

### Job orquestador

El Job `Orquestador_Pobreza_Multidimensional_g5` incorpora:

1. Inicialización y validación previa del proceso.
2. Comprobación del estado mediante componentes Java y consultas SQL.
3. Registro de auditoría de ejecución.
4. Carga secuencial de `dim_geografia_g5`, `dim_tiempo_g5`, `dim_indicadores_g5` y `fact_hogares_g5`.
5. Registro de errores y control de fallos mediante `OnSubjobError`, componentes de auditoría y `tDie`.

El modelo dimensional se almacena en la base `DWHDEV`, mientras que las tablas de preparación se encuentran en `DSADEV`.

## 4. Reglas de calidad de datos

Se implementaron validaciones durante la limpieza y la carga analítica.

| Regla | Control aplicado |
|---|---|
| DQ01 — Completitud | Identificadores obligatorios no nulos |
| DQ02 — Unicidad | Verificación de claves y registros duplicados |
| DQ03 — Validez | Rangos de edad y valores permitidos |
| DQ04 — Consistencia geográfica | Códigos y correspondencia provincia-cantón |
| DQ05 — Integridad referencial | Correspondencia de hogares, indicadores y geografía |
| DQ06 — Validez analítica | Privaciones con valores 0, 1 o NULL |

### Resultados de calidad verificados

| Métrica | Resultado |
|---|---:|
| Hogares analizados | 5.193.548 |
| Hogares con cantidad incorrecta de indicadores | 0 |
| Hogares con indicadores repetidos | 0 |
| Hogares con geografía inconsistente | 0 |
| Cantones con totales KPI inconsistentes | 0 |
| Correspondencia geográfica con NBI | 221 de 221 cantones |

**Completitud:** los campos obligatorios del modelo se verificaron durante el procesamiento. Los valores `NULL` de las privaciones se mantienen cuando un indicador no puede evaluarse y se reportan como no evaluables.

**Umbrales de aceptación:** ausencia de duplicados y errores de integridad en las claves analíticas; 100 % de correspondencia entre cantones para la comparación NBI. Las métricas de completitud por campo deben complementarse con los reportes de perfilado correspondientes.

## 5. Modelo dimensional e indicadores

El modelo utiliza tres dimensiones y una tabla de hechos:

| Tabla | Descripción |
|---|---|
| `dim_geografia_g5` | Provincias y cantones |
| `dim_tiempo_g5` | Fechas y periodos |
| `dim_indicadores_g5` | Nueve indicadores, dimensiones y pesos |
| `fact_hogares_g5` | Privaciones evaluadas por hogar, fecha e indicador |

### Indicadores utilizados

**Educación**
- I01: Inasistencia escolar
- I02: Logro educativo incompleto

**Agua y saneamiento**
- I03: Sin agua de empresa pública o municipio
- I04: Saneamiento inadecuado

**Vivienda y ambiente**
- I05: Hacinamiento
- I06: Déficit habitacional
- I07: Sin recolección municipal de basura
- I08: Sin electricidad por red pública
- I09: Uso de leña o carbón para cocinar

### Criterio de pobreza

Un hogar se clasifica como **pobre multidimensional confirmado** cuando presenta tres o más privaciones.

Los hogares también pueden clasificarse como no pobres confirmados o indeterminados, según la cantidad de privaciones verificadas y los indicadores no evaluables.

Se trata de un índice adaptado para el proyecto, no de una reproducción de la metodología oficial del INEC.

## 6. Resultados obtenidos

| Indicador | Resultado |
|---|---:|
| Hogares analizados | 5.193.548 |
| Registros en FACT | 46.741.932 |
| Cantones | 221 |
| Provincias | 24 |
| Hogares pobres confirmados | 1.195.578 |
| Hogares no pobres confirmados | 3.735.782 |
| Hogares indeterminados | 262.188 |
| Hogares clasificables | 4.931.360 |
| Pobreza multidimensional entre clasificables | 24,24 % |

### Análisis de privaciones

Entre los hogares pobres analizados, los indicadores con mayor proporción de privación evaluable fueron:

| Indicador | Porcentaje |
|---|---:|
| Déficit habitacional | 92,4 % |
| Sin agua de empresa pública o municipio | 82,9 % |
| Logro educativo incompleto | 75,1 % |

Las proporciones anteriores corresponden a los hogares pobres analizados y no representan la prevalencia entre todos los hogares del país.

### Comparación con NBI oficial

Se relacionaron los resultados del índice adaptado con el tabulado NBI 8.1 del INEC.

La comparación se realizó por provincia y cantón, utilizando exclusivamente los totales cantonales.

Durante la integración se identificó una diferencia de espacios en el nombre del cantón General Antonio Elizalde, solucionada mediante normalización SQL.

**Resultado:** 221 coincidencias de 221 cantones, sin duplicaciones ni territorios sin correspondencia.

La comparación permite calcular las diferencias entre ambos porcentajes de pobreza en puntos porcentuales.

## 7. Gobierno de datos y linaje

Se utiliza **OpenMetadata** para documentar los activos y las relaciones entre las distintas etapas de procesamiento.

El flujo de linaje considerado es:

```text
Fuente oficial
     ↓
RAW
     ↓
STG
     ↓
DIM / FACT
     ↓
KPI analíticos
     ↓
Dashboard
```

Los activos catalogados deben incluir su descripción, fuente, responsable y relaciones de origen a destino.

**Evidencias del catálogo:** incorporar las capturas de los activos y las relaciones de linaje efectivamente registradas en OpenMetadata, con un mínimo de tres activos relacionados.

## 8. Dashboard gubernamental

El tablero en Tableau utiliza las tablas y vistas analíticas de SingleStore:

- `kpi_pobreza_canton_g5`
- `kpi_pobreza_provincia_g5`
- `kpi_privaciones_canton_g5`
- `v_comparacion_nbi_g5`
- `v_dimension_pobreza_canton_g5`
- `v_dimension_pobreza_provincia_g5`

Las visualizaciones contempladas incluyen:

- Mapa coroplético de pobreza por cantón.
- Indicadores de pobreza por provincia.
- Ranking de cantones.
- Análisis de dimensiones e indicadores de privación.
- Comparación del índice adaptado con NBI oficial.

## 9. Ejecución y reproducibilidad

1. Clonar el repositorio.
2. Importar el proyecto en Qlik Talend Studio.
3. Configurar las conexiones y parámetros del contexto.
4. Verificar las bases `DSADEV` y `DWHDEV` en SingleStore.
5. Ejecutar los Jobs de ingesta y limpieza según las dependencias.
6. Ejecutar el Job orquestador.
7. Verificar las dimensiones, FACT y KPI mediante consultas SQL.
8. Conectar Tableau a las fuentes analíticas.
9. Revisar los activos y relaciones registrados en OpenMetadata.

No se deben publicar contraseñas ni credenciales de conexión en el repositorio.

## 10. Evidencias

Se recomienda organizar las evidencias del proyecto en las siguientes categorías:

- **Talend:** Jobs de ingesta, limpieza y orquestación.
- **Calidad:** reglas, resultados de perfilado y registros rechazados.
- **SingleStore:** modelo dimensional, KPI y consultas de validación.
- **OpenMetadata:** activos catalogados y linaje fuente-destino.
- **Tableau:** capturas del dashboard y sus indicadores.
- **GitHub:** historial de commits y documentación del proyecto.

## 11. Conclusiones

Se desarrolló una solución de ingeniería de datos que integra información oficial del Ecuador y permite analizar nueve indicadores de privación en más de cinco millones de hogares.

Los resultados obtenidos permiten identificar condiciones de pobreza multidimensional por cantón y provincia, analizar las principales privaciones y comparar la medición adaptada del Grupo 5 con el NBI oficial del INEC.

La arquitectura implementada integra procesos ETL, controles de calidad, almacenamiento analítico, auditoría y herramientas de gobierno y visualización de datos.

---

**Datatón Genius Lab IV — Grupo 5 | Sector Público | Ecuador 2022**
