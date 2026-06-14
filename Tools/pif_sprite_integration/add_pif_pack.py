#!/usr/bin/env python3
"""add_pif_pack.py - ADDITIVELY integrate a PIF pack into ONE fork install.

Adds only sprites the install's AFI set lacks (remapped PIF id not already in the
<head>.pak index or loose indexed/ files). Existing AFI/PIF art is never touched,
so it can't break anything. Deploys missing fusions into CustomBattlers/indexed/
and missing base sprites into BaseSprites/.

Usage: add_pif_pack.py <PIF CustomBattlers dir> <PIF BaseSprites dir|-> <game root> [--dry]
"""
import os,re,struct,sys,shutil
HERE=os.path.dirname(os.path.abspath(__file__))
# load divergent map from the sibling json so this stays in sync
import json
MAP=json.load(open(os.path.join(HERE,'pif_npt_map.json')))
PIF_TO_FORK={int(k):v for k,v in MAP['pif_to_fork'].items() if int(k)!=v}
def p2f(i): return PIF_TO_FORK.get(i,i)
FUSION=re.compile(r'^(\d+)\.(\d+)([a-z]?)\.png$'); BASE=re.compile(r'^(\d+)([a-z]?)\.png$')
def ai(a): return 0 if a=='' else ord(a)-ord('a')+1
PIF_CB,PIF_BS,INSTALL=sys.argv[1],sys.argv[2],sys.argv[3]
dry='--dry' in sys.argv[4:]
PACKED=INSTALL+'/Graphics/CustomBattlers_packed'; INDEXED=INSTALL+'/Graphics/CustomBattlers/indexed'; BASEOUT=INSTALL+'/Graphics/BaseSprites'
have=set()
if os.path.isdir(PACKED):
    for pf in os.listdir(PACKED):
        if not pf.endswith('.pak'): continue
        try: head=int(pf[:-4])
        except: continue
        with open(PACKED+'/'+pf,'rb') as fh:
            if fh.read(4)!=b'SPAK': continue
            n=struct.unpack('<I',fh.read(4))[0]; blob=fh.read(n*16)
        for i in range(n):
            body,alt,o,l=struct.unpack('<IIII',blob[i*16:i*16+16]); have.add((head,body,alt))
if os.path.isdir(INDEXED):
    for head in os.listdir(INDEXED):
        hp=INDEXED+'/'+head
        if not os.path.isdir(hp): continue
        for fn in os.listdir(hp):
            m=FUSION.match(fn)
            if m: have.add((int(m.group(1)),int(m.group(2)),ai(m.group(3))))
fus=0
for fn in os.listdir(PIF_CB):
    m=FUSION.match(fn)
    if not m: continue
    h,b,a=int(m.group(1)),int(m.group(2)),m.group(3)
    if (p2f(h),p2f(b),ai(a)) in have: continue
    if not dry:
        d='%s/%d'%(INDEXED,p2f(h)); os.makedirs(d,exist_ok=True)
        shutil.copy2(PIF_CB+'/'+fn,'%s/%d.%d%s.png'%(d,p2f(h),p2f(b),a))
    fus+=1
bas=0
if PIF_BS!='-' and os.path.isdir(PIF_BS):
    haveb=set(os.listdir(BASEOUT)) if os.path.isdir(BASEOUT) else set()
    for fn in os.listdir(PIF_BS):
        mb=BASE.match(fn)
        if not mb: continue
        tgt='%d%s.png'%(p2f(int(mb.group(1))),mb.group(2))
        if tgt in haveb: continue
        if not dry:
            os.makedirs(BASEOUT,exist_ok=True); shutil.copy2(PIF_BS+'/'+fn,BASEOUT+'/'+tgt)
        bas+=1
print("[%s] additions: fusions=%d base=%d %s"%(os.path.basename(INSTALL),fus,bas,'(DRY)' if dry else 'DEPLOYED'))
