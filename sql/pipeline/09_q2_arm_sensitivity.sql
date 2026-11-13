-- sql/pipeline/09_q2_arm_sensitivity.sql  (Phase 4, Q2 sensitivity: strict arm rule, 12 Nov)
-- Needs glp1.trials (sql/pipeline/02), glp1.trial_indications (sql/pipeline/03), glp1.q2_white_space (sql/pipeline/05).
-- Run from the repo root:  psql -d aact -f sql/pipeline/09_q2_arm_sensitivity.sql
-- Saves glp1.q2_arm_sensitivity and exports data/results/09_q2_arm_sensitivity.csv.
--
-- The question: does the shortlist hold when only trials with the GLP-1 in an EXPERIMENTAL arm
-- count (arm_rule = 'experimental arm'), dropping the 275 Option B trials with no EXPERIMENTAL arm?
-- The whole Q2 test is rerun on the smaller list: baseline, share, Phase 3 block, heating up.
-- Same rules as sql/pipeline/05 (threshold 5, bar = half the baseline, industry PHASE3 active or completed).
-- Each indication is scored under both rules: 'option B' must reproduce sql/pipeline/05 (check 1).

DROP TABLE IF EXISTS glp1.q2_arm_sensitivity;
CREATE TABLE glp1.q2_arm_sensitivity AS
WITH rules (arm_rule_set) AS (VALUES ('option B'), ('strict')),
trial_base AS (
    SELECT r.arm_rule_set, t.nct_id, t.phase, t.overall_status,
           CASE
               WHEN l.agency_class = 'INDUSTRY' THEN 'industry-led'
               WHEN l.agency_class IN ('OTHER','OTHER_GOV','NIH','FED','NETWORK','INDIV') THEN 'academic'
               ELSE 'unclassified'
           END AS lead_group,
           CASE
               WHEN t.start_date >= '2023-01-01' AND t.start_date < '2026-01-01' THEN 'recent'
               WHEN t.start_date >= '2020-01-01' AND t.start_date < '2023-01-01' THEN 'earlier'
           END AS time_window
    FROM rules r
    JOIN glp1.trials t ON r.arm_rule_set = 'option B' OR t.arm_rule = 'experimental arm'
    LEFT JOIN ctgov.sponsors l ON l.nct_id = t.nct_id AND l.lead_or_collaborator = 'lead'
),
ti AS (
    SELECT i.indication, b.*
    FROM glp1.trial_indications i
    JOIN trial_base b USING (nct_id)
    WHERE i.indication NOT IN ('Home base', 'Drug study')
      AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
),
field AS (   -- per rule set: the field, each trial once
    SELECT arm_rule_set,
           COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'recent')  AS field_recent,
           COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'earlier') AS field_earlier,
           100.0 * COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'recent' AND lead_group = 'industry-led')
                 / COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'recent') AS baseline_pct
    FROM ti GROUP BY arm_rule_set
),
per_ind AS (
    SELECT arm_rule_set, indication,
           COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'recent') AS recent_trials,
           COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'recent' AND lead_group = 'industry-led') AS industry_led,
           COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'recent' AND lead_group = 'academic') AS academic_recent,
           COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'earlier' AND lead_group = 'academic') AS academic_earlier,
           COUNT(DISTINCT nct_id) FILTER (WHERE lead_group = 'industry-led' AND phase = 'PHASE3'
               AND overall_status IN ('RECRUITING','NOT_YET_RECRUITING','ACTIVE_NOT_RECRUITING',
                                      'ENROLLING_BY_INVITATION','COMPLETED')) AS industry_ph3_block
    FROM ti GROUP BY arm_rule_set, indication
),
scored AS (
    SELECT p.*, ROUND(f.baseline_pct, 1) AS baseline_pct,
           ROUND(100.0 * p.industry_led / NULLIF(p.recent_trials, 0), 1) AS industry_share_pct,
           CASE WHEN p.recent_trials < 5 THEN 'too early to call'
                WHEN 100.0 * p.industry_led / p.recent_trials < f.baseline_pct * 0.5
                     AND p.industry_ph3_block = 0 THEN 'white space'
                ELSE 'not white space' END AS verdict,
           (p.academic_recent * f.field_earlier > p.academic_earlier * f.field_recent) AS heating_up
    FROM per_ind p JOIN field f USING (arm_rule_set)
)
SELECT b.indication,
       b.recent_trials AS recent_b, COALESCE(s.recent_trials, 0) AS recent_strict,
       b.industry_share_pct AS share_b, s.industry_share_pct AS share_strict,
       b.baseline_pct AS baseline_b, s.baseline_pct AS baseline_strict,
       b.industry_ph3_block AS ph3_block_b, s.industry_ph3_block AS ph3_block_strict,
       b.verdict AS verdict_b, COALESCE(s.verdict, 'too early to call') AS verdict_strict,   -- no strict trials left = too early
       (b.verdict = 'white space' AND b.heating_up) AS shortlist_b,
       COALESCE(s.verdict = 'white space' AND s.heating_up, FALSE) AS shortlist_strict
FROM scored b
LEFT JOIN scored s ON s.indication = b.indication AND s.arm_rule_set = 'strict'
WHERE b.arm_rule_set = 'option B'
ORDER BY (b.verdict = 'too early to call'), b.recent_trials DESC, b.indication;

\copy (SELECT * FROM glp1.q2_arm_sensitivity) TO 'data/results/09_q2_arm_sensitivity.csv' WITH (FORMAT csv, HEADER)

-- Checks
-- 1. The Option B rerun reproduces sql/pipeline/05 (expect 0 rows)
SELECT a.indication, a.verdict_b, w.verdict, a.shortlist_b, w.shortlist
FROM glp1.q2_arm_sensitivity a JOIN glp1.q2_white_space w USING (indication)
WHERE a.verdict_b <> w.verdict OR a.shortlist_b <> w.shortlist OR a.recent_b <> w.recent_trials;

-- 2. Rows where the strict rule changes the verdict or the shortlist
SELECT indication, recent_b, recent_strict, share_b, share_strict, verdict_b, verdict_strict,
       shortlist_b, shortlist_strict
FROM glp1.q2_arm_sensitivity
WHERE verdict_b IS DISTINCT FROM verdict_strict OR shortlist_b IS DISTINCT FROM shortlist_strict;
