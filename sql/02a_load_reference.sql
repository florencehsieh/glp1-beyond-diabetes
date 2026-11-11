-- sql/02a_load_reference.sql
-- Loads the reference CSVs into their own schema (glp1), separate from AACT's ctgov.
-- Run in psql from the repo root:  psql -d aact -f sql/02a_load_reference.sql
-- \copy is a psql command, so this file does not run in DataGrip.
-- Safe to rerun: each table is dropped and rebuilt, so edits to a CSV are picked up.

CREATE SCHEMA IF NOT EXISTS glp1;

-- One row per lowercase intervention name, from two files:
--   data/glp1_name_map.csv              the Phase 1 decisions (01b v7), 938 names
--   data/reference/glp1_name_additions.csv  names the Phase 1 search couldn't see
--                                       (codes, typos), decided in the 02b review (10 Nov)
-- The primary key stops a name being decided twice.
DROP TABLE IF EXISTS glp1.name_map;
CREATE TABLE glp1.name_map (
    drug_name      text PRIMARY KEY,
    decision       text NOT NULL,
    canonical_drug text,
    reason         text
);
\copy glp1.name_map FROM 'data/glp1_name_map.csv' WITH (FORMAT csv, HEADER true)
\copy glp1.name_map FROM 'data/reference/glp1_name_additions.csv' WITH (FORMAT csv, HEADER true)

-- One row per trial x intervention rescued by hand: the trial's GLP-1 sits under a
-- name that can't go in the name map (a generic or vague label that means other
-- things in other trials). drug_name = the lowercase intervention name that holds it.
DROP TABLE IF EXISTS glp1.trial_overrides;
CREATE TABLE glp1.trial_overrides (
    nct_id         text NOT NULL,
    drug_name      text NOT NULL,
    decision       text NOT NULL,
    canonical_drug text,
    reason         text,
    PRIMARY KEY (nct_id, drug_name)
);
\copy glp1.trial_overrides FROM 'data/reference/glp1_trial_overrides.csv' WITH (FORMAT csv, HEADER true)

-- Checks: 979 names (938 + 41 additions; 763 keep, 216 exclude); 16 overrides, 14 trials
SELECT decision, COUNT(*) FROM glp1.name_map GROUP BY decision;
SELECT COUNT(*) AS n_overrides, COUNT(DISTINCT nct_id) AS n_trials FROM glp1.trial_overrides;
-- Every override must match exactly one intervention row in its trial (0 rows = a typo)
SELECT t.nct_id, t.drug_name, COUNT(i.id) AS n_matches
FROM glp1.trial_overrides t
LEFT JOIN ctgov.interventions i ON i.nct_id = t.nct_id AND LOWER(i.name) = t.drug_name
GROUP BY 1, 2
HAVING COUNT(i.id) <> 1;

-- Phase 3 (11 Nov): one row per MeSH term tagged in Review 6 (data/review/README.md).
-- tag = home / real / broad / measure / error; indication filled for real terms only.
-- Only the stable columns are kept: the trial counts in the CSV change with each
-- snapshot, the same rule as the name map. Untagged terms (fewer than 5 trials) aren't here.
CREATE TEMP TABLE mesh_tags_raw (
    downcase_mesh_term text, n_trials int, n_industry int, n_academic int,
    n_unclassified int, pct_industry numeric, tag text, indication text, note text
);
\copy mesh_tags_raw FROM 'data/reference/03_mesh_terms_tagged.csv' WITH (FORMAT csv, HEADER true)
DROP TABLE IF EXISTS glp1.mesh_tags;
CREATE TABLE glp1.mesh_tags (
    downcase_mesh_term text PRIMARY KEY,
    tag                text,
    indication         text,
    note               text
);
INSERT INTO glp1.mesh_tags
SELECT downcase_mesh_term, NULLIF(tag, ''), NULLIF(indication, ''), NULLIF(note, '')
FROM mesh_tags_raw;

-- One row per trial x indication added by hand: title keyword hits and single-trial
-- fixes that MeSH tags miss. Adds only; never removes a tag (Decided, 11 Nov).
DROP TABLE IF EXISTS glp1.indication_additions;
CREATE TABLE glp1.indication_additions (
    nct_id     text NOT NULL,
    indication text NOT NULL,
    reason     text,
    PRIMARY KEY (nct_id, indication)
);
\copy glp1.indication_additions FROM 'data/reference/indication_additions.csv' WITH (FORMAT csv, HEADER true)

-- Checks: tag counts (62 terms, 1 untagged: renal insufficiency); every real term has an
-- indication (0 rows); every addition is a trial in glp1.trials (0 rows; run after 02)
SELECT COALESCE(tag, '(untagged)') AS tag, COUNT(*) FROM glp1.mesh_tags GROUP BY 1 ORDER BY 2 DESC;
SELECT downcase_mesh_term FROM glp1.mesh_tags WHERE tag = 'real' AND indication IS NULL;
SELECT a.nct_id FROM glp1.indication_additions a
WHERE to_regclass('glp1.trials') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM glp1.trials t WHERE t.nct_id = a.nct_id);
