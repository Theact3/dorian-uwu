# Pre-entrega 1 – Analítica de Datos: Predicción de fuga de clientes (churn) en telecomunicaciones

> El punto 1.a (contexto del problema y papers IEEE / ScienceDirect) se encuentra en el documento del grupo.

## 1.b Comparación de proyectos: países desarrollados vs. Chile

**Países desarrollados.** En Europa y Estados Unidos la predicción de churn se trabaja desde hace más de dos décadas, y las empresas suelen colaborar con la academia y publicar sus datos:

- **Orange (Francia)** liberó datos reales de clientes en la competencia *KDD Cup 2009*, que se volvieron un referente para evaluar modelos de churn. Idris et al. (2012) los usan para probar su modelo de Genetic Programming con AdaBoost.
- **Cell2Cell (EE.UU.)** facilitó su base de clientes móviles al *Teradata Center for CRM* de la Universidad de Duke para un torneo de modelos predictivos; es la segunda base usada por Idris et al. (2012).
- **Eircom (Irlanda)** entregó a la University College Dublin seis meses de detalle de llamadas de sus clientes, con los que Huang et al. (2010) construyeron más de 100 variables y aplicaron selección de atributos con NSGA-II.
- **IBM** publica la base *Telco Customer Churn* como dato de muestra de Cognos Analytics para enseñar analítica de churn (IBM, 2019), y **Amazon Web Services** ofrece una arquitectura de referencia para predecir y retener suscriptores con aprendizaje automático en la nube (Amazon Web Services, s.f.).

En estos casos, la predicción de churn es un proceso industrializado: se apoya en datos transaccionales masivos, en plataformas en la nube y en equipos de ciencia de datos que reentrenan los modelos de forma periódica.

**Chile.** El problema es igual o más relevante que en esos países. Desde la Ley 20.471, que creó la portabilidad numérica (implementada en 2012), un cliente puede cambiarse de compañía conservando su número, y la competencia por precio aumentó con la entrada de nuevos operadores. Hoy la Subsecretaría de Telecomunicaciones (Subtel) publica reportes periódicos de portaciones por compañía, y los operadores compiten por liderar las portaciones netas. Las principales diferencias con los países desarrollados son:

| Aspecto | Países desarrollados | Chile |
|---|---|---|
| Disponibilidad de datos | Las empresas liberan bases reales o anonimizadas (Orange, Cell2Cell, Eircom) y hay datos de muestra industriales (IBM) | No existen bases públicas de clientes de telecomunicaciones; la información pública es agregada (portaciones y abonados por compañía, de Subtel) |
| Publicación de proyectos | Hay papers conjuntos empresa-universidad y arquitecturas de referencia abiertas | Los modelos de las compañías son internos y no se publican; el desarrollo académico se concentra en universidades (por ejemplo, Maldonado et al., 2015, con selección de atributos orientada a la rentabilidad) |
| Enfoque | Modelos avanzados (ensambles, algoritmos genéticos, deep learning) sobre datos de uso detallados | El foco comercial está en las ofertas de retención y portabilidad; la analítica avanzada está menos documentada |

Por esta razón, el proyecto usa una base pública de referencia internacional (IBM Telco), cuya estructura (datos demográficos, de contrato, de servicios y de estado del cliente) es comparable a la que tendría un operador chileno. De esta forma, la metodología se puede replicar con datos locales.

---


## 2. Definición del problema, objetivos y características de la base de datos

### 2.1 Objetivo general

Desarrollar un modelo predictivo que, a partir de datos demográficos, contractuales, de consumo y geográficos de los clientes de una empresa de telecomunicaciones, identifique los patrones asociados a la fuga de clientes (*churn*) y estime la probabilidad de que un cliente abandone el servicio, para apoyar el diseño de estrategias de retención preventivas.

### 2.2 Objetivos específicos

1. Extraer e integrar, mediante consultas SQL, la información de clientes proveniente de dos bases de datos distintas (base de clientes y base de operaciones comerciales) en una base consolidada.
2. Diseñar e implementar un modelo estrella en SQL, con una tabla de hechos de clientes y tablas de dimensiones (cliente, ubicación, contrato y servicios), que facilite el análisis multidimensional del churn.
3. Limpiar y preparar la base consolidada con Python: tratar valores nulos, eliminar duplicados, codificar variables categóricas y excluir variables que filtren información del resultado (*data leakage*).
4. Caracterizar los patrones de comportamiento de los clientes que abandonan el servicio según el tipo de contrato, la antigüedad, el cargo mensual, los servicios contratados y la ubicación.
5. Dejar definida la variable objetivo (`churn_value`) y el conjunto de variables predictoras para la etapa de modelamiento de la entrega final.

### 2.3 Características de la base de datos original

Se usará la base **IBM Telco Customer Churn (versión 11.1.3+)**. Es un conjunto de datos de muestra que publica IBM para Cognos Analytics y que también está disponible en Kaggle. Representa a una compañía de telecomunicaciones ficticia que ofrece telefonía e Internet residencial.

| Característica | Detalle |
|---|---|
| Fuente | IBM Cognos Analytics, *Telco customer churn* (sample data); copia en Kaggle (ylchang, 2020) |
| Registros | 7.043 clientes, cada uno identificado por `Customer ID` |
| Lugar geográfico | Estado de California, Estados Unidos (1.106 ciudades, aprox. 1.600 códigos postales) |
| Periodo | Tercer trimestre (Q3) de un año fiscal; el estado del cliente se mide al cierre del trimestre |
| Variable objetivo | `Churn Value` (1 = abandonó en el trimestre, 0 = no abandonó) |
| Distribución de la variable objetivo | 1.869 clientes fugados (≈26,5 %), lo que constituye una clase minoritaria |
| Estado del cliente | `Customer Status`: *Stayed* (4.720), *Churned* (1.869), *Joined* (454) |

A diferencia de la versión resumida de Kaggle (un solo CSV de 21 columnas), esta versión trae la información repartida en cinco tablas relacionadas:

| Tabla | Llave | Contenido principal |
|---|---|---|
| Demographics | Customer ID | Género, edad, adulto mayor, estado civil, número de dependientes |
| Location | Customer ID | País, estado, ciudad, código postal, latitud y longitud |
| Population | Zip Code | Población estimada por código postal |
| Services | Customer ID | Antigüedad (meses), oferta, telefonía, tipo de Internet, servicios adicionales, contrato, método de pago, cargo mensual, cargos totales e ingresos totales |
| Status | Customer ID | Satisfacción, estado del cliente, churn (label/value), churn score, CLTV, categoría y motivo de la fuga |

### 2.4 Criterios de selección de la muestra

- **Geográfico:** se trabajará con todos los clientes de California. Como la base contiene un solo estado, no hace falta filtrar por territorio. Las variables de ubicación (ciudad, código postal y población) se conservan para analizar si la fuga se concentra en zonas determinadas.
- **Temporal:** se considera un solo periodo de observación, el Q3, porque es el único trimestre disponible. El análisis es de corte transversal: describe la situación del cliente al cierre del trimestre.
- **Clientes incluidos:** se excluyen los 454 clientes con estado *Joined*, que ingresaron durante el mismo trimestre. Todavía no ha transcurrido un periodo suficiente para observar si abandonan o no, y mantenerlos mezclaría clientes nuevos con clientes "que se quedaron". La muestra final queda en **6.589 clientes** (4.720 que permanecen y 1.869 que se fugan).
- **Variables excluidas por fuga de información:** `Churn Label`, `Churn Category`, `Churn Reason` y `Customer Status` se conocen solo después de que el cliente se fue, y `Churn Score` es una predicción previa de IBM. Se mantienen para el análisis descriptivo, pero no se usarán como predictores. `Satisfaction Score` queda en revisión, porque está casi determinada por el resultado.
- **Variables constantes:** `Count`, `Country`, `State` y `Quarter` tienen un único valor en toda la base y no aportan información, por lo que se eliminan.

### 2.5 Criterios de limpieza (se ejecutan en Python, punto 4)

1. **Duplicados:** se verifica que `customer_id` sea único después de las uniones (JOIN). Si un cliente aparece repetido, se conserva un solo registro.
2. **Valores nulos:**
   - En `Offer`, `Internet Type`, `Churn Category` y `Churn Reason`, el vacío significa "no aplica" (sin oferta, sin Internet, no se fugó), así que se reemplaza por la categoría `"None"` y no se imputa.
   - En variables numéricas con nulos reales, se imputa la mediana, que es menos sensible a valores extremos que la media.
3. **Coherencia lógica:** si un cliente no tiene Internet (`internet_service = 'No'`), sus servicios dependientes (seguridad, respaldo, streaming, etc.) deben ser `'No'`, y su descarga mensual en GB debe ser 0. Lo mismo se aplica a la telefonía y los cargos de larga distancia.
4. **Tipos de dato:** los montos y la antigüedad se convierten a numérico, y las variables Yes/No se pasan a binario (1/0).
5. **Codificación:** las variables categóricas con más de dos niveles (contrato, método de pago, tipo de Internet, oferta) se transforman con *one-hot encoding*.
6. **Valores atípicos:** se revisan `monthly_charge`, `total_charges` y `total_revenue` con el rango intercuartílico (IQR). Como son montos plausibles de clientes antiguos, se marcan, pero no se eliminan.
7. **Desbalance:** se registra la proporción 72/28 de la variable objetivo, que se considerará en la etapa de modelamiento (estratificación o re-muestreo).

---

## 3. Proceso ETL

### 3.a Extracción de datos con SQL

Las cinco tablas se cargan en dos bases de datos separadas en MySQL 8. Así se simula el escenario real de una empresa, donde la información del cliente y la operación comercial viven en sistemas distintos:

| Base de datos | Tablas | Rol |
|---|---|---|
| `db_clientes` | demographics, location, population | Sistema CRM / maestro de clientes |
| `db_operaciones` | services, status | Sistema de facturación y gestión comercial |

Con consultas `JOIN` entre ambas bases (por `customer_id` y `zip_code`) se crea la base consolidada `db_churn.clientes_consolidado`, aplicando el filtro de muestra (`customer_status <> 'Joined'`). El script completo está en [`etl_modelo_estrella.sql`](etl_modelo_estrella.sql).

**Repositorios utilizados:**
- IBM. (2019). *Telco customer churn (11.1.3+)* [Conjunto de datos]. IBM Cognos Analytics Base Samples. https://community.ibm.com/community/user/businessanalytics/blogs/steven-macko/2019/07/11/telco-customer-churn-1113
- Chang, Y. (2020). *Telco customer churn (11.1.3+)* [Conjunto de datos]. Kaggle. https://www.kaggle.com/datasets/ylchang/telco-customer-churn-1113

### 3.b Modelo estrella

La tabla de hechos tiene **un registro por cliente en el trimestre** y guarda las medidas numéricas y la variable objetivo. Las dimensiones describen al cliente desde cuatro ángulos:

```
                    ┌──────────────────┐
                    │   dim_cliente    │
                    │ sk_cliente (PK)  │
                    │ customer_id      │
                    │ gender, age      │
                    │ senior, married  │
                    │ dependents       │
                    └────────┬─────────┘
                             │
┌──────────────────┐ ┌───────┴──────────┐ ┌──────────────────┐
│  dim_ubicacion   │ │   fact_churn     │ │  dim_contrato    │
│ sk_ubicacion(PK) ├─┤ sk_cliente (FK)  ├─┤ sk_contrato (PK) │
│ city, zip_code   │ │ sk_ubicacion(FK) │ │ contract         │
│ lat, long        │ │ sk_contrato (FK) │ │ payment_method   │
│ population       │ │ sk_servicios(FK) │ │ paperless_billing│
└──────────────────┘ │ tenure_months    │ │ offer            │
                     │ monthly_charge   │ └──────────────────┘
                     │ total_charges    │
                     │ total_revenue    │ ┌──────────────────┐
                     │ total_refunds    │ │  dim_servicios   │
                     │ avg_gb_download  ├─┤ sk_servicios(PK) │
                     │ num_referrals    │ │ phone, internet  │
                     │ satisfaction     │ │ internet_type    │
                     │ cltv             │ │ security, backup │
                     │ churn_value      │ │ streaming, etc.  │
                     └──────────────────┘ └──────────────────┘
```

- **Grano:** cliente × trimestre (Q3).
- **Medidas:** antigüedad, cargo mensual, cargos totales, ingresos, reembolsos, consumo de datos, referidos, satisfacción, CLTV y `churn_value`.
- **Dimensiones:** `dim_cliente` (quién es), `dim_ubicacion` (dónde vive), `dim_contrato` (cómo paga y bajo qué condiciones) y `dim_servicios` (qué servicios usa). `dim_contrato` y `dim_servicios` guardan combinaciones únicas de atributos, lo que reduce la redundancia.

Con esto se pueden responder preguntas como "tasa de churn por tipo de contrato y tipo de Internet" o "churn por ciudad", con un solo JOIN por dimensión (ver consultas de validación al final del script).

---

## 4. Limpieza de datos con Python

La limpieza se hizo en Python (pandas) sobre la tabla `clientes_consolidado` que entrega el ETL en SQL. El código está en [`limpieza_churn.ipynb`](limpieza_churn.ipynb) (la misma versión como script está en [`limpieza_churn.py`](limpieza_churn.py)). Cada acción queda anotada en una bitácora (`bitacora_limpieza.csv`) con el número de registros afectados.

### 4.1 Diseño del proceso de limpieza

```
 clientes_consolidado (SQL, 6.589 filas)
            │
            ▼
 [1] Estandarización ── espacios, '' y 'None' → NaN
            │
            ▼
 [2] Duplicados ─────── customer_id único (1 fila por cliente)
            │
            ▼
 [3] Nulos ──────────── "no aplica" → 'None' | numéricas → mediana | categóricas → moda
            │
            ▼
 [4] Coherencia lógica ─ sin Internet ⇒ servicios = No, GB = 0
            │            sin telefonía ⇒ multiple_lines = No, larga distancia = 0
            ▼
 [5] Tipos de dato ──── montos y meses → numérico
            │
            ▼
 [6] Atípicos (IQR) ─── se marcan, no se eliminan
            │
            ├──────────────────────────────► churn_limpio_analisis.csv
            ▼                                (todas las variables, para el análisis descriptivo)
 [7] Fuga de información ── se excluyen churn_category, churn_reason,
            │               churn_score, satisfaction_score, customer_status
            ▼
 [8] Codificación ───── Yes/No → 1/0 | contrato, pago, tipo de Internet, oferta → one-hot
            │
            ▼
 churn_limpio_modelo.csv (100 % numérica, lista para modelar)
```

### 4.2 Criterios aplicados

| Paso | Criterio | Justificación |
|---|---|---|
| Estandarización | Se quitan espacios y los textos vacíos se convierten a `NaN` | Al importar los CSV, MySQL guarda las celdas vacías como texto vacío `''` y no como nulo; sin este paso, esos vacíos no aparecerían en el conteo de nulos |
| Duplicados | `customer_id` debe ser único; si un cliente se repite, se conserva el primer registro | El grano del modelo es un cliente; un registro repetido le daría más peso a ese cliente |
| Nulos estructurales | En `offer`, `internet_type`, `churn_category` y `churn_reason`, el vacío se reemplaza por `'None'` | Ahí el vacío significa "no aplica" (sin oferta, sin Internet, no se fugó); imputarlo con la moda crearía información falsa |
| Nulos numéricos | Se imputa la mediana | Los montos tienen distribución asimétrica y la mediana es menos sensible a los valores extremos que la media |
| Nulos categóricos | Se imputa la moda | Es el valor más probable y conserva las categorías que ya existen |
| Coherencia lógica | Los servicios que dependen de Internet o de telefonía se corrigen cuando el cliente no tiene el servicio base | Evita combinaciones imposibles que confundirían al modelo |
| Tipos | Los montos, meses y puntajes se convierten a numérico | Los cálculos estadísticos y los modelos requieren variables numéricas |
| Atípicos | Se usa la regla IQR (1,5×) para marcarlos, pero no se eliminan | Son clientes reales de alto consumo o con mucha antigüedad; eliminarlos sesgaría la muestra |
| Fuga de información | Las variables conocidas después de la fuga se excluyen de la base del modelo | Si se usaran, el modelo "conocería la respuesta" y su desempeño sería artificialmente alto |
| Alta cardinalidad | Se excluyen `city` y `zip_code` de la base del modelo | Hay más de 1.000 categorías; la ubicación queda representada por latitud, longitud y población |
| Codificación | Las binarias se pasan a 1/0 y las multinivel a *one-hot* con `drop_first` | Formato numérico que piden los algoritmos; `drop_first` evita la multicolinealidad perfecta |

### 4.3 Resultado

- **`churn_limpio_analisis.csv`:** base limpia con todas las variables, incluidos el motivo y la categoría de la fuga, para el análisis descriptivo de patrones.
- **`churn_limpio_modelo.csv`:** base 100 % numérica, sin nulos ni variables con fuga de información, con `churn_value` como variable objetivo.
- **`bitacora_limpieza.csv`:** el registro de cada criterio aplicado y la cantidad de filas afectadas. Las cifras de esta bitácora son las que se reportan en el informe.

---

## 5. Bibliografía

Amazon Web Services. (s.f.). *Guidance for subscriber churn prediction and retention on AWS*. https://aws.amazon.com/solutions/guidance/subscriber-churn-prediction-and-retention-on-aws/

Chang, Y. (2020). *Telco customer churn (11.1.3+)* [Conjunto de datos]. Kaggle. https://www.kaggle.com/datasets/ylchang/telco-customer-churn-1113

Huang, B., Buckley, B., & Kechadi, T.-M. (2010). Multi-objective feature selection by using NSGA-II for customer churn prediction in telecommunications. *Expert Systems with Applications, 37*(5), 3638–3646. https://doi.org/10.1016/j.eswa.2009.10.027

IBM. (2019). *Telco customer churn (11.1.3+)* [Conjunto de datos]. IBM Cognos Analytics Base Samples. https://community.ibm.com/community/user/businessanalytics/blogs/steven-macko/2019/07/11/telco-customer-churn-1113

Idris, A., Khan, A., & Lee, Y. S. (2012). Genetic programming and AdaBoosting based churn prediction for telecom. En *2012 IEEE International Conference on Systems, Man, and Cybernetics (SMC)* (pp. 1328–1332). IEEE. https://doi.org/10.1109/ICSMC.2012.6377917

Kimball, R., & Ross, M. (2013). *The data warehouse toolkit: The definitive guide to dimensional modeling* (3.ª ed.). Wiley.

Ley N.° 20.471. (2010). Crea el organismo administrador de la portabilidad numérica. Biblioteca del Congreso Nacional de Chile. https://www.bcn.cl/leychile

Maldonado, S., Flores, Á., Verbraken, T., Baesens, B., & Weber, R. (2015). Profit-based feature selection using support vector machines – General framework and an application for customer retention. *Applied Soft Computing, 35*, 740–748. https://doi.org/10.1016/j.asoc.2015.05.058

McKinney, W. (2010). Data structures for statistical computing in Python. En *Proceedings of the 9th Python in Science Conference* (pp. 56–61). https://doi.org/10.25080/Majora-92bf1922-00a

Subsecretaría de Telecomunicaciones. (s.f.). *Estadísticas del sector telecomunicaciones*. Gobierno de Chile. https://www.subtel.gob.cl/estudios-y-estadisticas/
