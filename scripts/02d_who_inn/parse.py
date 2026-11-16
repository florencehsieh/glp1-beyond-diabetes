import re, sys, json, pathlib
txtdir = pathlib.Path(sys.argv[1])
LAT = re.compile(r'^\s{0,3}([a-z][a-z0-9\-]*(?:um|i))(?: [a-z]+)?\s*[#*]?\s*(?:\s{3,}.*)?$')
NAME = re.compile(r'^\s{0,3}([a-zA-Zéèáíóú][\w\-éèáíóúñ]*(?: (?:alfa|beta|gamma|delta|pegol|zeta))?)\b')
KW = re.compile(r'GLP-?1|GLP-?\s?1|glucagon[- ]like|gastric inhibitory|glucose[- ]dependent insulinotropic|\bGIP\b|incretin|exendin', re.I)
END = re.compile(r'(glutide|enatide|dutide|patide|trutide|glipron)$')
SEQ = [re.compile(p) for p in [r'G.?T.?F.?[TIS].?S.?D', r'glycyl-?L-threonyl-?L-phenylalanyl-?L-(threonyl|isoleucyl|seryl)-?L-seryl', r'Gly-Thr-Phe-(Thr|Ile|Ser)-Ser-Asp', r'threonyl-L-phenylalanyl-L-threonyl-L-seryl-L-(α-)?aspartyl']]
out=[]; allr=[]
for f in sorted(txtdir.glob('pl*.txt'), key=lambda p:int(p.stem[2:])):
    pl=int(f.stem[2:]); lines=f.read_text(errors='ignore').replace('\f','').split('\n')
    starts=[]
    for i,l in enumerate(lines):
        m=LAT.match(l)
        dup = (i+1<len(lines) and re.match(r'^\s{0,3}([a-z][\w\-]+(?: [a-z]+)?)\s*[#*]?\s*$',l)
               and lines[i+1].strip().startswith(l.strip().rstrip('#* ').strip()))
        if (m and m.group(1).endswith('um')) or dup:
            # next nonblank line should be at low indent with a name
            j=i+1
            while j<len(lines) and (not lines[j].strip() or re.fullmatch(r"[\s\d,.]+",lines[j])): j+=1
            if j<len(lines):
                n=NAME.match(lines[j])
                if n and not lines[j].startswith('WHO'): starts.append((i,j,n.group(1)))
    for k,(i,j,eng) in enumerate(starts):
        stop=starts[k+1][0] if k+1<len(starts) else len(lines)
        block=lines[j:stop]
        # English part: until next line with a name at low indent (French)
        eng_lines=[block[0]]
        for l in block[1:]:
            if NAME.match(l) and not re.match(r'^\s*(WHO|Proposed|\d)',l): break
            eng_lines.append(l)
        def join(ls): 
            t=' '.join(x.strip() for x in ls if x.strip() and not re.match(r'^\s*(WHO Drug Information|Proposed INN|\d+\s*$)',x.strip()))
            return re.sub(r'-\s+','-',t)
        etxt=join(eng_lines); full=join(block)
        nospace=re.sub(r'\s','',full)
        why=[]
        if KW.search(etxt): why.append('a:kw-en')
        elif KW.search(full): why.append('a:kw-other')
        if END.search(eng.lower()): why.append('b:ending')
        if any(p.search(full) or p.search(nospace) for p in SEQ): why.append('c:seq')
        if why: out.append(dict(pl=pl,inn=eng,latin=lines[i].split()[0],why=why,en=etxt[:1500],line=j+1,end=stop))
        allr.append((pl,j,stop,eng))
json.dump(allr,open(sys.argv[2]+'.ranges','w'))
json.dump(out,open(sys.argv[2],'w'),ensure_ascii=False,indent=1)
print(len(out))
