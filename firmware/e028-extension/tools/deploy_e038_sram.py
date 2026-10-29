from pathlib import Path
import subprocess
import run_autonomous_probe as loader
loader.OUT=Path(__file__).resolve().parents[1]/'docs/e038-regression'
try:
 loader.deploy('instrument_e038','build-manifest.json','20261029-E038-SRAM')
 for op,expected in [(73,b'0x0000E038'),(74,b'0x00006020')]:
  r=subprocess.run(loader.COMMON+['--operation_index',str(op)],capture_output=True,timeout=12);raw=r.stdout+r.stderr
  (loader.OUT/f'20261029-E038-read{op}.log').write_bytes(raw)
  if r.returncode or expected not in raw:raise RuntimeError('E038 independent read failed')
 print('E038 SRAM and independent E038/6020 confirmed; Flash E037 unchanged')
except Exception:
 loader.OUT=loader.OUT.parent/'e037-regression';loader.deploy('instrument_e037','build-manifest.json','20261029-fallback-E037');raise
