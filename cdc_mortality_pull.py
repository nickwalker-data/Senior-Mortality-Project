"""
Senior Mortality Shift - Phase 1: pull CDC data from a REST API.
Source: CDC weekly deaths by jurisdiction and age (dataset y5bj-9g5w), Socrata SODA API.
"""

import requests
import pandas as pd

BASE_URL = "https://data.cdc.gov/resource/y5bj-9g5w.json"
YEARS = ("2015", "2022")                 # full years only (series ends Sept 2023)
SENIOR_GROUPS = ["65-74 years", "75-84 years", "85 years and older"]


def soql(params):
    """Send one GET request with SoQL parameters and return a DataFrame."""
    resp = requests.get(BASE_URL, params=params, timeout=60)
    resp.raise_for_status()               # stop loudly on 4xx/5xx instead of silently
    return pd.DataFrame(resp.json())


# --- Step 1: discovery - what columns does this endpoint return? ---
sample = soql({"$limit": 1})
print("Columns:", list(sample.columns))
print(sample.T, "\n")

# 'Predicted (weighted)' adjusts for late-reported deaths. Year is text, so it's quoted.
BASE_WHERE = (
    "type='Predicted (weighted)' "
    f"AND year between '{YEARS[0]}' and '{YEARS[1]}'"
)

# --- Step 2a: national deaths by Year x Age group (CDC's server does the GROUP BY) ---
national = soql({
    "$select": "year, age_group, sum(number_of_deaths) as deaths",
    "$where": BASE_WHERE + " AND jurisdiction='United States'",
    "$group": "year, age_group",
    "$order": "year, age_group",
    "$limit": 5000,
})

# --- Step 2b: 65+ deaths by State x Year (50 states + DC) ---
age_list = ",".join(f"'{a}'" for a in SENIOR_GROUPS)
states = soql({
    "$select": "state_abbreviation, jurisdiction, year, sum(number_of_deaths) as deaths",
    "$where": BASE_WHERE + f" AND age_group in({age_list}) AND jurisdiction!='United States' AND state_abbreviation!='PR'",
    "$group": "state_abbreviation, jurisdiction, year",
    "$limit": 50000,
})

# --- Step 2c: weeks per year. CDC years run 52 or 53 weeks (2020 has 53), so the trend
# baseline needs each year's week count. Count distinct week-ending dates per year.
week_dates = soql({
    "$select": "year, week_ending_date",
    "$where": BASE_WHERE,
    "$group": "year, week_ending_date",
    "$limit": 5000,
})
weeks = (
    week_dates.assign(year=week_dates["year"].astype(int))
    .groupby("year")["week_ending_date"].nunique()
    .rename("weeks_in_year").reset_index()
    .rename(columns={"year": "death_year"})
)
assert weeks["weeks_in_year"].between(52, 53).all(), f"Unexpected week counts:\n{weeks}"

# --- Step 3: clean with pandas (API returns text -> convert to numbers) ---
for df in (national, states):
    df["year"] = df["year"].astype(int)
    df["deaths"] = pd.to_numeric(df["deaths"]).round().astype(int)

national["age_group"] = national["age_group"].str.replace(" years", "", regex=False)
national = national.rename(columns={"year": "Year", "age_group": "AgeGroup", "deaths": "Deaths"})

# CDC reports New York City (YC) separately; merge it into New York.
states.loc[states["state_abbreviation"] == "YC", ["state_abbreviation", "jurisdiction"]] = ["NY", "New York"]
states = (
    states.groupby(["state_abbreviation", "jurisdiction", "year"], as_index=False)["deaths"].sum()
    .rename(columns={"state_abbreviation": "State", "jurisdiction": "StateName",
                     "year": "Year", "deaths": "Deaths65Plus"})
    .sort_values(["State", "Year"])
)

national.to_csv("us_deaths_by_age_year.csv", index=False)
states.to_csv("state_deaths_65plus.csv", index=False)
print(f"Saved us_deaths_by_age_year.csv ({len(national)} rows)")
print(f"Saved state_deaths_65plus.csv ({len(states)} rows, {states['State'].nunique()} jurisdictions)")

# Week counts go to a dbt seed (used by the fct_ marts) and are read by cdc_trend_analysis.py.
weeks.to_csv("cdc_dbt/seeds/cdc_weeks_per_year.csv", index=False)
print("Saved cdc_dbt/seeds/cdc_weeks_per_year.csv:",
      ", ".join(f"{r.death_year}={r.weeks_in_year}" for r in weeks.itertuples()))

# --- Step 4: validation - one number we already know ---
check = national.query("Year == 2015 and AgeGroup == '25-44'")["Deaths"].iloc[0]
assert check == 124889, f"Validation failed: got {check}, expected 124889"
print("Validation passed: 2015, ages 25-44 = 124,889 deaths")

# Share of US deaths that are 65+, by year
pivot = national.pivot(index="Year", columns="AgeGroup", values="Deaths")
senior_cols = ["65-74", "75-84", "85 and older"]
share = (pivot[senior_cols].sum(axis=1) / pivot.sum(axis=1) * 100).round(1)
print("\n% of US deaths age 65+:\n", share.to_string())