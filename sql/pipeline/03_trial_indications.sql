-- sql/pipeline/03_trial_indications.sql  (Phase 3: give every GLP-1 trial its indication(s), 11 Nov)
-- Needs glp1.trials (sql/pipeline/02) and glp1.mesh_tags + glp1.indication_additions (sql/pipeline/01).
-- Run from the repo root:  psql -d aact -f sql/pipeline/03_trial_indications.sql
--
-- Saves glp1.trial_indications: one row per trial x indication. Exports data/results/03_trial_indications.csv. Three sources, combined:
--   'mesh'      a mesh-list term tagged home or real (Review 6). home -> indication 'Home base'.
--               broad, measure and error terms, and untagged terms, map to nothing.
--   'condition' trials with NO mesh-list term whose sponsor-typed condition is plain type 2
--               diabetes or obesity spelled in a way MeSH didn't match ("type2 diabetes", "t2dm",
--               "non-diabetic obesity") -> 'Home base'. Words that change the target are excluded
--               (healthy, type 1, kidney/renal, neuropathy, steroid, double): those go to hand review.
--   'addition'  a hand decision in data/reference/indication_additions.csv
--               (title keyword hits, single-trial fixes, the drug-study bucket).
-- Additions only add; they never remove a MeSH tag (Decided, 11 Nov).
-- A trial can have several indications: count it in each, never sum across indications.
-- Trials with no row here are unmapped: the coverage check below lists them.

DROP TABLE IF EXISTS glp1.trial_indications;
CREATE TABLE glp1.trial_indications AS
WITH from_mesh AS (
    SELECT DISTINCT bc.nct_id,
           CASE mt.tag WHEN 'home' THEN 'Home base' ELSE mt.indication END AS indication
    FROM ctgov.browse_conditions bc
    JOIN glp1.trials t     ON t.nct_id = bc.nct_id
    JOIN glp1.mesh_tags mt ON mt.downcase_mesh_term = bc.downcase_mesh_term
    WHERE bc.mesh_type = 'mesh-list'          -- never mix with mesh-ancestor
      AND mt.tag IN ('home', 'real')
),
no_mesh AS (
    SELECT t.nct_id FROM glp1.trials t
    WHERE NOT EXISTS (SELECT 1 FROM ctgov.browse_conditions b
                      WHERE b.nct_id = t.nct_id AND b.mesh_type = 'mesh-list')
),
from_condition AS (
    SELECT n.nct_id, 'Home base' AS indication
    FROM no_mesh n
    JOIN ctgov.conditions c ON c.nct_id = n.nct_id
    GROUP BY n.nct_id
    HAVING STRING_AGG(LOWER(c.name), ' | ') ~ '(type ?2|t2d|obes|weight management)'
       AND STRING_AGG(LOWER(c.name), ' | ') !~ '(healthy|type ?1|renal|kidney|neuropath|double|steroid|glucocorticoid|pancreatectomy)'
),
from_additions AS (
    SELECT a.nct_id, a.indication
    FROM glp1.indication_additions a
    JOIN glp1.trials t ON t.nct_id = a.nct_id
)
SELECT nct_id, indication, STRING_AGG(source, '+' ORDER BY source) AS source
FROM (
    SELECT nct_id, indication, 'mesh' AS source FROM from_mesh
    UNION ALL
    SELECT nct_id, indication, 'condition' FROM from_condition
    UNION ALL
    SELECT nct_id, indication, 'addition' FROM from_additions
) s
GROUP BY nct_id, indication;               -- one row per trial x indication; source shows both if both

ALTER TABLE glp1.trial_indications ADD PRIMARY KEY (nct_id, indication);

-- Check 1: rows, trials mapped, trials unmapped (mapped + unmapped = 1,809)
SELECT COUNT(*)                                    AS n_rows,
       COUNT(DISTINCT nct_id)                      AS n_trials_mapped,
       (SELECT COUNT(*) FROM glp1.trials) - COUNT(DISTINCT nct_id) AS n_trials_unmapped
FROM glp1.trial_indications;

-- Check 2: trials per indication (a trial counts once per indication; never sum this column)
SELECT indication, COUNT(*) AS n_trials
FROM glp1.trial_indications
GROUP BY 1
ORDER BY 2 DESC;

-- Check 3: drug-study candidates for hand review (README Review 6): unmapped trials whose
-- conditions say healthy, PK, bioequivalence or impairment. Decisions go in indication_additions.csv
SELECT t.nct_id, STRING_AGG(LOWER(c.name), ' | ') AS conditions
FROM glp1.trials t
JOIN ctgov.conditions c ON c.nct_id = t.nct_id
WHERE NOT EXISTS (SELECT 1 FROM glp1.trial_indications i WHERE i.nct_id = t.nct_id)
GROUP BY t.nct_id
HAVING STRING_AGG(LOWER(c.name), ' | ') ~ '(healthy|pharmacokinetic|bioequivalen|equivalen|impairment)'
ORDER BY 2;

-- Check 4: sub-counts promised in Review 6 (README): MASH-titled trials inside MASLD,
-- HFpEF-titled trials inside Heart failure
SELECT i.indication, COUNT(*) AS n_subgroup
FROM glp1.trial_indications i
JOIN ctgov.studies s ON s.nct_id = i.nct_id
WHERE (i.indication = 'MASLD'         AND COALESCE(s.official_title, s.brief_title) ~* '\m(mash|nash)\M|steatohepatitis')
   OR (i.indication = 'Heart failure' AND COALESCE(s.official_title, s.brief_title) ~* 'hfpef|preserved ejection')
GROUP BY 1;

-- Export
\copy (SELECT * FROM glp1.trial_indications ORDER BY nct_id, indication) TO 'data/results/03_trial_indications.csv' WITH (FORMAT csv, HEADER)
