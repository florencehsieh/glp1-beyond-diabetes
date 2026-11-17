-- sql/review/03e_unlabelled_after_recall.sql  (Phase 3 top-up after the recall fix, 17 Nov 2026)
-- The recall fix (Review 11) took glp1.trials from 1,809 to 2,357. MeSH tags and the title keyword
-- pass labelled most new trials, but the Drug study label is a hand decision (03d), so new drug
-- studies arrive unlabelled. This lists every unlabelled trial, one row each, with a proposed label:
--   Drug study  conditions say healthy, PK, bioequivalence, impairment or insufficiency (Check 3 in
--               sql/pipeline/03, plus "insufficiency" for renal / hepatic insufficiency)
--   (blank)     a real condition: labelled by hand
-- unsure = TRUE when a drug-study row also names a condition that isn't healthy / impairment.
-- Decisions go into data/reference/indication_additions.csv with reason "unlabelled review 03e (17 Nov)".
-- Run with search_path = ctgov, public. Export: data/review/03e_unlabelled_after_recall.csv

WITH u AS (
    SELECT t.nct_id
    FROM glp1.trials t
    WHERE NOT EXISTS (SELECT 1 FROM glp1.trial_indications i WHERE i.nct_id = t.nct_id)
),
cond AS (   -- one row per trial: all conditions, and whether any is not a drug-study word
    SELECT c.nct_id,
           STRING_AGG(LOWER(c.name), ' | ' ORDER BY c.name) AS conditions,
           BOOL_OR(LOWER(c.name) !~ '(healthy|pharmacokinetic|bioequivalen|equivalen|impairment|insufficiency|volunteer)')
                                                             AS other_condition
    FROM conditions c
    JOIN u USING (nct_id)
    GROUP BY c.nct_id
),
lead AS (
    SELECT nct_id, agency_class, name
    FROM sponsors
    WHERE lead_or_collaborator = 'lead'
)
SELECT u.nct_id,
       CASE WHEN l.agency_class = 'INDUSTRY' THEN 'industry' ELSE 'academic' END AS lead,
       l.name                                                                    AS lead_sponsor,
       st.phase,
       d.primary_purpose                                                         AS purpose,
       EXTRACT(YEAR FROM st.start_date)::int                                     AS start_year,
       c.conditions,
       COALESCE(st.official_title, st.brief_title)                               AS title,
       CASE WHEN c.conditions ~ '(healthy|pharmacokinetic|bioequivalen|equivalen|impairment|insufficiency)'
            THEN 'Drug study' END                                                AS proposed,
       (c.conditions ~ '(healthy|pharmacokinetic|bioequivalen|equivalen|impairment|insufficiency)'
        AND c.other_condition)                                                   AS unsure,
       NULL::text                                                                AS my_decision,
       NULL::text                                                                AS reason
FROM u
JOIN studies st         ON st.nct_id = u.nct_id
LEFT JOIN designs d     ON d.nct_id = u.nct_id
LEFT JOIN lead l        ON l.nct_id = u.nct_id
LEFT JOIN cond c        ON c.nct_id = u.nct_id
ORDER BY proposed NULLS FIRST, unsure DESC, c.conditions;
