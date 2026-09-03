import re, os, sys
BR='brand'
sym=open(BR+'/disciplefy-symbol-master.svg').read()
SW,SH=863.0,1119.0
s_t=re.search(r'<g transform="([^"]+)"',sym).group(1)
s_in="\n".join('      <path d="%s"/>'%p.strip() for p in re.findall(r'<path d="([^"]+)"',sym,re.S))
wm=open(BR+'/wordmark/wordmark-gold.svg').read()
WW,WH=1929.0,274.0
w_t=re.search(r'<g transform="([^"]+)"',wm).group(1)
w_in="\n".join('      <path d="%s"/>'%p.strip() for p in re.findall(r'<path d="([^"]+)"',wm,re.S))

def horizontal(fill,bg,cap,gap_f):
    ws=(SH*cap)/WH; wmw,wmh=WW*ws,WH*ws
    gap=SW*gap_f; tw,th=SW+gap+wmw,SH; pad=th*0.14
    vw,vh=tw+2*pad,th+2*pad
    rect='  <rect width="%.0f" height="%.0f" fill="%s"/>\n'%(vw,vh,bg) if bg else ''
    wy=pad+(SH-wmh)/2
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %.0f %.0f" role="img" aria-label="Disciplefy">\n'
            '  <title>Disciplefy</title>\n%s'
            '  <g transform="translate(%.2f,%.2f)">\n    <g transform="%s" fill="%s" stroke="none">\n%s\n    </g>\n  </g>\n'
            '  <g transform="translate(%.2f,%.2f) scale(%.5f)">\n    <g transform="%s" fill="%s" stroke="none">\n%s\n    </g>\n  </g>\n'
            '</svg>\n')%(vw,vh,rect,pad,pad,s_t,fill,s_in,pad+SW+gap,wy,ws,w_t,fill,w_in)

cap=float(sys.argv[1]); gap=float(sys.argv[2])
for name,fill in [('gold','#E3B154'),('black','#0B0B0B'),('white','#FFFFFF'),('gold-light-bg','#D4930A')]:
    open(f'{BR}/lockup/horizontal-{name}.svg','w').write(horizontal(fill,None,cap,gap))
open(f'{BR}/lockup/horizontal-gold-on-black.svg','w').write(horizontal('#E3B154','#0B0B0B',cap,gap))
print(f"  cap={cap} gap={gap}")
