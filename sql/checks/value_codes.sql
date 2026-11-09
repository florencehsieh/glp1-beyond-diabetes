-- value_codes.sql: list the exact codes in every column Phases 2–4 filter on.
-- Runs on all AACT trials, not just GLP-1, because we only need the code list.
-- Keep NULLs in every result: that's where trials drop out silently.

-- 1. Sponsor classes: which codes count as academic? (Q2 sponsor groups)
SELECT agency_class, lead_or_collaborator,
       COUNT(*)               AS n_rows,
       COUNT(DISTINCT nct_id) AS n_trials
FROM sponsors
GROUP BY 1, 2
ORDER BY 1, 2;

-- 1b. Top lead-sponsor names per class: check each class holds what you expect
SELECT agency_class, name, n_trials
FROM (
    SELECT agency_class, name, COUNT(DISTINCT nct_id) AS n_trials,
           ROW_NUMBER() OVER (PARTITION BY agency_class
                              ORDER BY COUNT(DISTINCT nct_id) DESC) AS rn
    FROM sponsors
    WHERE lead_or_collaborator = 'lead'
    GROUP BY 1, 2
) t
WHERE rn <= 15
ORDER BY agency_class, n_trials DESC;

-- 2. study_type (Phase 2 filter)
SELECT study_type, COUNT(*) AS n_trials FROM studies GROUP BY 1 ORDER BY 2 DESC;

-- 3. phase (Q3 momentum: combined codes, NA, blanks)
SELECT phase, COUNT(*) AS n_trials FROM studies GROUP BY 1 ORDER BY 2 DESC;

-- 4. overall_status (Q3 status split + the WITHDRAWN question)
SELECT overall_status, COUNT(*) AS n_trials FROM studies GROUP BY 1 ORDER BY 2 DESC;

-- 5. group_type (Phase 2 experimental-arm join)
SELECT group_type, COUNT(*) AS n_arms FROM design_groups GROUP BY 1 ORDER BY 2 DESC;

-- 6. mesh_type (Phase 3 disease grouping)
SELECT mesh_type, COUNT(*) AS n_rows FROM browse_conditions GROUP BY 1 ORDER BY 2 DESC;

-- 7. Who owns the NULL arm types? (Phase 2 experimental-arm join)
--    If NULL arms belong only to observational studies, the
--    group_type = 'EXPERIMENTAL' join loses no interventional arms to NULLs.
SELECT s.study_type,
       (dg.group_type IS NULL)   AS null_type,
       COUNT(*)                  AS n_arms,
       COUNT(DISTINCT dg.nct_id) AS n_trials
FROM design_groups dg
JOIN studies s USING (nct_id)
GROUP BY 1, 2
ORDER BY 1, 2;

-- 8. NULL phase vs 'NA' phase: two kinds of "no phase" (Q3 momentum)
--    'NA' is a text code (not applicable: devices, behavioural);
--    NULL is a missing value. WHERE phase IS NULL misses 'NA'.
SELECT phase IS NULL AS null_phase,
       phase = 'NA'  AS na_phase,   -- shows blank on NULL rows: NULL = 'NA' is NULL
       study_type,
       COUNT(*)      AS n_trials
FROM studies
WHERE phase IS NULL OR phase = 'NA'
GROUP BY 1, 2, 3
ORDER BY 4 DESC;
