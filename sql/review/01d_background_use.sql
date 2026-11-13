-- sql/review/01d_background_use.sql  (8 Nov 2026)
-- Purpose: Review 4. For the 34 names that 01b v5 labels 'review: background use',
--          show the evidence per name x trial: study type, which arm types the
--          GLP-1 intervention sits in, how many arms it's in vs the trial's total,
--          and the trial title. Used to bucket each row A-E.
-- Name list generated from 01b v5 with STRING_AGG(quote_literal(drug_name)), not typed.
-- Expected: 37 rows (34 names; 3 names sit in 2 trials).
WITH bg_names AS (
    SELECT UNNEST(ARRAY[
    '2 ogtts with and without glp-1 analogue',
    'abrupt cessation of semaglutide',
    'add glp-1 receptor agonist',
    'angiotensin converting enzyme inhibitors, angiotensin ii receptor blockers, dpp-4 inhibitors, glp-1 receptor agonists, sglt2 inhibitors, calcium channel blockers, β receptor blocker',
    'application of glp-1ras drugs',
    'comparator: exenatide',
    'discontinuation and reinitiation of tirzepatide',
    'glp-1 dose reduction',
    'glp-1 medication initiation',
    'glp-1 non stop',
    'glp-1 not stop for 1 week',
    'glp-1 ra cessation interval',
    'glp-1 ra discontinuation interval',
    'glp-1 ra users with prolonged fasting instructions',
    'glp-1 ra users with standard npo instructions',
    'glp-1 receptor agonist (e.g., semaglutide, tirzepatide) - prescribed by the treating physician as standard care; the study does not assign or alter treatment.',
    'glp-1 stop for 1 week',
    'gradual dose reduction of semaglutide',
    'gut motility quantification using a capsule after initiating glp-1ra therapy',
    'initiation of tirzepatide',
    'maintain dual therapy (sulf/pio) as comparator to liraglutide',
    'maintenance of glp-1 dose',
    'new use of oral semaglutide',
    'new use of semaglutide injection',
    'on glp1 only',
    'on glp1 plus hrt',
    'semaglutide dose-tapering regimen',
    'semaglutide injectable product (not provided by the study)',
    'sleeve gastrectomy plus early mazdutide initiation',
    'structured weight loss program including behavioral support and optional meal re-placement or pharmacotherapy with glucagon-like peptide-1 receptor agonists (glp1-ra)',
    'the glp-1 receptor agonist users',
    'time since last glp-1 ra dose',
    'tirzepatide is administered as part of routine clinical care for obesity management, according to standard prescribing practices. dosing and treatment duration are determined by the treating physician',
    'to utilize the freestyle libre 3 continuous glucose monitoring system (fsl3) to help prolong the length of time people with diabetes maintain adherence to glp-1 and dual gip/glp-1 agonists'
    ]) AS drug_name
),
-- every intervention name, keeping the intervention id so we can reach the arms
hits AS (
    SELECT i.nct_id, i.id AS intervention_id, LOWER(i.name) AS drug_name
    FROM interventions i
    UNION
    SELECT o.nct_id, o.intervention_id, LOWER(o.name)
    FROM intervention_other_names o
),
bg_hits AS (
    SELECT h.*
    FROM hits h
    JOIN bg_names b ON b.drug_name = h.drug_name
),
-- total arms per trial
arms AS (
    SELECT nct_id, COUNT(*) AS n_arms
    FROM design_groups
    GROUP BY nct_id
),
-- arms that contain the GLP-1 intervention (LEFT JOIN: some trials have no arm data)
glp1_arms AS (
    SELECT bh.nct_id, bh.drug_name,
           COUNT(DISTINCT dg.id) AS n_glp1_arms,
           STRING_AGG(DISTINCT dg.group_type, ', ') AS glp1_arm_types
    FROM bg_hits bh
    LEFT JOIN design_group_interventions dgi ON dgi.intervention_id = bh.intervention_id
    LEFT JOIN design_groups dg               ON dg.id = dgi.design_group_id
    GROUP BY bh.nct_id, bh.drug_name
)
SELECT g.drug_name, g.nct_id, s.study_type,
       g.glp1_arm_types, g.n_glp1_arms, a.n_arms,
       s.brief_title
FROM glp1_arms g
JOIN studies s   ON s.nct_id = g.nct_id
LEFT JOIN arms a ON a.nct_id = g.nct_id
ORDER BY s.study_type, g.drug_name, g.nct_id;
