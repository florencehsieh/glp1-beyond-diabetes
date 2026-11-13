-- sql/pipeline/05_q2_white_space.sql  (Phase 4, Q2: which indications are white space? 12 Nov)
-- Needs glp1.trials (sql/pipeline/02) and glp1.trial_indications (sql/pipeline/03).
-- Run from the repo root:  psql -d aact -f sql/pipeline/05_q2_white_space.sql
-- Saves glp1.q2_white_space (one row per indication) and exports data/results/05_q2_white_space.csv.
--
-- Rules (Decided table / docs/decisions.md):
--   Windows      recent = trials starting 2023-2025, earlier = 2020-2022 (whole calendar years).
--   Indications  Home base is left out; a trial labelled Drug study is left out entirely.
--                A trial counts in each of its indications: never sum across rows.
--   Sponsors     lead sponsor agency_class (ctgov.sponsors): INDUSTRY = industry-led;
--                OTHER, OTHER_GOV, NIH, FED, NETWORK, INDIV = academic, split by whether any
--                collaborator is INDUSTRY; anything else = unclassified (counted, reported).
--   Baseline     industry-led share of recent trials outside home base (each trial once).
--   White space  recent trials >= 5 (minimum-trials threshold, 12 Nov), else "too early to call";
--                industry-led share below half the baseline; and no industry-led PHASE3 that is
--                active or completed, any year (12 Nov). Pure PHASE3 only (combined-phase rule).
--   Old block    the only block is a completed industry PHASE3 and industry has led no trial
--                since 2020: hand-check how that trial ended (12 Nov).
--   Heating up   academic trial starts grew faster than all trials outside home base
--                (recent/earlier), compared by cross-multiplying so earlier = 0 needs no division.
--   Sensitivity  the same verdict with the bar at 1/3 and 2/3 of baseline.
-- Not here yet: the generic vs branded split and the scouting label (they need the drug and
-- collaborator lists), and the "so what" lines.

DROP TABLE IF EXISTS glp1.q2_white_space;
CREATE TABLE glp1.q2_white_space AS
WITH params AS (
    SELECT 5 AS min_trials, 0.5 AS bar_fraction
),
-- one row per trial: sponsor group, window, enrollment, lead sponsor name
trial_base AS (
    SELECT t.nct_id, t.start_date, t.phase, t.overall_status, st.enrollment,
           l.name AS lead_sponsor,
           CASE
               WHEN l.agency_class = 'INDUSTRY' THEN 'industry-led'
               WHEN l.agency_class IN ('OTHER','OTHER_GOV','NIH','FED','NETWORK','INDIV')
                    AND EXISTS (SELECT 1 FROM ctgov.sponsors c
                                WHERE c.nct_id = t.nct_id AND c.lead_or_collaborator = 'collaborator'
                                  AND c.agency_class = 'INDUSTRY')
                   THEN 'academic + industry collaborator'
               WHEN l.agency_class IN ('OTHER','OTHER_GOV','NIH','FED','NETWORK','INDIV')
                   THEN 'academic alone'
               ELSE 'unclassified'
           END AS sponsor_group,
           CASE
               WHEN t.start_date >= '2023-01-01' AND t.start_date < '2026-01-01' THEN 'recent'
               WHEN t.start_date >= '2020-01-01' AND t.start_date < '2023-01-01' THEN 'earlier'
           END AS time_window
    FROM glp1.trials t
    JOIN ctgov.studies  st ON st.nct_id = t.nct_id
    LEFT JOIN ctgov.sponsors l ON l.nct_id = t.nct_id AND l.lead_or_collaborator = 'lead'
),
-- trial x indication, new areas only
ti AS (
    SELECT i.indication, b.*
    FROM glp1.trial_indications i
    JOIN trial_base b USING (nct_id)
    WHERE i.indication NOT IN ('Home base', 'Drug study')
      AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
),
-- the field: every trial outside home base, counted once
field AS (
    SELECT COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'recent')  AS field_recent,
           COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'earlier') AS field_earlier,
           COUNT(DISTINCT nct_id) FILTER (WHERE time_window = 'recent'
                                            AND sponsor_group = 'industry-led') AS field_recent_industry
    FROM ti
),
baseline AS (
    SELECT f.*, 100.0 * field_recent_industry / field_recent AS baseline_pct FROM field f
),
-- indication x window counts, then LAG() to put the earlier window next to the recent one
per_window AS (
    SELECT indication, time_window,
           COUNT(DISTINCT nct_id) AS trials,
           COUNT(DISTINCT nct_id) FILTER (WHERE sponsor_group = 'industry-led') AS industry_led,
           COUNT(DISTINCT nct_id) FILTER (WHERE sponsor_group = 'academic + industry collaborator') AS academic_with_industry,
           COUNT(DISTINCT nct_id) FILTER (WHERE sponsor_group = 'academic alone') AS academic_alone,
           COUNT(DISTINCT nct_id) FILTER (WHERE sponsor_group = 'unclassified') AS unclassified,
           COUNT(DISTINCT nct_id) FILTER (WHERE sponsor_group LIKE 'academic%') AS academic
    FROM ti
    WHERE time_window IS NOT NULL
    GROUP BY indication, time_window
),
windows AS (
    SELECT p.*,
           LAG(academic) OVER (PARTITION BY indication ORDER BY time_window) AS academic_earlier  -- 'earlier' sorts before 'recent'
    FROM (  -- every indication gets both windows, so a 0 window isn't missing
        SELECT i.indication, w.time_window,
               COALESCE(pw.trials, 0) AS trials, COALESCE(pw.industry_led, 0) AS industry_led,
               COALESCE(pw.academic_with_industry, 0) AS academic_with_industry,
               COALESCE(pw.academic_alone, 0) AS academic_alone,
               COALESCE(pw.unclassified, 0) AS unclassified, COALESCE(pw.academic, 0) AS academic
        FROM (SELECT DISTINCT indication FROM ti) i
        CROSS JOIN (VALUES ('earlier'), ('recent')) w(time_window)
        LEFT JOIN per_window pw USING (indication, time_window)
    ) p
),
-- recent-window extras: median enrollment, distinct lead sponsors, UNKNOWN status
recent_extras AS (
    SELECT indication,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY enrollment) AS median_enrollment,
           COUNT(DISTINCT lead_sponsor) AS lead_sponsors,
           COUNT(DISTINCT nct_id) FILTER (WHERE overall_status = 'UNKNOWN') AS unknown_status
    FROM ti WHERE time_window = 'recent'
    GROUP BY indication
),
-- the Phase 3 block, any year
phase3 AS (
    SELECT indication,
           COUNT(DISTINCT nct_id) FILTER (WHERE sponsor_group = 'industry-led' AND phase = 'PHASE3'
               AND overall_status IN ('RECRUITING','NOT_YET_RECRUITING','ACTIVE_NOT_RECRUITING',
                                      'ENROLLING_BY_INVITATION')) AS industry_ph3_active,
           COUNT(DISTINCT nct_id) FILTER (WHERE sponsor_group = 'industry-led' AND phase = 'PHASE3'
               AND overall_status = 'COMPLETED') AS industry_ph3_completed,
           COUNT(DISTINCT nct_id) FILTER (WHERE sponsor_group = 'industry-led'
               AND phase = 'PHASE2/PHASE3') AS industry_ph2_3_any_status,   -- shown, not a block
           COUNT(DISTINCT nct_id) FILTER (WHERE sponsor_group = 'industry-led'
               AND start_date >= '2020-01-01') AS industry_since_2020
    FROM ti GROUP BY indication
),
scored AS (
    SELECT r.indication,
           r.trials AS recent_trials, r.industry_led, r.academic_with_industry, r.academic_alone,
           r.unclassified,
           ROUND(100.0 * r.industry_led / NULLIF(r.trials, 0), 1) AS industry_share_pct,
           ROUND(b.baseline_pct, 1) AS baseline_pct,
           r.academic_earlier, r.academic AS academic_recent,
           (r.academic * b.field_earlier > r.academic_earlier * b.field_recent) AS heating_up,
           p3.industry_ph3_active, p3.industry_ph3_completed, p3.industry_ph2_3_any_status,
           p3.industry_since_2020,
           e.median_enrollment, e.lead_sponsors, e.unknown_status,
           100.0 * r.industry_led / NULLIF(r.trials, 0) AS share_raw,
           b.baseline_pct AS baseline_raw
    FROM windows r
    CROSS JOIN baseline b
    JOIN phase3 p3 USING (indication)
    LEFT JOIN recent_extras e USING (indication)
    WHERE r.time_window = 'recent'
)
SELECT s.indication, s.recent_trials, s.industry_led, s.academic_with_industry, s.academic_alone,
       s.unclassified, s.industry_share_pct, s.baseline_pct,
       ROUND(s.baseline_raw * pr.bar_fraction, 1) AS bar_pct,
       s.academic_earlier, s.academic_recent, s.heating_up,
       s.industry_ph3_active, s.industry_ph3_completed, s.industry_ph2_3_any_status,
       CASE WHEN s.recent_trials >= pr.min_trials
             AND s.share_raw < s.baseline_raw * pr.bar_fraction
             AND s.industry_ph3_active = 0 AND s.industry_ph3_completed > 0
             AND s.industry_since_2020 = 0 THEN TRUE ELSE FALSE END AS old_block_only,
       v.verdict,
       (v.verdict = 'white space' AND s.heating_up) AS shortlist,
       CASE WHEN s.recent_trials < pr.min_trials THEN 'too early to call'
            WHEN s.share_raw < s.baseline_raw / 3.0 AND s.industry_ph3_active + s.industry_ph3_completed = 0
                THEN 'white space' ELSE 'not white space' END AS verdict_bar_one_third,
       CASE WHEN s.recent_trials < pr.min_trials THEN 'too early to call'
            WHEN s.share_raw < s.baseline_raw * 2 / 3.0 AND s.industry_ph3_active + s.industry_ph3_completed = 0
                THEN 'white space' ELSE 'not white space' END AS verdict_bar_two_thirds,
       s.median_enrollment, s.lead_sponsors, s.unknown_status
FROM scored s
CROSS JOIN params pr
CROSS JOIN LATERAL (
    SELECT CASE WHEN s.recent_trials < pr.min_trials THEN 'too early to call'
                WHEN s.share_raw < s.baseline_raw * pr.bar_fraction
                     AND s.industry_ph3_active + s.industry_ph3_completed = 0 THEN 'white space'
                ELSE 'not white space' END AS verdict
) v
ORDER BY (v.verdict = 'too early to call'), s.recent_trials DESC, s.indication;

-- Export
\copy (SELECT * FROM glp1.q2_white_space) TO 'data/results/05_q2_white_space.csv' WITH (FORMAT csv, HEADER)

-- Checks
-- 1. The baseline and the field windows (expect 163 recent trials, 30.1% industry-led on 12 Nov)
WITH t AS (
    SELECT DISTINCT i.nct_id FROM glp1.trial_indications i
    WHERE i.indication NOT IN ('Home base', 'Drug study')
      AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
)
SELECT COUNT(*) FILTER (WHERE g.start_date >= '2023-01-01' AND g.start_date < '2026-01-01') AS field_recent,
       COUNT(*) FILTER (WHERE g.start_date >= '2020-01-01' AND g.start_date < '2023-01-01') AS field_earlier
FROM t JOIN glp1.trials g USING (nct_id);

-- 2. Sponsor groups add up to the recent trials in every row (expect 0 rows)
SELECT indication FROM glp1.q2_white_space
WHERE industry_led + academic_with_industry + academic_alone + unclassified <> recent_trials;

-- 3. One row per indication (expect 0 rows)
SELECT indication FROM glp1.q2_white_space GROUP BY 1 HAVING COUNT(*) > 1;

-- 4. The verdicts at a glance
SELECT verdict, shortlist, COUNT(*) FROM glp1.q2_white_space GROUP BY 1, 2 ORDER BY 1, 2;
