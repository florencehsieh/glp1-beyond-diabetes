-- sql/review/04h_benchmark_trials.sql  (Phase 4, "so what" lines: size benchmarks for PCOS, 14 Nov)
-- Needs glp1.trials (sql/pipeline/02) and glp1.trial_indications (sql/pipeline/03).
--
-- Question: PCOS has about 5 M women in the US and 6 M in the EU-27 (GBD 2023). Is that big enough
-- for industry? Benchmark = an indication where industry already runs a GLP-1 Phase 3 *as a disease
-- drug*. This lists every industry-led Phase 3 (incl. PHASE2/PHASE3) in a new indication with its
-- primary outcomes, so each can be read by hand: disease endpoint, weight endpoint, or both.
--
-- Result (14 Nov): see data/review/README.md, Review 10.
--
-- Export (from the repo root):
--   psql -d aact --csv -f sql/review/04h_benchmark_trials.sql -o data/review/04h_benchmark_trials.csv

SELECT
    ti.indication,
    st.nct_id,
    st.phase,
    st.overall_status,
    sp.name                                   AS lead_sponsor,
    st.start_date,
    st.brief_title,
    string_agg(d.measure, ' || ' ORDER BY d.id) AS primary_outcomes,
    bool_or(d.measure ~* 'weight|bmi|body mass') AS weight_in_primary
FROM glp1.trial_indications ti
JOIN ctgov.studies st
    ON st.nct_id = ti.nct_id
JOIN ctgov.sponsors sp
    ON sp.nct_id = ti.nct_id
   AND sp.lead_or_collaborator = 'lead'
   AND sp.agency_class = 'INDUSTRY'
JOIN ctgov.design_outcomes d
    ON d.nct_id = ti.nct_id
   AND d.outcome_type = 'primary'
WHERE st.phase IN ('PHASE3', 'PHASE2/PHASE3')
  AND st.overall_status <> 'WITHDRAWN'
  AND ti.indication NOT IN ('Home base', 'Drug study')
GROUP BY ti.indication, st.nct_id, st.phase, st.overall_status, sp.name, st.start_date, st.brief_title
ORDER BY ti.indication, st.start_date;
