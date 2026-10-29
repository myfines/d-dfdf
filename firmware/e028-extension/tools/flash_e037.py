"""Explicit authorized E037 Flash program+verify, fixed hash and identity checks."""
import subprocess,json,hashlib,time
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'docs/e037-regression'
private=Path('E:/gaoyun/private/esp-web');fs=private/'build/instrument_e037/impl/pnr/instrument_e037.fs'
expected=json.loads((out/'build-manifest.json').read_text())['artifact_sha256']
if hashlib.sha256(fs.read_bytes()).hexdigest()!=expected:raise RuntimeError('Bitstream hash mismatch')
cli='E:/gaoyun/tools/gowin/programmer1.9.11.03Education(2536).Win64/Programmer/bin/programmer_cli.exe'
common=[cli,'--device','GW2A-18C','--cable-index','1','--frequency','2.5MHz']
def run(args,name,timeout):
 t=time.monotonic()
 try:r=subprocess.run(common+args,capture_output=True,timeout=timeout)
 except subprocess.TimeoutExpired as e:
  (out/name).write_bytes((e.stdout or b'')+(e.stderr or b''));raise RuntimeError('Programmer timed out; no success claimed')
 raw=r.stdout+r.stderr;(out/name).write_bytes(raw)
 if r.returncode:raise RuntimeError('Programmer failed; inspect '+name)
 return raw,time.monotonic()-t
raw,_=run(['--scan'],'20261029-Flash-scan.log',12)
if b'0x0000081B' not in raw.upper().replace(b'0X',b'0x'):raise RuntimeError('Unexpected JTAG identity')
print('Identity and fixed hash verified; starting GAO-Bridge operation37',flush=True)
raw,seconds=run(['--operation_index','37','--spiaddr','0x000000','--fsFile',str(fs)],'20261029-Flash.log',60)
if b'successfully' not in raw.lower() or b'100%' not in raw:raise RuntimeError('Explicit Flash verification success absent')
summary=dict(version='E037',operation=37,frequency='2.5MHz',spi_address=0,sha256=expected,program_verify_success=True,duration_seconds=seconds,independent_boot_confirmed=False,coldboot_tested=False,real_wifi_acceptance=False)
(out/'flash-result.json').write_text(json.dumps(summary,indent=2))
for op,version in [(73,b'0x0000E037'),(74,b'0x00006020')]:
 raw,_=run(['--operation_index',str(op)],f'20261029-Flash-read{op}.log',12)
 if version not in raw:raise RuntimeError('Independent postwrite read mismatch')
summary.update(usercode='E037',status='6020',independent_boot_confirmed=True)
(out/'flash-result.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary),flush=True)
