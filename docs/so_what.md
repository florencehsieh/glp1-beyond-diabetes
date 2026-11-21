# The "so what": patient numbers and existing treatments

One section per shortlisted or watchlist indication: how many patients, whether the size is big enough, and
whether a treatment is already approved, each with a source. Rule and region: see `docs/decisions.md`
("The so what", "Region", "Size benchmarks"). Source material for the Phase 6 write-up (Findings,
Recommendations, Limitations), not the final text.

Patient numbers: GBD 2023 Results tool (IHME), prevalence, all ages, 2023, downloaded 14 Nov 2026.
Files in `data/external/gbd/`. US = United States of America; EU-27 = sum of the 27 member states' counts
(GBD has no EU location); UK reported separately (outside the EMA market).

## PCOS

**The line:** About 5 M women in the US and 6 M in the EU-27 have PCOS (GBD 2023). That's the size of
Alzheimer's, where Novo ran a large Phase 3, and close to CKD in type 2 diabetes, where a GLP-1 is approved.
No drug is approved for PCOS itself, and only one company has led a GLP-1 trial in it: a Phase 2 started in 2024.

### 1. How many patients

GBD 2023 puts PCOS prevalence (women, all ages) at 5.06 M in the US (range 3.55–7.01 M), 5.98 M in the EU-27
and 1.20 M in the UK. That's about 3% of all women (US 3.0%, EU-27 2.6%). This is a conservative floor:
clinicians usually quote 6–13% of women of reproductive age. The gap comes from GBD dividing by all women and
using a stricter definition. The EU-27 figure is the sum of the 27 countries, because GBD has no EU location.
The UK is reported separately because it isn't part of the EMA market (the MHRA approves drugs there since
Brexit).

### 2. Is it big enough?

To judge the number, I set a floor and benchmarks.

- **Floor:** the rare-disease line (US under 200,000; EU 5 or fewer per 10,000). PCOS is about 25× above it,
  so it isn't small.
- **Size match, Alzheimer's (and other dementias):** 4.89 M in the US, about the same as PCOS. Novo ran a
  3,808-patient Phase 3 programme (evoke/evoke+) there. It missed in Nov 2025, but it shows industry will bet
  big at this size.
- **Ceiling, CKD in type 2 diabetes:** 7.99 M in the US, only 1.6× PCOS, and a GLP-1 is approved there
  (Ozempic, FLOW trial, Jan 2025).
- **Takeaway:** size doesn't explain why industry has stayed out of PCOS.
- **Caveats:** the benchmarks count both sexes, while PCOS counts women only. In the EU, both benchmarks are
  bigger than PCOS (7.76 M and 8.79 M) because the population is older.

| GBD 2023 prevalence, all ages | US | EU-27 | UK |
|---|---|---|---|
| PCOS (women only) | 5.06 M | 5.98 M | 1.20 M |
| Alzheimer's disease and other dementias | 4.89 M | 7.76 M | 1.04 M |
| CKD due to type 2 diabetes | 7.99 M | 8.79 M | 1.23 M |

Psoriasis and IBD (no GBD pull): industry's GLP-1 Phase 3s there are Lilly combinations (its own immune drug +
tirzepatide) with an endpoint of disease control **and** at least 10% weight loss. One sentence in the
write-up, as a possible route into PCOS (e.g. ovulation restored and weight loss). Evidence: Review 10 in
`data/review/README.md`.

### 3. Existing treatment

Neither the FDA nor the EMA has approved a drug to treat PCOS itself. The only labels that name it are
fertility drugs approved to induce ovulation in women trying to conceive: clomiphene in the US,
gonadotropins such as GONAL-f in the EU. Everything else (metformin, the pill, anti-androgens) is used
off-label for symptoms. So a GLP-1 wouldn't face an approved competitor outside fertility, but it would have
to beat cheap standard care to get paid for. The one approved route runs through fertility, where GLP-1s
clash: they're stopped before trying to conceive.

### 4. What the trial data adds

PCOS is the stronger of Q2's two white spaces (the other is stroke): 11 trials started 2023–2025, 10
different lead sponsors, 1 of them industry (9.1%, against a 19.5% bar), and no industry Phase 3. That one is
Hengrui's HRS9531 Phase 2 (lead Fujian Shengdi, NCT06595797, started 2024, status unknown, primary outcome
body weight). PCOS was academic only from 2011 to 2024, 13 years before the first industry trial, against a
9-year median lag across the areas industry entered. It holds under the strict arm rule (9 trials, 1 industry,
11.1%) and without its 4 UNKNOWN-status trials (7 trials, 0 industry).
Two academic Phase 3s were positive, though both come from one group and were small.

### 5. Limitations

This isn't market sizing: it counts patients, not price, uptake or how many would get a drug. All numbers
come from GBD alone so they compare like for like; other sources give higher counts. The EU-27 figure has no
uncertainty range, because summing 27 ranges isn't valid. Trial counts come from the AACT snapshot of
3 Nov 2026.

### Sources

- GBD 2023 Results tool (IHME), downloaded 14 Nov 2026: `data/external/gbd/gbd_pcos_prevalence_2023_eu27_uk_us_2026-11-14.csv`,
  `gbd_benchmarks_prevalence_2023_2026-11-14.csv` (US and Western Europe file
  `gbd_pcos_prevalence_2023_2026-11-14.csv` kept, Western Europe not used). Free for non-commercial
  use with attribution.
- FDA approval of Ozempic for CKD in type 2 diabetes, 28 Jan 2025:
  [Pharmacy Times](https://www.pharmacytimes.com/view/fda-approves-semaglutide-to-reduce-kidney-disease-cardiovascular-death-risk-in-adults-with-type-2-diabetes-chronic-kidney-disease)
- Evoke/evoke+ results, Nov–Dec 2025:
  [Alzheimer Europe](https://www.alzheimer-europe.org/news/results-evoke-and-evoke-trials-show-no-effect-oral-semaglutide-ad-progression)
- FDA, "Polycystic Ovary Syndrome (PCOS)", women's health page, content current as of 1 Jun 2026:
  [fda.gov](https://www.fda.gov/consumers/womens-health-topics/polycystic-ovary-syndrome-pcos) (treatments)
- openFDA drug label search, run 14 Nov 2026:
  `indications_and_usage:("polycystic ovary" OR "polycystic ovarian" OR PCOS)` → 30 labels, all clomiphene
  (indication: "ovulatory dysfunction in women desiring pregnancy"; PCOS named as likely responders)
- EMA medicines search for "polycystic", run 14 Nov 2026: 10 centrally authorised products, 9 fertility drugs
  (GONAL-f, Bemfola, Rekovelle, Puregon, Elonva, Pergoveris, Ovaleap, Ovitrelle, Luveris) and 1 false hit
  (Jinarc, tolvaptan, polycystic kidney disease). EMA MeSH tags: infertility, anovulation, reproductive
  techniques; none PCOS. Clomiphene and metformin are authorised nationally, so they don't appear.
- [GONAL-f EPAR](https://www.ema.europa.eu/en/medicines/human/EPAR/gonal-f): first indication "Anovulation
  (including polycystic ovarian disease, PCOD) in women who have been unresponsive to treatment with
  clomiphene citrate"
- Off-label care list: Teede HJ, Tay CT, Laven JJE, et al. Recommendations from the 2023 International
  Evidence-based Guideline for the Assessment and Management of Polycystic Ovary Syndrome. *J Clin Endocrinol
  Metab* 2023;108(10):2447–2469. [doi:10.1210/clinem/dgad463](https://doi.org/10.1210/clinem/dgad463).
  The combined pill is first-line for irregular cycles and hyperandrogenism; metformin mainly for metabolic
  features; an anti-androgen can be added if hirsutism doesn't respond to the pill; anti-obesity medicines
  may be considered as in general-population guidelines. Evidence rated low to moderate quality.
  ([Guideline summary, Monash](https://assets.monashivf.com/assets/Summary-International-evidence-based-guideline-for-the-assessment-and-management-of-polycystic-ovary-syndrome-2023.pdf))

## Stroke

Lean version of the PCOS section (decided 21 Nov: same 5 parts, shorter; stroke is the thinner lead).
**Patients are counted as incidence, not prevalence** (decided 21 Nov): the trials give a GLP-1 in the first
days after a stroke, so the market is new strokes per year, not people living after one. This doesn't
compare like for like with PCOS's prevalence.

**The line:** About 390,000 new ischemic strokes a year in the US and 700,000 in the EU-27 (GBD 2023). No drug
is approved in the US or EU to protect the brain after a stroke, only to dissolve or remove the clot. No
company has ever led a GLP-1 stroke trial; universities now run 2 Phase 3s in China. But both finished
Phase 2s missed their main goal, so the case rests on subgroup signals.

### 1. How many patients

GBD 2023 puts new ischemic strokes (incidence, all ages, both sexes) at 388,155 a year in the US (range
354,280–425,615), 703,915 in the EU-27 and 66,322 in the UK. Rates per 100,000: US 115.7, EU-27 155.1, UK
95.9; these are crude all-age rates, so the EU-27's higher rate likely reflects its older population. The EU-27 figure is the sum of the 27 countries
(rate = summed number ÷ summed population, as for PCOS). This is an upper bound: 3 of the 4 acute trials
enrol only large-vessel strokes treated by clot removal (thrombectomy). A US estimate puts large-vessel
occlusions at 77,569 a year (95% CI 65,835–91,091, 2015 population; Rai et al. 2017), about 1 in 5 of
GBD's US count, and only 10,284 thrombectomies were done in 2015. Thrombectomy has grown since; no current
US or EU total was found.

### 2. Is it big enough?

- **Floor:** far above any rare-disease line (that line is set on prevalence, so this is a rough check).
- **The real market is the subgroup:** roughly 78,000 large-vessel strokes a year in the US, fewer of them
  treated by thrombectomy. That is small next to PCOS's 5 M women, but an acute drug is given to every
  eligible patient, in hospital, at a high price per case.
- **Takeaway:** size is not the problem; evidence is (part 4).
- **Caveat:** no benchmarks pulled for incidence; PCOS's benchmarks are prevalence and don't apply.

### 3. Existing treatment

Approved for acute ischemic stroke, US and EU: only drugs that dissolve the clot. FDA: alteplase (Activase)
and tenecteplase (TNKase, approved Mar 2025, the first new stroke drug in about 30 years). EMA: tenecteplase
(Metalyse; stroke indication within 4.5 h, CHMP opinion Dec 2023, now in the authorised indication); alteplase is authorised nationally, so it doesn't
appear in the EMA list. Clot removal (thrombectomy) is a device procedure, not a drug. Other labels that
name stroke are for preventing the next one (clopidogrel, ticagrelor; asundexian, FDA Nov 2026).

**No brain-protection (neuroprotective) drug is approved by the FDA or EMA.** A GLP-1 would sit on top of
clot removal, not compete with it. The closest rival: edaravone dexborneol (Sanbexin, Simcere), approved in
China in 2020 and given FDA breakthrough designation in 2024. It matters here because both GLP-1 Phase 3s
are in China, where it is already on the market.

### 4. What the trial data adds

Stroke is the thinner of Q2's two white spaces: 5 trials started 2023–2025, 5 different lead sponsors, 0
industry, and no company has led a GLP-1 stroke trial in any year (12 trials since 2016). It fails the strict
arm rule (3 trials, too early to call), so it is a weaker finding than PCOS.

The evidence so far is negative on the main goal:
- **TEXAIS** (exenatide, Australia, NCT03287076, Phase 2, 350 patients): no benefit on neurological recovery
  at 7 days (61.2% vs 56.7%, p = .38); it did lower blood sugar safely (*Stroke*, Dec 2023).
- **GALLOP** (semaglutide after clot removal, CUHK, NCT05920889, Phase 2, 140 patients): no benefit on
  90-day recovery (56.5% vs 54.9%); a signal only in patients not given a clot-buster, a subgroup
  (*Nature Communications*, Dec 2025).

The two Phase 3s (NCT06788626, 390 patients; NCT07030621, 436 patients, both after clot removal in China,
both not yet recruiting) follow those signals. Three more academic trials are planned for 2026, including
tirzepatide after clot removal (NCT07734792, Phase 2/3).

### 5. Limitations

Patients, not market size. The incidence count covers all ischemic strokes, much more than the trials'
subgroup. The large-vessel figure is a 2015-based US model; no EU equivalent. Two older trials in the Stroke
row look like they break the stroke split and should be checked: NCT03948347 (2019, new strokes at 90 days,
closer to prevention) and NCT02673931 (2016, organ protection in heart surgery). Both started before 2023, so
the verdict doesn't change. Trial counts come from the AACT snapshot of 3 Nov 2026.

### Sources

- GBD 2023 Results tool (IHME), downloaded 21 Nov 2026, incidence, ischemic stroke, all ages, both sexes,
  2023, Number and Rate, US + UK + EU-27 countries:
  `data/external/gbd/gbd_ischemic_stroke_incidence_2023_eu27_uk_us_2026-11-21.csv`
- Rai AT, et al. A population-based incidence of acute large vessel occlusions and thrombectomy eligible
  patients indicates significant potential for growth of endovascular stroke therapy in the USA.
  *J NeuroIntervent Surg* 2017;9(8):722–726. [PMC5583675](https://pmc.ncbi.nlm.nih.gov/articles/PMC5583675)
- openFDA drug label search, run 21 Nov 2026: `indications_and_usage:"acute ischemic stroke"` → 40 labels:
  ticagrelor (38, prevention), Activase (alteplase), TNKase (tenecteplase); no neuroprotectant
- EMA medicines list (JSON report), downloaded 21 Nov 2026, 1,568 authorised human medicines, regex on
  therapeutic indication (ischaemic/acute stroke, cerebral infarct, neuroprotect): Metalyse (acute
  treatment) and 14 clopidogrel products (prevention); no neuroprotectant
- FDA approval of TNKase for acute ischemic stroke, 3 Mar 2025:
  [NeurologyLive](https://www.neurologylive.com/view/fda-approves-tenecteplase-acute-ischemic-stroke)
- [Metalyse EPAR](https://www.ema.europa.eu/en/medicines/human/EPAR/metalyse) (stroke indication)
- Asundexian approval, Nov 2026: [AJMC](https://www.ajmc.com/view/fda-approves-asundexian-first-fxia-inhibitor-to-prevent-repeat-stroke)
- No FDA-approved neuroprotectant: [Endovascular Today, Jun 2025](https://evtoday.com/articles/2025-june/neuroprotection-where-do-we-stand)
- Sanbexin: [NMPA approval of sublingual tablets, Simcere, Nov 2024](https://www.biospace.com/press-releases/china-nmpa-approves-simceres-sanbexin-sublingual-tablets-for-the-treatment-of-acute-ischemic-stroke)
  (injection approved 2020, per Simcere); [FDA breakthrough designation, Sep 2024](https://neurologylive.com/view/fda-grants-breakthrough-therapy-designation-edaravone-dexborneol-combination-therapy-ais)
- TEXAIS: Management of poststroke hyperglycemia: results of the TEXAIS randomized clinical trial.
  *Stroke* 2023. [Griffith repository](https://research-repository.griffith.edu.au/items/070735c0-279f-4520-ac26-50c168123778)
- GALLOP: Nature Communications 2025, [doi:10.1038/s41467-025-66167-z](https://doi.org/10.1038/s41467-025-66167-z);
  [PMC12717234](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12717234/)

## Watchlist

**The line:** 3 of the 7 watchlist indications have no approved drug at all: methamphetamine use disorder,
cannabis use disorder and cancer therapy-induced metabolic toxicity.
Endometrial cancer comes close: nothing is approved for the fertility-sparing treatment its trials test.
Early signals, not recommendations (watchlist rule, `docs/decisions.md`).

Light version, by the 14 Nov rule ("So what" for the watchlist): patients from GBD 2023 with the PCOS settings,
"not in GBD" where GBD has no cause, and the FDA/EMA check. No benchmarks per row: compare with the PCOS
benchmarks above (Alzheimer's 4.89 M, CKD in T2D 7.99 M in the US) and the rare-disease floor (US 200,000).
Trials = trial starts 2023–2026 (`data/results/06_q2_watchlist.csv`). Upper bound = the GBD count is for the
whole disease, while the trials study a subgroup.

| Indication | Trials 2023–26 | Patients US / EU-27 / UK (GBD 2023) | FDA approved | EMA (centrally authorised) | One line |
|---|---|---|---|---|---|
| Methamphetamine use disorder | 4 | 1.09 M / 0.63 M / 0.20 M (Amphetamine use disorders) | None | None | No approved drug; GBD's group is wider than methamphetamine |
| Cannabis use disorder | 3 | 2.91 M / 1.70 M / 0.51 M | None | None | No approved drug; PP-01 in Phase 3 (Fast Track) for withdrawal |
| Cancer therapy-induced metabolic toxicity | 3 | Not in GBD | None | None | No approved drug; side effects of ADT and lorlatinib |
| Endometrial cancer and atypical hyperplasia | 8 | 0.79 M / 0.71 M / 0.11 M (Uterine cancer), upper bound | Advanced disease only | Advanced disease only | Nothing approved for fertility-sparing treatment |
| Atrial fibrillation | 10 | 7.51 M / 8.32 M / 1.36 M | Many (anticoagulants, rate and rhythm drugs) | 23 products | Approved drugs exist; none aimed at weight-driven AF |
| Infertility | 7 | 1.54 M / 3.17 M / 0.47 M (Female infertility), upper bound | Clomiphene, gonadotropins, bromocriptine | 12 fertility drugs | Approved drugs exist; trials are weight loss before IVF |
| Breast cancer | 5 | 2.96 M / 3.92 M / 0.59 M, upper bound | Many cancer drugs | Many | None for weight or metabolism in breast cancer |

Rows sorted: no approved drug first, then by how close the approved drugs come to what the trials test.

### Notes by indication

- **Addiction.** Methamphetamine and cannabis use disorder have no approved drug. NIDA: "no FDA-approved
  medications exist for stimulant use disorders, cannabis use disorder, or poly-SUDs". The only openFDA hit for
  methamphetamine is Desoxyn, methamphetamine itself, for ADHD. Opioid use disorder and smoking, which do have
  approved drugs, dropped off the watchlist (below).
- **Cancer therapy-induced metabolic toxicity.** Not in GBD: a side effect across several cancers. The trials
  test androgen deprivation therapy in prostate cancer (NCT06908694), lorlatinib in lung cancer (NCT07782359)
  and cardiometabolic risk after cancer treatment (NCT07202247). openFDA and EMA: no product with this
  indication.
- **Endometrial cancer and atypical hyperplasia.** Upper bound: GBD counts all uterine cancer; the trials
  pair a GLP-1 with a progestin IUD to treat atypical hyperplasia or early cancer and keep fertility.
  Approved drugs cover advanced disease only: FDA megestrol ("palliative treatment of advanced carcinoma of
  the breast or endometrium"), dostarlimab, pembrolizumab, durvalumab, lenvatinib; EMA Jemperli, Keytruda,
  Imfinzi, Lynparza. Fertility-sparing care uses progestins outside these labels (ESGO/ESHRE/ESGE guideline
  2023; its recommendations not checked here).
- **Infertility.** Upper bound and a mismatch: GBD counts female infertility, but 2 of the 7 trials study men
  (NCT05586802 Klinefelter syndrome, NCT07179120 obese men). The female trials are weight loss before IVF or
  embryo transfer and PCOS infertility, a weaker signal (watchlist decision, 14 Nov). Female infertility has
  the widest US range in the set: 0.29–3.75 M.
- **Atrial fibrillation and breast cancer.** Plenty of approved drugs for the disease, none for what the
  trials test: weight loss to cut AF coming back after ablation or AF burden, and weight loss in early breast
  cancer or survivors.
- **Across the watchlist.** Many of these are weight-loss trials in a new group of patients (AF, breast cancer,
  infertility, some endometrial). Semaglutide and tirzepatide are already approved
  for obesity, so the value for a sponsor is the disease result, not the weight loss (not sourced here; cite
  the Wegovy and Zepbound labels if used in the write-up).

### Dropped after Review 11 (16 Nov)

Review 11's recall fix found 4 Lilly Phase 2 trials of brenipatide (LY3537031, a GIP/GLP-1 agonist) that the
old name list missed: NCT07223840 (smoking), NCT07420283 (opioid use disorder), NCT07410507 (schizophrenia,
tagged antipsychotic-induced weight gain) and NCT07286175 (bipolar relapse). Each row now has an industry-led
trial, so it fails the "no industry" test (`data/results/06_q2_watchlist.csv`). Lilly also runs brenipatide
Phase 3 trials in alcohol use disorder (NCT07219966, NCT07219953) and major depressive disorder (NCT07412756,
NCT07775300): a big sponsor is moving into psychiatry and addiction, which is a signal in itself.

- **Antipsychotic-induced weight gain** (7 trials 2023–26, 2 industry-led): no approved drug; metformin used
  off-label (meta-analysis, 2016).
- **Smoking cessation** (7, 1 industry-led): NRT, varenicline and bupropion approved; cytisinicline may follow
  in 2027 after the FDA's Jun 2026 refusal over manufacturing.
- **Opioid use disorder** (4, 1 industry-led): methadone, buprenorphine and naltrexone approved; GLP-1 tested as
  an add-on (NCT06651177).

### Limitations

Same as PCOS: patients, not market size; GBD only, so like for like; EU-27 has no uncertainty range. 1 of 7
rows has no count. Upper-bound rows overstate the size of what the trials test. The EMA list covers central
authorisations only: medicines authorised country by country (e.g. NRT, methadone, metformin, clomiphene)
don't show. Some watchlist signals rest on planned 2026 starts. NCT07286175 (bipolar relapse) is tagged
antipsychotic-induced weight gain by the bipolar MeSH rule, which is wrong; the row still drops on its other
industry-led trial (NCT07410507).

### Sources

- GBD 2023 Results tool (IHME), downloaded 14 Nov 2026, prevalence, all ages, 2023, both sexes, EU-27 + US + UK:
  `data/external/gbd/gbd_{atrial_fibrillation, uterine_cancer, breast_cancer, female_infertility,
  opioid_use_disorders, amphetamine_use_disorders, cannabis_use_disorders}_prevalence_2023_eu27_uk_us_2026-11-14.csv`
- openFDA drug label search, run 14 Nov 2026, `indications_and_usage:` + "atrial fibrillation" · "smoking
  cessation" (noisy: also matches blood-pressure labels' lifestyle advice; real hits varenicline, bupropion) ·
  "opioid use disorder" OR "opioid dependence" · "methamphetamine" OR "stimulant use disorder" (Desoxyn only) ·
  "cannabis use disorder" (no matches) · "endometrial cancer/carcinoma/hyperplasia" · "infertility" OR
  "ovulation induction" · "antipsychotic" AND "weight gain" (olanzapine warnings only) · "chemotherapy-induced"
  OR "androgen deprivation" with hyperglycemia/metabolic/weight (no matches)
- EMA medicines list (JSON report), downloaded 14 Nov 2026, human medicines with status Authorised (1,564),
  regex on therapeutic indication and MeSH area:
  `https://www.ema.europa.eu/en/documents/report/medicines-output-medicines_json-report_en.json`
- [FDA, Medications for Opioid Use Disorder](https://www.fda.gov/drugs/food-and-drug-administration-overdose-prevention-framework/medications-opioid-use-disorder),
  content current as of 9 Nov 2026
- [FDA, Want to Quit Smoking? FDA-Approved and FDA-Cleared Cessation Products Can Help](https://www.fda.gov/consumers/consumer-updates/want-quit-smoking-fda-approved-and-fda-cleared-cessation-products-can-help),
  content current as of 21 Jul 2022
- [NIDA Strategic Plan 2022–2026, Priority Area 2](https://nida.nih.gov/about-nida/2022-2026-strategic-plan/priority-area-2)
  (stimulant and cannabis use disorder)
- [NIDA, Cannabis (Marijuana)](https://nida.nih.gov/research-topics/cannabis-marijuana), Sep 2024
- Cytisinicline CRL, Jun 2026: [Achieve 8-K, SEC](https://www.sec.gov/Archives/edgar/data/0000949858/000119312526344571/achv-ex99_1.htm);
  [Benzinga](https://www.benzinga.com/news/fda/26/06/60020423/fda-declines-to-approve-achieve-life-sciences-smoking-cessation-drug-q4-resubmission-planned)
- PP-01 Phase 3: [Psychiatric Times, Sep 2026](https://www.psychiatrictimes.com/view/treating-cannabis-use-disorder-withdrawal-with-pp-01-nida-grant-accelerates-phase-3-trial)
- Metformin for antipsychotic-induced weight gain: [systematic review and meta-analysis, 2016](https://pubmed.ncbi.nlm.nih.gov/27716110/)
- [ESGO/ESHRE/ESGE Guidelines for the fertility-sparing treatment of patients with endometrial carcinoma](https://fvvo.eu/articles/esgoeshreesge-guidelines-for-the-fertility-sparing-treatment-of-patients-with-endometrial-carcinoma/FVVO.15.1.065),
  Facts Views Vis ObGyn 2023;15(1):3–23; [review of fertility-sparing approaches (PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8910633/)
