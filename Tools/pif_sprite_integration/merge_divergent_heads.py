import os,re,struct,sys,hashlib
PIF_TO_FORK={553:1038,554:1039,555:1040,556:553,557:581,558:554,559:555,560:556,561:557,
562:558,563:559,564:560,565:561,566:1109,567:1110,568:687,569:688,570:689,571:737,572:738}
def p2f(i): return PIF_TO_FORK.get(i,i)
FORK_TO_PIF={v:k for k,v in PIF_TO_FORK.items()}
FUSION=re.compile(r'^(\d+)\.(\d+)([a-z]?)\.png$')
def read_pak(path):
    out={}
    if not os.path.exists(path): return out
    d=open(path,'rb').read()
    if d[:4]!=b'SPAK': return out
    n=struct.unpack('<I',d[4:8])[0]; off=8; idx=[]
    for _ in range(n): idx.append(struct.unpack('<IIII',d[off:off+16])); off+=16
    ds=8+n*16
    for body,alt,o,l in idx: out[(body,alt)]=d[ds+o:ds+o+l]
    return out
def alt_str(a): return '' if a==0 else chr(ord('a')+a-1)

PIF_CB=sys.argv[1]; PIF_BS=sys.argv[2]; INSTALL=sys.argv[3]
PACKED=INSTALL+'/Graphics/CustomBattlers_packed'
INDEXED=INSTALL+'/Graphics/CustomBattlers/indexed'
BASEOUT=INSTALL+'/Graphics/BaseSprites'
dry = (len(sys.argv)>4 and sys.argv[4]=='--dry')

# index PIF filenames by PIF head for the heads we need
need_pif_heads={FORK_TO_PIF[h] for h in FORK_TO_PIF}  # PIF heads that map to divergent fork heads
pif_by_head={h:[] for h in need_pif_heads}
allf=os.listdir(PIF_CB)
for fn in allf:
    m=FUSION.match(fn)
    if m and int(m.group(1)) in need_pif_heads:
        pif_by_head[int(m.group(1))].append(fn)

written=0; alts=0; bases=0; heads=0
for fork_head in sorted(FORK_TO_PIF):
    pif_head=FORK_TO_PIF[fork_head]
    files=pif_by_head.get(pif_head,[])
    if not files and not os.path.exists(PIF_BS+'/%d.png'%pif_head): continue
    heads+=1
    dstdir=INDEXED+'/'+str(fork_head)
    if not dry: os.makedirs(dstdir,exist_ok=True)
    # existing AFI pak for this fork head (to preserve as alt)
    afi=read_pak(PACKED+'/%d.pak'%fork_head)
    # write PIF mains (remap body)
    pif_mains=set()
    for fn in files:
        m=FUSION.match(fn); b=int(m.group(2)); alt=m.group(3)
        fb=p2f(b)
        target='%d.%d%s.png'%(fork_head,fb,alt)
        if alt=='': pif_mains.add(fb)
        if not dry:
            data=open(PIF_CB+'/'+fn,'rb').read()
            open(dstdir+'/'+target,'wb').write(data)
        written+=1
    # preserve AFI main sprites as alt 'z' where PIF replaced the main
    for (body,a),data in afi.items():
        if a==0 and body in pif_mains and body!=0:
            altpath=dstdir+'/%d.%dz.png'%(fork_head,body)
            if not dry and not os.path.exists(altpath):
                open(altpath,'wb').write(data); alts+=1
    # base sprite
    for cand in ['%d.png'%pif_head]:
        bp=PIF_BS+'/'+cand
        if os.path.exists(bp):
            if not dry:
                os.makedirs(BASEOUT,exist_ok=True)
                open(BASEOUT+'/%d.png'%fork_head,'wb').write(open(bp,'rb').read())
            bases+=1
print("install=%s heads=%d pif_mains_written=%d afi_alts=%d base=%d %s"%(os.path.basename(INSTALL),heads,written,alts,bases,'(DRY)' if dry else ''))
