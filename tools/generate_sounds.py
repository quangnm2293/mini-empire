import math, os, random, struct, wave
ROOT=os.path.expanduser('~/workspace/mini-empire/sounds'); os.makedirs(ROOT,exist_ok=True)
SR=22050; random.seed(7)
def write(name, samples):
    samples=[max(-1,min(1,s)) for s in samples]
    with wave.open(os.path.join(ROOT,name),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h',int(s*32767)) for s in samples))
def tone(freq,dur,vol=.35,freq2=None,type='sine'):
    out=[]
    n=int(SR*dur)
    for i in range(n):
        t=i/SR; f=freq if freq2 is None else freq+(freq2-freq)*(i/n)
        v=math.sin(2*math.pi*f*t)
        if type=='square': v=0.6*(1 if v>=0 else -1)
        out.append(v*vol*(1-i/n)**0.6)
    return out
def mix(*tracks):
    n=max(len(x) for x in tracks); out=[0]*n
    for tr in tracks:
        for i,v in enumerate(tr): out[i]+=v
    return out
def noise(dur,vol=.3,decay=1):
    return [(random.uniform(-1,1)*vol*(1-i/int(SR*dur))**decay) for i in range(int(SR*dur))]
def seq(notes,note_dur=.13,vol=.35):
 conditioner=[]
 out=[]
 for f in notes: out += tone(f,note_dur,vol)
 return out
write('click.wav',tone(700,.06,.22,500))
write('chop.wav',noise(.09,.42))
write('deposit.wav',mix(tone(880,.16,.28),tone(1320,.22,.22)))
write('sword.wav',mix(noise(.13,.34),tone(180,.13,.18,70)))
write('arrow.wav',tone(1100,.16,.22,280))
write('tower.wav',tone(520,.18,.26,920))
write('placed.wav',mix(tone(95,.25,.5,55),noise(.18,.18)))
write('train_ready.wav',seq([660,880,990],.09,.28))
write('horn.wav',mix(tone(196,.65,.32,type='square'),tone(247,.65,.22,type='square')))
write('win.wav',seq([523,659,784,1046],.17,.32))
write('lose.wav',seq([392,330,262,196],.2,.32))
# ambient pad loop 4 sec (quiet)
amb=[]
chords=[(220,277,330),(196,247,294),(175,220,262),(196,247,294)]
for ci,ch in enumerate(chords):
    for i in range(SR):
        t=i/SR; v=sum(math.sin(2*math.pi*f*t) for f in ch)/3
        amb.append(v*.055)
write('ambient.wav',amb)
print('sounds', os.listdir(ROOT))
