-- sql/01_explore_names.sql
WITH names AS (
    SELECT nct_id, LOWER(name) AS drug_name, 'interventions' AS src
    FROM interventions
    UNION ALL
    SELECT nct_id, LOWER(name), 'other_names'
    FROM intervention_other_names
)
SELECT drug_name, src, COUNT(DISTINCT nct_id) AS n_trials
FROM names
WHERE drug_name ~* '(glutide|enatide|dutide|tirzepatide|retatrutide|orforglipron|danuglipron|glp[- ]?1|ozempic|wegovy|rybelsus|mounjaro|zepbound|victoza|saxenda|trulicity|byetta|bydureon|lyxumia|adlyxin|tanzeum|soliqua|xultophy|cagrisema|iglarlixi|ideglira)'
GROUP BY drug_name, src
ORDER BY n_trials DESC;