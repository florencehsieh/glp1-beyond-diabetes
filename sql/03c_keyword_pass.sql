-- sql/03c_keyword_pass.sql  (Phase 3: title keyword pass, option B of 11 Nov)
-- Needs glp1.trials (sql/02) and glp1.trial_indications (sql/03b).
-- Finds trials whose official title names an indication they aren't labelled with yet,
-- because sponsors often tag only the population (SELECT, FLOW, STEP-HFpEF).
-- Every hit is reviewed by hand; yes decisions go in data/reference/indication_additions.csv,
-- then rerun 02a and 03b. Keywords were written BEFORE looking at hits (11 Nov walk),
-- except 'cardiovascular outcomes', added 11 Nov after SELECT missed the known-trials check.
-- Export (from the repo root):
--   psql -d aact --csv -f sql/03c_keyword_pass.sql -o data/review/03c_keyword_hits.csv

WITH kw (indication, pattern) AS (
    VALUES
    -- Not ischaemia: that belongs to ASCVD
    ('Heart failure', 'heart failure|cardiac failure|hfpef|preserved ejection fraction|hfref|reduced ejection fraction'),
    -- Not fibrosis or cirrhosis: those also come from alcohol or hepatitis
    ('MASLD', '\m(mash|masld|nash|nafld)\M|steatohepatitis|fatty liver|hepatic steatosis'),
    -- Not renal impairment (usually a PK study) or acute kidney injury
    ('CKD', 'chronic kidney disease|\mckd\M|kidney disease|diabetic kidney disease|diabetic nephropathy|albuminuria'),
    -- Plain "cardiovascular" is too broad: those titles come out as 'ASCVD?' for hand review below.
    -- Stroke: prevention -> ASCVD, acute treatment -> Stroke (decided by hand)
    ('ASCVD', 'cardiovascular events|cardiovascular outcomes|\mmace\M|atherosclerotic|\mascvd\M|coronary artery disease|myocardial infarction|heart attack|\mstroke\M|peripheral arter(y|ial) disease')
),
hits AS (
    SELECT k.indication, t.nct_id
    FROM kw k
    JOIN glp1.trials t ON TRUE
    JOIN ctgov.studies s ON s.nct_id = t.nct_id
    WHERE COALESCE(s.official_title, s.brief_title) ~* k.pattern
    UNION
    SELECT 'ASCVD?', t.nct_id                 -- plain "cardiovascular" only: hand review
    FROM glp1.trials t
    JOIN ctgov.studies s ON s.nct_id = t.nct_id
    WHERE COALESCE(s.official_title, s.brief_title) ~* 'cardiovascular'
      AND COALESCE(s.official_title, s.brief_title) !~* (SELECT pattern FROM kw WHERE indication = 'ASCVD')
)
SELECT h.indication AS keyword_indication,
       h.nct_id,
       CASE WHEN sp.agency_class = 'INDUSTRY' THEN 'industry' ELSE 'academic' END AS lead,
       s.phase,
       (SELECT STRING_AGG(i.indication, '; ' ORDER BY i.indication)
          FROM glp1.trial_indications i WHERE i.nct_id = h.nct_id)        AS labelled_now,
       COALESCE(s.official_title, s.brief_title)                          AS title,
       (SELECT STRING_AGG(o.measure, ' || ')
          FROM design_outcomes o WHERE o.nct_id = h.nct_id AND o.outcome_type = 'primary') AS primary_outcomes
FROM hits h
JOIN ctgov.studies s ON s.nct_id = h.nct_id
LEFT JOIN ctgov.sponsors sp ON sp.nct_id = h.nct_id AND sp.lead_or_collaborator = 'lead'
WHERE NOT EXISTS (SELECT 1 FROM glp1.trial_indications i                -- only trials not yet labelled with it
                  WHERE i.nct_id = h.nct_id AND i.indication = REPLACE(h.indication, '?', ''))
  AND NOT (h.indication = 'ASCVD?' AND EXISTS (SELECT 1 FROM glp1.trial_indications i
                  WHERE i.nct_id = h.nct_id AND i.indication = 'Heart failure'))
ORDER BY 1, 2;
