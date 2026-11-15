-- Endometrial cancer: how many trials, and how many distinct lead sponsors?
SELECT
    COUNT(DISTINCT ti.nct_id)        AS trials,
    COUNT(DISTINCT s.name)         AS lead_sponsors
FROM glp1.trial_indications ti
JOIN ctgov.sponsors s
    ON s.nct_id = ti.nct_id
WHERE ti.indication = 'Endometrial cancer and atypical hyperplasia'
  AND s.lead_or_collaborator = 'lead';

SELECT ti.nct_id, s.name, st.start_date
FROM glp1.trial_indications ti
JOIN ctgov.sponsors s
    ON s.nct_id = ti.nct_id
   AND s.lead_or_collaborator = 'lead'
JOIN ctgov.studies st
    ON st.nct_id = ti.nct_id
WHERE ti.indication = 'Endometrial cancer and atypical hyperplasia'
ORDER BY st.start_date;

-- Endometrial cancer: what do the 12 trials actually measure?
SELECT
    ti.nct_id,
    st.brief_title,
    designo.measure
FROM glp1.trial_indications ti
JOIN ctgov.studies st
    ON st.nct_id = ti.nct_id
JOIN ctgov.design_outcomes designo
    ON designo.nct_id = ti.nct_id
WHERE ti.indication = 'Endometrial cancer and atypical hyperplasia'
  AND designo.outcome_type = 'primary'
ORDER BY ti.nct_id;