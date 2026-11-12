-- sql/04d_q2_drug_split.sql  (Phase 4, Q2 add-on: generic vs branded GLP-1 in academic trials, 12 Nov)
-- Needs glp1.trials (sql/02), glp1.trial_indications (sql/03b), glp1.q2_white_space (sql/04),
-- glp1.q2_watchlist (sql/04b). Run from the repo root:  psql -d aact -f sql/04d_q2_drug_split.sql
-- Saves glp1.q2_drug_split (one row per indication) and exports data/results/04d_q2_drug_split.csv.
--
-- Rules (Decided, 9-10 Nov):
--   Generic  = other companies sell approved copies, so a university can just buy it:
--              exenatide, liraglutide, albiglutide (withdrawn 2018). Judged by drug, not trial date.
--   Branded  = every other named GLP-1 (dulaglutide, semaglutide, tirzepatide, lixisenatide,
--              next-wave drugs): a trial usually needs the company's help.
--   Tested arms = the arms that let the trial in (arm rule Option B): its EXPERIMENTAL arms, or
--              any GLP-1 arm when the trial has no EXPERIMENTAL arm.
--   A trial is branded if any branded drug is in a tested arm; generic if only generic drugs are;
--   "no named drug" if its only GLP-1 is class wording ("GLP-1 receptor agonist").
--   Mixed (generic + branded in tested arms) is reported, and counted as branded.
-- Scope: academic-led trials (both academic groups) started 2023-2025, same filters as sql/04.
-- The GLP-1 intervention list below repeats Steps 1-2 of sql/02 (names, other names, overrides).

DROP TABLE IF EXISTS glp1.q2_drug_split;
CREATE TABLE glp1.q2_drug_split AS
WITH glp1_interventions AS (
    SELECT i.nct_id, i.id AS intervention_id, m.canonical_drug
    FROM ctgov.interventions i
    JOIN glp1.name_map m ON LOWER(i.name) = m.drug_name
    WHERE m.decision = 'keep'
    UNION
    SELECT o.nct_id, o.intervention_id, m.canonical_drug
    FROM ctgov.intervention_other_names o
    JOIN glp1.name_map m ON LOWER(o.name) = m.drug_name
    WHERE m.decision = 'keep'
    UNION
    SELECT t.nct_id, i.id, t.canonical_drug
    FROM glp1.trial_overrides t
    JOIN ctgov.interventions i ON i.nct_id = t.nct_id AND LOWER(i.name) = t.drug_name
    WHERE t.decision = 'keep'
),
tested_drugs AS (   -- GLP-1 drugs in the arms that let each trial in
    SELECT DISTINCT gi.nct_id, gi.canonical_drug,
           CASE WHEN gi.canonical_drug IS NULL THEN 'class wording'
                WHEN gi.canonical_drug IN ('exenatide', 'liraglutide', 'albiglutide') THEN 'generic'
                ELSE 'branded' END AS drug_type
    FROM glp1_interventions gi
    JOIN glp1.trials t                        ON t.nct_id = gi.nct_id
    JOIN ctgov.design_group_interventions dgi ON dgi.intervention_id = gi.intervention_id
    JOIN ctgov.design_groups dg               ON dg.id = dgi.design_group_id
    WHERE (t.arm_rule = 'experimental arm' AND dg.group_type = 'EXPERIMENTAL')
       OR  t.arm_rule = 'no experimental arm'
),
trial_drug_type AS (   -- one row per trial
    SELECT nct_id,
           CASE WHEN BOOL_OR(drug_type = 'branded') THEN 'branded'
                WHEN BOOL_OR(drug_type = 'generic') THEN 'generic'
                ELSE 'no named drug' END AS drug_type,
           BOOL_OR(drug_type = 'branded') AND BOOL_OR(drug_type = 'generic') AS is_mixed
    FROM tested_drugs GROUP BY nct_id
),
academic_recent AS (
    SELECT i.indication, t.nct_id,
           EXISTS (SELECT 1 FROM ctgov.sponsors c WHERE c.nct_id = t.nct_id
                   AND c.lead_or_collaborator = 'collaborator' AND c.agency_class = 'INDUSTRY') AS has_industry_collab
    FROM glp1.trial_indications i
    JOIN glp1.trials t USING (nct_id)
    JOIN ctgov.sponsors l ON l.nct_id = t.nct_id AND l.lead_or_collaborator = 'lead'
    WHERE i.indication NOT IN ('Home base', 'Drug study')
      AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
      AND t.start_date >= '2023-01-01' AND t.start_date < '2026-01-01'
      AND l.agency_class IN ('OTHER','OTHER_GOV','NIH','FED','NETWORK','INDIV')
)
SELECT a.indication,
       COUNT(DISTINCT a.nct_id) AS academic_recent,
       COUNT(DISTINCT a.nct_id) FILTER (WHERE d.drug_type = 'generic') AS generic,
       COUNT(DISTINCT a.nct_id) FILTER (WHERE d.drug_type = 'branded') AS branded,
       COUNT(DISTINCT a.nct_id) FILTER (WHERE d.is_mixed) AS of_branded_mixed,
       COUNT(DISTINCT a.nct_id) FILTER (WHERE d.drug_type = 'no named drug') AS no_named_drug,
       COUNT(DISTINCT a.nct_id) FILTER (WHERE d.drug_type = 'branded' AND a.has_industry_collab) AS branded_with_industry_collab,
       ROUND(100.0 * COUNT(DISTINCT a.nct_id) FILTER (WHERE d.drug_type = 'branded')
             / NULLIF(COUNT(DISTINCT a.nct_id) FILTER (WHERE d.drug_type IN ('generic','branded')), 0), 0) AS branded_pct_of_named,
       COALESCE(w.verdict, 'too early to call') AS q2_verdict,
       COALESCE(wl.on_watchlist, FALSE) AS on_watchlist
FROM academic_recent a
LEFT JOIN trial_drug_type d USING (nct_id)
LEFT JOIN glp1.q2_white_space w USING (indication)
LEFT JOIN glp1.q2_watchlist wl USING (indication)
GROUP BY a.indication, w.verdict, wl.on_watchlist
ORDER BY academic_recent DESC, a.indication;

\copy (SELECT * FROM glp1.q2_drug_split) TO 'data/results/04d_q2_drug_split.csv' WITH (FORMAT csv, HEADER)

-- Checks
-- Groups add up: generic + branded + no named drug = academic_recent (expect 0 rows)
SELECT indication FROM glp1.q2_drug_split WHERE generic + branded + no_named_drug <> academic_recent;

-- The shortlist, the watchlist and every indication with 5+ trials
SELECT d.* FROM glp1.q2_drug_split d
JOIN glp1.q2_white_space w USING (indication)
WHERE w.recent_trials >= 5 OR d.on_watchlist
ORDER BY d.on_watchlist, d.academic_recent DESC;
