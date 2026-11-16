-- sql/review/02d_who_inn_check.sql  (Phase 2 reopened, recall check 3: WHO INN lists, 16 Nov 2026)
-- Outside check of the name list: every GLP-1-family INN in WHO Proposed INN Lists 70-135
-- (found by mechanism words, name endings and the glucagon-family sequence motif; scripts/02d_who_inn/parse.py),
-- matched to AACT on whole words. Written by an independent AI review, numbers re-checked by hand.
-- Run from the repo root:  psql -d aact -f sql/review/02d_who_inn_check.sql

\set ON_ERROR_STOP 1
CREATE TEMP TABLE inn (inn text, pl int);
\copy inn FROM 'data/review/02d_who_inn_candidates.csv' WITH (FORMAT csv)
ALTER TABLE inn ADD COLUMN w1 text; UPDATE inn SET w1 = split_part(inn,' ',1);

-- every intervention name / other name, one row per word
CREATE TEMP TABLE name_words AS
SELECT nct_id, intervention_id, lname, src, w
FROM (
  SELECT nct_id, id AS intervention_id, LOWER(name) AS lname, 'name' AS src FROM ctgov.interventions
  UNION ALL
  SELECT nct_id, intervention_id, LOWER(name), 'other_name' FROM ctgov.intervention_other_names
) n, regexp_split_to_table(n.lname, '[^a-z0-9]+') AS w
WHERE w <> '';
CREATE INDEX ON name_words (w);

CREATE TEMP TABLE hits AS
SELECT DISTINCT i.inn, nw.nct_id, nw.intervention_id, nw.lname, nw.src
FROM inn i JOIN name_words nw ON nw.w = i.w1
WHERE i.inn NOT LIKE '% %' OR nw.lname ~ ('\m' || i.inn || '\M');

-- on my list? keep rows naming the INN (canonical or as a word in drug_name)
CREATE TEMP TABLE onlist AS
SELECT i.inn,
  COUNT(*) FILTER (WHERE m.decision='keep') AS n_keep,
  COUNT(*) FILTER (WHERE m.decision='exclude') AS n_excl,
  BOOL_OR(m.decision='keep' AND m.drug_name ~ ('(^|[^a-z0-9])' || i.inn || '($|[^a-z0-9])')) AS bare_word_kept
FROM inn i LEFT JOIN glp1.name_map m
  ON m.canonical_drug = i.inn OR m.drug_name ~ ('(^|[^a-z0-9])' || i.inn || '($|[^a-z0-9])')
GROUP BY i.inn;

\copy (SELECT i.inn, i.pl, o.n_keep, o.n_excl, COUNT(DISTINCT h.nct_id) AS aact_trials, COUNT(DISTINCT h.nct_id) FILTER (WHERE t.nct_id IS NULL) AS missing FROM inn i JOIN onlist o USING (inn) LEFT JOIN hits h USING (inn) LEFT JOIN glp1.trials t ON t.nct_id = h.nct_id GROUP BY 1,2,3,4 ORDER BY i.pl, i.inn) TO 'data/review/02d_who_inn_summary.csv' WITH (FORMAT csv, HEADER true)

-- detail of every missing trial
\copy (SELECT h.inn, h.nct_id, s.study_type, s.overall_status, h.src, h.lname, (m.drug_name IS NOT NULL) AS name_is_keep, m.decision AS name_decision, EXISTS (SELECT 1 FROM design_group_interventions dgi JOIN design_groups dg ON dg.id=dgi.design_group_id WHERE dgi.intervention_id=h.intervention_id AND dg.group_type='EXPERIMENTAL') AS in_exp_arm, EXISTS (SELECT 1 FROM design_groups dg WHERE dg.nct_id=h.nct_id AND dg.group_type='EXPERIMENTAL') AS trial_has_exp, EXISTS (SELECT 1 FROM design_group_interventions dgi WHERE dgi.intervention_id=h.intervention_id) AS in_any_arm, left(s.brief_title,90) AS title FROM hits h JOIN ctgov.studies s USING (nct_id) LEFT JOIN glp1.name_map m ON m.drug_name = h.lname WHERE NOT EXISTS (SELECT 1 FROM glp1.trials t WHERE t.nct_id=h.nct_id) ORDER BY 1,2) TO 'data/review/02d_who_inn_missing_detail.csv' WITH (FORMAT csv, HEADER true)
