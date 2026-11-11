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

## Review 5: description hits, the recall gap (10 Nov 2026)

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

Then 1,848 → 1,809 (11 Nov): WITHDRAWN trials dropped in `glp1.trials` (39: 26 non-industry-led, 13 industry-led).
Backbone 49 → 47.

## Review 6: MeSH term tagging, Phase 3 (11 Nov 2026, tagging done)

What does each MeSH term become: an indication, home base, or nothing? Phase 3 gives every trial in
`glp1.trials` its indication(s); this review decides the terms. Grain: **one row per term**, not per trial.
Query `sql/03_mesh_terms_by_sponsor.sql` (`mesh-list` only) · rows `data/results/03_mesh_terms_by_sponsor.csv`
(267 terms) · evidence `03_mesh_terms_tagged.csv` (the 62 terms with 5+ trials; columns `tag`, `indication`, `note`)

Result: 61 of 62 tagged (32 `real`, 11 `broad`, 10 `home`, 8 `notd`); `renal insufficiency` left blank for the
drug-study bucket. The 32 `real` terms make 20 indications. The 205 terms below 5 trials are not tagged yet: the
coverage check decides whether to tag more of the tail.

**A tag only decides the trials that have no other term.** Most trials carry several terms, so their other
terms carry them. Before deciding a term, check its trials that carry it alone.

**Tag by what the trial targets, not who it enrols.** Gestational diabetes trials target type 2 prevention (home);
schizophrenia trials mostly target weight (antipsychotic-induced weight gain); infertility trials target pregnancy
rates (infertility). **A per-term industry share can mislead**: industry tags parent terms (metabolic diseases,
endocrine system diseases, nutrition disorders) and plain "obesity" for adolescents, so `pediatric obesity` shows
0% industry while industry's adolescent Phase 3s sit under "obesity".

| Tag | Meaning | What happens to its trials | Examples decided |
|---|---|---|---|
| `home` | Type 2 diabetes, obesity, or the diabetes spectrum, including prevention | Counted in Q1, kept off the white-space shortlist | type 2 diabetes, obesity, overweight, morbid obesity, prediabetic state, glucose intolerance, hyperglycaemia, gestational diabetes |
| `real` | A disease a drug label would name, outside home base | A new indication: candidates for the shortlist | type 1 diabetes, PCOS, alcoholism, CKD, NAFLD |
| `broad` | A real disease group, too wide to be one indication | No indication; other terms decide | cardiovascular diseases, metabolic diseases, metabolic syndrome, nutrition disorders (check: 32 trials, all industry) |
| `notd` | A mechanism or measure, not a disease | No indication; other terms decide | weight loss, body weight, insulin resistance |

Rules decided 11 Nov:

| Topic | Decision | Why | Cost |
|---|---|---|---|
| Type 1 diabetes | `real`, a new indication | No GLP-1 is approved in type 1; 18% industry-led | Novo tried and failed (ADJUNCT trials), so white space there may be an old failure |
| Alcohol use disorder | Its own indication, from `alcoholism` | A label names the substance. The generic addiction terms hold meth, opioid and smoking trials, not hidden alcohol ones | NCT02690987 (alcohol + nicotine) counts in both: never add indications up |
| CKD | Merge `renal insufficiency, chronic` + `diabetic nephropathies` + `albuminuria` + `kidney diseases` | All kidney treatment trials | `renal insufficiency` left out: 4 of its 7 trials outside the CKD tag are industry PK studies in renal impairment |
| MASLD | Indication MASLD = `non-alcoholic fatty liver disease`; `fatty liver` not merged | The trials hold the whole spectrum (many measure liver fat), so MASH would overstate it. Only 1 of `fatty liver`'s 7 untagged trials is a liver trial (NCT07718126); the keyword pass catches it | The BD reader thinks in MASH: report the MASH-titled count |
| Prediabetes group | `home`: glucose intolerance, prediabetic state, hyperglycaemia | Diabetes spectrum; 15 of 20 hyperglycaemia trials carry a diabetes tag anyway | If diabetes prevention becomes a label race, it's hidden in home base |
| Gestational diabetes | `home` | 5 of 6 trials treat women after gestational diabetes to prevent type 2: diabetes prevention, as for prediabetes | A "too early to call" row (6 trials, 2 in 2023–2025, all academic) the reader won't see |
| Mechanism and measure terms | `notd`, map to no indication. A trial tagged only with them goes to the drug-study bucket. Applies to weight loss, body weight, body weight changes, weight gain, motor activity, inflammation, insulin resistance, hypoglycaemia | 48 of 50 insulin-resistance trials carry other terms; the 2 alone are physiology in healthy people. As `home`, the tag would mislabel Parkinson's or schizophrenia trials as diabetes work. Hypoglycaemia is a safety outcome in 11 of 14 trials | A trial whose target hides behind a mechanism term goes unmapped; the coverage check is the backstop. Watch: NCT02527993 (post-bypass hypoglycaemia, lands in home via obesity), NCT04909333 (exenatide as a diagnostic test) |
| Parent terms | `broad`: glucose metabolism disorders, endocrine system diseases, overnutrition, mental disorders, behaviour addictive, substance-related disorders | Every trial carries a more specific term. Meth and opioid trials (1–2 each) come in through the keyword pass | |
| Pediatric obesity | `home` | An age extension of the obesity label (approved from 12) | |
| Straight merges | Obstructive sleep apnoea (2 terms), Smoking cessation (2), Osteoarthritis (2), Stroke (ischaemic stroke + stroke); single-term: atrial fibrillation, Parkinson's, Alzheimer's, psoriasis | One disease each | Stroke mixes acute brain-protection trials with prevention |
| Hypertension | `real` | Lilly runs 3 orforglipron Phase 3s targeting blood pressure in obesity (2025): an industry programme, not just a measure | 3 old blood-pressure mechanism studies add to the academic count |
| Schizophrenia + bipolar disorder | `real`, indication **Antipsychotic-induced weight gain** | 8 of 11 trials target weight or metabolic health; a labelled market (olanzapine + samidorphan) with a specific cause | 2 bipolar cognition trials (NCT02423824, NCT06331286) are mislabelled; NCT06939088 goes to AUD through the keyword pass |
| Infertility | `real` | Target = fertility outcomes (IVF pregnancy rates, embryo quality, fertility-sparing) | The 3 PCOS IVF trials count in both PCOS and Infertility |
| Heart failure | `real`, one indication | MeSH has no HFpEF term; STEP-HFpEF is tagged obesity only | HFrEF and HFpEF mixed: report the HFpEF count from the keyword pass (`hfpef\|preserved ejection`) |
| ASCVD | Merge coronary artery disease + myocardial infarction + atherosclerosis; Stroke kept separate | One disease process; the label SELECT earned. Stroke is neurology to a BD team, and its acute trials protect the brain | Acute MI trials mixed with prevention |
| Endometrial cancer and atypical hyperplasia | Merge the two terms | One treatment setting (obese women, often fertility-sparing); 5 of 12 trials carry both | A pure cancer label is smaller than this row |
| Hypothalamic obesity | `real`, from `sexual infantilism` + `craniopharyngioma` (MeSH's labels for these trials) | Obesity from brain-tumour damage: a different cause and an orphan market, like antipsychotic-induced weight gain | A reviewer may call it home base |

**Drug-study bucket** (decided 11 Nov, option A): PK, bioequivalence, drug interactions, organ-impairment PK,
healthy-volunteer physiology. Counted and reported, kept out of Q1's new-area timeline, Q2 and Q3. Decided by hand
at the end of mapping, only for (1) trials with no indication and (2) trials in a new indication that are Phase 1
or have PK words in the title. Stored in `indication_additions.csv` with indication = `drug study`.
Why: they test the drug, not a disease; mapped as a disease they make industry look active where it isn't
(the renal-impairment PK studies in CKD). Not found by a regex over all trials: 329 titles have PK words (303
industry-led), but many are efficacy trials with PK as a secondary aim, and 254 of them carry a home tag anyway.
Waiting for it: 4 renal-impairment PK studies (NCT03482024, NCT02320045, NCT00833716, NCT06352411), NCT07327281
(healthy volunteers), NCT02403284 and NCT00822003 (insulin-resistance physiology), NCT05482789 (exenatide PK in
gestational diabetes). Cost: a PK trial with no PK words that isn't Phase 1 can slip into a new indication.

**Keyword pass** (decided 11 Nov, option B): 3 of the 4 known trials miss through MeSH (SELECT: overweight +
obesity; FLOW: type 2 diabetes; STEP-HFpEF: obesity), because industry tags the population, not the new disease.
The conditions field says the same; only the title names the disease. So, per indication as it's mapped: search
`official_title` for its keywords among trials not yet mapped to it, review the hits by hand, and save the yes
decisions in `data/reference/indication_additions.csv` (`nct_id`, `indication`, `reason`). **Write the keywords
before looking at the hits**, and record them with the indication. A hit that belongs to another indication gets
that indication, not a "no". Why not hand-add the 4 known trials: the check would pass by construction and stop
being a check. Cost: trials naming the disease only in their outcomes still slip through (a limitation).
