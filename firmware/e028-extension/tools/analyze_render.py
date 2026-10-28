"""Compare the four tb_audio_render dumps; this is digital simulation evidence."""
import argparse,json,wave
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,default=Path('.'));p.add_argument('--output',type=Path,required=True);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True);rows=[];spectra=[]
for t in range(4):
 x=np.loadtxt(a.input/f'timbre{t}.txt');rate=46875
 y=np.abs(np.fft.rfft((x-x.mean())*np.hanning(len(x))));f=np.fft.rfftfreq(len(x),1/rate)
 spectra.append(y/(np.linalg.norm(y)+1e-12))
 rows.append(dict(timbre=t,samples=len(x),peak=float(abs(x).max()),rms=float(np.sqrt(np.mean(x*x))),dc=float(x.mean()),clipped_fraction=float(np.mean(abs(x)>=32767)),centroid_hz=float(sum(y*f)/sum(y))))
 with wave.open(str(a.output/f'timbre{t}-RTL.wav'),'wb') as w:
  w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes(x.astype('<i2').tobytes())
pairs=[dict(pair=[i,j],cosine_distance=float(1-np.dot(spectra[i],spectra[j]))) for i in range(4) for j in range(i+1,4)]
(a.output/'analysis.json').write_text(json.dumps(dict(source='RTL simulation, not DAC recording',sample_rate=rate,rows=rows,normalized_spectral_distances=pairs),indent=2),encoding='utf-8')
assert all(r['rms']>100 and r['clipped_fraction']==0 for r in rows)
assert min(p['cosine_distance'] for p in pairs)>.01
print('PASS four timbre spectra differ after level normalization; single-note samples unclipped')
