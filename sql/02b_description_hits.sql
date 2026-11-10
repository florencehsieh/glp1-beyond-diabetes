-- sql/02b_description_hits.sql  (Phase 2, recall-gap review, decided 10 Nov)
-- Finds GLP-1 drugs the name search missed: interventions whose DESCRIPTION has GLP-1
-- wording, in interventional trials not already in glp1_interventions. Mostly
-- development codes (e.g. VK2735: "a peptide GLP-1 and GIP dual agonist").
-- One row per intervention name x trial, with the evidence for a hand decision.
-- first_pass is a suggestion only; the decision is made by hand, as in 01b Reviews 1-4.
-- Needs sql/02a_load_reference.sql loaded; run with search_path = ctgov, public.
-- Pieces 1-3 copy glp1_interventions from 02_glp1_trials.sql: keep them in step.
-- Known blind spot: codes whose description has no GLP-1 wording (HEC88473, PB1023).

WITH glp1_interventions AS (
    SELECT i.nct_id, i.id AS intervention_id
    FROM interventions i
    JOIN glp1.name_map m ON LOWER(i.name) = m.drug_name
    WHERE m.decision = 'keep'
    UNION
    SELECT o.nct_id, o.intervention_id
    FROM intervention_other_names o
    JOIN glp1.name_map m ON LOWER(o.name) = m.drug_name
    WHERE m.decision = 'keep'
    UNION
    SELECT t.nct_id, i.id
    FROM glp1.trial_overrides t
    JOIN interventions i ON t.nct_id = i.nct_id AND LOWER(i.name) = t.drug_name
    WHERE t.decision = 'keep'
),
hits AS (
    -- Same pattern as 01_explore_names.sql line 11, plus the spelled-out hormone name
    SELECT i.nct_id, i.id AS intervention_id, i.name, i.intervention_type,
           REGEXP_REPLACE(i.description, '\s+', ' ', 'g') AS description
    FROM interventions i
    JOIN studies s ON s.nct_id = i.nct_id
    WHERE i.description ~* '(glutide|enatide|dutide|tirzepatide|retatrutide|orforglipron|danuglipron|glp[- ]?1|glucagon[- ]like peptide[- ]?1|ozempic|wegovy|rybelsus|mounjaro|zepbound|victoza|saxenda|trulicity|byetta|bydureon|lyxumia|adlyxin|tanzeum|soliqua|xultophy|cagrisema|iglarlixi|ideglira)'
      AND s.study_type = 'INTERVENTIONAL'
      AND i.intervention_type IN ('DRUG', 'BIOLOGICAL', 'COMBINATION_PRODUCT')
      AND i.name !~* '(gliptin|dpp|placebo)'                  -- DPP-4 inhibitors, placebos
      AND NOT EXISTS (SELECT 1 FROM glp1_interventions g WHERE g.nct_id = i.nct_id)
),
arm_types AS (
    -- Which arm types hold this intervention (aggregated first: one row per intervention)
    SELECT dgi.intervention_id,
           STRING_AGG(DISTINCT dg.group_type, ', ' ORDER BY dg.group_type) AS arm_types
    FROM design_group_interventions dgi
    JOIN design_groups dg ON dg.id = dgi.design_group_id
    WHERE dgi.intervention_id IN (SELECT intervention_id FROM hits)
    GROUP BY dgi.intervention_id
)
SELECT
    CASE
        WHEN h.name ~* '(teduglutide|glepaglutide|apraglutide)'               THEN 'exclude: GLP-2'
        -- Rules kept narrow on purpose: anything they miss goes to hand review
        WHEN h.name ~* '(exendin|avexitide)'                                  THEN 'exclude: receptor blocker'
        WHEN h.name ~* '^(glp[- ]?1|glucagon[- ]?like[- ]?peptide|native human glucagon|synthetic glp)'
         AND h.description ~* '(infus|pmol)'                                  THEN 'exclude: native GLP-1'
        WHEN h.description ~* '(continue glp|prior to the procedure)'        THEN 'exclude: background use'
        ELSE 'review'
    END                     AS first_pass,
    h.nct_id,
    LOWER(h.name)           AS drug_name,
    h.intervention_type,
    a.arm_types,
    sp.agency_class         AS lead_class,
    sp.name                 AS lead_sponsor,
    s.brief_title,
    h.description
FROM hits h
JOIN studies s        ON s.nct_id = h.nct_id
LEFT JOIN arm_types a ON a.intervention_id = h.intervention_id
LEFT JOIN sponsors sp ON sp.nct_id = h.nct_id AND sp.lead_or_collaborator = 'lead'
ORDER BY first_pass, drug_name, h.nct_id;
