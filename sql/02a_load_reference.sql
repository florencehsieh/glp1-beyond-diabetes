-- sql/02a_load_reference.sql
-- Loads the reference CSVs into their own schema (glp1), separate from AACT's ctgov.
-- Run once per database, in psql from the repo root:  psql -d aact -f sql/02a_load_reference.sql
-- \copy is a psql command, so this file does not run in DataGrip.
-- To reload after editing a CSV: TRUNCATE the table, then rerun its \copy line.

CREATE SCHEMA IF NOT EXISTS glp1;

-- One row per lowercase intervention name: the Phase 1 decisions (01b v7)
CREATE TABLE IF NOT EXISTS glp1.name_map (
    drug_name      text PRIMARY KEY,
    decision       text NOT NULL,
    canonical_drug text,
    reason         text
);
\copy glp1.name_map FROM 'data/glp1_name_map.csv' WITH (FORMAT csv, HEADER true)

-- One row per trial rescued by hand (Review 1, 7 Nov)
CREATE TABLE IF NOT EXISTS glp1.trial_overrides (
    nct_id         text PRIMARY KEY,
    decision       text NOT NULL,
    canonical_drug text,
    reason         text
);
\copy glp1.trial_overrides FROM 'data/reference/glp1_trial_overrides.csv' WITH (FORMAT csv, HEADER true)

-- Checks: 938 names (722 keep, 216 exclude); 7 overrides
SELECT decision, COUNT(*) FROM glp1.name_map GROUP BY decision;
SELECT COUNT(*) AS n_overrides FROM glp1.trial_overrides;
