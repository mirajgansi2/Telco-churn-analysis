"""
Customer Churn Analysis - Python component (Watson dataset version)
Source: Telco Customer Churn .xlsx (geo + CLTV variant)

Steps:
1. Load the xlsx and rename columns to match the Postgres 'customers_full' schema
2. Engineer tenure/charge buckets (churnflag already exists as 'Churn Value')
3. Train a logistic regression churn model (geo columns excluded as features —
   too many categories, low predictive value per-category)
4. Score every customer with a churn probability
5. Write the result straight into Postgres, replacing 'customers_full'
"""

import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import classification_report, roc_auc_score
from sqlalchemy import create_engine

# ---- EDIT THESE THREE LINES ----
RAW_PATH = "Telco_customer_churn.xlsx"   # your Watson-variant file (csv or xlsx both work)
PG_CONN = "postgresql://postgres:admin123@localhost:5432/telco_churn"
OUTPUT_CSV = "customers_full_scored.csv"   # local backup copy, optional
# ---------------------------------


def load_raw(path: str) -> pd.DataFrame:
    """Load xlsx or csv. Excel-exported CSVs are often Windows-1252, not UTF-8."""
    if path.lower().endswith((".xlsx", ".xls")):
        return pd.read_excel(path)
    try:
        return pd.read_csv(path, encoding="utf-8")
    except UnicodeDecodeError:
        print("UTF-8 failed, retrying with cp1252 (common for Excel-exported CSVs)...")
        return pd.read_csv(path, encoding="cp1252")

RENAME_MAP = {
    "CustomerID": "customerid",
    "Count": "count",
    "Country": "country",
    "State": "state",
    "City": "city",
    "Zip Code": "zipcode",
    "Lat Long": "latlong",
    "Latitude": "latitude",
    "Longitude": "longitude",
    "Gender": "gender",
    "Senior Citizen": "seniorcitizen",
    "Partner": "partner",
    "Dependents": "dependents",
    "Tenure Months": "tenure",
    "Phone Service": "phoneservice",
    "Multiple Lines": "multiplelines",
    "Internet Service": "internetservice",
    "Online Security": "onlinesecurity",
    "Online Backup": "onlinebackup",
    "Device Protection": "deviceprotection",
    "Tech Support": "techsupport",
    "Streaming TV": "streamingtv",
    "Streaming Movies": "streamingmovies",
    "Contract": "contract",
    "Paperless Billing": "paperlessbilling",
    "Payment Method": "paymentmethod",
    "Monthly Charges": "monthlycharges",
    "Total Charges": "totalcharges",
    "Churn Label": "churn",
    "Churn Value": "churnvalue",
    "Churn Score": "churnscore",
    "CLTV": "cltv",
    "Churn Reason": "churnreason",
}


def clean_data(path: str) -> pd.DataFrame:
    df = load_raw(path)

    # Only rename columns that actually exist in this file — different
    # downloads of the Watson dataset vary slightly in header spelling
    existing_map = {k: v for k, v in RENAME_MAP.items() if k in df.columns}
    df = df.rename(columns=existing_map)
    print("Columns after rename:", df.columns.tolist())

    # TotalCharges: same blank-string issue as the simple dataset
    df["totalcharges"] = df["totalcharges"].replace(" ", np.nan)
    df["totalcharges"] = pd.to_numeric(df["totalcharges"], errors="coerce")
    df["totalcharges"] = df["totalcharges"].fillna(df["monthlycharges"])

    # Zip code as text preserves leading zeros
    if "zipcode" in df.columns:
        df["zipcode"] = df["zipcode"].astype(str).str.zfill(5)

    def tenure_bucket(t):
        if t <= 12: return "0-1 yr"
        if t <= 24: return "1-2 yr"
        if t <= 48: return "2-4 yr"
        if t <= 60: return "4-5 yr"
        return "5+ yr"
    df["tenurebucket"] = df["tenure"].apply(tenure_bucket)

    def charge_bucket(c):
        if c < 35: return "Low (<$35)"
        if c < 70: return "Medium ($35-70)"
        if c < 100: return "High ($70-100)"
        return "Very High ($100+)"
    df["chargebucket"] = df["monthlycharges"].apply(charge_bucket)

    # churnvalue already exists in this dataset (0/1) — use it as churnflag
    df["churnflag"] = df["churnvalue"] if "churnvalue" in df.columns else (df["churn"] == "Yes").astype(int)

    return df


def train_and_score(df: pd.DataFrame) -> pd.DataFrame:
    # Exclude IDs, geo text (too many categories), leakage columns
    # (churnscore/cltv/churnreason all correlate with the outcome by construction),
    # and the target itself
    drop_cols = [
        "customerid", "count", "country", "state", "city", "zipcode", "latlong",
        "latitude", "longitude", "churn", "churnvalue", "churnscore", "cltv",
        "churnreason", "tenurebucket", "chargebucket", "churnflag",
    ]
    drop_cols = [c for c in drop_cols if c in df.columns]

    X = df.drop(columns=drop_cols)
    y = df["churnflag"]

    cat_cols = X.select_dtypes(include="object").columns.tolist()
    X_enc = pd.get_dummies(X, columns=cat_cols, drop_first=True)

    X_train, X_test, y_train, y_test = train_test_split(
        X_enc, y, test_size=0.2, random_state=42, stratify=y
    )

    scaler = StandardScaler()
    X_train_s = scaler.fit_transform(X_train)
    X_test_s = scaler.transform(X_test)

    model = LogisticRegression(max_iter=2000, class_weight="balanced")
    model.fit(X_train_s, y_train)

    y_prob = model.predict_proba(X_test_s)[:, 1]
    print("ROC-AUC:", round(roc_auc_score(y_test, y_prob), 3))
    print(classification_report(y_test, model.predict(X_test_s),
                                 target_names=["Stayed", "Churned"]))

    coefs = pd.Series(model.coef_[0], index=X_enc.columns).sort_values(
        key=abs, ascending=False
    )
    print("\nTop churn drivers (positive coef = higher churn risk):")
    print(coefs.head(10).round(3))

    X_all_s = scaler.transform(X_enc)
    df["predictedchurnprob"] = model.predict_proba(X_all_s)[:, 1].round(3)
    return df


if __name__ == "__main__":
    data = clean_data(RAW_PATH)
    data = train_and_score(data)

    data.to_csv(OUTPUT_CSV, index=False)
    print(f"\nSaved local backup to {OUTPUT_CSV}")

    engine = create_engine(PG_CONN)
    data.to_sql("customers_full", engine, if_exists="replace", index=False)
    print(f"Wrote {len(data)} rows to Postgres table 'customers_full' (replaced)")