import json,time,threading,urllib.request,wave,math
from pathlib import Path
import numpy as np,sounddevice as sd
cfg=json.loads(Path('E:/gaoyun/private/esp-web/config.json').read_text());root=Path('E:/gaoyun/private/esp-web/acceptance-20261028');out=Path('E:/gaoyun/releases/e028-flash-record/firmware/e028-extension/docs/e031-acceptance');rows=[];done=threading.Event()
def request(path,post=False):
 r=urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8765'+path,data=b'' if post else None,headers={'Authorization':'Bearer '+cfg['browser_token']}),timeout=4);return r.read()
def send(c):request('/api/c/'+c,True)
def heartbeat():
 while not done.wait(1):
  try:send('Q00')
  except Exception:pass
def state():return json.loads(request('/api/state'))
def record(label,seconds=3):
 a=sd.rec(int(seconds*48000),samplerate=48000,channels=1,device=1,dtype='float32');sd.wait();x=a[:,0].astype(float)
 with wave.open(str(root/(label+'.wav')),'wb') as w:w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
 f=np.fft.rfftfreq(len(x),1/48000);p=abs(np.fft.rfft((x-x.mean())*np.hanning(len(x))));p[f<50]=0;k=int(np.argmax(p));rms=np.sqrt(np.mean(x*x));pitch=[]
 for j in range(0,len(x)-4800,2400):
  spec=abs(np.fft.rfft(x[j:j+4800]*np.hanning(4800),n=48000));pitch.append(float(np.argmax(spec[240:285])+240))
 row={'label':label,'rms_dbfs':round(float(20*np.log10(max(rms,1e-12))),2),'peak':round(float(max(abs(x))),5),'clip_fraction':float(np.mean(abs(x)>=.99)),'dominant_hz':round(float(f[k]),2),'spectral_centroid_hz':round(float(sum(f*p)/max(sum(p),1e-12)),1),'state':state(),'control':'authenticated relay HTTP API, same backend as WebMCP; not a browser tool call'}
 # harmonic signature at C4, normalized to fundamental magnitude
 bins=[float(max(p[abs(f-261.625565*h)<2])) for h in range(1,9)];row['harmonics_relative']=[round(v/max(bins[0],1e-12),3) for v in bins]
 rows.append(row);(out/'http-suite.json').write_text(json.dumps(rows,indent=2));print(json.dumps({k:row[k] for k in ['label','rms_dbfs','peak','dominant_hz','spectral_centroid_hz']}),flush=True)
threading.Thread(target=heartbeat,daemon=True).start()
try:
 for c in ['M00000000','D00','R00','H00','F00','V18','X00','B2000','Y80']:send(c)
 for t in range(4):
  send('M00000000');send('T%02X'%t);time.sleep(1.6);send('M00001000');time.sleep(2);record('timbre-'+str(t),2)
 send('M00000000');send('T01');time.sleep(1.6);send('M00001000');time.sleep(2)
 for label,c in [('brightness-low','Y10'),('brightness-high','YFF'),('vibrato-zero','X00'),('vibrato-high','X50'),('volume-low','V08'),('volume-high','V18')]:
  send(c);time.sleep(2);record(label,2)
 for c in ['X00','Y80','V10']:send(c)
 for name,code in [('dry',0),('chorus',1),('delay',2),('reverb',4)]:
  send('F%02X'%code);time.sleep(2);record('fx-'+name,2)
 send('M00000000');time.sleep(2);record('final-release',2)
finally:
 for c in ['M00000000','D00','R00','H00','F00','B2000','X00','V18','T00']:
  try:send(c)
  except Exception:pass
 done.set();send('L00');print('Cleanup completed',flush=True)
