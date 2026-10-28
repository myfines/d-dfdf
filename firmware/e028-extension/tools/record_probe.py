"""Record temporary E02A sequencer; no hardware writes are performed here."""
import argparse,json,time,wave
from pathlib import Path
import sounddevice as sd
import numpy as np
from audio_probe import metrics
p=argparse.ArgumentParser();p.add_argument('--device',type=int,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--seconds',type=float,default=32);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
t0=time.time();x=sd.rec(int(a.seconds*48000),samplerate=48000,channels=1,device=a.device,dtype='float32')
(a.output/'recording.json').write_text(json.dumps(dict(start_unix=t0,seconds=a.seconds,device=a.device,status='recording')),encoding='utf-8')
sd.wait();x=x[:,0]
with wave.open(str(a.output/'DAC-probe.wav'),'wb') as w:
 w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
rows=[]
for second in range(int(a.seconds)):
 rows.append(dict(second=second,**metrics(x[second*48000:(second+1)*48000],48000)))
(a.output/'recording.json').write_text(json.dumps(dict(start_unix=t0,seconds=a.seconds,device=a.device,status='complete',source='Realtek physical input; temporary SRAM E02A sequencer',windows=rows),indent=2),encoding='utf-8')
