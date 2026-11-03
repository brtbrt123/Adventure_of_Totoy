"""Original32s restrained intro motif, stdlib synthesis; no samples or external composition."""
from pathlib import Path
import math, wave, array, json
ROOT=Path(__file__).resolve().parents[3]
RATE=48000
SECONDS=32
mix=array.array('f',[0.0])*(RATE*SECONDS)
def tone(midi,start,length,volume,kind='pad'):
    freq=440*2**((midi-69)/12)
    for n in range(int(length*RATE)):
        at=int(start*RATE)+n
        if at>=len(mix):break
        t=n/RATE
        if kind=='pad':
            env=min(1,t/1.3)*min(1,(length-t)/1.6)
            value=math.sin(math.tau*freq*t)+.2*math.sin(math.tau*freq*2*t)
        else:
            env=(1-math.exp(-t*70))*math.exp(-t*2.1)
            value=math.sin(math.tau*freq*t)+.15*math.sin(math.tau*freq*2.01*t)
        mix[at]+=value*env*volume
# Dminor, Bbmaj, Csus, Dminor: a quiet returning-home progression.
for index,chord in enumerate([(50,57,65),(46,53,62),(48,55,65),(50,57,65)]):
    for note in chord:tone(note,index*8,8,.035)
for start,note in [(1,74),(2.8,77),(4.6,81),(9,74),(11,72),(13.8,69),(17,72),(19.5,77),(21.5,79),(25,77),(27,74),(29.5,69)]:
    tone(note,start,2.2,.045,'bell')
peak=max(map(abs,mix));gain=.48/max(peak,.001)
out=array.array('h')
for i,value in enumerate(mix):
    t=i/RATE
    fade=min(1,t/.25,(SECONDS-t)/.35)
    out.append(round(max(-1,min(1,value*gain*max(0,fade)))*32767))
path=ROOT/'presentation/audio/music/intro_theme.wav'
with wave.open(str(path),'wb') as w:
    w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(out.tobytes())
(path.with_suffix('.json')).write_text(json.dumps({'title':'Returning Lights - intro sketch','origin':'Original synthesized composition for Adventure of Totoy; no external samples','seconds':SECONDS,'rate':RATE,'channels':1,'notes':'Dminor/Bb/Csus/Dminor sustained sine pads and soft bell motif; quiet playback, loop; owner pacing/audio approval pending','script':'art/reference/intro_cutscene_v1/compose_music.py'},indent=2)+'\n')
print('Wrote original intro theme:',path)
