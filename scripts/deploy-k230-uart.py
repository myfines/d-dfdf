"""Bounded raw-REPL script deployment. Never writes firmware or block devices."""
import argparse,json,time,hashlib,re
from pathlib import Path
import serial
ROOT=Path(__file__).resolve().parents[1]
LOG=ROOT/'logs/20261022-k230-uart-sync-deploy'

def collect(s,seconds):
 out=bytearray();end=time.monotonic()+seconds
 while time.monotonic()<end:out.extend(s.read(4096))
 return bytes(out)

def main():
 ap=argparse.ArgumentParser();ap.add_argument('phase',choices=['inspect','stage','trial','install','start']);args=ap.parse_args()
 LOG.mkdir(exist_ok=True)
 with serial.Serial('COM9',12000000,timeout=.1) as s:
  s.dtr=True
  s.write(b'\x03\x02\r\n');prior=collect(s,1.5)
  s.write(b'\x03\r\n');prior+=collect(s,.5)
  s.write(b"print('UART_'+'DEPLOY_READY')\r\n");prior+=collect(s,.5)
  (LOG/(args.phase+'-handshake.bin')).write_bytes(prior)
  if b'UART_DEPLOY_READY\r\n' not in prior or b'>>> ' not in prior:raise RuntimeError('Friendly REPL not proven')
  s.write(b'\x01');banner=collect(s,.4)
  if b'raw REPL' not in banner:raise RuntimeError('Raw REPL not proven')
  if args.phase=='inspect':
   code="""import os,uhashlib,ubinascii,ujson,machine
records=[]
for path in ['/sdcard/main.py','/sdcard/boot.py','/sdcard/pinch_preview_v2.py','/sdcard/k230_hand_keypoint_official.py','/sdcard/kmodel/hand_det.kmodel','/sdcard/kmodel/handkp_det.kmodel','/sdcard/uart_gesture_sender_standalone.py']:
 try:
  h=uhashlib.sha256()
  with open(path,'rb') as f:
   while True:
    b=f.read(4096)
    if not b:break
    h.update(b)
  rec={'path':path,'size':os.stat(path)[6],'sha256':ubinascii.hexlify(h.digest()).decode()}
  if path in ['/sdcard/main.py','/sdcard/boot.py']:
   with open(path,'rb') as f:rec['hex']=ubinascii.hexlify(f.read()).decode()
  records.append(rec)
 except OSError:records.append({'path':path,'missing':True})
print('DEPLOYJSON '+ujson.dumps({'files':records,'has_machine_reset':hasattr(machine,'reset')}))
"""
   duration=25
  elif args.phase=='stage':
   source=(ROOT/'build/k230/uart_gesture_sender_standalone.py').read_bytes()
   expected='de7aefb6406658549538fe1d7f51b903aa48451dc729356eb245d564d7a5ff0f'
   if hashlib.sha256(source).hexdigest()!=expected:raise RuntimeError('Local candidate changed')
   target='/sdcard/uart_gesture_sender_standalone.py';temp=target+'.upload'
   code="import os,uhashlib,ubinascii\nf=open(%r,'wb')\n"%temp
   for offset in range(0,len(source),256):code+="f.write(ubinascii.unhexlify(%r))\n"%source[offset:offset+256].hex()
   code+="""f.close()
with open(%r,'rb') as f:uploaded=f.read()
assert ubinascii.hexlify(uhashlib.sha256(uploaded).digest()).decode()==%r
compile(uploaded,%r,'exec')
try:
 with open(%r,'rb') as f:existing=f.read()
except OSError:existing=None
if existing is None:os.rename(%r,%r)
elif existing==uploaded:os.remove(%r)
else:
 assert ubinascii.hexlify(uhashlib.sha256(existing).digest()).decode()=='e88ea108a08d80d27c64377d0a92eacf9a189d4d62c723fb9abf039846615e91'
 os.rename('/sdcard/uart_gesture_sender_standalone.py','/sdcard/uart_gesture_sender_before_sync_fix.py')
 os.rename('/sdcard/uart_gesture_sender_standalone.py.upload','/sdcard/uart_gesture_sender_standalone.py')
if hasattr(os,'sync'):os.sync()
print('STAGE_OK',len(uploaded),%r)
"""%(temp,expected,target,target,temp,target,temp,expected)
   duration=5
  elif args.phase=='install':
   inventory=json.loads((LOG/'inspect.json').read_text())
   original=next(x for x in inventory['files'] if x['path']=='/sdcard/main.py')
   launcher=(ROOT/'k230/uart_gesture_launcher.example.py').read_bytes()
   backup='/sdcard/main_before_uart_E025_'+time.strftime('%Y%m%d_%H%M%S')+'.py'
   (LOG/'main-original.py').write_bytes(bytes.fromhex(original['hex']))
   (LOG/'installed-launcher.py').write_bytes(launcher)
   meta={'backup':backup,'original_sha256':original['sha256'],'launcher_sha256':hashlib.sha256(launcher).hexdigest()}
   (LOG/'installation.json').write_text(json.dumps(meta,indent=2))
   code="""import os,uhashlib,ubinascii
with open('/sdcard/main.py','rb') as f:original=f.read()
assert ubinascii.hexlify(uhashlib.sha256(original).digest()).decode()==%r
try:
 os.stat(%r)
 raise RuntimeError('Backup already exists')
except OSError:pass
with open(%r,'wb') as f:assert f.write(original)==len(original)
with open(%r,'rb') as f:assert f.read()==original
launcher=ubinascii.unhexlify(%r)
compile(launcher,'/sdcard/main.py','exec')
with open('/sdcard/main.py.uart_new','wb') as f:assert f.write(launcher)==len(launcher)
with open('/sdcard/main.py.uart_new','rb') as f:assert f.read()==launcher
os.remove('/sdcard/main.py')
os.rename('/sdcard/main.py.uart_new','/sdcard/main.py')
if hasattr(os,'sync'):os.sync()
with open('/sdcard/main.py','rb') as f:assert f.read()==launcher
print('INSTALL_OK',%r,ubinascii.hexlify(uhashlib.sha256(launcher).digest()).decode())
"""%(original['sha256'],backup,backup,backup,launcher.hex(),backup)
   duration=5
  else:
   path='/sdcard/uart_gesture_sender_standalone.py' if args.phase=='trial' else '/sdcard/main.py'
   code="with open(%r) as f:source=f.read()\nexec(compile(source,%r,'exec'),{'__name__':'__main__'})\n"%(path,path)
   duration=18
  program=code.encode()
  for i in range(0,len(program),128):s.write(program[i:i+128]);s.flush();time.sleep(.01)
  s.write(b'\x04');s.flush();result=collect(s,duration)
  (LOG/(args.phase+'-capture.bin')).write_bytes(banner+result)
  if args.phase not in ['trial','start']:s.write(b'\x02')
 if args.phase=='inspect':
  match=re.search(rb'DEPLOYJSON ([^\r\n]+)',result)
  if not match:raise RuntimeError('No inventory result: '+repr(result[-300:]))
  data=json.loads(match[1]);(LOG/'inspect.json').write_text(json.dumps(data,indent=2))
  print(json.dumps({'files':[{k:v for k,v in x.items() if k!='hex'} for x in data['files']],'has_machine_reset':data['has_machine_reset']}))
 elif args.phase in ['trial','start']:
  reports=re.findall(rb'UART_GESTURE accepted=(\d+) seq=(\d+) valid=(\d+) confidence=(\d+)',result)
  summary={'reports':len(reports),'first':reports[:3],'last':reports[-2:],'PINCH2_lines':result.count(b'PINCH2,'),'traceback':b'Traceback' in result,'stopped':b'UART_GESTURE stopped' in result}
  (LOG/(args.phase+'-summary.txt')).write_text(repr(summary))
  print(summary)
  if not reports or summary['traceback'] or summary['stopped']:raise RuntimeError('UART sender trial failed: '+repr(result[-500:]))
 else:
  marker=b'STAGE_OK' if args.phase=='stage' else b'INSTALL_OK'
  print(repr(result[-400:]))
  if marker not in result or b'Traceback' in result:raise RuntimeError('Deployment phase not verified')
if __name__=='__main__':main()

