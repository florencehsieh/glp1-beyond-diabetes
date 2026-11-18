-- sql/pipeline/11_hero_timeline.sql  (Phase 5: data for the hero chart, chart 1; 18 Nov)
-- Needs glp1.trials (sql/pipeline/02) and glp1.trial_indications (sql/pipeline/03).
-- Run from the repo root:  psql -d aact -f sql/pipeline/11_hero_timeline.sql
-- Saves glp1.hero_timeline (one row per indication x start year) and exports
-- data/results/11_hero_timeline.csv, the chart's only data source.
--
-- Definitions (Decided 18 Nov, sanity check B12; the 12 Nov counts could not be reproduced):
--   New-area trial  a trial in glp1.trials with at least one indication other than Home base,
--                   and not labelled Drug study: the same filter as Q2 and Q3 (sql/pipeline/05, 10).
--                   WITHDRAWN is already out (sql/pipeline/02).
--   Dot             one indication x start year; size = trials started that year. A trial in two
--                   indications sits in both dots, so never sum the dots: footnote counts (check 2)
--                   count each trial once.
--   Start year      from studies.start_date. Planned = start_date_type ESTIMATED (not started yet,
--                   or the sponsor hasn't confirmed the date).
--   2026            hollow dots: partial year (snapshot 3 Nov 2026) and about half planned (12 Nov).
--   2027+           left off the chart; check 3 gives the footnote count. No start date: left off.

DROP TABLE IF EXISTS glp1.hero_timeline;
CREATE TABLE glp1.hero_timeline AS
WITH new_area AS (
    SELECT i.indication, t.nct_id,
           EXTRACT(YEAR FROM t.start_date)::int AS start_year,
           (s.start_date_type = 'ESTIMATED') AS planned
    FROM glp1.trial_indications i
    JOIN glp1.trials t   USING (nct_id)
    JOIN ctgov.studies s USING (nct_id)
    WHERE i.indication NOT IN ('Home base', 'Drug study')
      AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
)
SELECT indication, start_year,
       COUNT(DISTINCT nct_id)                        AS trials,
       COUNT(DISTINCT nct_id) FILTER (WHERE planned) AS planned,
       (start_year = 2026)                           AS hollow,
       MIN(start_year) OVER (PARTITION BY indication) = start_year AS first_year_of_area
FROM new_area
WHERE start_year IS NOT NULL AND start_year <= 2026
GROUP BY indication, start_year
ORDER BY indication, start_year;

\copy (SELECT * FROM glp1.hero_timeline) TO 'data/results/11_hero_timeline.csv' WITH (FORMAT csv, HEADER)

-- Checks and footnote numbers
-- 1. One row per indication x year (expect 0 rows)
SELECT indication, start_year FROM glp1.hero_timeline GROUP BY 1, 2 HAVING COUNT(*) > 1;

-- 2. Footnote: new-area trials per year, each trial once, with the planned share (2024-2026)
SELECT EXTRACT(YEAR FROM t.start_date)::int AS start_year,
       COUNT(DISTINCT t.nct_id) AS trials,
       COUNT(DISTINCT t.nct_id) FILTER (WHERE s.start_date_type = 'ESTIMATED') AS planned,
       ROUND(100.0 * COUNT(DISTINCT t.nct_id) FILTER (WHERE s.start_date_type = 'ESTIMATED')
             / COUNT(DISTINCT t.nct_id), 0) AS planned_pct
FROM glp1.trials t
JOIN ctgov.studies s USING (nct_id)
WHERE t.nct_id IN (SELECT nct_id FROM glp1.trial_indications WHERE indication NOT IN ('Home base', 'Drug study'))
  AND t.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
  AND t.start_date >= '2024-01-01' AND t.start_date < '2027-01-01'
GROUP BY 1 ORDER BY 1;

-- 3. Footnote: new-area trials planned for 2027 or later (left off the chart)
SELECT COUNT(DISTINCT t.nct_id) AS trials_2027_plus
FROM glp1.trials t
WHERE t.nct_id IN (SELECT nct_id FROM glp1.trial_indications WHERE indication NOT IN ('Home base', 'Drug study'))
  AND t.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
  AND t.start_date >= '2027-01-01';

-- 4. Indications whose first trial starts in 2026 (the newest areas), out of all new-area indications
SELECT COUNT(*) FILTER (WHERE first_year = 2026) AS first_in_2026, COUNT(*) AS indications,
       STRING_AGG(indication, '; ' ORDER BY indication) FILTER (WHERE first_year = 2026) AS which
FROM (SELECT indication, MIN(start_year) AS first_year FROM glp1.hero_timeline GROUP BY 1) f;
