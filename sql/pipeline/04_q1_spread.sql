-- sql/pipeline/04_q1_spread.sql  (Phase 4, Q1: where did GLP-1s spread beyond diabetes, and when? 12 Nov)
-- Needs glp1.trials (sql/pipeline/02) and glp1.trial_indications (sql/pipeline/03).
-- Run from the repo root:  psql -d aact -f sql/pipeline/04_q1_spread.sql
-- Saves glp1.q1_spread (one row per indication) and exports data/results/04_q1_spread.csv.
--
-- Per indication: first trial year (and that trial), first academic-led and first industry-led
-- year, the industry lag (industry year - academic year), trials in all years.
--   Home base stays in as one row: the starting point of the timeline. Drug study trials are out.
--   Lead sponsor class decides the group (INDUSTRY vs the academic classes), as in sql/pipeline/05.
--   Lag NULL = industry has never led a trial there: keep those rows, they're the strongest signal.
--   Lag < 0 = industry got there first.
--   Trials with no start_date can't be placed on the timeline: counted in the check at the end.

DROP TABLE IF EXISTS glp1.q1_spread;
CREATE TABLE glp1.q1_spread AS
WITH ti AS (
    SELECT i.indication, t.nct_id, t.start_date,
           CASE WHEN l.agency_class = 'INDUSTRY' THEN 'industry-led'
                WHEN l.agency_class IN ('OTHER','OTHER_GOV','NIH','FED','NETWORK','INDIV') THEN 'academic-led'
                ELSE 'unclassified' END AS lead_group
    FROM glp1.trial_indications i
    JOIN glp1.trials t USING (nct_id)
    LEFT JOIN ctgov.sponsors l ON l.nct_id = t.nct_id AND l.lead_or_collaborator = 'lead'
    WHERE i.indication <> 'Drug study'
      AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
      AND t.start_date IS NOT NULL
),
first_trial AS (   -- the earliest trial per indication (ties broken by nct_id)
    SELECT indication, nct_id AS first_nct_id, lead_group AS first_lead_group,
           ROW_NUMBER() OVER (PARTITION BY indication ORDER BY start_date, nct_id) AS rn
    FROM ti
),
per AS (
    SELECT indication,
           MIN(EXTRACT(YEAR FROM start_date))::int AS first_year,
           MIN(EXTRACT(YEAR FROM start_date)) FILTER (WHERE lead_group = 'academic-led')::int AS first_academic_year,
           MIN(EXTRACT(YEAR FROM start_date)) FILTER (WHERE lead_group = 'industry-led')::int AS first_industry_year,
           COUNT(DISTINCT nct_id) AS trials_all_years,
           COUNT(DISTINCT nct_id) FILTER (WHERE lead_group = 'industry-led') AS industry_led_all_years
    FROM ti GROUP BY indication
)
SELECT p.indication, p.first_year, f.first_nct_id, f.first_lead_group,
       p.first_academic_year, p.first_industry_year,
       p.first_industry_year - p.first_academic_year AS industry_lag_years,
       p.trials_all_years, p.industry_led_all_years
FROM per p
JOIN first_trial f ON f.indication = p.indication AND f.rn = 1
ORDER BY p.first_year, p.indication;

\copy (SELECT * FROM glp1.q1_spread) TO 'data/results/04_q1_spread.csv' WITH (FORMAT csv, HEADER)

-- Checks
-- 1. Trials with no start date, left off the timeline
SELECT COUNT(*) AS trials_no_start_date FROM glp1.trials WHERE start_date IS NULL;
-- 2. One row per indication (expect 0 rows)
SELECT indication FROM glp1.q1_spread GROUP BY 1 HAVING COUNT(*) > 1;

SELECT * FROM glp1.q1_spread;
