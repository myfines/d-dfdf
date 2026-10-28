import json,time,threading,urllib.request,wave
from pathlib import Path
import numpy as np,sounddevice as sd
c=json.loads(Path('E:/gaoyun/private/esp-web/config.json').read_text());root=Path('E:/gaoyun/private/esp-web/acceptance-20261028');out=Path('E:/gaoyun/releases/e028-flash-record/firmware/e028-extension/docs/e031-acceptance');end=threading.Event();rows=[]
def send(k):urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8765/api/c/'+k,data=b'',headers={'Authorization':'Bearer '+c['browser_token']}),timeout=4).read()
def hb():
 while not end.wait(1):
  try:send('Q00')
  except Exception:pass
threading.Thread(target=hb,daemon=True).start()
try:
 for k in ['M00000000','D00','R00','H00','B2000','X00','Y80','V10']:send(k)
 for label,t,fx in [('envelope-epiano',0,0),('envelope-strings',2,0),('delay-low-level',1,2)]:
  for k in ['M00000000','T%02X'%t,'F%02X'%fx]:send(k)
  time.sleep(2);a=sd.rec(48000*9,samplerate=48000,channels=1,device=1,dtype='float32');start=time.monotonic();time.sleep(1);send('M00001000');on=time.monotonic()-start;time.sleep(4);send('M00000000');off=time.monotonic()-start;sd.wait();x=a[:,0].astype(float)
  with wave.open(str(root/(label+'.wav')),'wb') as w:w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
  env=np.sqrt(np.mean(x.reshape(-1,960)**2,axis=1));row={'label':label,'host_note_on_s':on,'host_note_off_s':off,'rms_20ms':env.round(7).tolist(),'peak':float(max(abs(x))),'clip_fraction':float(np.mean(abs(x)>=.99)),'tail_last_second_dbfs':float(20*np.log10(max(np.sqrt(np.mean(x[-48000:]**2)),1e-12))),'notice':'Host timestamps are not FPGA input edges; no end-to-end latency claim. Realtek gain may alter envelope.'};rows.append(row);(out/'envelope-suite.json').write_text(json.dumps(rows,indent=2));print(json.dumps({k:row[k] for k in ['label','peak','clip_fraction','tail_last_second_dbfs']}),flush=True)
finally:
 end.set()
 for k in ['M00000000','D00','R00','H00','F00','V18','T00','L00']:
  try:send(k)
  except Exception:pass
 print('Cleanup done',flush=True)
