-- sql/02_glp1_trials.sql  (Phase 2, work in progress)
-- Needs sql/02a_load_reference.sql loaded first; run with search_path = ctgov, public.
-- Status 9 Nov: Steps 1-2 (glp1_interventions: 2,050 trials) and the strict Step 3
-- (glp1_experimental: 1,485 trials) done; final SELECT = Step 3b drop-out breakdown
-- (190 not interventional, 14 no arm data, 361 GLP-1 only in non-experimental arms).
-- Next: replace glp1_experimental with glp1_arm_check (Option B), then Step 4.

WITH glp1_interventions AS (
    -- Piece 1: GLP-1 names in interventions
    SELECT i.nct_id, i.id AS intervention_id, m.canonical_drug
    FROM interventions i
    JOIN glp1.name_map m ON LOWER(i.name) = m.drug_name
    WHERE m.decision = 'keep'

    UNION

    -- Piece 2: GLP-1 names in intervention_other_names (brands, codes)
    SELECT o.nct_id, o.intervention_id, m.canonical_drug
    FROM intervention_other_names o
    JOIN glp1.name_map m ON LOWER(o.name) = m.drug_name
    WHERE m.decision = 'keep'

    UNION

    -- Piece 3: the 7 hand-rescued trials (overrides)
    SELECT t.nct_id, i.id AS intervention_id, t.canonical_drug
    FROM glp1.trial_overrides t
    JOIN interventions i ON t.nct_id = i.nct_id
    WHERE i.name ~* 'glp-1'
      AND t.decision = 'keep'
),
glp1_experimental AS (
    -- Step 3: keep trials where the GLP-1 itself sits in an EXPERIMENTAL arm
    SELECT DISTINCT gi.nct_id
    FROM glp1_interventions gi
    JOIN design_group_interventions dgi ON gi.intervention_id = dgi.intervention_id  -- drug → bridge
    JOIN design_groups dg               ON dgi.design_group_id = dg.id               -- bridge → arm
    WHERE dg.group_type = 'EXPERIMENTAL'
),
dropped AS (
    -- trials in glp1_interventions but NOT in glp1_experimental
    SELECT DISTINCT nct_id FROM glp1_interventions
    EXCEPT
    SELECT nct_id FROM glp1_experimental
)
SELECT
    CASE
        WHEN s.study_type <> 'INTERVENTIONAL'               THEN '1 not interventional'
        WHEN NOT EXISTS (SELECT 1 FROM design_groups dg
                         WHERE dg.nct_id = d.nct_id)        THEN '2 no arm data'
        WHEN NOT EXISTS (SELECT 1
                         FROM glp1_interventions gi
                         JOIN design_group_interventions dgi  ON dgi.intervention_id = gi.intervention_id
                         WHERE gi.nct_id = d.nct_id)        THEN '3 GLP-1 not linked to an arm'
        ELSE '4 GLP-1 only in non-experimental arms'
    END AS reason,
    COUNT(*) AS n_trials
FROM dropped d
JOIN studies s ON s.nct_id = d.nct_id
GROUP BY 1
ORDER BY 1;