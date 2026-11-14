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
No drug is approved for PCOS itself, and no company has ever led a GLP-1 trial in it.

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

PCOS is the only white space in Q2: 10 trials started 2023–2025, 9 different lead sponsors, and no
industry-led trial ever. It has been academic since 2011, about 15 years with no industry entry, against a
9-year median lag in areas industry did enter. It holds under the strict arm rule (8 trials, 0 industry).
Two academic Phase 3s were positive, though both come from one group and were small.

### 5. Limitations

This isn't market sizing: it counts patients, not price, uptake or how many would get a drug. All numbers
come from GBD alone so they compare like for like; other sources give higher counts. The EU-27 figure has no
uncertainty range, because summing 27 ranges isn't valid. Trial counts come from the AACT snapshot of
3 Nov 2026.

### Sources

- GBD 2023 Results tool (IHME), downloaded 14 Nov 2026: `data/external/gbd/gbd_pcos_prevalence_2023_eu27_uk_2026-11-14.csv`,
  `gbd_benchmarks_prevalence_2023_2026-11-14.csv` (Western Europe file kept, not used). Free for non-commercial
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
