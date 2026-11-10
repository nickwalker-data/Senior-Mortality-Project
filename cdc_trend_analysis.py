"""
Senior Mortality Shift - Phase 1b: trend baseline, excess deaths, and a chart.
numpy (arrays + math), statsmodels (OLS trend), matplotlib (chart).
A trend baseline beats a flat average: deaths were already rising before COVID.
"""

import numpy as np
import pandas as pd
import statsmodels.api as sm
import matplotlib.pyplot as plt

df = pd.read_csv("us_deaths_by_age_year.csv")          # Year, AgeGroup, Deaths
AGE_ORDER = [a for a in ["Under 25", "25-44", "45-64", "65-74", "75-84", "85 and older", "85+"]
             if a in set(df["AgeGroup"])]                  # keep only labels present in the file

rows = []
for age in AGE_ORDER:
    g = df[df["AgeGroup"] == age].sort_values("Year")
    pre = g[g["Year"] <= 2019]

    # --- statsmodels: Deaths = intercept + slope * Year, fit on 2015-2019 only
    X = sm.add_constant(pre["Year"].to_numpy())         # numpy array + intercept column
    model = sm.OLS(pre["Deaths"].to_numpy(), X).fit()

    # --- project the trend onto every year (numpy array in, numpy array out)
    years = g["Year"].to_numpy()
    expected = model.predict(sm.add_constant(years))

    for yr, actual, exp in zip(years, g["Deaths"].to_numpy(), expected):
        rows.append({"Year": yr, "AgeGroup": age, "Deaths": actual,
                     "Expected": round(exp), "Slope_per_year": round(model.params[1]),
                     "R2_2015_2019": round(model.rsquared, 3)})

out = pd.DataFrame(rows)
out["Excess"] = out["Deaths"] - out["Expected"]
out["PctAboveExpected"] = np.round(100 * (out["Deaths"] / out["Expected"] - 1), 1)
out.to_csv("excess_deaths_trend_baseline.csv", index=False)

covid = out[out["Year"] >= 2020]
print("Excess deaths vs. 2015-2019 TREND baseline\n")
print(covid.pivot(index="AgeGroup", columns="Year", values="PctAboveExpected")
           .reindex(AGE_ORDER).to_string())
print("\nTotal excess deaths 2020-2022:", f"{int(covid['Excess'].sum()):,}")
print("Pre-COVID trend fit (R^2) by age group:")
print(out.drop_duplicates("AgeGroup").set_index("AgeGroup")["R2_2015_2019"].to_string())

# --- matplotlib: one small panel per age group, actual vs expected
fig, axes = plt.subplots(2, 3, figsize=(13, 7), sharex=True)
for ax, age in zip(axes.flat, AGE_ORDER):
    g = out[out["AgeGroup"] == age]
    ax.plot(g["Year"], g["Deaths"] / 1000, marker="o", color="#1f4e79", label="Actual")
    ax.plot(g["Year"], g["Expected"] / 1000, linestyle="--", color="#999999",
            label="Expected (2015-19 trend)")
    ax.fill_between(g["Year"], g["Expected"] / 1000, g["Deaths"] / 1000,
                    where=(g["Deaths"] > g["Expected"]) & (g["Year"] >= 2020), color="#c0504d", alpha=0.25,
                    label="Excess")
    ax.axvline(2019.5, color="#cccccc", linewidth=1)
    peak = g.loc[g["PctAboveExpected"].idxmax()]
    ax.set_title(f"{age}  (peak +{peak['PctAboveExpected']}% in {int(peak['Year'])})", fontsize=10)
    ax.set_ylabel("Deaths (thousands)")
    ax.grid(alpha=0.3)
axes.flat[0].legend(fontsize=8, loc="upper left")
fig.suptitle("US deaths vs. pre-COVID trend, by age group (CDC, 2015-2022)", fontsize=13)
fig.tight_layout()
fig.savefig("excess_deaths_by_age.png", dpi=150)
print("\nSaved excess_deaths_trend_baseline.csv and excess_deaths_by_age.png")