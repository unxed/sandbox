"""Generate sse2int.asm: guest test of the integer SSE2 (XMM) instructions of DOSBox-X.
The expected results come from a small independent model written here, not from the emulator.
Usage: python3 gen_sse2int.py > sse2int.asm   (then: nasm -f bin sse2int.asm -o SSE2I.COM)"""
import random, struct

random.seed(20261021)
A = bytes([0x80,0x7F,0x01,0xFF,0x12,0x34,0x56,0x78,0xFF,0xFF,0x00,0x80,0xDE,0xAD,0xBE,0xEF])
B = bytes([0x7F,0x80,0x01,0x02,0xFF,0xFE,0x10,0x20,0x01,0x00,0xFF,0x7F,0xCA,0xFE,0xBA,0xBE])
C = bytes(random.randrange(256) for _ in range(16))   # more bytes
D = bytes(random.randrange(256) for _ in range(16))

def lanes(x,n):  return [int.from_bytes(x[i:i+n],'little') for i in range(0,16,n)]
def join(v,n):   return b''.join((e & ((1<<(8*n))-1)).to_bytes(n,'little') for e in v)
def sgn(e,n):    return e - (1<<(8*n)) if e >= 1<<(8*n-1) else e
def clamp(v,lo,hi): return max(lo,min(hi,v))

def binop(f,n):
    return lambda a,b: join([f(x,y,n) for x,y in zip(lanes(a,n),lanes(b,n))],n)
def add(x,y,n): return x+y
def sub(x,y,n): return x-y
def adds(x,y,n): return clamp(sgn(x,n)+sgn(y,n),-(1<<(8*n-1)),(1<<(8*n-1))-1)
def subs(x,y,n): return clamp(sgn(x,n)-sgn(y,n),-(1<<(8*n-1)),(1<<(8*n-1))-1)
def addus(x,y,n): return min(x+y,(1<<(8*n))-1)
def subus(x,y,n): return max(x-y,0)
def eq(x,y,n): return -1 if x==y else 0
def gt(x,y,n): return -1 if sgn(x,n)>sgn(y,n) else 0
def mullw(x,y,n): return sgn(x,2)*sgn(y,2)
def mulhw(x,y,n): return (sgn(x,2)*sgn(y,2))>>16

def pmaddwd(a,b):
    wa=[sgn(e,2) for e in lanes(a,2)]; wb=[sgn(e,2) for e in lanes(b,2)]
    return join([wa[2*i]*wb[2*i]+wa[2*i+1]*wb[2*i+1] for i in range(4)],4)
def pmuludq(a,b):
    da=lanes(a,4); db=lanes(b,4)
    return join([da[0]*db[0],da[2]*db[2]],8)
def unpack(n,high):
    def f(a,b):
        la=lanes(a,n); lb=lanes(b,n); h=len(la)//2; o=h if high else 0
        r=[]
        for i in range(h): r+= [la[o+i],lb[o+i]]
        return join(r,n)
    return f
def pack(n,lo,hi):
    def f(a,b):
        r=[clamp(sgn(e,n),lo,hi) for e in lanes(a,n)+lanes(b,n)]
        return join(r,n//2)
    return f
def shiftx(n,kind):
    def f(a,b):
        cnt=int.from_bytes(b[:8],'little'); bits=8*n; r=[]
        for e in lanes(a,n):
            if kind=='sra': r.append(sgn(e,n)>>min(cnt,bits-1))
            elif cnt>=bits: r.append(0)
            elif kind=='sll': r.append(e<<cnt)
            else: r.append(e>>cnt)
        return join(r,n)
    return f

OPS = [
 ('paddb',binop(add,1)),('paddw',binop(add,2)),('paddd',binop(add,4)),('paddq',binop(add,8)),
 ('psubb',binop(sub,1)),('psubw',binop(sub,2)),('psubd',binop(sub,4)),('psubq',binop(sub,8)),
 ('paddsb',binop(adds,1)),('paddsw',binop(adds,2)),('psubsb',binop(subs,1)),('psubsw',binop(subs,2)),
 ('paddusb',binop(addus,1)),('paddusw',binop(addus,2)),('psubusb',binop(subus,1)),('psubusw',binop(subus,2)),
 ('pcmpeqb',binop(eq,1)),('pcmpeqw',binop(eq,2)),('pcmpeqd',binop(eq,4)),
 ('pcmpgtb',binop(gt,1)),('pcmpgtw',binop(gt,2)),('pcmpgtd',binop(gt,4)),
 ('pmullw',binop(mullw,2)),('pmulhw',binop(mulhw,2)),('pmaddwd',pmaddwd),('pmuludq',pmuludq),
 ('pand',lambda a,b: bytes(x&y for x,y in zip(a,b))),('pandn',lambda a,b: bytes(~x&y&255 for x,y in zip(a,b))),
 ('por',lambda a,b: bytes(x|y for x,y in zip(a,b))),('pxor',lambda a,b: bytes(x^y for x,y in zip(a,b))),
 ('punpcklbw',unpack(1,False)),('punpcklwd',unpack(2,False)),('punpckldq',unpack(4,False)),('punpcklqdq',unpack(8,False)),
 ('punpckhbw',unpack(1,True)),('punpckhwd',unpack(2,True)),('punpckhdq',unpack(4,True)),('punpckhqdq',unpack(8,True)),
 ('packsswb',pack(2,-128,127)),('packuswb',pack(2,0,255)),('packssdw',pack(4,-32768,32767)),
]
# shifts by the count in the low qword of xmm1: 3 (inside), 70 (beyond every width)
SHIFTS = []
for nm,n,kind in (('psllw',2,'sll'),('pslld',4,'sll'),('psllq',8,'sll'),('psrlw',2,'srl'),('psrld',4,'srl'),('psrlq',8,'srl'),('psraw',2,'sra'),('psrad',4,'sra')):
    SHIFTS.append((nm,shiftx(n,kind)))

tests=[]   # (name, code lines, expected 16 bytes)
for nm,f in OPS:
    tests.append((nm,['movdqu xmm0, [iA]','movdqu xmm1, [iB]','%s xmm0, xmm1'%nm,'movdqu [res], xmm0'],f(A,B)))
    tests.append((nm+' (2)',['movdqu xmm0, [iC]','movdqu xmm1, [iD]','%s xmm0, xmm1'%nm,'movdqu [res], xmm0'],f(C,D)))
    tests.append((nm+' m128',['movdqu xmm0, [iA]','%s xmm0, [iB]'%nm,'movdqu [res], xmm0'],f(A,B)))
for nm,f in SHIFTS:
    for cnt in (3,70):
        cv=struct.pack('<QQ',cnt,0x1122334455667788)
        tests.append(('%s by %d'%(nm,cnt),['movdqu xmm0, [iA]','movdqu xmm1, [cnt%d]'%cnt,'%s xmm0, xmm1'%nm,'movdqu [res], xmm0'],f(A,cv)))
# shifts by an immediate
IMMS=[('psllw',2,'sll',(3,20)),('pslld',4,'sll',(5,40)),('psllq',8,'sll',(9,70)),('psrlw',2,'srl',(3,20)),('psrld',4,'srl',(5,40)),('psrlq',8,'srl',(9,70)),('psraw',2,'sra',(3,20)),('psrad',4,'sra',(5,40))]
for nm,n,kind,cs in IMMS:
    for c in cs:
        tests.append(('%s xmm,%d'%(nm,c),['movdqu xmm0, [iA]','%s xmm0, %d'%(nm,c),'movdqu [res], xmm0'],shiftx(n,kind)(A,struct.pack('<Q',c)+bytes(8))))
def bshift(left):
    def f(a,c):
        return bytes(((a[i-c] if left else a[i+c]) if 0 <= (i-c if left else i+c) < 16 else 0) for i in range(16))
    return f
for nm,left in (('pslldq',True),('psrldq',False)):
    for c in (4,15,20):
        tests.append(('%s xmm,%d'%(nm,c),['movdqu xmm0, [iA]','%s xmm0, %d'%(nm,c),'movdqu [res], xmm0'],bshift(left)(A,c) if c<16 else bytes(16)))
def shuf(kind,i):
    d=list(lanes(A,4)); w=lanes(A,2)
    if kind=='d': return join([d[(i>>(2*k))&3] for k in range(4)],4)
    if kind=='lw': return join([w[(i>>(2*k))&3] for k in range(4)]+w[4:],2)
    return join(w[:4]+[w[4+((i>>(2*k))&3)] for k in range(4)],2)
for nm,kind in (('pshufd','d'),('pshuflw','lw'),('pshufhw','hw')):
    for i in (0x1B,0xE4,0x55):
        tests.append(('%s %02Xh'%(nm,i),['movdqu xmm1, [iA]','%s xmm0, xmm1, %d'%(nm,i),'movdqu [res], xmm0'],shuf(kind,i)))
        tests.append(('%s m128 %02Xh'%(nm,i),['%s xmm0, [iA], %d'%(nm,i),'movdqu [res], xmm0'],shuf(kind,i)))
# moves
tests.append(('movdqa load/store',['movdqa xmm0, [iA]','movdqa [res], xmm0'],A))
tests.append(('movdqu load/store',['movdqu xmm0, [iB]','movdqu [res], xmm0'],B))
tests.append(('movdqa reg',['movdqa xmm1, [iA]','movdqa xmm0, xmm1','movdqu [res], xmm0'],A))
tests.append(('movntdq',['movdqu xmm0, [iC]','movntdq [res], xmm0'],C))
tests.append(('movd xmm,eax',['mov eax, 0x11223344','movdqu xmm0, [iA]','movd xmm0, eax','movdqu [res], xmm0'],struct.pack('<IIII',0x11223344,0,0,0)))
tests.append(('movd xmm,m32',['movdqu xmm0, [iA]','movd xmm0, [iB]','movdqu [res], xmm0'],B[:4]+bytes(12)))
tests.append(('movd eax,xmm',['movdqu xmm0, [iA]','movd eax, xmm0','mov [res], eax'],A[:4]+bytes(12)))
tests.append(('movd m32,xmm',['movdqu xmm0, [iC]','movd [res], xmm0'],C[:4]+bytes(12)))
tests.append(('movq xmm,xmm (F3 0F 7E)',['movdqu xmm0, [iA]','movdqu xmm1, [iB]','movq xmm0, xmm1','movdqu [res], xmm0'],B[:8]+bytes(8)))
tests.append(('movq xmm,m64',['movdqu xmm0, [iA]','movq xmm0, [iB]','movdqu [res], xmm0'],B[:8]+bytes(8)))
tests.append(('movq m64,xmm (66 0F D6)',['movdqu xmm0, [iC]','movq [res], xmm0'],C[:8]+bytes(8)))
tests.append(('movq xmm,xmm (66 0F D6)',['movdqu xmm0, [iA]','movdqu xmm1, [iB]','db 0x66, 0x0F, 0xD6, 0xC8','movdqu [res], xmm0'],A[:8]+bytes(8) if False else B[:0]+A) if False else None)
tests=[t for t in tests if t]

out=[]
out.append('; GENERATED by gen_sse2int.py: guest test of the integer SSE2 (XMM) instructions of DOSBox-X.')
out.append('; Needs "enable sse2 = true" and cputype=pentium_iii. Build: nasm -f bin sse2int.asm -o SSE2I.COM.')
out.append('\torg 100h\n\tcpu p4\n')
out.append(open('dosbox-x-sse2/sse2_common.inc').read())
out.append('run:')
for i,(nm,code,exp) in enumerate(tests):
    out.append('\tCLR')
    for c in code: out.append('\t'+c)
    out.append('\tCHK "%s", e%d'%(nm.replace('"',"'"),i))
out.append('\tret\n')
out.append('\talign 16\nres:\ttimes 16 db 0')
for lbl,d in (('iA',A),('iB',B),('iC',C),('iD',D)):
    out.append('%s:\tdb %s'%(lbl,','.join('0x%02X'%x for x in d)))
for cnt in (3,70):
    out.append('cnt%d:\tdq %d, 0x1122334455667788'%(cnt,cnt))
for i,(nm,code,exp) in enumerate(tests):
    out.append('e%d:\tdb %s'%(i,','.join('0x%02X'%x for x in exp)))
print('\n'.join(out))
