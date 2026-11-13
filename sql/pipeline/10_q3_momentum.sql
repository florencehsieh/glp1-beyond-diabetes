-- sql/pipeline/10_q3_momentum.sql  (Phase 4, Q3: how fast does each indication move to late stage? 12 Nov)
-- Needs glp1.trials (sql/pipeline/02), glp1.trial_indications (sql/pipeline/03), glp1.q2_white_space (sql/pipeline/05)
-- and glp1.q2_watchlist (sql/pipeline/06). Run from the repo root:  psql -d aact -f sql/pipeline/10_q3_momentum.sql
-- Saves glp1.q3_momentum (one row per indication) and exports data/results/10_q3_momentum.csv.
--
-- Rules (Decided table / docs/decisions.md):
--   Indications  every new-area indication with at least one Phase 2+ trial (PHASE2, PHASE2/PHASE3,
--                PHASE3), any year. Home base and Drug study left out, as in sql/pipeline/05. Shortlist and
--                watchlist rows are flagged. A trial counts in each of its indications: never sum.
--   Phase rule   main: only pure PHASE3 is Phase 3; PHASE2/PHASE3 counts as Phase 2; PHASE1/PHASE2
--                as Phase 1 (4 Nov). Sensitivity: PHASE2/PHASE3 counted as Phase 3.
--   NA, PHASE4   counted and reported, left out of both phase measures (top and bottom, 9 Nov).
--   Speed (main) years from the first trial of any phase to the first Phase 3 (changed 12 Nov:
--                GLP-1s are approved drugs, so Phase 3 often comes before any Phase 2 and the
--                4 Nov Phase 2 -> 3 gap goes negative; kept as a side column). NULL = no Phase 3 yet.
--                Shown with who ran that first Phase 3.
--   Status       active = RECRUITING, NOT_YET_RECRUITING, ACTIVE_NOT_RECRUITING, ENROLLING_BY_INVITATION;
--                completed = COMPLETED; stopped = TERMINATED, SUSPENDED; unknown = UNKNOWN (9 Nov).
--   Completed    a failed trial that ran to its end shows as COMPLETED (EVOKE, Exenatide-PD3), so
--                status can't show failure: check 5 lists the completed Phase 3s on the shortlist
--                and watchlist for a hand check of how each ended (12 Nov).
--   why_stopped  each stopped Phase 2+ trial sorted by hand into bad news (safety, futility),
--                good news (stopped early for benefit) or noise (recruitment, funding, supply,
--                business decision, COVID) (4 Nov). Only bad news counts against an indication.
--                Check 2 lists any stopped Phase 2+ trial missing from the hand list.
--   Phase 2 read for a long gap or no Phase 3: Phase 2 trials completed, and of those, how many
--                posted results (calculated_values.were_results_reported) (12 Nov, voice).
--   Backup       share of 2023-2025 trials at Phase 2 or later (PHASE2/PHASE3 counts either way),
--                NA and PHASE4 out of top and bottom.

DROP TABLE IF EXISTS glp1.q3_momentum;
CREATE TABLE glp1.q3_momentum AS
WITH why_stopped_sorted (nct_id, stop_group, note) AS (   -- hand list, 12 Nov: 8 trials
    VALUES ('NCT01255163', 'noise', 'AstraZeneca withdrew support (funding)'),
           ('NCT05897372', 'noise', 'slow recruitment'),
           ('NCT04763564', 'noise', 'drug supply interrupted'),
           ('NCT00529204', 'noise', 'lack of recruitment'),
           ('NCT04988997', 'noise', 'terminated by sponsor, no reason given (business decision)'),
           ('NCT01206101', 'noise', 'low recruitment, trial execution'),
           ('NCT03279731', 'noise', 'recruitment goals not met'),
           ('NCT04741074', 'noise', 'low recruitment')
),
ti AS (   -- trial x indication, new areas only (same filters as sql/pipeline/05)
    SELECT i.indication, t.nct_id, t.phase, t.overall_status,
           EXTRACT(YEAR FROM t.start_date)::int AS start_year,
           (t.start_date >= '2023-01-01' AND t.start_date < '2026-01-01') AS recent,
           CASE WHEN l.agency_class = 'INDUSTRY' THEN 'industry-led'
                WHEN l.agency_class IN ('OTHER','OTHER_GOV','NIH','FED','NETWORK','INDIV') THEN 'academic-led'
                ELSE 'unclassified' END AS lead_group,
           CASE WHEN t.overall_status IN ('RECRUITING','NOT_YET_RECRUITING','ACTIVE_NOT_RECRUITING',
                                          'ENROLLING_BY_INVITATION') THEN 'active'
                WHEN t.overall_status = 'COMPLETED' THEN 'completed'
                WHEN t.overall_status IN ('TERMINATED','SUSPENDED') THEN 'stopped'
                WHEN t.overall_status = 'UNKNOWN' THEN 'unknown' END AS status_bucket,
           COALESCE(cv.were_results_reported, FALSE) AS results_reported,
           w.stop_group
    FROM glp1.trial_indications i
    JOIN glp1.trials t USING (nct_id)
    LEFT JOIN ctgov.sponsors l ON l.nct_id = t.nct_id AND l.lead_or_collaborator = 'lead'
    LEFT JOIN ctgov.calculated_values cv ON cv.nct_id = t.nct_id
    LEFT JOIN why_stopped_sorted w ON w.nct_id = t.nct_id
    WHERE i.indication NOT IN ('Home base', 'Drug study')
      AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
),
-- the first Phase 3 per indication (main rule), with who ran it
first_ph3 AS (
    SELECT DISTINCT ON (indication) indication, nct_id AS first_ph3_trial, lead_group AS first_ph3_lead
    FROM ti WHERE phase = 'PHASE3' AND start_year IS NOT NULL
    ORDER BY indication, start_year, nct_id
),
per_ind AS (
    SELECT indication,
           COUNT(DISTINCT nct_id) AS trials_all_years,
           MIN(start_year) AS first_trial_year,
           -- main rule
           MIN(start_year) FILTER (WHERE phase IN ('PHASE2','PHASE2/PHASE3')) AS first_ph2_year,
           MIN(start_year) FILTER (WHERE phase = 'PHASE3')                    AS first_ph3_year,
           -- sensitivity: PHASE2/PHASE3 counted as Phase 3
           MIN(start_year) FILTER (WHERE phase = 'PHASE2')                    AS first_ph2_year_sens,
           MIN(start_year) FILTER (WHERE phase IN ('PHASE3','PHASE2/PHASE3')) AS first_ph3_year_sens,
           -- Phase 3 trials by status and lead
           COUNT(DISTINCT nct_id) FILTER (WHERE phase = 'PHASE3') AS ph3_trials,
           COUNT(DISTINCT nct_id) FILTER (WHERE phase = 'PHASE3' AND lead_group = 'industry-led') AS ph3_industry,
           COUNT(DISTINCT nct_id) FILTER (WHERE phase = 'PHASE3' AND status_bucket = 'active')    AS ph3_active,
           COUNT(DISTINCT nct_id) FILTER (WHERE phase = 'PHASE3' AND status_bucket = 'completed') AS ph3_completed,
           COUNT(DISTINCT nct_id) FILTER (WHERE phase = 'PHASE3' AND status_bucket = 'stopped')   AS ph3_stopped,
           COUNT(DISTINCT nct_id) FILTER (WHERE phase = 'PHASE3' AND status_bucket = 'unknown')   AS ph3_unknown,
           COUNT(DISTINCT nct_id) FILTER (WHERE phase = 'PHASE2/PHASE3') AS ph2_3_trials,
           -- Phase 2 (main rule: PHASE2 + PHASE2/PHASE3): did they finish, did they post results
           COUNT(DISTINCT nct_id) FILTER (WHERE phase IN ('PHASE2','PHASE2/PHASE3')) AS ph2_trials,
           COUNT(DISTINCT nct_id) FILTER (WHERE phase IN ('PHASE2','PHASE2/PHASE3')
                                            AND status_bucket = 'completed') AS ph2_completed,
           COUNT(DISTINCT nct_id) FILTER (WHERE phase IN ('PHASE2','PHASE2/PHASE3')
                                            AND status_bucket = 'completed' AND results_reported) AS ph2_completed_with_results,
           COUNT(DISTINCT nct_id) FILTER (WHERE phase IN ('PHASE2','PHASE2/PHASE3')
                                            AND status_bucket = 'stopped') AS ph2_stopped,
           -- stopped Phase 2+ trials by reason
           COUNT(DISTINCT nct_id) FILTER (WHERE stop_group = 'bad news')  AS stopped_bad_news,
           COUNT(DISTINCT nct_id) FILTER (WHERE stop_group = 'good news') AS stopped_good_news,
           COUNT(DISTINCT nct_id) FILTER (WHERE stop_group = 'noise')     AS stopped_noise,
           -- labels left out of the phase measures
           COUNT(DISTINCT nct_id) FILTER (WHERE phase = 'NA')     AS na_trials,
           COUNT(DISTINCT nct_id) FILTER (WHERE phase = 'PHASE4') AS ph4_trials,
           -- backup measure, 2023-2025
           COUNT(DISTINCT nct_id) FILTER (WHERE recent AND phase IN ('PHASE2','PHASE2/PHASE3','PHASE3')) AS recent_ph2_plus,
           COUNT(DISTINCT nct_id) FILTER (WHERE recent AND phase NOT IN ('NA','PHASE4')) AS recent_phased
    FROM ti GROUP BY indication
)
SELECT p.indication,
       COALESCE(ws.shortlist, FALSE) AS on_shortlist,
       COALESCE(wl.on_watchlist, FALSE) AS on_watchlist,
       p.trials_all_years,
       p.first_trial_year, p.first_ph3_year,
       p.first_ph3_year - p.first_trial_year AS years_to_ph3,
       f.first_ph3_trial, f.first_ph3_lead,
       p.first_ph3_year_sens - p.first_trial_year AS years_to_ph3_sens,
       p.first_ph2_year,
       p.first_ph3_year - p.first_ph2_year AS years_ph2_to_ph3,              -- side column (4 Nov measure)
       p.ph3_trials, p.ph3_industry, p.ph3_active, p.ph3_completed, p.ph3_stopped, p.ph3_unknown,
       p.ph2_3_trials,
       p.ph2_trials, p.ph2_completed, p.ph2_completed_with_results, p.ph2_stopped,
       p.stopped_bad_news, p.stopped_good_news, p.stopped_noise,
       p.na_trials, p.ph4_trials,
       p.recent_ph2_plus, p.recent_phased,
       ROUND(100.0 * p.recent_ph2_plus / NULLIF(p.recent_phased, 0), 0) AS recent_ph2_plus_pct
FROM per_ind p
LEFT JOIN first_ph3 f USING (indication)
LEFT JOIN glp1.q2_white_space ws USING (indication)
LEFT JOIN glp1.q2_watchlist wl USING (indication)
WHERE p.first_ph2_year IS NOT NULL OR p.first_ph3_year IS NOT NULL
   OR p.ph2_trials + p.ph3_trials > 0                -- any Phase 2+ trial, even without a start date
ORDER BY (p.first_ph3_year IS NULL), years_to_ph3, p.indication;

\copy (SELECT * FROM glp1.q3_momentum) TO 'data/results/10_q3_momentum.csv' WITH (FORMAT csv, HEADER)

-- Checks
-- 1. One row per indication (expect 0 rows)
SELECT indication FROM glp1.q3_momentum GROUP BY 1 HAVING COUNT(*) > 1;

-- 2. Every stopped Phase 2+ trial in new areas is in the hand list (expect 0 rows)
SELECT DISTINCT t.nct_id, t.phase, s.why_stopped
FROM glp1.trial_indications i JOIN glp1.trials t USING (nct_id) JOIN ctgov.studies s USING (nct_id)
WHERE i.indication NOT IN ('Home base', 'Drug study')
  AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
  AND t.phase IN ('PHASE2','PHASE2/PHASE3','PHASE3') AND t.overall_status IN ('TERMINATED','SUSPENDED')
  AND t.nct_id NOT IN ('NCT01255163','NCT05897372','NCT04763564','NCT00529204',
                       'NCT04988997','NCT01206101','NCT03279731','NCT04741074');

-- 3. Phase 3 status buckets add up (expect 0 rows)
SELECT indication FROM glp1.q3_momentum
WHERE ph3_active + ph3_completed + ph3_stopped + ph3_unknown <> ph3_trials;

-- 4. Rows where the sensitivity rule (PHASE2/PHASE3 as Phase 3) changes the speed
SELECT indication, years_to_ph3, years_to_ph3_sens, ph2_3_trials
FROM glp1.q3_momentum WHERE years_to_ph3 IS DISTINCT FROM years_to_ph3_sens;

-- 5. Hand-check list: completed Phase 3s on the shortlist and watchlist (how did each end?)
SELECT DISTINCT q.indication, t.nct_id, l.agency_class AS lead_class, EXTRACT(YEAR FROM t.start_date)::int AS start_year,
       cv.were_results_reported AS results_posted, s.enrollment, s.brief_title
FROM glp1.q3_momentum q
JOIN glp1.trial_indications i ON i.indication = q.indication
JOIN glp1.trials t ON t.nct_id = i.nct_id
JOIN ctgov.studies s ON s.nct_id = t.nct_id
LEFT JOIN ctgov.sponsors l ON l.nct_id = t.nct_id AND l.lead_or_collaborator = 'lead'
LEFT JOIN ctgov.calculated_values cv ON cv.nct_id = t.nct_id
WHERE (q.on_shortlist OR q.on_watchlist) AND t.phase = 'PHASE3' AND t.overall_status = 'COMPLETED'
ORDER BY q.indication, start_year;
