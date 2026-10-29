"""SRAM-only integrated score/config/PCM return test; restores E037 in finally."""
import json,subprocess,time,hashlib
from pathlib import Path
import numpy as np
import serial,serial.tools.list_ports
import run_autonomous_probe as loader
from recording_store import RecordingStore
root=Path(__file__).resolve().parents[1];loader.OUT=root/'docs/e037-regression'
private=Path('E:/gaoyun/private/esp-web');ports=[p for p in serial.tools.list_ports.comports() if p.vid==0x403 and p.pid==0x6010]
if len(ports)!=1:raise RuntimeError('Expected one FTDI serial receive port')
store=RecordingStore();valid=0;invalid=0;normal=0;observed={};lines=[]
try:
 loader.deploy('integration_probe','probe-manifest.json','20261029-integration-probe-SRAM')
 with serial.Serial(ports[0].device,115200,timeout=.25) as stream:
  start=time.monotonic()
  while time.monotonic()-start<12:
   raw=stream.readline(192);line=raw.decode('ascii',errors='replace')
   if store.ingest(line):
    valid+=1;lines.append(line);s=store.status();observed[s['last_chunk']]=s['applied']
   elif raw.strip().startswith(b'A'):invalid+=1
   elif raw:normal+=1
 assert store.status()['complete'],'Not all128 chunks received'
 assert observed[0]['mapped_note']==31,'Remapped key not applied'
 assert all(s['score_ready'] and s['score_length']==3 for s in observed.values()),'Score commit readback wrong'
 assert all(s['adsr_enabled'] and s['adsr_config'].upper()=='9CDA0' for s in observed.values()),'ADSR applied readback wrong'
 wav=store.wav();(private/'e037-integration-capture.wav').write_bytes(wav)
 x=np.frombuffer(wav[44:],dtype=np.uint8).astype(float)-128
 assert np.max(abs(x))>0,'Digital recording contains no signal'
 report=dict(valid_packets=valid,malformed_record_lines=invalid,normal_or_blank_lines=normal,recording=store.status(),mapped_slot0=observed[0],
 pcm_peak=int(np.max(abs(x))),pcm_rms=float(np.sqrt(np.mean(x*x))),wav_sha256=hashlib.sha256(wav).hexdigest(),
 limitation='Internal command injection and USB-B transport diagnostic derivative; not actual Wi-Fi routing, physical input latency or full-production analog acceptance.')
 (loader.OUT/'board-integration-test.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
finally:
 loader.deploy('instrument_e037','build-manifest.json','20261029-restore-E037')
 for op,expected in [(73,b'0x0000E037'),(74,b'0x00006020')]:
  r=subprocess.run(loader.COMMON+['--operation_index',str(op)],capture_output=True,timeout=12);raw=r.stdout+r.stderr
  (loader.OUT/f'20261029-restore-read{op}.log').write_bytes(raw)
  if r.returncode or expected not in raw:raise RuntimeError('Restore read failed')
 print('Restored E037/6020; Flash unchanged',flush=True)
