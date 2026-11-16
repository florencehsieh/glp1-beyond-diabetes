import csv,collections,sys
rows=list(csv.DictReader(open(sys.argv[1])))
notglp={'teduglutide','elsiglutide','dasiglucagon','glepaglutide','apraglutide','avexitide','sonefpeglutide','imapextide','macupatide'}
by=collections.defaultdict(dict)
for r in rows:
    if r['inn'] in notglp: continue
    t=by[r['inn']].setdefault(r['nct_id'],dict(r,names=set(),keep=False,exp=False,anyarm=False))
    t['names'].add(r['lname'][:60])
    if r['name_decision']=='keep':
        t['keep']=True; t['exp']|=r['in_exp_arm']=='t'; t['anyarm']|=r['in_any_arm']=='t'
for inn,ts in by.items():
    c=collections.Counter()
    for n,t in ts.items():
        if t['study_type']!='INTERVENTIONAL': k='not interventional'
        elif t['overall_status']=='WITHDRAWN': k='WITHDRAWN'
        elif not t['keep']: k='NAME NOT KEPT'
        elif not t['anyarm']: k='kept name not linked to any arm'
        elif t['trial_has_exp']=='t' and not t['exp']: k='comparator-only'
        else: k='??'
        c[k]+=1; t['k']=k
    print(inn, len(ts), dict(c))
    for n,t in ts.items():
        if t['k'] not in ('not interventional','WITHDRAWN'): print('    ',n,t['k'],t['overall_status'],sorted(t['names']),'|',t['title'][:60])
