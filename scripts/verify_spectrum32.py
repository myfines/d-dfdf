"""Validate simulated sample spectra; this is not an analog DAC measurement."""
import argparse, json
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser()
p.add_argument("samples",type=Path)
p.add_argument("--output",type=Path,required=True)
a=p.parse_args()
x=np.loadtxt(a.samples);fs=46875.0
assert len(x)>=8192, "Insufficient sample window"
y=np.abs(np.fft.rfft((x-x.mean())*np.hanning(len(x))))
f=np.fft.rfftfreq(len(x),1/fs)
rows=[]
for expected in range(129,1091,31):
 mask=np.flatnonzero(abs(f-expected)<=fs/len(x))
 i=int(mask[np.argmax(y[mask])])
 assert 0<i<len(y)-1 and y[i]>y[i-1] and y[i]>y[i+1], f"Missing independent peak {expected} Hz"
 assert y[i]>10000, f"Weak peak {expected} Hz"
 rows.append({"expected_hz":expected,"observed_bin_hz":float(f[i]),"magnitude":float(y[i])})
assert len(rows)==32 and len({r["observed_bin_hz"] for r in rows})==32
result={"source":"RTL simulation, not hardware measurement","sample_rate_hz":fs,"sample_count":len(x),"independent_peaks":32,"max_bin_error_hz":max(abs(r["expected_hz"]-r["observed_bin_hz"]) for r in rows),"peak_sample":float(max(abs(x))),"peaks":rows}
a.output.write_text(json.dumps(result,indent=2),encoding="utf-8")
print("PASS spectrum: 32 separate simulated fundamentals; max bin error",round(result["max_bin_error_hz"],3),"Hz")
