-- sql/pipeline/08_q2_scouting.sql  (Phase 4, Q2 add-on: scouting label, 12 Nov)
-- Needs glp1.trials, glp1.trial_indications, glp1.q2_white_space (sql/pipeline/05), glp1.q2_watchlist (sql/pipeline/06).
-- Window 2023-2025, like Q2. Watchlist rows left out since 14 Nov (the watchlist counts 2023-2026, sql/pipeline/06).
-- Run from the repo root:  psql -d aact -f sql/pipeline/08_q2_scouting.sql
-- Saves glp1.q2_scouting (one row per indication) and exports data/results/08_q2_scouting.csv.
--
-- Rule (Decided 10 Nov, maker list 12 Nov, Huadong added 17 Nov):
--   GLP-1 maker = one of 16 companies with a GLP-1 drug of their own, matched by name pattern:
--     Novo Nordisk, Eli Lilly, AstraZeneca (+ MedImmune, + Amylin, exenatide's original maker),
--     Sanofi, Boehringer Ingelheim, Amgen, Pfizer, Roche (+ Genentech), MSD, Innovent, Hengrui,
--     Hansoh, Viking, Zealand, Altimmune, Huadong (HDM1002, HDM1005; found by the recall fix).
--     GSK left out: albiglutide withdrawn 2018.
--   Check (17 Nov): each maker leads glp1.trials trials of its own GLP-1 (by hand, data/review/README.md
--   Review 11), and check 3 below: no non-maker collaborator leads GLP-1 trials (expect 0 rows).
--   Scouting share = academic-led trials started 2023-2025 with a GLP-1 maker as collaborator
--                    / all academic-led trials started 2023-2025 in the indication.
--   Baseline       = the same share across all academic-led trials outside home base, same window.
--   Label          = "being scouted" if the share is above the baseline, else "open";
--                    "too early to call" below the 5-trial threshold (same as sql/pipeline/05).
--   Breakdown      = every industry collaborator on those academic trials, makers or not, with
--                    its trial count, so the reader can judge one random firm vs a real maker.

DROP TABLE IF EXISTS glp1.q2_scouting;
CREATE TABLE glp1.q2_scouting AS
WITH makers(company, pattern) AS (VALUES
    ('Novo Nordisk', 'novo nordisk%'), ('Eli Lilly', 'eli lilly%'),
    ('AstraZeneca', 'astrazeneca%'), ('AstraZeneca', 'medimmune%'), ('AstraZeneca', 'amylin%'),
    ('Sanofi', 'sanofi%'), ('Boehringer Ingelheim', 'boehringer%'), ('Amgen', 'amgen%'),
    ('Pfizer', 'pfizer%'), ('Roche', '%roche%'), ('Roche', 'genentech%'),
    ('MSD', 'merck sharp%'), ('MSD', 'msd %'),
    ('Innovent', 'innovent%'), ('Hengrui', '%hengrui%'), ('Hansoh', '%hansoh%'),
    ('Viking', 'viking%'), ('Zealand', 'zealand pharma%'), ('Altimmune', 'altimmune%'),
    ('Huadong', '%huadong%')
),
academic_recent AS (   -- trial x indication, academic-led, 2023-2025, new areas only
    SELECT i.indication, t.nct_id
    FROM glp1.trial_indications i
    JOIN glp1.trials t USING (nct_id)
    JOIN ctgov.sponsors l ON l.nct_id = t.nct_id AND l.lead_or_collaborator = 'lead'
    WHERE i.indication NOT IN ('Home base', 'Drug study')
      AND i.nct_id NOT IN (SELECT nct_id FROM glp1.trial_indications WHERE indication = 'Drug study')
      AND t.start_date >= '2023-01-01' AND t.start_date < '2026-01-01'
      AND l.agency_class IN ('OTHER','OTHER_GOV','NIH','FED','NETWORK','INDIV')
),
collabs AS (           -- industry collaborators on those trials, with the maker name if one
    SELECT DISTINCT c.nct_id, c.name AS collaborator, m.company AS maker
    FROM ctgov.sponsors c
    LEFT JOIN makers m ON LOWER(c.name) LIKE m.pattern
    WHERE c.lead_or_collaborator = 'collaborator' AND c.agency_class = 'INDUSTRY'
      AND c.nct_id IN (SELECT nct_id FROM academic_recent)
),
baseline AS (
    SELECT 100.0 * COUNT(DISTINCT a.nct_id) FILTER (WHERE EXISTS (
               SELECT 1 FROM collabs c WHERE c.nct_id = a.nct_id AND c.maker IS NOT NULL))
           / COUNT(DISTINCT a.nct_id) AS baseline_pct,
           COUNT(DISTINCT a.nct_id) AS field_academic
    FROM academic_recent a
),
per AS (
    SELECT a.indication,
           COUNT(DISTINCT a.nct_id) AS academic_recent,
           COUNT(DISTINCT a.nct_id) FILTER (WHERE EXISTS (
               SELECT 1 FROM collabs c WHERE c.nct_id = a.nct_id AND c.maker IS NOT NULL)) AS with_maker
    FROM academic_recent a GROUP BY a.indication
),
breakdown AS (
    SELECT a.indication,
           STRING_AGG(x.label, '; ' ORDER BY x.n DESC, x.label) AS collaborators
    FROM (SELECT DISTINCT indication FROM academic_recent) a
    JOIN LATERAL (
        SELECT COALESCE(c.maker || ' (maker)', c.collaborator) || ' x' || COUNT(DISTINCT c.nct_id) AS label,
               COUNT(DISTINCT c.nct_id) AS n
        FROM collabs c JOIN academic_recent r ON r.nct_id = c.nct_id AND r.indication = a.indication
        GROUP BY COALESCE(c.maker || ' (maker)', c.collaborator)
    ) x ON TRUE
    GROUP BY a.indication
)
SELECT p.indication, w.recent_trials, p.academic_recent, p.with_maker,
       ROUND(100.0 * p.with_maker / p.academic_recent, 1) AS scouting_share_pct,
       ROUND(b.baseline_pct, 1) AS baseline_pct,
       CASE WHEN w.recent_trials < 5 THEN 'too early to call'
            WHEN 100.0 * p.with_maker / p.academic_recent > b.baseline_pct THEN 'being scouted'
            ELSE 'open' END AS scouting_label,
       COALESCE(bd.collaborators, '') AS industry_collaborators,
       w.verdict AS q2_verdict, w.shortlist
FROM per p
CROSS JOIN baseline b
JOIN glp1.q2_white_space w USING (indication)
LEFT JOIN breakdown bd USING (indication)
WHERE p.indication NOT IN (SELECT indication FROM glp1.q2_watchlist WHERE on_watchlist)   -- 14 Nov (c); filter added 18 Nov (A05); baseline still uses all rows
ORDER BY (w.recent_trials < 5), p.academic_recent DESC, p.indication;

\copy (SELECT * FROM glp1.q2_scouting) TO 'data/results/08_q2_scouting.csv' WITH (FORMAT csv, HEADER)

-- Checks
-- 1. Which collaborator names matched a maker (read them: a wrong pattern shows here)
SELECT DISTINCT m.company, c.name FROM ctgov.sponsors c
JOIN (VALUES ('Novo Nordisk','novo nordisk%'),('Eli Lilly','eli lilly%'),('AstraZeneca','astrazeneca%'),
             ('AstraZeneca','medimmune%'),('AstraZeneca','amylin%'),('Sanofi','sanofi%'),
             ('Boehringer Ingelheim','boehringer%'),('Amgen','amgen%'),('Pfizer','pfizer%'),
             ('Roche','%roche%'),('Roche','genentech%'),('MSD','merck sharp%'),('MSD','msd %'),
             ('Innovent','innovent%'),('Hengrui','%hengrui%'),('Hansoh','%hansoh%'),
             ('Viking','viking%'),('Zealand','zealand pharma%'),('Altimmune','altimmune%'),
             ('Huadong','%huadong%')) m(company, pattern)
  ON LOWER(c.name) LIKE m.pattern
JOIN glp1.trials t ON t.nct_id = c.nct_id
ORDER BY 1, 2;
-- 2. The baseline
SELECT baseline_pct FROM glp1.q2_scouting LIMIT 1;

SELECT * FROM glp1.q2_scouting WHERE recent_trials >= 5;

-- 3. Missed makers: industry collaborators on 2023-2025 academic trials, not matched to a maker,
--    that lead GLP-1 trials themselves (expect 0 rows; a row = a maker missing from the list)
SELECT c.name AS collaborator, COUNT(DISTINCT l.nct_id) AS glp1_trials_led
FROM ctgov.sponsors c
JOIN glp1.trials t ON t.nct_id = c.nct_id AND t.start_date >= '2023-01-01' AND t.start_date < '2026-01-01'
JOIN ctgov.sponsors lead ON lead.nct_id = c.nct_id AND lead.lead_or_collaborator = 'lead'
                         AND lead.agency_class IN ('OTHER','OTHER_GOV','NIH','FED','NETWORK','INDIV')
JOIN ctgov.sponsors l ON l.name = c.name AND l.lead_or_collaborator = 'lead'
JOIN glp1.trials t2 ON t2.nct_id = l.nct_id
WHERE c.lead_or_collaborator = 'collaborator' AND c.agency_class = 'INDUSTRY'
  AND NOT EXISTS (SELECT 1 FROM (VALUES ('novo nordisk%'),('eli lilly%'),('astrazeneca%'),('medimmune%'),
                  ('amylin%'),('sanofi%'),('boehringer%'),('amgen%'),('pfizer%'),('%roche%'),('genentech%'),
                  ('merck sharp%'),('msd %'),('innovent%'),('%hengrui%'),('%hansoh%'),('viking%'),
                  ('zealand pharma%'),('altimmune%'),('%huadong%')) m(pattern) WHERE LOWER(c.name) LIKE m.pattern)
GROUP BY 1;
