-- sql/review/01c_unclear_names.sql
-- Shows every trial behind the 12 "review: unclear" names, so you can judge them.
WITH unclear(drug_name) AS (
    VALUES ('glp-1'), ('glucagon-like peptide-1'), ('glucagon-like peptide 1'),
           ('glucagon like peptide-1'), ('glucagon-like peptide-1 (glp-1)'),
           ('incretin-based therapies (glp-1 and glp-1/gip)'), ('glp-1 plus basal insulin'),
           ('glucose-insulinotropic peptide, glucagon-like peptide-1'), ('glp 1'),
           ('glucagon like peptide -1'), ('glp-1 control'), ('glucagon-like peptide-1,')
),
hits AS (
    SELECT i.nct_id, LOWER(i.name) AS drug_name, i.description
    FROM interventions i
    UNION ALL
    SELECT o.nct_id, LOWER(o.name), i.description
    FROM intervention_other_names o
    JOIN interventions i ON i.id = o.intervention_id
)
SELECT DISTINCT
       h.drug_name,
       h.nct_id,
       s.brief_title,
       s.study_type,
       h.description
FROM hits h
JOIN unclear u ON u.drug_name = h.drug_name
JOIN studies s ON s.nct_id = h.nct_id
ORDER BY h.drug_name, h.nct_id;