-- sql/01b_name_review.sql  (v6, 8 Nov 2026)
-- Purpose: give every GLP-1-looking drug name a first-pass label
--          (keep / exclude / review) and a canonical_drug, so only
--          the "review" rows need a human decision.
-- Rules are checked top to bottom: the FIRST rule that matches wins.
-- v2 (6 Nov): fixed v1 mislabels and split "review" into 4 types (unclear names, unfamiliar drugs, background use, placebo + active)
-- v3: rule 0 for Review 1 (unclear names)
-- v4: rule 0b for Review 2 (unfamiliar drugs)
-- v5: rule 0c for Review 3 (placebo + active)
-- v6: rule 0d for Review 4 (background use)
WITH names AS (
    SELECT nct_id, LOWER(name) AS drug_name FROM interventions
    UNION ALL
    SELECT nct_id, LOWER(name) FROM intervention_other_names
),
counted AS (
    SELECT drug_name, COUNT(DISTINCT nct_id) AS n_trials
    FROM names
    WHERE drug_name ~* '(glutide|enatide|dutide|tirzepatide|retatrutide|orforglipron|danuglipron|glp[- ]?1|glucagon[- ]like peptide|ozempic|wegovy|rybelsus|mounjaro|zepbound|victoza|saxenda|trulicity|byetta|bydureon|lyxumia|adlyxin|tanzeum|soliqua|xultophy|cagrisema|iglarlixi|ideglira)'
    GROUP BY drug_name
),
labelled AS (
    SELECT
        drug_name,
        n_trials,
        CASE
            -- 0. hand-decided names from Review 1 (unclear names, 7 Nov 2026)
            --    exact match only; real-drug trials behind generic names are
            --    rescued in data/reference/glp1_trial_overrides.csv
            WHEN drug_name IN ('glp 1', 'glp-1',
                               'glucagon like peptide -1', 'glucagon like peptide-1',
                               'glucagon-like peptide 1', 'glucagon-like peptide-1',
                               'glucagon-like peptide-1 (glp-1)')
                THEN 'exclude: generic name'
            WHEN drug_name IN ('glucagon-like peptide-1,',
                               'glucose-insulinotropic peptide, glucagon-like peptide-1')
                THEN 'exclude: native GLP-1'
            WHEN drug_name = 'glp-1 control'
                THEN 'exclude: GLP-1 blocker'
            WHEN drug_name = 'glp-1 plus basal insulin'
                THEN 'keep'
            WHEN drug_name = 'incretin-based therapies (glp-1 and glp-1/gip)'
                THEN 'keep: class wording'
            -- 0b. hand-decided names from Review 2 (unfamiliar drugs, 8 Nov 2026)
            --     evidence: AACT intervention descriptions first, web only if silent
            WHEN drug_name = 'sonefpeglutide'
                THEN 'exclude: GLP-2 drug'
            WHEN drug_name IN ('berobenatide', 'bofanglutide', 'efsubaglutide alfa', 
                               'efsubaglutide alfa 10 mg qw', 'efsubaglutide alfa 1mg qw and 3mg q2w', 
                               'efsubaglutide alfa 20 mg qw', 'efsubaglutide alfa 3mg q2w and 1mg qw', 
                               'efsubaglutide alfa 40 mg q2w', 'efsubaglutide alfa 40 mg qw', 
                               'efsubaglutide alfa 5 mg qw', 'efsubaglutide alfa 80 mg q4w', 
                               'efsubaglutide alfa 80 mg qw', 'efsubaglutide alfa injection', 'froniglutide', 
                               'glp-1/fgf21 dual agonist (hec88473)', 'hec88473, placebo, dulaglutide', 
                               'noiiglutide injection', 'phase iib：efsubaglutide alfa 10 mg qw', 
                               'phase iib：efsubaglutide alfa 20 mg q2w', 'phase iib：efsubaglutide alfa 20 mg qw', 
                               'phase iib：efsubaglutide alfa 5 mg qw', 'rexenatide-4', 'rhglp-1(7-36)', 
                               'supaglutide', 'supaglutide injection', 'supaglutide injection+metformin', 
                               'vurolenatide 100mg/pbo', 'vurolenatide 50/50 mg', 'vurolenatide 50mg/pbo', 
                               'zovaglutide', 'zovaglutide arm 1', 'zovaglutide arm 2', 'zovaglutide dose 1', 
                               'zovaglutide dose 2')
                THEN 'keep'
            -- 0c. hand-decided names from Review 3 (placebo + active, 8 Nov 2026)
            --     pattern B: the GLP-1 itself is the placebo -> exclude
            --     patterns A and C: a real GLP-1 is given -> keep
            --     evidence: data/review/01c_placebo_active_decided.csv
            WHEN drug_name IN ('cagrilintide b and placebo semaglutide i',
                               'empagliflozin 10mg oral tablet and placebo pen injector matching semaglutide',
                               'intervention period 3: semaglutide placebo + empagliflozin',
                               'intervention period 4: semaglutide placebo + empagliflozin placebo',
                               'placebo matching empagliflozin and placebo pen injector matching semaglutide')
                THEN 'exclude: placebo'
            WHEN drug_name IN ('exenatide and placebo',
                               'exenatide - exenatide - placebo',
                               'exenatide - placebo - exenatide',
                               'exenatide-lar plus dapagliflozin placebo',
                               'intervention period 2: semaglutide + empagliflozin placebo',
                               'lae102 placebo,+tirzepatide',
                               'liraglutide (saxenda) 6mg/ml inj pen 3ml or placebo',
                               'liraglutide or placebo',
                               'placebo in combination with semaglutide',
                               'placebo+semaglutide',
                               'polyethylene glycol loxenatide or placebo',
                               'semaglutide 2.4 mg and placebo 1.0 mg',
                               'semaglutide 2.4 mg and placebo 2.0 mg')
                THEN 'keep'
            -- 0d. hand-decided names from Review 4 (background use, 8 Nov 2026)
            --     keep: the protocol assigns or sets the GLP-1 dose (A, taper D)
            --     exclude: own GLP-1 only, observational, stop arm, or pre-procedure stop (B, D)
            --     evidence: data/review/01d_background_use_decided.csv
            WHEN drug_name IN ('add glp-1 receptor agonist',
                               'application of glp-1ras drugs',
                               'comparator: exenatide',
                               'discontinuation and reinitiation of tirzepatide',
                               'glp-1 dose reduction',
                               'gradual dose reduction of semaglutide',
                               'maintenance of glp-1 dose',
                               'semaglutide dose-tapering regimen',
                               'sleeve gastrectomy plus early mazdutide initiation')
                THEN 'keep'
            WHEN drug_name IN ('2 ogtts with and without glp-1 analogue',
                               'abrupt cessation of semaglutide',
                               'angiotensin converting enzyme inhibitors, angiotensin ii receptor blockers, dpp-4 inhibitors, glp-1 receptor agonists, sglt2 inhibitors, calcium channel blockers, β receptor blocker',
                               'glp-1 medication initiation',
                               'glp-1 non stop',
                               'glp-1 not stop for 1 week',
                               'glp-1 ra cessation interval',
                               'glp-1 ra discontinuation interval',
                               'glp-1 ra users with prolonged fasting instructions',
                               'glp-1 ra users with standard npo instructions',
                               'glp-1 receptor agonist (e.g., semaglutide, tirzepatide) - prescribed by the treating physician as standard care; the study does not assign or alter treatment.',
                               'glp-1 stop for 1 week',
                               'gut motility quantification using a capsule after initiating glp-1ra therapy',
                               'initiation of tirzepatide',
                               'maintain dual therapy (sulf/pio) as comparator to liraglutide',
                               'new use of oral semaglutide',
                               'new use of semaglutide injection',
                               'on glp1 only',
                               'on glp1 plus hrt',
                               'semaglutide injectable product (not provided by the study)',
                               'structured weight loss program including behavioral support and optional meal re-placement or pharmacotherapy with glucagon-like peptide-1 receptor agonists (glp1-ra)',
                               'the glp-1 receptor agonist users',
                               'time since last glp-1 ra dose',
                               'tirzepatide is administered as part of routine clinical care for obesity management, according to standard prescribing practices. dosing and treatment duration are determined by the treating physician',
                               'to utilize the freestyle libre 3 continuous glucose monitoring system (fsl3) to help prolong the length of time people with diabetes maintain adherence to glp-1 and dual gip/glp-1 agonists')
                THEN 'exclude: background use'
            -- 1. text says the GLP-1 is NOT given
            WHEN drug_name ~ '(non-glp|not including|excluding|except for|besides|\+ no )'
                THEN 'exclude: no GLP-1'
            -- 2. drug names to look up by hand
            WHEN drug_name ~ '(rhglp|hec88473|rexenatide|berobenatide|vurolenatide)'
                THEN 'review: unfamiliar drug'
            -- 3. GLP-1/GLP-2 duals ARE GLP-1 drugs (must come before the GLP-2 rule)
            WHEN drug_name ~ '(glp-1/glp-2|glp-1r/glp-2r|dapiglutide)'
                THEN 'keep'
            -- 4. GLP-2 drugs
            WHEN drug_name ~ '(teduglutide|tedguglutide|glepaglutide|apraglutide|elsiglutide|glp-?2|peptide[- ]?2)'
                THEN 'exclude: GLP-2 drug'
            -- 5. receptor blockers
            WHEN drug_name ~ '(antagonis|exendin ?[(\[]?9|exendin-9)'
                THEN 'exclude: GLP-1 blocker'
            -- 6. measurements, imaging, food products
            WHEN drug_name ~ '(plasma|blood|level|expression|\mpet\M|tracer|activating|postbiotic|formula\M|booster|cellbeads|perilla|evolv)'
                THEN 'exclude: not a treatment'
            -- 7. native / synthetic human GLP-1 (physiology studies)
            WHEN drug_name ~ '(7-36|7,36|9-36|9,36|native|human glp|human glucagon|synthetic glp|glp-1 infusion|glp-1 hormone|glp-1 peptide|clamp|iigi|increasing doses|last 5 amino|intradermal|glp-1 (high|low|mid-range) dose|glp-1 \+ |glp-1 and gip\M|glp-1 and glucagon|peptide- 1 \(glp-1\) infusion|nmol/kg)'
                THEN 'exclude: native GLP-1'
            -- 8. placebo AND a real drug in the same name
            WHEN drug_name ~ '(placebo|vehicle|pbo)'
             AND drug_name ~ '( or placebo|and placebo|placebo ?\+|placebo,\+|placebo in combination|/pbo|- placebo -|- exenatide - placebo|dapagliflozin placebo|empagliflozin placebo$)'
                THEN 'review: placebo + active'
            -- 9. placebo only
            WHEN drug_name ~ '(placebo|vehicle)'
                THEN 'exclude: placebo'
            -- 10. GLP-1 is background, not the tested treatment
            WHEN drug_name ~ '(users|cessation|discontinu|stop|time since|dose reduction|maintenance of|prescribed by|routine clinical care|not provided by|standard of care|initiation|new use|on glp1|tapering|freestyle|motility|ogtt|npo|fasting|comparator|application of|add glp|optional|angiotensin)'
                THEN 'review: background use'
            -- 11. known GLP-1 drugs and brands
            WHEN drug_name ~ '(semaglutide|tirzepatide|liraglutide|liroglutide|lirglutide|\mexenatide|dulaglutide|lixisenatide|albiglutide|taspoglutide|efpeglenatide|retatrutide|survodutide|mazdutide|cotadutide|pemvidutide|efinopegdutide|orforglipron|danuglipron|maridebart|ecnoglutide|loxenatide|losenatide|beinaglutide|benaglutide|ozempic|wegovy|rybelsus|mounjaro|monjouro|zepbound|victoza|vicotza|saxenda|trulicity|byetta|bayetta|byeta|bydureon|lyxumia|tanzeum|soliqua|xultophy|ideglira|iglarlixi|cagrisema)'
                THEN 'keep'
            -- 12. other -glutide / -enatide / -dutide names
            WHEN drug_name ~ '(glutide|enatide|dutide)'
                THEN 'review: unfamiliar drug'
            -- 13. class wording, no drug named
            WHEN drug_name ~ '(agonist|analog|glp-?1 ?-?ras?\M|glp1-?ra|glp 1 ra|glp-1a\M|glp-1 medication|glp-1 therapy|oral glp-1)'
                THEN 'keep: class wording'
            ELSE 'review: unclear'
        END AS first_pass,
        CASE
            WHEN drug_name ~ 'hec88473'                    THEN 'hec88473'
            WHEN drug_name ~ '(efsubaglutide|supaglutide)' THEN 'efsubaglutide alfa'
            WHEN drug_name ~ 'rexenatide'                  THEN 'exenatide'
            WHEN drug_name ~ 'rhglp'                       THEN 'beinaglutide'
            WHEN drug_name ~ 'berobenatide'  THEN 'berobenatide'
            WHEN drug_name ~ 'zovaglutide'   THEN 'zovaglutide'
            WHEN drug_name ~ 'noiiglutide'   THEN 'noiiglutide'
            WHEN drug_name ~ 'bofanglutide'  THEN 'bofanglutide'
            WHEN drug_name ~ 'froniglutide'  THEN 'froniglutide'
            WHEN drug_name ~ 'vurolenatide'  THEN 'vurolenatide'
            WHEN drug_name = 'glp-1 plus basal insulin'                                   THEN 'lixisenatide'
            WHEN drug_name ~ '(semaglutide|ozempic|wegovy|rybelsus|cagrisema)'            THEN 'semaglutide'
            WHEN drug_name ~ '(tirzepatide|mounjaro|monjouro|zepbound)'                   THEN 'tirzepatide'
            WHEN drug_name ~ '(liraglutide|liroglutide|lirglutide|victoza|vicotza|saxenda|xultophy|ideglira)' THEN 'liraglutide'
            WHEN drug_name ~ '(\mexenatide|byetta|bayetta|byeta|bydureon|itca 650)'       THEN 'exenatide'
            WHEN drug_name ~ '(dulaglutide|trulicity)'                                    THEN 'dulaglutide'
            WHEN drug_name ~ '(lixisenatide|lyxumia|soliqua|iglarlixi)'                   THEN 'lixisenatide'
            WHEN drug_name ~ '(albiglutide|tanzeum)'                                      THEN 'albiglutide'
            WHEN drug_name ~ 'taspoglutide'    THEN 'taspoglutide'
            WHEN drug_name ~ 'efpeglenatide'   THEN 'efpeglenatide'
            WHEN drug_name ~ 'retatrutide'     THEN 'retatrutide'
            WHEN drug_name ~ 'survodutide'     THEN 'survodutide'
            WHEN drug_name ~ 'mazdutide'       THEN 'mazdutide'
            WHEN drug_name ~ 'cotadutide'      THEN 'cotadutide'
            WHEN drug_name ~ 'pemvidutide'     THEN 'pemvidutide'
            WHEN drug_name ~ 'efinopegdutide'  THEN 'efinopegdutide'
            WHEN drug_name ~ 'orforglipron'    THEN 'orforglipron'
            WHEN drug_name ~ 'danuglipron'     THEN 'danuglipron'
            WHEN drug_name ~ 'maridebart'      THEN 'maridebart cafraglutide'
            WHEN drug_name ~ 'ecnoglutide'     THEN 'ecnoglutide'
            WHEN drug_name ~ '(loxenatide|losenatide)'   THEN 'loxenatide'
            WHEN drug_name ~ '(beinaglutide|benaglutide)' THEN 'beinaglutide'
            WHEN drug_name ~ 'dapiglutide'     THEN 'dapiglutide'
        END AS canonical_drug
    FROM counted
)
SELECT drug_name, n_trials, first_pass, canonical_drug
FROM labelled
ORDER BY first_pass, n_trials DESC;