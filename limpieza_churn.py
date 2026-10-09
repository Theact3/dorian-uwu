# %% [markdown]
# # Punto 4 – Limpieza de datos con Python
# **Base:** `clientes_consolidado` (resultado del ETL en SQL, punto 3.a) — IBM Telco Customer Churn 11.1.3+, California, Q3.
#
# Flujo: carga → estandarización → duplicados → nulos → coherencia lógica → tipos → atípicos → fuga de información → codificación → exportación.

# %%
import numpy as np
import pandas as pd

pd.set_option("display.max_columns", 60)

bitacora = []  # registro de cada acción de limpieza para el informe


def registrar(paso, accion, filas_afectadas):
    bitacora.append({"paso": paso, "accion": accion, "filas_afectadas": int(filas_afectadas)})


# %% [markdown]
# ## 4.1 Carga de la base consolidada
# Opción A (por defecto): CSV exportado desde MySQL Workbench (`SELECT * FROM db_churn.clientes_consolidado` → Export).
# Opción B: lectura directa desde MySQL con SQLAlchemy (requiere `pip install sqlalchemy pymysql`).

# %%
RUTA_CSV = "clientes_consolidado.csv"
df = pd.read_csv(RUTA_CSV)

# Opción B:
# from sqlalchemy import create_engine
# engine = create_engine("mysql+pymysql://usuario:clave@localhost/db_churn")
# df = pd.read_sql("SELECT * FROM clientes_consolidado", engine)

print("Dimensión original:", df.shape)
df.head()

# %%
df.info()

# %% [markdown]
# ## 4.2 Estandarización de texto
# Se eliminan espacios sobrantes y los textos vacíos (`''`, que MySQL genera al importar celdas vacías) se convierten en `NaN` para tratarlos como nulos.

# %%
cols_texto = df.select_dtypes(include=["object", "string"]).columns
nulos_antes = int(df[cols_texto].isnull().sum().sum())
for c in cols_texto:
    df[c] = df[c].astype(str).str.strip().replace({"": np.nan, "nan": np.nan, "None": np.nan})
registrar("4.2", "Textos vacíos o 'None' convertidos a NaN",
          df[cols_texto].isnull().sum().sum() - nulos_antes)

# %% [markdown]
# ## 4.3 Duplicados
# Se verifica que `customer_id` sea único (un registro por cliente, grano del modelo).

# %%
dup_id = df.duplicated(subset="customer_id").sum()
dup_total = df.duplicated().sum()
print(f"Duplicados por customer_id: {dup_id} | filas idénticas: {dup_total}")
df = df.drop_duplicates(subset="customer_id", keep="first").reset_index(drop=True)
registrar("4.3", "Registros duplicados eliminados (customer_id)", dup_id)

# %% [markdown]
# ## 4.4 Valores nulos

# %%
nulos = df.isnull().sum()
tabla_nulos = pd.DataFrame({"nulos": nulos, "%": (nulos / len(df) * 100).round(2)})
tabla_nulos[tabla_nulos["nulos"] > 0].sort_values("nulos", ascending=False)

# %% [markdown]
# **Criterio:** en `offer`, `internet_type`, `churn_category` y `churn_reason` el vacío significa *“no aplica”* (sin oferta, sin Internet, no se fugó), por lo que se reemplaza por la categoría `"None"`. Las numéricas con nulos reales se imputan con la **mediana** (robusta a valores extremos); las categóricas restantes, con la **moda**.

# %%
cols_no_aplica = ["offer", "internet_type", "churn_category", "churn_reason"]
for c in cols_no_aplica:
    n = df[c].isnull().sum()
    df[c] = df[c].fillna("None")
    registrar("4.4", f"{c}: vacío → 'None' (no aplica)", n)

cols_num = [
    "age", "number_of_dependents", "latitude", "longitude", "population",
    "number_of_referrals", "tenure_in_months", "avg_monthly_long_distance_charges",
    "avg_monthly_gb_download", "monthly_charge", "total_charges", "total_refunds",
    "total_extra_data_charges", "total_long_distance_charges", "total_revenue",
    "satisfaction_score", "churn_value", "churn_score", "cltv",
]
for c in cols_num:
    df[c] = pd.to_numeric(df[c], errors="coerce")  # 4.6 tipos: texto → número

for c in cols_num:
    n = df[c].isnull().sum()
    if n:
        df[c] = df[c].fillna(df[c].median())
        registrar("4.4", f"{c}: nulos imputados con mediana", n)

for c in df.select_dtypes(include=["object", "string"]).columns:
    n = df[c].isnull().sum()
    if n:
        df[c] = df[c].fillna(df[c].mode()[0])
        registrar("4.4", f"{c}: nulos imputados con moda", n)

print("Nulos restantes:", int(df.isnull().sum().sum()))

# %% [markdown]
# ## 4.5 Coherencia lógica entre variables
# - Sin Internet ⇒ servicios dependientes = `No`, `internet_type = None`, descarga = 0.
# - Sin telefonía ⇒ `multiple_lines = No` y cargos de larga distancia = 0.

# %%
serv_internet = ["online_security", "online_backup", "device_protection_plan",
                 "premium_tech_support", "streaming_tv", "streaming_movies",
                 "streaming_music", "unlimited_data"]
sin_internet = df["internet_service"] == "No"
inconsist = (sin_internet & ((df[serv_internet] == "Yes").any(axis=1)
                             | (df["avg_monthly_gb_download"] > 0)
                             | (df["internet_type"] != "None"))).sum()
df.loc[sin_internet, serv_internet] = "No"
df.loc[sin_internet, "avg_monthly_gb_download"] = 0
df.loc[sin_internet, "internet_type"] = "None"
registrar("4.5", "Inconsistencias corregidas en clientes sin Internet", inconsist)

sin_fono = df["phone_service"] == "No"
inconsist = (sin_fono & ((df["multiple_lines"] == "Yes")
                         | (df["avg_monthly_long_distance_charges"] > 0)
                         | (df["total_long_distance_charges"] > 0))).sum()
df.loc[sin_fono, "multiple_lines"] = "No"
df.loc[sin_fono, ["avg_monthly_long_distance_charges", "total_long_distance_charges"]] = 0
registrar("4.5", "Inconsistencias corregidas en clientes sin telefonía", inconsist)

# Montos negativos o antigüedad imposible
neg = (df[["monthly_charge", "total_charges", "total_revenue"]] < 0).any(axis=1).sum()
print("Registros con montos negativos:", neg)
registrar("4.5", "Registros con montos negativos detectados", neg)

# %% [markdown]
# ## 4.6 Valores atípicos (IQR)
# Se marcan los valores fuera de [Q1 − 1,5·IQR ; Q3 + 1,5·IQR]. **No se eliminan**: corresponden a clientes antiguos o de alto consumo y son información válida para el modelo.

# %%
cols_atip = ["monthly_charge", "total_charges", "total_revenue", "total_refunds",
             "total_extra_data_charges", "avg_monthly_gb_download", "tenure_in_months"]
resumen_atip = []
for c in cols_atip:
    q1, q3 = df[c].quantile([0.25, 0.75])
    iqr = q3 - q1
    li, ls = q1 - 1.5 * iqr, q3 + 1.5 * iqr
    n = ((df[c] < li) | (df[c] > ls)).sum()
    resumen_atip.append({"variable": c, "lim_inf": round(li, 2), "lim_sup": round(ls, 2),
                         "atipicos": int(n), "%": round(n / len(df) * 100, 2)})
    registrar("4.6", f"{c}: atípicos marcados (no eliminados)", n)
pd.DataFrame(resumen_atip)

# %% [markdown]
# ## 4.7 Eliminación de columnas sin información y con fuga de información
# - **Sin variación / identificación:** `customer_status` (ya filtrado), `city`, `zip_code` (alta cardinalidad; la ubicación se representa con latitud, longitud y población).
# - **Fuga de información (data leakage):** `churn_category`, `churn_reason`, `churn_score`, `satisfaction_score` y `customer_status` se conocen después de la fuga o derivan de ella. Se conservan en `df_analisis` (descriptivo) pero **no** en `df_modelo`.

# %%
df_analisis = df.copy()

cols_fuga = ["churn_category", "churn_reason", "churn_score", "satisfaction_score", "customer_status"]
cols_sin_info = ["city", "zip_code"]
df_modelo = df.drop(columns=cols_fuga + cols_sin_info)  # customer_id se mantiene solo como identificador
registrar("4.7", "Columnas eliminadas por fuga de información: " + ", ".join(cols_fuga), 0)
registrar("4.7", "Columnas eliminadas por alta cardinalidad: " + ", ".join(cols_sin_info), 0)

# %% [markdown]
# ## 4.8 Codificación de variables categóricas
# - Binarias Yes/No → 1/0; `gender` → `gender_female` (1 = Female).
# - Multinivel (`contract`, `payment_method`, `internet_type`, `offer`) → one-hot encoding (`drop_first=True` para evitar multicolinealidad).

# %%
cols_bin = [c for c in df_modelo.select_dtypes(include=["object", "string"]).columns
            if set(df_modelo[c].unique()) <= {"Yes", "No"}]
for c in cols_bin:
    df_modelo[c] = (df_modelo[c] == "Yes").astype(int)
df_modelo["gender_female"] = (df_modelo.pop("gender") == "Female").astype(int)

cols_multi = ["contract", "payment_method", "internet_type", "offer"]
df_modelo = pd.get_dummies(df_modelo, columns=cols_multi, drop_first=True, dtype=int)
registrar("4.8", f"Binarias codificadas 1/0: {len(cols_bin) + 1}", 0)
registrar("4.8", f"Multinivel con one-hot: {', '.join(cols_multi)}", 0)

print("Columnas de texto restantes:", list(df_modelo.select_dtypes(include=["object", "string"]).columns))
print("Dimensión base modelo:", df_modelo.shape)

# %% [markdown]
# ## 4.9 Distribución de la variable objetivo

# %%
dist = df_modelo["churn_value"].value_counts().rename({0: "Permanece", 1: "Se fuga"})
print(pd.DataFrame({"clientes": dist, "%": (dist / dist.sum() * 100).round(1)}))

# %% [markdown]
# La clase “Se fuga” es minoritaria; en la etapa de modelamiento se usará partición estratificada y métricas como AUC / recall (no solo accuracy).

# %% [markdown]
# ## 4.10 Bitácora de limpieza y exportación

# %%
tabla_bitacora = pd.DataFrame(bitacora)
tabla_bitacora

# %%
df_analisis.to_csv("churn_limpio_analisis.csv", index=False)
df_modelo.to_csv("churn_limpio_modelo.csv", index=False)
tabla_bitacora.to_csv("bitacora_limpieza.csv", index=False)
print("Exportado: churn_limpio_analisis.csv, churn_limpio_modelo.csv, bitacora_limpieza.csv")
