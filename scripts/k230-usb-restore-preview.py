"""Resume existing SD main via plain raw REPL; no persistent board writes."""
import serial
import time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
LOG=ROOT/'logs/20261021-k230-usb/restore-preview.bin'
CODE="""import os,uhashlib,ubinascii
for p in ['/sdcard/main.py','/sdcard/pinch_preview_v2.py','/sdcard/main_electronic_contest_backup_20261020.py','/sdcard/main_before_pinch_v2_20261021.py','/sdcard/boot.py','/sdcard/kmodel/hand_det.kmodel','/sdcard/kmodel/handkp_det.kmodel']:
 h=uhashlib.sha256()
 with open(p,'rb') as f:
  while True:
   b=f.read(4096)
   if not b:break
   h.update(b)
 print('RETAINED',p,os.stat(p)[6],ubinascii.hexlify(h.digest()).decode())
with open('/sdcard/main.py') as f: launcher=f.read()
print('RESTORE_MAIN',launcher)
exec(compile(launcher,'/sdcard/main.py','exec'))
"""

def collect(s,seconds):
    out=bytearray();end=time.monotonic()+seconds
    while time.monotonic()<end:out.extend(s.read(4096))
    return bytes(out)

def main():
    LOG.parent.mkdir(parents=True,exist_ok=True)
    with serial.Serial('COM9',12000000,timeout=.1) as s:
        s.dtr=True
        s.write(b'\x03\x02\r\n');prior=collect(s,1)
        s.write(b'\x01');banner=collect(s,.5)
        if b'raw REPL' not in banner:raise RuntimeError(repr(banner))
        data=CODE.encode()
        for i in range(0,len(data),128):
            s.write(data[i:i+128]);s.flush();time.sleep(.01)
        s.write(b'\x04');s.flush()
        result=collect(s,16)
    LOG.write_bytes(prior+banner+result)
    if b'PINCH2,' not in result or b'Traceback' in result:
        raise RuntimeError('Preview startup not verified; inspect saved log before retrying')
    print('Original main preview resumed; PINCH2 lines:',result.count(b'PINCH2,'))

if __name__=='__main__':main()
