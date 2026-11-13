-- sql/pipeline/06_q2_watchlist.sql  (Phase 4, Q2 watchlist: early signals below the threshold, 12 Nov)
-- Needs glp1.q2_white_space (sql/pipeline/05). Run from the repo root:  psql -d aact -f sql/pipeline/06_q2_watchlist.sql
-- Saves glp1.q2_watchlist and exports data/results/06_q2_watchlist.csv.
--
-- Rule (Decided, 12 Nov; written before looking at the result). An indication is on the watchlist
-- when it passes all five:
--   1 Size          3-4 trials started 2023-2025 (below the 5-trial threshold)
--   2 Independent   3+ different lead sponsors among those trials
--   3 No industry   0 industry-led trials in 2023-2025
--   4 No competitor no industry-led PHASE3, active or completed, any year (same clause as white space)
--   5 Not a copy    fewer than half of its 2023-2025 trials also carry a shortlisted indication
-- No growth test (2 -> 4 is noise) and no sensitivity reruns: early signals, not recommendations.

DROP TABLE IF EXISTS glp1.q2_watchlist;
CREATE TABLE glp1.q2_watchlist AS
WITH recent AS (   -- trial x indication, 2023-2025, new areas only (same filters as sql/pipeline/05)
    SELECT i.indication, t.nct_id, t.phase
    FROM glp1.trial_indications i
    JOIN glp1.trials t USING (nct_id)
    WHERE i.indication NOT IN ('Home base', 'Drug study')
      AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
      AND t.start_date >= '2023-01-01' AND t.start_date < '2026-01-01'
),
shortlisted AS (SELECT indication FROM glp1.q2_white_space WHERE shortlist),
copy_check AS (    -- how many of an indication's recent trials also carry a shortlisted label
    SELECT r.indication,
           COUNT(DISTINCT r.nct_id) FILTER (WHERE EXISTS (
               SELECT 1 FROM glp1.trial_indications o JOIN shortlisted s USING (indication)
               WHERE o.nct_id = r.nct_id AND o.indication <> r.indication)) AS shared_with_shortlist,
           STRING_AGG(DISTINCT COALESCE(r.phase, 'NULL'), ', ') AS phases
    FROM recent r GROUP BY r.indication
)
SELECT w.indication, w.recent_trials, w.lead_sponsors, w.industry_led,
       w.industry_ph3_active, w.industry_ph3_completed,
       c.shared_with_shortlist, w.unknown_status, c.phases,
       (w.recent_trials BETWEEN 3 AND 4)                           AS t1_size,
       (w.lead_sponsors >= 3)                                       AS t2_independent,
       (w.industry_led = 0)                                         AS t3_no_industry,
       (w.industry_ph3_active + w.industry_ph3_completed = 0)       AS t4_no_competitor,
       (c.shared_with_shortlist * 2 < w.recent_trials)              AS t5_not_a_copy,
       (w.recent_trials BETWEEN 3 AND 4 AND w.lead_sponsors >= 3 AND w.industry_led = 0
        AND w.industry_ph3_active + w.industry_ph3_completed = 0
        AND c.shared_with_shortlist * 2 < w.recent_trials)          AS on_watchlist
FROM glp1.q2_white_space w
JOIN copy_check c USING (indication)
WHERE w.recent_trials BETWEEN 3 AND 4          -- only size-passers are worth listing
ORDER BY on_watchlist DESC, w.recent_trials DESC, w.indication;

\copy (SELECT * FROM glp1.q2_watchlist) TO 'data/results/06_q2_watchlist.csv' WITH (FORMAT csv, HEADER)

SELECT * FROM glp1.q2_watchlist;
