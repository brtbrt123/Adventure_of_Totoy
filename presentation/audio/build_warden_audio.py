"""Deterministic foley mixes from existing credited recorded cues; no synthetic oscillators."""
from pathlib import Path
from array import array
import hashlib
import json
import wave
import math

HERE = Path(__file__).resolve().parent
RATE = 44100
# source, playback-rate, gain, delay seconds. Credits follow the retained cue provenance.
RECIPES = {
    'wake': [('golem_charge.wav',.65,.55,0),('gold_warning.wav',.65,.25,.08)],
    'step': [('armor_hit.wav',.55,.65,0),('golem_stomp.wav',.8,.35,0)],
    'step_2': [('armor_hit_2.wav',.6,.65,0),('golem_stomp.wav',.9,.35,0)],
    'cleave_tell': [('swing.wav',.65,.6,0),('armor_hit.wav',.6,.25,.1)],
    'cleave_strike': [('golem_sweep.wav',.7,.6,0),('armor_hit_2.wav',.65,.5,.06)],
    'lash_tell': [('golem_charge.wav',.8,.5,0),('swing_2.wav',.7,.3,.1)],
    'lash_strike': [('swing_2.wav',1.25,.6,0),('armor_hit_3.wav',1.15,.65,.07)],
    'ring_tell': [('golem_beam.wav',.65,.45,0),('swing.wav',.6,.3,.1)],
    'ring_strike': [('golem_stomp.wav',.65,.65,0),('golem_sweep.wav',.8,.3,.08)],
    'guard_hit': [('armor_hit.wav',.6,.55,0),('gold_warning.wav',1.4,.3,.02)],
    'guard_hit_2': [('armor_hit_2.wav',.65,.55,0),('gold_warning.wav',1.5,.3,.02)],
    'guard_break': [('posture_break.wav',1.15,.6,0),('gold_warning.wav',.5,.3,.08)],
    'death': [('armor_hit_3.wav',.55,.5,0),('golem_stomp.wav',.6,.5,.13),('armor_hit.wav',.7,.25,.38)],
}


def read(path):
    with wave.open(str(path),'rb') as w:
        assert w.getsampwidth()==2
        channels, rate = w.getnchannels(), w.getframerate()
        samples = array('h',w.readframes(w.getnframes()))
    return [sum(samples[i:i+channels])/channels/32768 for i in range(0,len(samples),channels)], rate


def main():
    report = []
    preview = []
    for name, layers in RECIPES.items():
        mix = []
        for source, speed, gain, delay in layers:
            samples, rate = read(HERE/source)
            step = rate*speed/RATE
            length = int((len(samples)-1)/step)
            offset = round(delay*RATE)
            if len(mix)<offset+length:
                mix.extend([0.0]*(offset+length-len(mix)))
            for i in range(length):
                p = i*step
                j = int(p)
                sample = samples[j]*(1-(p-j))+samples[j+1]*(p-j)
                envelope = min(1.0,i/(RATE*.005), (length-i)/(RATE*.08))
                mix[offset+i] += sample*gain*envelope
        peak = max(abs(x) for x in mix)
        gain = .65/max(.65,peak)
        data = array('h',(round(x*gain*32767) for x in mix))
        path = HERE/f'warden_{name}.wav'
        with wave.open(str(path),'wb') as w:
            w.setparams((1,2,RATE,0,'NONE','not compressed'))
            w.writeframes(data.tobytes())
        preview.extend(data)
        preview.extend([0]*round(RATE*.4))
        report.append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'creator':'Project foley remix of existing recorded CC0 cues (Kenney, artisticdude, StarNinjas, Brian MacIntosh); see retained source credits',
            'license':'CC0-1.0 source recordings; project remix',
            'processing':{'layers':layers,'sample_rate':RATE,'peak':peak*gain,'fade_in_ms':5,'fade_out_ms':80},
            'source_sha256':{s:hashlib.sha256((HERE/s).read_bytes()).hexdigest() for s,_,_,_ in layers}})
    with wave.open(str(HERE/'warden_preview.wav'),'wb') as w:
        w.setparams((1,2,RATE,0,'NONE','not compressed'))
        w.writeframes(array('h',preview).tobytes())
    manifest = json.loads((HERE/'sources.json').read_text())
    manifest['warden_recorded_remixes'] = report
    (HERE/'sources.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'WARDEN AUDIO: {len(report)} mono PCM recorded remixes, peaks <= .65')


if __name__=='__main__':
    main()
