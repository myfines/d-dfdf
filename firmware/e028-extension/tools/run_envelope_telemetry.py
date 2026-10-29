"""Read-only diagnostic UART capture, bounded SRAM-only probe, guaranteed restore attempt."""
import json,time,subprocess,hashlib
from pathlib import Path
import serial,serial.tools.list_ports
import run_autonomous_probe as loader
root=Path(__file__).resolve().parents[1]
loader.OUT=root/'docs/e035-regression'
private=Path('E:/gaoyun/private/esp-web')
ports=[p for p in serial.tools.list_ports.comports() if p.vid==0x0403 and p.pid==0x6010]
if len(ports)!=1:raise RuntimeError('Expected exactly one known FTDI serial port')
port=ports[0].device
rows=[];buffer=bytearray();bad=0
try:
 loader.deploy('audio_adsr_uart','probe-adsr-uart-manifest.json','20261029-envelope-uart-SRAM')
 with serial.Serial(port,115200,timeout=.2) as stream:
  started=time.monotonic()
  while time.monotonic()-started<39:
   buffer.extend(stream.read(512))
   while len(buffer)>=6:
    if buffer[0]!=0xA5:del buffer[0];continue
    packet=buffer[:6]
    if packet[0]^packet[1]^packet[2]^packet[3]^packet[4]!=packet[5]:
     bad+=1;del buffer[0];continue
    del buffer[:6]
    rows.append(dict(seconds=time.monotonic()-started,slot=packet[1],level=packet[2]*256+packet[3],state=packet[4]))
 (loader.OUT/'adsr-board-telemetry.json').write_text(json.dumps(dict(port=port,bad_checksum=bad,records=rows),indent=2))
 print('valid packets',len(rows),'checksum failures',bad,flush=True)
 if not rows:raise RuntimeError('No valid telemetry; reject test')
 for slot in [9,11,15,16]:
  levels=[r['level'] for r in rows if r['slot']==slot]
  print('slot',slot,'count',len(levels),'first',levels[:3],'last',levels[-3:],flush=True)
finally:
 loader.deploy('instrument_e035','build-manifest.json','20261029-uart-restore-E035')
 for op,expected in [(73,b'0x0000E035'),(74,b'0x00006020')]:
  r=subprocess.run(loader.COMMON+['--operation_index',str(op)],capture_output=True,timeout=12)
  raw=r.stdout+r.stderr
  (loader.OUT/f'20261029-uart-restore-read{op}.log').write_bytes(raw)
  if r.returncode or expected not in raw:raise RuntimeError('Restore independent read failed')
 print('Restored E035/6020; Flash unchanged',flush=True)
