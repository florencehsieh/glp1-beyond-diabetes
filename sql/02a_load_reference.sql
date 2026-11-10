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
