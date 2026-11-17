# Sanity check prompt (Phases 1–4)

Give this to each reviewer unchanged, except the ID prefix on the last line.

---

You are reviewing a data analysis project before its write-up. Your job is to find where the work is
wrong, inconsistent or out of date, and to prove each finding with evidence. You are not fixing anything.

## The project

`glp1-beyond-diabetes`: a SQL analysis of ClinicalTrials.gov (AACT snapshot of 3 Nov 2026, local Postgres
database `aact`). The question: where are GLP-1 receptor agonist drugs being tested beyond diabetes and
obesity, and is academia there before industry? Raw AACT tables are in schema `ctgov`; everything the
project builds is in schema `glp1`. `bash sql/pipeline/run_all.sh` rebuilds every table and
`data/results/*.csv`.

The four phases:

| Phase | What it decides | Main files |
|---|---|---|
| 1 Name review | Which intervention names count as a GLP-1 | `data/glp1_name_map.csv`, `data/reference/glp1_name_additions.csv`, `sql/review/01*` |
| 2 Trial list | Which trials give a GLP-1 in a tested arm (`glp1.trials`) | `sql/pipeline/01`–`02`, `data/reference/glp1_trial_overrides.csv`, recall reviews `sql/review/02b`–`02d` |
| 3 Indications | Which disease(s) each trial targets (`glp1.trial_indications`) | `sql/pipeline/03`, `data/reference/03_mesh_terms_tagged.csv`, `data/reference/indication_additions.csv`, `sql/review/03*` |
| 4 Analysis | Q1 spread, Q2 white space + follow-ups, watchlist, Q3 momentum, the "so what" | `sql/pipeline/04`–`10`, `data/results/`, `docs/so_what.md`, `data/external/gbd/` |

The rules and their reasons are in `docs/decisions.md` and `data/review/README.md`. Read those first.

The project was changed several times: the trial list grew (recall reviews in Phase 2) after Phases 3
and 4 had been done once. Treat every count, review and sentence as possibly out of date.

## Ground rules

1. **Don't trust the docs. Recompute.** A number in a doc is a claim. Check it against the database or
   the results files.
2. **Every finding needs evidence** that someone else can rerun: trial IDs (NCT…), file and line, the
   query you ran, and what it returned.
3. **Say how you know.** Start `how_checked` with `RAN:` if you executed a query or script, or `READ:`
   if you only read the code or docs. A `READ:` finding is a suspicion, not a result.
4. **Don't edit any repo file.** If you test what a fix would change, use temp tables, a transaction
   you roll back, or a copy. If you rebuild with `run_all.sh`, check that `git status` is clean at the end.
5. **Don't open `docs/sanity_checks/`** except this file. Other reviewers' results are there; your
   check must be independent.
6. **Cover all four phases before going deep on any one.** Don't stop after the first big finding.
7. If you can't run something (no database, no tool), list it under "Not checked". Don't guess.

## What to check

For each phase, check these. Add anything else you think matters.

**Every phase**
- *Recall*: what should be in but isn't? Look outside the project's own searches: any filter (a date,
  a sponsor type, a condition, a text pattern) leaves something out. For each search, say what its
  filters exclude and whether the docs state it as a limitation.
- *Precision*: what is in but shouldn't be? Take a random sample (state the seed) and read the records.
- *Rules vs code*: does the SQL do what `decisions.md` says? Thresholds, time windows, sponsor
  classes, status groups, the arm rule.
- *Consistency*: is each rule applied the same way everywhere, including to items added later?
- *Version*: was each hand review run on the current list, or only on the list as it was then? Which
  items added later skipped which review?
- *Known answers*: do trials the docs name as examples land where the docs say?
- *Grain and joins*: one row per what? Duplicates, row explosion, NULLs, unmatched joins.

**Phase 1**: names that are GLP-1 receptor agonists (INNs, brands, development codes of any era,
spelling variants) but aren't in the name map; kept names that don't give a real GLP-1 (placebos,
the native hormone, tracers, other drug classes); `canonical_drug` consistency (one drug, one name).

**Phase 2**: the arm rule (Option B) and its edge cases; the interventional and WITHDRAWN filters; the
overrides; the backbone flag; the scope of each recall review (02b, 02c, 02d) and what falls outside it.

**Phase 3**: trials with no label; each label source (MeSH tags, the condition rule, the hand additions)
on edge cases; MeSH terms with no tag; a trial filed under "Home base" whose title or conditions name
another disease; Drug study labels.

**Phase 4**: recompute each verdict and headline number; check each sentence in `docs/so_what.md` and
the Q2/watchlist rows in `docs/decisions.md` against `data/results/`; check the GBD numbers against
`data/external/gbd/`; run the sensitivity checks the docs describe.

**Housekeeping**: does `run_all.sh` reproduce the committed results exactly? Out-of-date numbers in
the README, SQL comments and docs; git state.

## For every problem: test its impact

Before you rate a finding, ask: **if this were fixed, would a verdict change?** (the white-space
shortlist, the watchlist, a Q1 or Q3 result, a sentence in `so_what.md`). Test it if you can and write
what you found in `changes_verdict`. A finding that changes no verdict can still matter if it makes a
published sentence false.

## Output

1. A summary of at most 5 lines: the most serious problems first.
2. A CSV in a code block, with exactly these columns:

```
id,phase,area,finding,evidence,how_checked,impact,changes_verdict,severity
```

- `id`: your prefix + number (A01, A02…)
- `phase`: 1, 2, 3, 4, or `all`
- `area`: a few words (e.g. "keyword pass", "arm rule", "so what")
- `finding`: one sentence, what is wrong
- `evidence`: NCT IDs, file paths, line numbers, numbers before and after
- `how_checked`: `RAN:` or `READ:` + what you did
- `impact`: `count` / `verdict` / `wording` / `docs` / `none`
- `changes_verdict`: `yes` / `no` / `not tested`, + one line on why
- `severity`:
  - `high`: changes a verdict, changes a headline number by more than 1%, or makes a published sentence false
  - `medium`: changes counts but not verdicts, or a rule is applied inconsistently
  - `low`: docs, comments or housekeeping; no number changes
  - `pass`: a check you ran that found nothing (include these, one row per main check)

Quote every field that contains a comma. One problem per row: if the same cause produces several
problems, give the cause one row and list the cases in `evidence`.

3. "Not checked": what you couldn't check and why.

Your ID prefix is: **A**
