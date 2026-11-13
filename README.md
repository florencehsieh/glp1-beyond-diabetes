# glp1-beyond-diabetes
SQL analysis of ClinicalTrials.gov (AACT): where GLP-1 drugs are being tested beyond diabetes, and who’s leading.

## Data model

All work lives in Postgres (`aact`). AACT's raw tables sit in the `ctgov` schema;
everything this project builds sits in `glp1`.

**Pipeline:** `ctgov` → `glp1.trials` → `glp1.trial_indications` → results tables

| Table | One row per | What it is |
|---|---|---|
| `trials` | trial | 1,809 interventional trials that give a GLP-1 in a tested arm (`02`) |
| `trial_indications` | trial × indication | Which disease(s) each trial targets (`03`) |
| `q1_spread` | indication | Q1: when GLP-1s reached each indication, academia or industry first (`04`) |
| `q2_white_space` | indication | Q2: where academia is active and industry isn't (`05`) |
| `q2_watchlist`, `q2_drug_split`, `q2_scouting`, `q2_arm_sensitivity` | indication | Q2 follow-ups: early signals, generic vs branded, who to watch, robustness check (`06`–`09`) |
| `q3_momentum` | indication | Q3: how fast each indication reaches Phase 3 (`10`) |

Reference tables (`name_map`, `trial_overrides`, `mesh_tags`, `indication_additions`) hold the
hand-review decisions, loaded from `data/reference/` by `01`.

**Folders**
- `sql/pipeline/`: builds every table above; each also exports to `data/results/`
- `sql/review/`: one-off hand reviews; evidence in `data/review/` ([key](data/review/README.md)).
  Their numbers are the project phase, not pipeline steps.
- `sql/checks/`: lookup helpers

**Rebuild everything** (from the repo root): `bash sql/pipeline/run_all.sh`

**Watch out:** `trial_indications` has several rows per trial, so count with `COUNT(DISTINCT nct_id)`.
