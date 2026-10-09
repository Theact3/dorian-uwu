# Predicción de fuga de clientes (churn) en telecomunicaciones

Pre-entrega 1 – Analítica de Datos.

El proyecto construye la base de datos para predecir qué clientes abandonan una empresa de telecomunicaciones. Usa la base pública **IBM Telco Customer Churn 11.1.3+**: 7.043 clientes de California, EE.UU., en el tercer trimestre (Q3).

## Contenido

| Archivo | Descripción |
|---|---|
| [`informe_preentrega.md`](informe_preentrega.md) | Texto del informe: puntos 1.b, 2, 3, 4 y 5 (bibliografía APA) |
| [`etl_modelo_estrella.sql`](etl_modelo_estrella.sql) | ETL en MySQL 8: dos bases de origen, consolidación y modelo estrella |
| [`limpieza_churn.ipynb`](limpieza_churn.ipynb) | Limpieza de datos en Python (pandas) |
| [`limpieza_churn.py`](limpieza_churn.py) | El mismo código como script |

## Cómo reproducir

1. Descargar los 5 CSV desde [Kaggle – Telco customer churn (11.1.3+)](https://www.kaggle.com/datasets/ylchang/telco-customer-churn-1113).
2. En MySQL 8, ajustar las rutas de `LOAD DATA` en `etl_modelo_estrella.sql` y ejecutar el script.
3. Exportar `db_churn.clientes_consolidado` como `clientes_consolidado.csv` en la carpeta del proyecto.
4. Instalar las dependencias con `pip install pandas numpy jupyter` y ejecutar `limpieza_churn.ipynb`.

Al terminar se generan tres archivos: `churn_limpio_analisis.csv`, `churn_limpio_modelo.csv` y `bitacora_limpieza.csv`.
