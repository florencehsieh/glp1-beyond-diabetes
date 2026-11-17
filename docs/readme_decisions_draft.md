# Key decisions: README draft

Draft, 17 Nov 2026. Flo picked these five from `docs/decisions.md` for the README; each has the full
shape (options · choice · why · cost · check). Numbers are from the 17 Nov rerun (2,357 trials, all
labelled). Recheck every number before Phase 6.

Note: the headline's "most of them with a Phase 3" became "all with an industry Phase 3": after the
recall fix all 10 non-white-space areas have one (active or completed).

## 1. What counts as white space

- **Options:** zero industry trials; a fixed share (e.g. under 10%); a share anchored to the field.
- **Choice:** an indication is white space when industry leads less than half the baseline share of its
  2023–2025 trial starts (baseline 36.7%, bar 18.3%), no industry Phase 3 is active or completed in any
  year, and it has at least 5 trial starts. Below 5 it's "too early to call".
- **Why:** zero is too strict: 3 industry vs 50 academic is still an opening. A fixed % is arbitrary, so
  anchor it to the field. An industry Phase 3 means a competitor is already close. With "active" alone,
  heart failure would have looked open, a false lead.
- **Cost:** atrial fibrillation misses the cut at 4 trials despite 4 different academic leads (it goes on
  the watchlist). An area a company tried long ago and left no longer counts (the "old block only" flag
  catches that case).
- **Check:** PCOS holds at one third and two thirds of baseline, and under the strict arm rule (8 trials,
  still 0 industry).

## 2. Reframing the headline instead of the rules

- **Options:** loosen the rules to get more white-space names, or keep them and reframe the headline.
- **Choice:** keep every rule. Headline: "Industry has already followed academia into 10 of the 11 busiest
  new GLP-1 areas, all with an industry Phase 3. PCOS is the one big exception. The next openings are
  early."
- **Why:** "industry is already there" is valuable news for a BD team: it stops them chasing a crowded area
  thinking they're early. Loosening the rules after seeing the answer would be tuning them to the result.
- **Cost:** a one-item shortlist rests heavily on PCOS, including its 3 UNKNOWN-status trials (at 7 trials
  it still passes).
- **Check:** the rules were written before the results, and the watchlist rule for early signals was
  written before looking.

## 3. Testing recall with a list I didn't write

- **Options:** WHO INN lists; a drug database filtered by target; name endings in AACT only.
- **Choice:** WHO Proposed INN Lists 70–135, matched to AACT on whole words.
- **Why:** my first recall test ("15 of 15 known code-only GLP-1s found") was built from drugs I already
  knew, so it couldn't find unknown ones. A recall check needs a test set you didn't write.
- **Cost:** drugs with a code but no INN yet are outside it; WHO's mechanism text is largely supplied by
  the manufacturer.
- **Check:** the list went 1,809 → 2,357 trials across three passes (INN check +22, code leads +16). PCOS
  held; the watchlist dropped from 10 to 7 once Lilly's brenipatide trials were found.

## 4. Completed doesn't mean it worked

- **Options:** trust the registry status, or check how each completed Phase 3 ended.
- **Choice:** hand-check each completed Phase 3 on the shortlist and watchlist against posted results and
  result papers (`data/review/04f_completed_ph3_check.csv`).
- **Why:** a trial that runs to its end shows as COMPLETED whatever the result, so EVOKE, Exenatide-PD3 and
  TAO all look like progress in the registry. Without the check, PCOS's completed Phase 3s could be
  failures counted as progress.
- **Cost:** only a handful of trials; "unknown" where no results or paper exist.
- **Check:** PCOS 2 worked, 1 unknown; TAO (antipsychotic-induced weight gain) failed, weight P = .98 vs
  placebo.

## 5. Who is already circling: the scouting label

- **Options:** weight academic trials by industry backing; add a label; ignore collaborators.
- **Choice:** a label, "open" or "being scouted": the share of academic trials with a GLP-1 maker as
  collaborator vs the baseline (7.0%). 16 makers, each confirmed to lead trials of its own GLP-1.
- **Why:** big-pharma backing of academic trials is a real signal (money, speed, connections) that a plain
  academic/industry split hides. A label beats a weight, because half or a third is arbitrary.
- **Cost:** each "being scouted" label rests on one trial, and Novo and Lilly supply drug to academic trials
  as routine support.
- **Check:** the count per company sits next to each label; check 3 (`sql/pipeline/08`) finds makers
  missing from the list, and it caught Huadong. PCOS is "open": no GLP-1 maker backs any of its 10 trials.
