-- sql/pipeline/06_q2_watchlist.sql  (Phase 4, Q2 watchlist: early signals below the threshold; rule 12 Nov, window 13–14 Nov)
-- Needs glp1.trials, glp1.trial_indications and glp1.q2_white_space (sql/pipeline/05).
-- Run from the repo root:  psql -d aact -f sql/pipeline/06_q2_watchlist.sql
-- Saves glp1.q2_watchlist and exports data/results/06_q2_watchlist.csv.
--
-- Rule (Decided 12 Nov, written before looking at the result; window extended 13 Nov, rule 5 window 14 Nov).
-- An indication is on the watchlist when it passes all five:
--   1 Size          under 5 trials started 2023-2025 (so Q2 doesn't judge it)
--                   AND 3+ trials started 2023-2026
--   2 Independent   3+ different lead sponsors among the 2023-2026 trials
--   3 No industry   0 industry-led trials started 2023-2026
--   4 No competitor no industry-led PHASE3, active or completed, any year (same clause as white space)
--   5 Not a copy    fewer than half of its 2023-2026 trials also carry a shortlisted indication
-- Why 2026 here and not in Q2: the watchlist is about early signals and has no growth test, so a partial
-- 2026 (snapshot 3 Nov 2026) biases no comparison. Q2 and its follow-ups (05, 07, 08, 09) stay at 2023-2025.
-- Side columns, not part of the rule:
--   trials_2027_plus            planned starts in 2027 or later
--   actual_2326 / planned_2326  2023-2026 trials by start_date_type (ACTUAL vs ESTIMATED): a planned
--                               start may slip or be withdrawn
--   strict_*                    the same rules counting only trials with the GLP-1 in an EXPERIMENTAL arm
--                               (arm_rule = 'experimental arm', as in sql/pipeline/09)
-- No growth test and no sensitivity reruns beyond the strict check: early signals, not recommendations.

DROP TABLE IF EXISTS glp1.q2_watchlist;
CREATE TABLE glp1.q2_watchlist AS
WITH base AS (   -- trial x indication, new areas only (same filters as sql/pipeline/05), all start years
    SELECT i.indication, t.nct_id, t.phase, t.overall_status, t.arm_rule, t.start_date,
           s.start_date_type,
           l.name AS lead_sponsor,
           (l.agency_class = 'INDUSTRY') AS industry_led
    FROM glp1.trial_indications i
    JOIN glp1.trials t USING (nct_id)
    JOIN ctgov.studies s USING (nct_id)
    LEFT JOIN ctgov.sponsors l ON l.nct_id = t.nct_id AND l.lead_or_collaborator = 'lead'
    WHERE i.indication NOT IN ('Home base', 'Drug study')
      AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
),
win AS (         -- the 2023-2026 window used by rules 1-3 and 5
    SELECT * FROM base
    WHERE start_date >= '2023-01-01' AND start_date < '2027-01-01'
),
shortlisted AS (SELECT indication FROM glp1.q2_white_space WHERE shortlist),
shared AS (      -- 2023-2026 trials that also carry a shortlisted label (rule 5)
    SELECT DISTINCT w.indication, w.nct_id
    FROM win w
    JOIN glp1.trial_indications o ON o.nct_id = w.nct_id AND o.indication <> w.indication
    JOIN shortlisted s ON s.indication = o.indication
),
counts AS (
    SELECT b.indication,
           COUNT(DISTINCT b.nct_id) FILTER (WHERE b.start_date >= '2023-01-01' AND b.start_date < '2026-01-01') AS trials_2325,
           COUNT(DISTINCT b.nct_id) FILTER (WHERE b.start_date >= '2023-01-01' AND b.start_date < '2027-01-01') AS trials_2326,
           COUNT(DISTINCT b.nct_id) FILTER (WHERE b.start_date >= '2027-01-01')                                AS trials_2027_plus
    FROM base b GROUP BY b.indication
),
win_counts AS (
    SELECT w.indication,
           COUNT(DISTINCT w.lead_sponsor)                                     AS lead_sponsors,
           COUNT(DISTINCT w.nct_id) FILTER (WHERE w.industry_led)             AS industry_led,
           COUNT(DISTINCT w.nct_id) FILTER (WHERE w.start_date_type = 'ACTUAL')    AS actual_2326,
           COUNT(DISTINCT w.nct_id) FILTER (WHERE w.start_date_type = 'ESTIMATED') AS planned_2326,
           COUNT(DISTINCT w.nct_id) FILTER (WHERE w.overall_status = 'UNKNOWN')    AS unknown_status,
           COUNT(DISTINCT sh.nct_id)                                          AS shared_with_shortlist,
           STRING_AGG(DISTINCT COALESCE(w.phase, 'NULL'), ', ')               AS phases,
           -- strict arm rule: EXPERIMENTAL-arm trials only
           COUNT(DISTINCT w.nct_id) FILTER (WHERE w.arm_rule = 'experimental arm')                            AS strict_trials_2326,
           COUNT(DISTINCT w.nct_id) FILTER (WHERE w.arm_rule = 'experimental arm'
                                              AND w.start_date < '2026-01-01')                               AS strict_trials_2325,
           COUNT(DISTINCT w.lead_sponsor) FILTER (WHERE w.arm_rule = 'experimental arm')                      AS strict_lead_sponsors,
           COUNT(DISTINCT w.nct_id) FILTER (WHERE w.arm_rule = 'experimental arm' AND w.industry_led)         AS strict_industry_led,
           COUNT(DISTINCT sh.nct_id) FILTER (WHERE w.arm_rule = 'experimental arm')                           AS strict_shared
    FROM win w
    LEFT JOIN shared sh ON sh.indication = w.indication AND sh.nct_id = w.nct_id
    GROUP BY w.indication
),
scored AS (
    SELECT c.indication, c.trials_2325, c.trials_2326, c.trials_2027_plus,
           wc.lead_sponsors, wc.industry_led,
           q.industry_ph3_active, q.industry_ph3_completed,
           wc.shared_with_shortlist, wc.actual_2326, wc.planned_2326, wc.unknown_status, wc.phases,
           (c.trials_2325 < 5 AND c.trials_2326 >= 3)                     AS t1_size,
           (wc.lead_sponsors >= 3)                                         AS t2_independent,
           (wc.industry_led = 0)                                           AS t3_no_industry,
           (q.industry_ph3_active + q.industry_ph3_completed = 0)          AS t4_no_competitor,
           (wc.shared_with_shortlist * 2 < c.trials_2326)                  AS t5_not_a_copy,
           wc.strict_trials_2326, wc.strict_lead_sponsors, wc.strict_industry_led,
           (wc.strict_trials_2325 < 5 AND wc.strict_trials_2326 >= 3
            AND wc.strict_lead_sponsors >= 3 AND wc.strict_industry_led = 0
            AND q.industry_ph3_active + q.industry_ph3_completed = 0
            AND wc.strict_shared * 2 < wc.strict_trials_2326)              AS strict_on_watchlist
    FROM counts c
    JOIN win_counts wc USING (indication)
    JOIN glp1.q2_white_space q USING (indication)
)
SELECT indication, trials_2325, trials_2326, trials_2027_plus, lead_sponsors, industry_led,
       industry_ph3_active, industry_ph3_completed, shared_with_shortlist,
       actual_2326, planned_2326, unknown_status, phases,
       t1_size, t2_independent, t3_no_industry, t4_no_competitor, t5_not_a_copy,
       (t1_size AND t2_independent AND t3_no_industry AND t4_no_competitor AND t5_not_a_copy) AS on_watchlist,
       strict_trials_2326, strict_lead_sponsors, strict_industry_led, strict_on_watchlist
FROM scored
WHERE t1_size                                   -- only size-passers are worth listing
ORDER BY on_watchlist DESC, trials_2326 DESC, indication;

\copy (SELECT * FROM glp1.q2_watchlist) TO 'data/results/06_q2_watchlist.csv' WITH (FORMAT csv, HEADER)

-- Checks
-- 1. Every 2023-2026 trial is either ACTUAL or ESTIMATED (expect 0 rows)
SELECT indication, trials_2326, actual_2326, planned_2326 FROM glp1.q2_watchlist
WHERE actual_2326 + planned_2326 <> trials_2326;
-- 2. The 2023-2025 count matches Q2 (expect 0 rows)
SELECT w.indication, w.trials_2325, q.recent_trials FROM glp1.q2_watchlist w
JOIN glp1.q2_white_space q USING (indication) WHERE w.trials_2325 <> q.recent_trials;

SELECT * FROM glp1.q2_watchlist;
