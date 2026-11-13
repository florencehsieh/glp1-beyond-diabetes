-- sql/review/03c_keyword_pass.sql  (Phase 3: title keyword pass, option B of 11 Nov)
-- Needs glp1.trials (sql/pipeline/02) and glp1.trial_indications (sql/pipeline/03).
-- Finds trials whose title names an indication they aren't labelled with yet,
-- because sponsors often tag only the population (SELECT, FLOW, STEP-HFpEF).
-- Every hit is reviewed by hand; yes decisions go in data/reference/indication_additions.csv,
-- then rerun pipeline/01 and pipeline/03.
--
-- Pass 1 (11 Nov, Review 7): Heart failure, MASLD, CKD, ASCVD. Keywords written BEFORE
--   looking at hits (11 Nov walk), except 'cardiovascular outcomes', added after SELECT missed
--   the known-trials check. Searched official_title only.
-- Pass 2 (11 Nov, Review 9): the 19 other indications with 5+ trials. Keywords written and
--   expanded on 11 Nov; every term was fixed BEFORE looking at any hits.
--   From pass 2 on, BOTH titles are searched (official and brief: sponsors word them differently).
--
-- How a row works:
--   kind    match = a hit is pre-sorted likely yes; look = always hand review, never auto-yes
--   pattern case-insensitive regex (~*); \m \M = word start / end
--   abbr    case-SENSITIVE regex (~) for short abbreviations, so AD doesn't match "ad libitum"
--   block   removed from the title before matching, so "non-smoking" can't hit Smoking but a
--           title with both "non-smoking" and "smoking cessation" still does
-- A look row is dropped when a match row of the same indication hits the same trial.
-- A trial already labelled with the indication is dropped.
--
-- Export (from the repo root):
--   psql -d aact --csv -f sql/review/03c_keyword_pass.sql -o data/review/03c_keyword_hits_v2.csv
-- WARNING: a rerun lists only hits that are STILL unlabelled, so once the yes decisions are
-- in indication_additions.csv it returns fewer rows. Don't overwrite an earlier export:
-- export a new pass to a new file (e.g. 03c_keyword_hits_v3.csv).

WITH kw (indication, kind, pattern, abbr, block) AS (
    VALUES
    -- ---------- Pass 1 (11 Nov), unchanged ----------
    -- Not ischaemia: that belongs to ASCVD
    ('Heart failure', 'match', 'heart failure|cardiac failure|hfpef|preserved ejection fraction|hfref|reduced ejection fraction', NULL, NULL),
    -- Not fibrosis or cirrhosis: those also come from alcohol or hepatitis
    ('MASLD', 'match', '\m(mash|masld|nash|nafld)\M|steatohepatitis|fatty liver|hepatic steatosis', NULL, NULL),
    -- Not renal impairment (usually a PK study) or acute kidney injury
    ('CKD', 'match', 'chronic kidney disease|\mckd\M|kidney disease|diabetic kidney disease|diabetic nephropathy|albuminuria', NULL, NULL),
    -- Stroke: prevention -> ASCVD, acute treatment -> Stroke (decided by hand)
    ('ASCVD', 'match', 'cardiovascular events|cardiovascular outcomes|\mmace\M|atherosclerotic|\mascvd\M|coronary artery disease|myocardial infarction|heart attack|\mstroke\M|peripheral arter(y|ial) disease', NULL, NULL),
    -- Plain "cardiovascular" is too broad: hand review (dropped below if labelled Heart failure)
    ('ASCVD', 'look', 'cardiovascular', NULL, NULL),

    -- ---------- Pass 2 (11 Nov) ----------
    -- 1 Type 1. Block the old type 2 names; LADA is look only
    ('Type 1 diabetes', 'match',
     '\mtype (1|i|one) diabet|\mtype (1|i) (and|or|&|/) (type )?(2|ii) diabet|diabetes( mellitus)?,? type (1|i)\M|insulin[- ]dependent diabet|juvenile([- ]onset)? diabet|autoimmune diabet|brittle diabet',
     '\m(T1DM?|IDDM)\M',
     'non[- ]?insulin[- ]dependent|latent autoimmune diabet\w*'),
    ('Type 1 diabetes', 'look',
     'latent autoimmune diabet|islet (cell )?transplant|beta[- ]cell (function )?preservation|new[- ]onset diabet',
     '\mLADA\M', NULL),

    -- 2 PCOS
    ('PCOS', 'match', 'polycystic ovar|stein[- ]leventhal', '\mPCOS\M', NULL),
    ('PCOS', 'look', 'hyperandrogen|hirsutism|anovulat|oligo-?amenorrh|oligomenorrh', NULL, NULL),

    -- 3 AUD. Never plain "alcohol": non-alcoholic fatty liver is MASLD
    ('Alcohol use disorder', 'match',
     'alcoholism|alcohol (use|dependen|abuse|addict|consumption|intake|drinking|craving|self-administration)|(heavy|binge|hazardous|harmful|problem|excessive) drinking',
     '\mAUD\M',
     'non-?alcoholic|alcohol withdrawal'),
    ('Alcohol-related liver disease', 'look',
     'alcohol(ic|-related|-associated)? (liver|hepatitis|steatohepatitis|cirrhosis)',
     NULL, 'non-?alcoholic'),
    ('Alcohol use disorder', 'look', '\methanol\M', NULL, NULL),   -- often a drug-interaction study

    -- 4 Stroke. Overlaps ASCVD: every hit gets the prevention-vs-treatment hand review (11 Nov split)
    ('Stroke', 'match',
     '\mstrokes?\M|cerebrovascular (accident|event|disease)|(cerebral|brain) (infarct|isch(a)?emi)|intracerebral ha?emorrhage|subarachnoid ha?emorrhage|thrombectomy|thrombolysis',
     '\m(CVA|SAH)\M',
     'stroke volume|heat ?stroke|sunstroke'),
    ('Stroke', 'look', 'transient isch(a)?emic attack|hemipar|hemipleg|aneurysm', '\mTIA\M', NULL),

    -- 5 Sleep apnoea
    ('Obstructive sleep apnoea', 'match',
     'sleep[- ]apn(o)?ea|sleep[- ]disordered breathing|apn(o)?ea[- ]hypopn(o)?ea',
     '\m(OSA|OSAS|OSAHS|AHI)\M', NULL),
    ('Obstructive sleep apnoea', 'look', 'hypoventilation|snoring|\mcpap\M', NULL, NULL),

    -- 6 Antipsychotic weight gain. Schizophrenia -> AIWG (tag by target, 11 Nov)
    ('Antipsychotic-induced weight gain', 'match',
     'anti-?psychotic|neuroleptic|clozapine|olanzapine|quetiapine|risperidone|paliperidone|aripiprazole|schizophren|schizoaffective|first[- ]episode psychosis',
     '\mAIWG\M', NULL),
    ('Antipsychotic-induced weight gain', 'look',
     '\mpsychos[ie]s\M|\mpsychotic\M|severe mental illness|bipolar|psychotropic|(medication|drug)[- ]induced weight',
     '\mSMI\M', NULL),
    ('Major depressive disorder', 'look', 'depressi(on|ve)', NULL, NULL),

    -- 7 AF
    ('Atrial fibrillation', 'match', 'atrial fib|\mafib\M|\ma-fib\M', '\mAF\M', NULL),
    ('Atrial fibrillation', 'look', 'atrial flutter|atrial arrhythmi|catheter ablation|pulmonary vein isolation', NULL, NULL),

    -- 8 OA
    ('Osteoarthritis', 'match', 'osteoarthr|degenerative joint disease|gonarthrosis|coxarthrosis', '\mOA\M', NULL),
    ('Osteoarthritis', 'look', 'knee pain|joint pain|arthroplasty|(joint|knee|hip) replacement', NULL, NULL),

    -- 9 Endometrial (cancer AND atypical hyperplasia). Not endometriosis
    ('Endometrial cancer and atypical hyperplasia', 'match',
     'endometrial (cancer|carcinoma|adenocarcinoma)|uter(ine|us) (corpus )?(cancer|carcinoma)|corpus uteri|endometrial hyperplasia|atypical (endometrial )?hyperplasia|endometrial intraepithelial neoplasia',
     '\mEIN\M', NULL),
    ('Endometrial cancer and atypical hyperplasia', 'look', 'fertility[- ]sparing|levonorgestrel|lng-ius|progest', NULL, NULL),

    -- 10 Smoking. Block "healthy non-smoking subjects" (phase 1 titles)
    ('Smoking cessation', 'match', '\msmok(ing|ers?)\M|tobacco|nicotine|cigarette|vaping', NULL, 'non-?smok\w*'),

    -- 11 Alzheimer's
    ('Alzheimer''s', 'match', 'alzheimer', '\mAD\M', NULL),
    ('Alzheimer''s', 'look',
     'dementia|mild cognitive impairment|cognitive (decline|impairment|dysfunction)|amyloid|\mtau\M|neurodegenerat|lewy',
     '\mMCI\M', NULL),

    -- 12 Hypertension. Other hypertensions are blocked here, then looked for as their own indications
    ('Hypertension', 'match',
     '\mhypertensi(on|ve)\M|high blood pressure|elevated blood pressure', '\mHTN\M',
     '(pulmonary|portal|intracranial|ocular|intra-?abdominal|gestational|pregnancy[- ]induced)( arterial)? hypertensi\w*|pre-?eclampsi\w*|hypertensive disorders? of pregnancy|\mpah\M'),
    ('Hypertension', 'look', 'blood pressure', NULL, NULL),          -- usually a measure
    ('Idiopathic intracranial hypertension', 'look', 'intracranial hypertension|pseudotumou?r cerebri', '\mIIH\M', NULL),
    ('Pulmonary arterial hypertension', 'look', 'pulmonary (arterial )?hypertension', '\mPAH\M', NULL),

    -- 13 Parkinson's. \mparkinsons?\M can't match "parkinsonism"; PD dropped (= pharmacodynamics)
    ('Parkinson''s', 'match', '\mparkinsons?\M|paralysis agitans', NULL, NULL),
    ('Multiple system atrophy', 'look', 'multiple system atrophy|progressive supranuclear|parkinsonism', '\m(MSA|PSP)\M', NULL),

    -- 14 Hypothalamic obesity. Genetic obesity: home base or new, decided later
    ('Hypothalamic obesity', 'match', 'hypothalamic (obesity|injury|damage|dysfunction|lesion)|acquired hypothalamic|craniopharyngioma', NULL, NULL),
    ('Hypothalamic obesity', 'look', 'suprasellar|pituitary (tumou?r|adenoma)', NULL, NULL),
    ('Genetic obesity (decide later)', 'look',
     'prader[- ]willi|bardet[- ]biedl|\mmc4r\M|\mpomc\M|\mlepr\M|monogenic obesity|syndromic obesity|genetic obesity',
     '\mPWS\M', NULL),

    -- 15 Psoriasis. Psoriatic arthritis is its own indication
    ('Psoriasis', 'match', 'psoria', NULL, 'psoriatic arthritis'),
    ('Psoriatic arthritis', 'look', 'psoriatic arthritis', NULL, NULL),
    ('Other skin (new?)', 'look', 'hidradenitis|atopic dermatitis|eczema', NULL, NULL),

    -- 16 IBD. Not IBS; short bowel is GLP-2 territory
    ('Inflammatory bowel disease', 'match', 'inflammatory bowel|crohn|ulcerative colitis|pouchitis', '\mIBD\M', NULL),
    ('Inflammatory bowel disease', 'look', '\mcolitis\M', '\mUC\M', NULL),

    -- 17 Infertility
    ('Infertility', 'match',
     'infertil|subfertil|in vitro fertili[sz]ation|embryo transfer|assisted reproduct|ovulation induction',
     '\m(IVF|ICSI)\M', NULL),
    ('Infertility', 'look', 'conception|live birth|pregnancy rate|sperm|semen|hypogonadism|erectile', NULL, NULL),

    -- 18 Breast cancer. Never the stem "breast": breast milk / breastfeeding (lactation drug studies)
    ('Breast cancer', 'match',
     'breast (cancer|carcinoma|neoplasm|tumou?r|malignan)|mammary carcinoma|ductal carcinoma in situ',
     '\mDCIS\M', NULL),
    ('Breast cancer', 'look', 'aromatase inhibitor|\mher2\M|hormone[- ]receptor[- ]positive', NULL, NULL),

    -- 19 Cannabis
    ('Cannabis use disorder', 'match', 'cannabis|marijuana|marihuana|cannabinoid use', '\mCUD\M', NULL),
    ('Cannabis use disorder', 'look', '\mthc\M', NULL, NULL),

    -- + Other addictions (several already exist as labels; the review assigns the exact one)
    ('Other addiction (new?)', 'look',
     'opioid (use|dependen|addict)|cocaine|methamphetamine|stimulant use|substance use|addiction',
     '\m(OUD|SUD)\M', 'alcohol addiction|nicotine addiction|smoking addiction')
),
docs AS (                                     -- both titles, the brief one only if it differs
    SELECT t.nct_id,
           CONCAT_WS(' || ', s.official_title, NULLIF(s.brief_title, s.official_title)) AS title
    FROM glp1.trials t
    JOIN ctgov.studies s ON s.nct_id = t.nct_id
),
hits AS (
    SELECT k.indication, k.kind, d.nct_id,
           COALESCE((REGEXP_MATCH(c.clean, '(' || k.pattern || ')', 'i'))[1],
                    (REGEXP_MATCH(c.clean, '(' || k.abbr || ')'))[1])           AS matched
    FROM kw k
    CROSS JOIN docs d
    CROSS JOIN LATERAL (SELECT CASE WHEN k.block IS NULL THEN d.title
                                    ELSE REGEXP_REPLACE(d.title, k.block, '', 'gi') END AS clean) c
    WHERE (k.pattern IS NOT NULL AND c.clean ~* k.pattern)
       OR (k.abbr    IS NOT NULL AND c.clean ~  k.abbr)
),
hits1 AS (                                    -- one row per indication x kind x trial
    SELECT indication, kind, nct_id, STRING_AGG(DISTINCT matched, '; ') AS matched
    FROM hits GROUP BY 1, 2, 3
)
SELECT h.indication AS keyword_indication,
       h.kind,
       h.matched,
       h.nct_id,
       CASE WHEN sp.agency_class = 'INDUSTRY' THEN 'industry' ELSE 'academic' END AS lead,
       s.phase,
       (SELECT STRING_AGG(i.indication, '; ' ORDER BY i.indication)
          FROM glp1.trial_indications i WHERE i.nct_id = h.nct_id)        AS labelled_now,
       d.title,
       (SELECT STRING_AGG(o.measure, ' || ')
          FROM ctgov.design_outcomes o WHERE o.nct_id = h.nct_id AND o.outcome_type = 'primary') AS primary_outcomes
FROM hits1 h
JOIN docs d          ON d.nct_id = h.nct_id
JOIN ctgov.studies s ON s.nct_id = h.nct_id
LEFT JOIN ctgov.sponsors sp ON sp.nct_id = h.nct_id AND sp.lead_or_collaborator = 'lead'
WHERE NOT EXISTS (SELECT 1 FROM glp1.trial_indications i             -- only trials not yet labelled with it
                  WHERE i.nct_id = h.nct_id AND i.indication = h.indication)
  AND NOT (h.kind = 'look' AND EXISTS (SELECT 1 FROM hits1 m         -- a match already covers it
                  WHERE m.nct_id = h.nct_id AND m.indication = h.indication AND m.kind = 'match'))
  AND NOT (h.indication = 'ASCVD' AND h.kind = 'look' AND EXISTS (SELECT 1 FROM glp1.trial_indications i
                  WHERE i.nct_id = h.nct_id AND i.indication = 'Heart failure'))
ORDER BY h.kind, h.indication,
         (sp.agency_class = 'INDUSTRY' AND s.phase = 'PHASE3') DESC, h.nct_id;
