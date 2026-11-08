WITH hits AS (
    SELECT DISTINCT i.nct_id
    FROM interventions i
    LEFT JOIN intervention_other_names o ON o.intervention_id = i.id
    WHERE i.name ~* 'bofanglutide' OR o.name ~* 'bofanglutide'   -- change the drug here (2 places)
)
SELECT h.nct_id, 'intervention' AS source,
       i.name || COALESCE(' (aka ' || STRING_AGG(o.name, ', ') || ')', '') AS label,
       i.description AS text
FROM hits h
JOIN interventions i ON i.nct_id = h.nct_id
LEFT JOIN intervention_other_names o ON o.intervention_id = i.id
GROUP BY h.nct_id, i.id, i.name, i.description
UNION ALL
SELECT h.nct_id, 'brief summary', NULL, b.description
FROM hits h JOIN brief_summaries b ON b.nct_id = h.nct_id
UNION ALL
SELECT h.nct_id, 'detailed description', NULL, d.description
FROM hits h JOIN detailed_descriptions d ON d.nct_id = h.nct_id
ORDER BY nct_id, source;