# Hand reviews: what the pattern letters mean

Each hand review sorted rows into lettered patterns before deciding them. **The letters restart in every
review**, so "A" means something different in each file. This page is the key.

The decisions themselves live in SQL: `sql/01b_name_review.sql` rule 0 (Review 1), 0b (Review 2),
0c (Review 3), 0d (Review 4). The CSVs here are the evidence behind them.

Every review asks the same question in the end: **does an arm of this trial get a GLP-1 receptor agonist
that the study assigns?**

## Review 1: unclear names (7 Nov 2026)

Is a generic name like "glp-1" the drug or the body's own hormone?
Query `sql/01c_unclear_names.sql` · evidence `01c_unclear_names_decided.csv` (73 rows, column `bucket`)

| Bucket | Meaning | Decision | Rows |
|---|---|---|---|
| A | Native hormone: GLP-1 infused or measured as physiology | Exclude | 46 |
| B | Real GLP-1 drug behind the generic name | Keep (trial rescued in `data/reference/glp1_trial_overrides.csv`) | 8 keep, 1 exclude* |
| C | Not a GLP-1 at all | Exclude | 7 |
| D | Look it up (checked on clinicaltrials.gov) | Decided per trial; all 3 excluded | 3 |
| blank | Observational study, nobody given anything | `out_of_scope` | 8 |

\* NCT07368855: a real drug, but a retrospective records study of patients already on it (background use).

## Review 2: unfamiliar drug names (8 Nov 2026)

Is each unfamiliar name a GLP-1? **No letters**: the 35 names were grouped into 12 molecules with a
`SUBSTRING` regex and each molecule checked in AACT's own text, the web only where AACT was silent.
No evidence CSV; the decisions are rule 0b in `01b` (34 keep, sonefpeglutide excluded as GLP-2).
Lookup query: `sql/checks/drug_lookup.sql`.

## Review 3: placebo + active names (8 Nov 2026)

Does the arm get the real drug, or is the GLP-1 the placebo?
Evidence `01c_placebo_active_decided.csv` (18 names, column `pattern`)

| Pattern | Meaning | Decision | Names |
|---|---|---|---|
| A | The placebo belongs to another drug; the GLP-1 is real | Keep | 8 |
| B | The GLP-1 itself is the placebo | Exclude | 5 |
| C | Blinded label or crossover: the arm gets the real GLP-1 at some point | Keep | 5 |

## Review 4: background use (8 Nov 2026)

Does the trial give the GLP-1, or only study people already on it?
Query `sql/01d_background_use.sql` · evidence `01d_background_use_decided.csv` (37 rows, column `bucket`)

| Bucket | Meaning | Name clues | Decision | Rows |
|---|---|---|---|---|
| A | Assigned after all: a plain drug name that only got flagged by a rule | "semaglutide 1 mg weekly", "initiate liraglutide" | Keep | 6 |
| B | Background only | "users", "already on", "prescribed", "existing", "continue", "standard care", "NPO / fasting" | Exclude | 22 |
| C | Backbone in every arm: GLP-1 in all arms, another drug tested on top (e.g. NCT07671391) | | Keep the name; counted in Phase 2 as `is_backbone` | 0 |
| D | Stopping | "cessation", "withdrawal", "taper", "discontinue" | Taper or pause-and-restart: keep. Full stop or pre-procedure stop: exclude | 4 keep, 5 exclude |
| E | Can't tell: check the record | anything else | Resolved into A–D | 0 |

C and E were planned buckets; no row ended in them.

## Review 5: description hits, the recall gap (10 Nov 2026, in progress)

Which GLP-1 drugs did the name search miss? Trials whose intervention **description** has GLP-1 wording
but which aren't among the 2,050 in `glp1_interventions`: mostly development codes and typos.
Query `sql/02b_description_hits.sql` · rows `02b_description_hits.csv` (191 rows, 167 trials) ·
evidence `02b_description_hits_decided.csv` (same 191 rows, columns `pattern`, `decision`,
`canonical_drug`, `clue`; join on `nct_id` + `drug_name`)

Step 1, `first_pass` (SQL rules, narrow on purpose): `exclude: GLP-2`, `exclude: receptor blocker`,
`exclude: native GLP-1`, `exclude: background use`, else `review` (93 trials, 83 names).

Step 2, hand patterns for the `review` rows:

| Pattern | Meaning | Test | Likely call | Trials |
|---|---|---|---|---|
| A | A GLP-1 drug the name search missed: code, new formulation, typo (VK2735, ITCA 650, "semagludtide") | Does the AACT description call it a GLP-1 receptor agonist? | **Decided 10 Nov: keep**, split by name type (below). Last 3 decided 10 Nov: "group a (triple combination…)" ×2 keep (overrides), "glp-1 cellbeads" exclude (cell therapy) | ~52 |
| B | Treatment bundle ("best medical treatment", "weight loss medications such as…") | Does the protocol give a named GLP-1 in the tested arm? Same test as Review 4 | **Decided 10 Nov: 1 keep, 19 exclude** (20 trials, 21 rows). Named GLP-1 with a dose → keep; "could include" / doctor's choice / background → exclude. A GLP-1 that is only one option or a later step in a tested *strategy* → exclude: the trial tests the strategy, not the GLP-1 (NCT01974544, NCT07223242) | 20 |
| C | Not a GLP-1, or a physiology tool (blood test, metformin, saline, native GLP-1 arm) | Is the named drug a GLP-1 at all? | **Decided 10 Nov: exclude** (25 rows). Two names first sorted here were moved to A after reading the full text: "cs0159" (gives semaglutide) and "degludec insulin" (IDegLira) | ~23 |

**Where pattern A keeps go depends on the name** (decided 10 Nov):

- **A drug code or drug name** (vk2735, met097, itca 650, "semagludtide") always means that drug, so it goes in
  `data/reference/glp1_name_additions.csv` (41 names) and joins every trial that uses it. That finds more trials
  than 02b did: e.g. met097 is in 12 trials, only 1 with GLP-1 wording in its description.
- **A vague label** ("formulation a", "cs0159", "subcutaneous injection", "degludec insulin") means other things in
  other trials ("cs0159" alone is linafexor, an FXR agonist, in 9 trials), so the trial is rescued one by one in
  `data/reference/glp1_trial_overrides.csv`, which now names the exact intervention (`drug_name` column).

Found outside 02b (no GLP-1 wording anywhere in AACT): HEC88473 ("hec88473 injection", 2 trials) and PB1023
(Glymera, 7 names; AACT silent, GLP-1 RA per AdisInsight). Both added to the name additions file.

Result: headline 1,754 → 1,845 interventional trials (+91). Includes EVOKE (NCT04777396, semaglutide in Alzheimer's,
missed through the typo "semagludtide") and Parkinson's trials of NLY01 and PT320.

Then 1,845 → 1,848 (10 Nov): BMS-686117 (NCT00508287, code-only GLP-1 RA, added to the name additions) and the 2 "group a"
trials (NCT07635953 tirzepatide, NCT06946628 semaglutide, added to the overrides). Backbone stays 49.
