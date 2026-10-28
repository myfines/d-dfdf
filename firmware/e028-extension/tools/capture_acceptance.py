import json,time,wave,sys,urllib.request
from pathlib import Path
import numpy as np,sounddevice as sd
label=sys.argv[1];duration=float(sys.argv[2]) if len(sys.argv)>2 else 2
root=Path('E:/gaoyun/private/esp-web/acceptance-20261028');root.mkdir(exist_ok=True)
c=json.loads(Path('E:/gaoyun/private/esp-web/config.json').read_text())
def state():return json.load(urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8765/api/state',headers={'Authorization':'Bearer '+c['browser_token']})))
s0=state();audio=sd.rec(int(duration*48000),samplerate=48000,channels=1,device=1,dtype='float32');sd.wait();x=audio[:,0].astype(float)
with wave.open(str(root/(label+'.wav')),'wb') as w:w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
f=np.fft.rfftfreq(len(x),1/48000);p=abs(np.fft.rfft((x-x.mean())*np.hanning(len(x))));valid=np.flatnonzero((f>40)&(f<15000));top=valid[np.argsort(p[valid])[-25:][::-1]];peaks=[]
for k in top:
 if all(abs(f[k]-q[0])>3 for q in peaks):peaks.append([round(float(f[k]),2),round(float(p[k]),3)])
 if len(peaks)==8:break
notes=[]
for n in range(32):
 target=130.81278265*2**(n/12);sel=np.flatnonzero(abs(f-target)<2);k=sel[np.argmax(p[sel])];near=np.flatnonzero((abs(f-target)>5)&(abs(f-target)<12));noise=float(np.median(p[near]))
 notes.append({'n':n,'hz':round(float(f[k]),2),'amplitude':round(float(p[k]),3),'local_snr_db':round(float(20*np.log10(max(p[k],1e-12)/max(noise,1e-12))),1)})
rms=float(np.sqrt(np.mean(x*x)));row={'label':label,'time':time.time(),'duration':duration,'rms_dbfs':round(20*np.log10(max(rms,1e-12)),2),'peak':round(float(max(abs(x))),5),'clip_fraction':float(np.mean(abs(x)>=.99)),'peaks':peaks,'note_bins':notes,'before':s0,'after':state()}
(root/(label+'.json')).write_text(json.dumps(row,indent=2));out=Path('E:/gaoyun/releases/e028-flash-record/firmware/e028-extension/docs/e031-acceptance');out.mkdir(exist_ok=True);(out/(label+'.json')).write_text(json.dumps(row,indent=2));print(json.dumps({k:row[k] for k in ['label','rms_dbfs','peak','clip_fraction','peaks']}))
