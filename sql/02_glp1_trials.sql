-- sql/02_glp1_trials.sql  (Phase 2)
-- Needs sql/02a_load_reference.sql loaded first; run with search_path = ctgov, public.
-- Builds glp1_trials: one row per interventional trial that gives a GLP-1 in a tested arm.
--   Steps 1-2  glp1_interventions: GLP-1 interventions from names, other names, overrides (2,140 trials)
--   Step 3     glp1_arm_check: arm rule Option B (decided 9 Nov), one row per trial + arm_rule label
--   Step 4     glp1_trials: interventional only; headline count 1,845 (10 Nov, after the 02b review)
--   Step 5     glp1_backbone: is_backbone flag (Option C, drug add-ons only), a limitation count
-- The Step 3b drop-out breakdown of the strict rule lives in git history (f27a302).

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

    -- Piece 3: trials rescued by hand (overrides), matched on the exact intervention
    SELECT t.nct_id, i.id AS intervention_id, t.canonical_drug
    FROM glp1.trial_overrides t
    JOIN interventions i ON t.nct_id = i.nct_id
                        AND LOWER(i.name) = t.drug_name
    WHERE t.decision = 'keep'
),
glp1_arm_check AS (
    -- Step 3, arm rule Option B. Two pieces, disjoint by construction:
    -- Piece A: the GLP-1 itself sits in an EXPERIMENTAL arm (the strict rule = sensitivity check)
    SELECT DISTINCT gi.nct_id, 'experimental arm' AS arm_rule
    FROM glp1_interventions gi
    JOIN design_group_interventions dgi ON gi.intervention_id = dgi.intervention_id  -- drug → bridge
    JOIN design_groups dg               ON dgi.design_group_id = dg.id               -- bridge → arm
    WHERE dg.group_type = 'EXPERIMENTAL'

    UNION

    -- Piece B: the trial has no EXPERIMENTAL arm at all, and the GLP-1 sits in some arm.
    -- Sponsors label arms loosely (e.g. Exenatide-PD3). Comparator-only trials stay out:
    -- they have an EXPERIMENTAL arm, just not one with the GLP-1.
    SELECT DISTINCT gi.nct_id, 'no experimental arm' AS arm_rule
    FROM glp1_interventions gi
    JOIN design_group_interventions dgi ON gi.intervention_id = dgi.intervention_id
    WHERE NOT EXISTS (SELECT 1
                      FROM design_groups dg
                      WHERE dg.nct_id = gi.nct_id
                        AND dg.group_type = 'EXPERIMENTAL')
),
glp1_arms AS (
    -- Helper for Step 5: every arm that holds a GLP-1, with which drug
    SELECT DISTINCT gi.nct_id, dg.id AS arm_id, dg.group_type, gi.canonical_drug
    FROM glp1_interventions gi
    JOIN design_group_interventions dgi ON gi.intervention_id = dgi.intervention_id
    JOIN design_groups dg               ON dgi.design_group_id = dg.id
),
glp1_backbone AS (
    -- Step 5, backbone flag (Option C, decided 10 Nov). A flag for the limitation, not a filter.
    -- Backbone = the same GLP-1 (canonical_drug) sits in an EXPERIMENTAL arm and a
    -- comparator arm, and the experimental arm adds a drug the comparator arm lacks.
    -- Drug = DRUG or BIOLOGICAL, not placebo. Behavioural, device, diet add-ons don't count.
    -- Leaves out head-to-heads (different GLP-1s) and dose comparisons (nothing added).
    SELECT DISTINCT e.nct_id
    FROM glp1_arms e
    JOIN glp1_arms c
      ON c.nct_id = e.nct_id
     AND c.canonical_drug IS NOT DISTINCT FROM e.canonical_drug   -- class-wording rows have NULL
     AND c.group_type IN ('ACTIVE_COMPARATOR', 'PLACEBO_COMPARATOR', 'SHAM_COMPARATOR')
    JOIN design_group_interventions de ON de.design_group_id = e.arm_id
    JOIN interventions i               ON i.id = de.intervention_id
    WHERE e.group_type = 'EXPERIMENTAL'
      AND i.intervention_type IN ('DRUG', 'BIOLOGICAL')
      AND i.name !~* 'placebo'
      AND NOT EXISTS (SELECT 1 FROM glp1_interventions gi            -- add-on isn't itself a GLP-1
                      WHERE gi.intervention_id = i.id)
      AND NOT EXISTS (SELECT 1 FROM design_group_interventions dc    -- and the comparator lacks it
                      WHERE dc.design_group_id = c.arm_id
                        AND dc.intervention_id = i.id)
),
glp1_trials AS (
    -- Step 4: one row per interventional GLP-1 trial
    SELECT s.nct_id, a.arm_rule,
           (b.nct_id IS NOT NULL) AS is_backbone,
           s.start_date, s.phase, s.overall_status, s.source_class
    FROM studies s
    JOIN glp1_arm_check a     ON a.nct_id = s.nct_id
    LEFT JOIN glp1_backbone b ON b.nct_id = s.nct_id
    WHERE s.study_type = 'INTERVENTIONAL'
)
-- Headline count, split by arm rule (the NULL row is the total), with backbone trials
SELECT arm_rule,
       COUNT(*)                                   AS n_rows,
       COUNT(DISTINCT nct_id)                     AS n_trials,
       COUNT(DISTINCT nct_id) FILTER (WHERE is_backbone) AS n_backbone
FROM glp1_trials
GROUP BY ROLLUP (arm_rule)
ORDER BY arm_rule NULLS LAST;
