-- sql/review/03_mesh_terms_by_sponsor.sql  (end of Week 2: white-space exploration, start of Phase 3)
-- Needs glp1.trials (sql/pipeline/02_trials.sql). Run with search_path = ctgov, public.
-- The most common MeSH terms among the GLP-1 trials, split by lead sponsor class.
-- First look at industry vs academic per area, and the term list Phase 3 maps into indications.
--   mesh-list only: the term assigned directly. Never count across mesh-list and mesh-ancestor.
--   Lead sponsor: one lead row per trial (checked 9 Nov), so the join keeps one row per trial.
--   Sponsor classes (decided 9 Nov): industry = INDUSTRY; academic = OTHER, OTHER_GOV, NIH, FED,
--   NETWORK, INDIV; unclassified = UNKNOWN, AMBIG, NULL. Two groups only for this first look;
--   the three sponsor groups (collaborator split) come in Phase 4b.
-- A trial carries several terms, so the term rows add up to more than 1,809: never sum them.
-- Export (from the repo root):
--   psql -d aact --csv -f sql/review/03_mesh_terms_by_sponsor.sql -o data/review/03_mesh_terms_by_sponsor.csv
-- (the coverage check at the bottom is commented out so the CSV holds one table)

WITH lead AS (
    SELECT t.nct_id,
           CASE
               WHEN sp.agency_class = 'INDUSTRY' THEN 'industry'
               WHEN sp.agency_class IN ('OTHER', 'OTHER_GOV', 'NIH', 'FED', 'NETWORK', 'INDIV')
                   THEN 'academic'
               ELSE 'unclassified'
           END AS sponsor_group
    FROM glp1.trials t
    LEFT JOIN sponsors sp ON sp.nct_id = t.nct_id
                         AND sp.lead_or_collaborator = 'lead'
),
terms AS (
    -- One row per trial x term (DISTINCT guards against a term listed twice in one trial)
    SELECT DISTINCT bc.nct_id, bc.downcase_mesh_term
    FROM browse_conditions bc
    JOIN glp1.trials t ON t.nct_id = bc.nct_id
    WHERE bc.mesh_type = 'mesh-list'
)
SELECT tm.downcase_mesh_term,
       COUNT(*)                                              AS n_trials,
       COUNT(*) FILTER (WHERE l.sponsor_group = 'industry')     AS n_industry,
       COUNT(*) FILTER (WHERE l.sponsor_group = 'academic')     AS n_academic,
       COUNT(*) FILTER (WHERE l.sponsor_group = 'unclassified') AS n_unclassified,
       ROUND(100.0 * COUNT(*) FILTER (WHERE l.sponsor_group = 'industry') / COUNT(*), 1)
                                                             AS pct_industry
FROM terms tm
JOIN lead l ON l.nct_id = tm.nct_id
GROUP BY tm.downcase_mesh_term
ORDER BY n_trials DESC, tm.downcase_mesh_term;

-- Coverage check: how many trials have no mesh-list term at all (they'd never get an indication)
-- SELECT COUNT(*) AS n_trials,
--        COUNT(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM browse_conditions bc
--                                           WHERE bc.nct_id = t.nct_id
--                                             AND bc.mesh_type = 'mesh-list')) AS n_no_mesh_list
-- FROM glp1.trials t;
