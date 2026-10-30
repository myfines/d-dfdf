"""SRAM-only current-core diagnostic, real OLED I2C, then exact E049 restore.
Does not exercise the phone/ESP link or physical optical/gesture inputs.
"""
import hashlib,json,subprocess,time
from pathlib import Path
import serial
from recording_store import RecordingStore

ROOT=Path(__file__).resolve().parents[1]
PRIVATE=Path('E:/gaoyun/private/esp-web')
OUT=ROOT/'docs/e050-integration'
COMMON=['E:/gaoyun/tools/gowin/programmer1.9.11.03Education(2536).Win64/Programmer/bin/programmer_cli.exe',
        '--device','GW2A-18C','--cable-index','1','--frequency','2.5MHz']
RESTORE=PRIVATE/'build/instrument_e049_ap/impl/pnr/instrument_e049_ap.fs'
PROBE=PRIVATE/'build/oled_integration_e050/impl/pnr/oled_integration_e050.fs'
RESTORE_SHA='e9148e835c0dc08b764a16039bb6696e025b285967bbf6f4129d96d5175a6790'

def operation(args,name):
 r=subprocess.run(COMMON+args,capture_output=True,timeout=40)
 raw=r.stdout+r.stderr;(OUT/name).write_bytes(raw)
 if r.returncode or b'Error:' in raw:raise RuntimeError('Programmer failed: '+name)
 return raw

def deploy(path,sha,name):
 if hashlib.sha256(path.read_bytes()).hexdigest()!=sha:raise RuntimeError('Bitstream hash mismatch: '+str(path))
 raw=operation(['--operation_index','2','--fsFile',str(path)],name)
 if b'100%' not in raw:raise RuntimeError('No completed SRAM programming: '+name)

def main():
 OUT.mkdir(exist_ok=True)
 build=json.loads((OUT/'probe-build.json').read_text(encoding='utf-8'))
 expected=build['artifact_sha256']
 if hashlib.sha256((ROOT/'src/instrument_core.v').read_bytes()).hexdigest()!=build['source_core_sha256']:raise RuntimeError('Production source changed since probe build')
 if hashlib.sha256(RESTORE.read_bytes()).hexdigest()!=RESTORE_SHA:raise RuntimeError('Restore artifact mismatch')
 scan=operation(['--scan'],'scan.log')
 if b'0x0000081B' not in scan or b'1 device(s) found' not in scan:raise RuntimeError('Unexpected device identity')
 lines=[];report={};store=RecordingStore();observed={};debug=[];invalid=0
 try:
  with serial.Serial('COM13',115200,timeout=.1) as port:
   deploy(PROBE,expected,'probe-sram.log')
   end=time.monotonic()+12
   while time.monotonic()<end:
    line=port.readline(192).decode('ascii',errors='replace');lines.append(line)
  (PRIVATE/'e050-integration-frames.txt').write_text(''.join(lines),encoding='utf-8')
  for line in lines:
   text=line.strip()
   if store.ingest(text):observed[store.last_chunk]=dict(store.metadata)
   elif text.startswith('A'):invalid+=1
   elif text.startswith('Z'):
    if len(text)!=17:raise RuntimeError('Malformed OLED diagnostic line')
    state=list(bytes.fromhex(text[1:]));debug.append(state)
  report.update(valid_A_packets=sum(x.startswith('A') for x in lines)-invalid,invalid_A_packets=invalid,
   chunks=len(store.chunks),OLED_status_packets=len(debug),OLED_ack_online=any(x[1]==1 for x in debug),
   source_core_sha256=hashlib.sha256((ROOT/'src/instrument_core.v').read_bytes()).hexdigest(),
   limitation='Injected SRAM diagnostic commands; OLED-online is I2C ACK evidence, not visual inspection. No phone/ESP, optical gesture, cold boot, analog audio or physical latency acceptance.')
  mapping=list(range(32));mapping[0]=31;rest=bank1=lit=0
  for version,online,screen,flags,note,bank,target,suggested in debug:
   assert version==0x50 and online<=1 and screen==3 and flags<=3 and note<32 and bank<4
   matches=[i for i,v in enumerate(mapping) if flags==3 and v==note]
   expected_target=sum(1<<(i%8) for i in matches if i//8==bank)
   expected_bank=bank if expected_target or not matches else matches[0]//8
   assert target==expected_target and suggested==expected_bank,'OLED mapping/bank mismatch'
   rest+=flags==1;bank1+=bank==1;lit+=target!=0
  report.update(rest_snapshots=rest,bank2_snapshots=bank1,target_snapshots=lit,OLED_mapping_reference_passed=True)
  assert store.status()['complete'] and invalid==0,'Recording transport incomplete/malformed'
  assert observed[0]['mapped_note']==31,'Keymap readback failed'
  assert all(m['score_ready'] and m['score_length']==3 and m['adsr_enabled'] and m['adsr_config'].upper()=='9CDA0' for m in observed.values()),'Applied score/ADSR metadata failed'
  wav=store.wav();pcm=[int(v)-128 for v in wav[44:]]
  assert max(map(abs,pcm))>0,'PCM has no signal'
  (PRIVATE/'e050-integration.wav').write_bytes(wav)
  report.update(pcm_peak=max(map(abs,pcm)),wav_sha256=hashlib.sha256(wav).hexdigest(),applied_metadata_verified=True)
  assert debug and rest and bank1 and lit,'Missing guide scenarios'
  assert report['OLED_ack_online'],'OLED did not ACK: inspect power/wiring'
  report['passed']=True
 except Exception as error:
  report.update(passed=False,error=str(error));raise
 finally:
  (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
  deploy(RESTORE,RESTORE_SHA,'restore-e049.log')
  for op,expected_read in [(73,b'0x0000E049'),(74,b'0x00006020')]:
   raw=operation(['--operation_index',str(op)],'restore-read'+str(op)+'.log')
   if expected_read not in raw:raise RuntimeError('Restore identity mismatch')
  report['restored_E049_6020']=True
  (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
  print(json.dumps(report),flush=True)

if __name__=='__main__':main()
