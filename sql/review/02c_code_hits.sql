-- sql/review/02c_code_hits.sql  (Phase 2 reopened, recall gap 2: code-only drugs, 15 Nov 2026)
-- Finds GLP-1 drugs named only by a development code, with no GLP-1 wording anywhere in the
-- record (02b's blind spot: e.g. AZD5004, HRS9531, CT-388, amycretin as NNC0487-0111).
-- New GLP-1s run their first trials in obesity, type 2 diabetes or weight, so the search
-- lists every code in those industry-led trials, one row per code, and the code is
-- reviewed by hand, not the trial. A kept code goes into glp1_name_additions.csv and then
-- joins every trial that uses it, in any disease.
-- Scope (decided 15 Nov, option A): codes first seen in 2015 or later, no other drug class
-- named in their intervention descriptions, and 2+ trials; plus 1-trial codes whose
-- description hints at the class. Left out: ~380 1-trial codes (a write-up limitation).
-- Recall test before scoping: 15 of 15 known code-only GLP-1s found (see data/review/README.md).
-- Known leak: the other-class filter drops a GLP-1 whose trials also name insulin (GZR18,
-- with GZR4) or another drug. Check: rerun with the filter flipped (27 codes, 15 Nov);
-- GZR18 and ZT002 (zovaglutide) were found that way and added by hand.
-- Run with search_path = ctgov, public. Export: data/review/02c_code_hits.csv

WITH names AS (   -- intervention names and other names, drugs only
    SELECT i.nct_id, i.id AS intervention_id, i.name
    FROM interventions i
    WHERE i.intervention_type IN ('DRUG', 'BIOLOGICAL', 'COMBINATION_PRODUCT')
    UNION
    SELECT o.nct_id, o.intervention_id, o.name
    FROM intervention_other_names o
    JOIN interventions i ON i.id = o.intervention_id
    WHERE i.intervention_type IN ('DRUG', 'BIOLOGICAL', 'COMBINATION_PRODUCT')
),
codes AS (   -- the code inside a name, normalised: "HRS-9531 injection" -> hrs9531
    SELECT n.nct_id, n.intervention_id, LOWER(n.name) AS drug_name,
           LOWER(REGEXP_REPLACE(SUBSTRING(n.name FROM '(?i)([a-z]{1,6}[- ]?[0-9]{2,}[a-z]?)'),
                                '[- ]', '', 'g')) AS code
    FROM names n
    WHERE n.name ~* '[a-z]{1,6}[- ]?[0-9]{2,}'
      AND n.name !~* 'placebo$'
),
metabolic AS (   -- industry-led, interventional, not withdrawn, obesity / diabetes / weight
    SELECT st.nct_id
    FROM studies st
    JOIN sponsors sp ON sp.nct_id = st.nct_id AND sp.lead_or_collaborator = 'lead'
    WHERE sp.agency_class = 'INDUSTRY'
      AND st.study_type = 'INTERVENTIONAL'
      AND st.overall_status <> 'WITHDRAWN'
      AND EXISTS (SELECT 1 FROM conditions c
                  WHERE c.nct_id = st.nct_id
                    AND c.downcase_name ~ '(obes|overweight|diabet|t2dm|t2d\M|weight)')
),
cand AS (   -- codes in those trials that aren't in the name map and whose trial isn't in the list
    SELECT c.code, COUNT(DISTINCT c.nct_id) AS n_metabolic_trials
    FROM codes c
    JOIN metabolic m USING (nct_id)
    WHERE c.code IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM glp1.name_map nm WHERE nm.drug_name = c.drug_name)
      AND c.nct_id NOT IN (SELECT nct_id FROM glp1.trials)
    GROUP BY c.code
),
evidence AS (   -- every trial with the code (any disease), aggregated to one row per code
    SELECT c.code,
           COUNT(DISTINCT c.nct_id)                                        AS n_trials_all,
           MIN(st.start_date)                                              AS first_start,
           STRING_AGG(DISTINCT c.drug_name, ' | ')                         AS names,
           STRING_AGG(DISTINCT sp.name, ' | ')                             AS lead_sponsors,
           BOOL_OR(i.description ~* '(insulin|sglt|gliflozin|dpp-?4|gliptin|metformin|sulfonylurea|thiazolidinedione|glucokinase|vaccine|statin|pcsk9)')
                                                                           AS other_class,
           BOOL_OR(i.description ~* '(glp|incretin|gip|glucagon|amylin|agonist)') AS class_hint,
           LEFT(STRING_AGG(DISTINCT REGEXP_REPLACE(i.description, '\s+', ' ', 'g'), ' || '), 400)
                                                                           AS descriptions,
           LEFT(STRING_AGG(DISTINCT st.brief_title, ' || '), 400)          AS titles
    FROM codes c
    JOIN cand USING (code)
    JOIN studies st       ON st.nct_id = c.nct_id
    JOIN interventions i  ON i.id = c.intervention_id
    LEFT JOIN sponsors sp ON sp.nct_id = c.nct_id AND sp.lead_or_collaborator = 'lead'
    WHERE st.study_type = 'INTERVENTIONAL' AND st.overall_status <> 'WITHDRAWN'
    GROUP BY c.code
)
SELECT e.code, c.n_metabolic_trials, e.n_trials_all, e.first_start, e.class_hint,
       e.lead_sponsors, e.names, e.titles, e.descriptions
FROM evidence e
JOIN cand c USING (code)
WHERE NOT COALESCE(e.other_class, FALSE)
  AND e.first_start >= '2015-01-01'
  AND (c.n_metabolic_trials >= 2 OR e.class_hint)
ORDER BY c.n_metabolic_trials DESC, e.code;
