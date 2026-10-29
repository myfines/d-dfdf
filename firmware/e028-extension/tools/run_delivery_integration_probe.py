"""Current production-core derivative, AP relay disabled; inject W/U/C/G,
receive real-board applied metadata/PCM over USB, then restore E045.
This is not Android/Wi-Fi transport or physical input latency acceptance.
"""
import hashlib,json,subprocess,threading,time
from pathlib import Path
import numpy as np
import serial
from recording_store import RecordingStore
import run_autonomous_probe as loader

root=Path(__file__).resolve().parents[1];out=root/'docs/e046-integration';out.mkdir(exist_ok=True)
loader.OUT=out;private=Path('E:/gaoyun/private/esp-web')
fs=private/'build/integration_delivery_probe/impl/pnr/integration_delivery_probe.fs'
sha=hashlib.sha256(fs.read_bytes()).hexdigest()
(out/'probe-manifest.json').write_text(json.dumps(dict(artifact_sha256=sha)))
restore=json.loads((root/'docs/e045-regression/manifest.json').read_text())['artifact_sha256']
(out/'restore-manifest.json').write_text(json.dumps(dict(artifact_sha256=restore)))
stop=threading.Event();lines=[];store=RecordingStore()
try:
 with serial.Serial('COM13',115200,timeout=.1) as port:
  def reader():
   while not stop.is_set():
    raw=port.readline(192)
    if raw:lines.append(raw.decode('ascii',errors='replace'))
  thread=threading.Thread(target=reader);thread.start()
  try:
   loader.deploy('integration_delivery_probe','probe-manifest.json','probe-sram')
   end=time.monotonic()+12
   while time.monotonic()<end:time.sleep(.1)
  finally:stop.set();thread.join(2)
 valid=invalid=0;observed={}
 for line in lines:
  if store.ingest(line):valid+=1;s=store.status();observed[s['last_chunk']]=s['applied']
  elif line.strip().startswith('A'):invalid+=1
 (private/'e046-integration-frames.txt').write_text(''.join(lines))
 assert store.status()['complete'],'Not all128 chunks received'
 assert invalid==0,'Malformed A packet'
 assert observed[0]['mapped_note']==31,'Mapping not applied'
 assert all(s['score_ready'] and s['score_length']==3 for s in observed.values()),'Score not committed'
 assert all(s['adsr_enabled'] and s['adsr_config'].upper()=='9CDA0' for s in observed.values()),'ADSR readback wrong'
 wav=store.wav();(private/'e046-integration.wav').write_bytes(wav)
 pcm=np.frombuffer(wav[44:],np.uint8).astype(float)-128
 assert max(abs(pcm))>0,'Recorded PCM contains no signal'
 report=dict(valid_packets=valid,invalid_record_packets=invalid,chunks=store.status()['chunks'],mapped_slot0=observed[0],all_applied_metadata_verified=True,pcm_peak=float(max(abs(pcm))),pcm_rms=float(np.sqrt(np.mean(pcm*pcm))),wav_sha256=hashlib.sha256(wav).hexdigest(),source_core_sha256=hashlib.sha256((root/'src/instrument_core.v').read_bytes()).hexdigest(),limitation='Injected commands, diagnostic USB UART; not actual ESP/Android/UI or physical latency acceptance')
 (out/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
finally:
 stop.set();loader.deploy('instrument_e045_ap','restore-manifest.json','restore-e045')
 for op,expected in [(73,b'0x0000E045'),(74,b'0x00006020')]:
  r=subprocess.run(loader.COMMON+['--operation_index',str(op)],capture_output=True,timeout=12);data=r.stdout+r.stderr;(out/('restore-read'+str(op)+'.txt')).write_bytes(data)
  if r.returncode or expected not in data:raise RuntimeError('Restore identity read failed')
 print('Restored full E045/E045+6020; Flash unchanged',flush=True)
