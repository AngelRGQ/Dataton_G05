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


## 8. Dashboard gubernamental

El tablero en Tableau utiliza las tablas y vistas analíticas de SingleStore:

- `kpi_pobreza_canton_g5`
- `kpi_pobreza_provincia_g5`
- `kpi_privaciones_canton_g5`
- `v_comparacion_nbi_g5`
- `v_dimension_pobreza_canton_g5`
- `v_dimension_pobreza_provincia_g5`

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

## 10. Conclusiones

Se desarrolló una solución de ingeniería de datos que integra información oficial del Ecuador y permite analizar nueve indicadores de privación en más de cinco millones de hogares.

Los resultados obtenidos permiten identificar condiciones de pobreza multidimensional por cantón y provincia, analizar las principales privaciones y comparar la medición adaptada del Grupo 5 con el NBI oficial del INEC.

La arquitectura implementada integra procesos ETL, controles de calidad, almacenamiento analítico, auditoría y herramientas de gobierno y visualización de datos.

---

**Datatón Genius Lab IV — Grupo 5 | Sector Público | Ecuador 2022**


---

## Documentaci�n adicional de OpenMetadata

# DATATON GRUPO 5 ÔÇö Gesti├│n, linaje y calidad de datos con OpenMetadata

Proyecto acad├®mico de documentaci├│n, catalogaci├│n, trazabilidad y evaluaci├│n de calidad de datos utilizando **OpenMetadata**, **Docker** y scripts de **Python**. El trabajo se centra en organizar activos de datos asociados al an├ílisis sociodemogr├ífico, incluyendo fuentes relacionadas con el INEC, poblaci├│n, pobreza y ENEMDU.

> **Estado del proyecto:** se ha comprobado que una instancia local de OpenMetadata funciona en Docker. Tambi├®n se ha ejecutado un script de linaje, pero en una ejecuci├│n documentada los cuatro jobs devolvieron errores `404` por tablas no encontradas. No se ha confirmado a├║n la creaci├│n exitosa de todos los linajes ni de las pruebas de calidad.

## Objetivos

- Centralizar la documentaci├│n de bases de datos, esquemas, tablas y columnas.
- Facilitar el descubrimiento de activos mediante el cat├ílogo de OpenMetadata.
- Representar el linaje de procesos de limpieza y transformaci├│n de datos.
- Establecer roles de consulta, administraci├│n e integraci├│n.
- Definir controles de calidad, por ejemplo, verificar que `id_vivienda` no contenga valores nulos.

## Tecnolog├¡as

| Tecnolog├¡a | Uso |
| --- | --- |
| OpenMetadata | Cat├ílogo, gobierno, linaje y pruebas de calidad de metadatos |
| Docker / Docker Compose | Despliegue de servicios |
| MySQL | Almacenamiento de metadatos de OpenMetadata en el Compose compartido |
| Elasticsearch | Indexaci├│n y b├║squeda |
| Python | Automatizaci├│n de registro de linaje |
| `requests` | Consumo de la API REST de OpenMetadata desde Python |
| Airflow / Ingestion | Componente de ingesta incluido en el Compose compartido; su ejecuci├│n local no est├í confirmada |

El archivo Compose compartido utiliza las im├ígenes `docker.getcollate.io/openmetadata/server:1.12.6`, `docker.getcollate.io/openmetadata/db:1.12.6`, `docker.elastic.co/elasticsearch/elasticsearch:9.3.0` y `docker.getcollate.io/openmetadata/ingestion:1.12.6`. **Verificar compatibilidad de versiones antes de un nuevo despliegue.**

## Arquitectura general

```text
Navegador / usuarios
        |
        v
OpenMetadata Server (localhost:8585)
        |                 \
        v                  v
      MySQL           Elasticsearch
        ^
        |
API REST de OpenMetadata <--- Scripts Python de linaje

[Airflow / Ingestion: opcional seg├║n el despliegue]
```

En el entorno local revisado se observaron tres contenedores saludables: `openmetadata_server`, `openmetadata_mysql` y `openmetadata_elasticsearch`. El Compose compartido incluye adem├ís migraciones y un servicio de ingesta.

## Requisitos

- Windows con PowerShell (o un sistema compatible con Docker).
- Docker Desktop y Docker Compose.
- Python 3 y `pip` para ejecutar los scripts.
- Memoria y almacenamiento suficientes para OpenMetadata, MySQL y Elasticsearch.
- Acceso autorizado a las fuentes de datos que se deseen catalogar.

## Puesta en marcha

### 1. Comprobar los servicios existentes

```powershell
docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
```

En la instalaci├│n local documentada se usaron estos puertos:

| Servicio | Puerto del host |
| --- | --- |
| OpenMetadata | `8585` (administraci├│n: `8586`) |
| MySQL | `3306` |
| Elasticsearch | `9200` y `9300` |

Abrir **http://localhost:8585** para acceder al cat├ílogo.

### 2. Desplegar desde Compose (solo en un entorno nuevo y revisado)

```powershell
docker compose config
docker compose up -d
```

**Precauci├│n:** el Compose recibido fija nombres como `openmetadata_server` y publica puertos ya usados por la instalaci├│n local. **No ejecutarlo directamente si OpenMetadata ya est├í funcionando.** Para una segunda instancia se deben aislar los nombres de contenedores, el proyecto Compose, los vol├║menes y la red, y cambiar los puertos publicados. Evitar `docker compose down -v` para no borrar datos.

### 3. Ejecutar el script de linaje

Desde la carpeta del proyecto:

```powershell
python -m pip install requests
python om_linaje_dataton_v2.py
```

Si se utiliza un entorno virtual, instalar las dependencias dentro de ese entorno. La configuraci├│n de URL, credenciales y token de API debe mantenerse fuera del c├│digo versionado.

## Organizaci├│n de datos y cat├ílogo

En el trabajo se mencionaron los siguientes identificadores de servicios y activos. **No deben asumirse equivalentes**: es necesario validar sus nombres exactos en OpenMetadata.

- Servicio configurado en una pantalla: `DB_DATATON_GRUPO5`.
- Servicio referenciado por el script en errores `404`: `BD_DATATON_G5`.
- Tabla utilizada en una prueba de calidad: `DATATON_GRUPO5.default.DWHDEV.fact_hogares_g5`.
- Columna seleccionada para la prueba: `id_vivienda`.

Los nombres completamente calificados (*Fully Qualified Names*, FQN) deben coincidir con el servicio, la base de datos, el esquema y la tabla registrados en el cat├ílogo.

## Procesos de linaje

El script `om_linaje_dataton_v2.py` intent├│ procesar los siguientes jobs:

| Job | Tabla que no pudo localizar en la ejecuci├│n registrada |
| --- | --- |
| `job_limpieza_inec_grupo5` | `BD_DATATON_G5.default.DSADEV.CPV_2022_Poblacion_Canton_g5` |
| `job_limpieza_inec_nbi_grupo5` | `BD_DATATON_G5.default.DSADEV.raw_inec_nbi_8_1_pobreza_por_canton_provincia_g5` |
| `job_limpieza_enemdu_grupo5` | `BD_DATATON_G5.default.DSADEV.BDDenemdu_personas_2022_anual_g5` |
| `Orquestador_Pobreza_Multidimensional_g5` | `BD_DATATON_G5.default.DSADEV.stg_CPV_2022_Poblacion_Canton_g5` |

**Resultado observado:** `0 jobs procesados, 4 con error`. La API respondi├│ `404 table instance ... not found`.

### Resoluci├│n de errores 404

1. Abrir **Explore ÔåÆ Tables** en OpenMetadata.
2. Buscar la tabla correspondiente.
3. Copiar su FQN exacto y compararlo con el del script.
4. Confirmar si el servicio real se llama `BD_DATATON_G5`, `DB_DATATON_GRUPO5` u otro nombre.
5. Si la tabla no existe en el cat├ílogo, configurar primero su registro/ingesta de metadatos.
6. Reejecutar el script y comprobar los linajes desde la interfaz.

No crear tablas ficticias solo para evitar los errores: el linaje debe apuntar a activos reales.

## Gobierno y roles

Se exploraron roles de OpenMetadata para distribuir responsabilidades:

| Rol | Uso previsto |
| --- | --- |
| Data Consumer | Consulta de activos y metadatos |
| Data Steward | Documentaci├│n, gobierno y mantenimiento de metadatos |
| Ingestion bot role | Automatizaci├│n de la ingesta |
| Lineage bot role | Automatizaci├│n del linaje |
| Profiler bot role | Perfilado de datos |
| Quality / Data quality bot role | Procesos autom├íticos de calidad |

Los permisos efectivos dependen de las pol├¡ticas asociadas a cada rol. Aplicar el principio de m├¡nimo privilegio.

## Calidad de datos

Se trabaj├│ con un caso de prueba de **nivel de columna**:

| Propiedad | Valor |
| --- | --- |
| Tabla | `DATATON_GRUPO5.default.DWHDEV.fact_hogares_g5` |
| Columna | `id_vivienda` |
| Tipo de prueba | `Column Values To Be Not Null` |
| Dimensi├│n | Completeness |
| Prop├│sito | Detectar valores nulos en el identificador de vivienda |

Durante la configuraci├│n se observ├│ un error de API: `Cannot deserialize value of type java.lang.String from Array value`, asociado a `CreateTestCase.parameterValues[].value`. Esto indica que la solicitud conten├¡a un arreglo donde la API esperaba una cadena de texto. **No hay evidencia en el registro disponible de que la prueba haya quedado guardada y ejecutada correctamente.**

Para diagnosticarlo, revisar en las herramientas de desarrollador del navegador la solicitud fallida a la API de casos de prueba, especialmente `parameterValues`, y corregir el formato del par├ímetro que la interfaz env├¡a.

## Problemas conocidos

| Problema | Diagn├│stico / acci├│n |
| --- | --- |
| `ModuleNotFoundError: No module named 'requests'` | Instalar con `python -m pip install requests` |
| `404 ... tables/name/... not found` | Validar FQN e ingesta previa de tablas |
| `Cannot deserialize ... String from Array` | Revisar `parameterValues[].value` en la solicitud de prueba de calidad |
| Conflictos al iniciar un segundo Compose | Aislar puertos, nombres, vol├║menes, redes y proyecto Compose |

## Seguridad y buenas pr├ícticas

- **No publicar** contrase├▒as, tokens, archivos `.env` con secretos ni claves de API.
- El Compose compartido contiene credenciales de ejemplo: reemplazarlas antes de utilizarlo en un entorno expuesto.
- **No subir** `docker-volume/db-data/`, archivos internos de MySQL, vol├║menes de Elasticsearch ni respaldos con datos sensibles.
- Revisar y anonimizar cualquier dato del INEC u otras fuentes seg├║n su licencia y condiciones de uso.
- Mantener copias de seguridad antes de migrar o modificar la instalaci├│n.
- Evitar levantar dos instancias completas de OpenMetadata en una misma m├íquina sin revisar consumo de CPU, RAM y disco.

### `.gitignore` sugerido

```gitignore
.env
.env.*
!.env.example
__pycache__/
*.py[cod]
.venv/
venv/
docker-volume/
*.log
*.sql
*.sql.gz
*.bak
*.rar
```

## Estructura sugerida del repositorio

```text
DATATON-GRUPO5/
Ôö£ÔöÇÔöÇ README.md
Ôö£ÔöÇÔöÇ docker-compose.yml          # Solo una versi├│n revisada y sin secretos
Ôö£ÔöÇÔöÇ om_linaje_dataton_v2.py     # Si se incorpora al repositorio
Ôö£ÔöÇÔöÇ .gitignore
Ôö£ÔöÇÔöÇ .env.example                # Variables sin valores secretos
ÔööÔöÇÔöÇ docs/                       # Capturas y documentaci├│n opcionales
```

Esta estructura es **una propuesta** y no una afirmaci├│n de que todos estos archivos est├®n ya presentes en el repositorio.

## Pr├│ximos pasos

- Confirmar el nombre real del servicio de base de datos en OpenMetadata.
- Completar el registro de tablas de origen y transformaci├│n.
- Corregir y verificar los cuatro jobs de linaje.
- Guardar y ejecutar las pruebas de calidad de datos.
- Documentar los resultados con capturas y evidencias verificables.
- Publicar el repositorio sin credenciales ni datos internos de Docker.

## Equipo

**DATATON ÔÇö Grupo 5**  
Proyecto acad├®mico de gesti├│n y trazabilidad de metadatos.

> Completar instituci├│n, integrantes, asignatura, fecha y licencia antes de la publicaci├│n final.
