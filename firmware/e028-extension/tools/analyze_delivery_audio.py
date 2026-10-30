"""Reproducible physical recording analysis; never controls hardware."""
import argparse,csv,json,wave
from pathlib import Path
import numpy as np
from scipy.signal import find_peaks

def transition_windows(samples, rate, offset, slots=30):
 rows=[]
 for slot in range(slots):
  start=int((offset+slot*2)*rate);end=start+2*rate
  y=samples[max(start,0):min(end,len(samples))]
  steady=y[int(.35*rate):int(1.75*rate)]
  rows.append(dict(slot=slot,complete=start>=0 and end<=len(samples),
   peak=float(max(abs(y))) if len(y) else None,
   near_fullscale_samples=int(np.sum(abs(y)>=.99)),
   steady_near_fullscale_samples=int(np.sum(abs(steady)>=.99))))
 return rows

def main():
 p=argparse.ArgumentParser();p.add_argument('tag');a=p.parse_args()
 root=Path(__file__).resolve().parents[1];out=root/'docs'/a.tag;raw=Path('E:/gaoyun/private/esp-web')/a.tag
 report=json.loads((out/'report.json').read_text());rate=report['pc_sample_rate'];offset=report['sequence_offset_seconds']
 with wave.open(str(raw/'capture.wav')) as stream:x=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').astype(float)/32768
 windows=transition_windows(x,rate,offset)
 (out/'transition-windows.json').write_text(json.dumps(dict(windows=windows,
  complete=all(row['complete'] for row in windows),
  near_fullscale_samples=sum(row['near_fullscale_samples'] for row in windows),
  no_recording_overload=all(row['near_fullscale_samples']==0 for row in windows),
  limitation='Captures test-stimulus and PC-input overload; cannot alone assign distortion to production RTL.'),indent=2)+'\n',encoding='utf-8')
 def segment(slot,start=.35,duration=1.4):
  i=int((offset+slot*2+start)*rate);return x[i:i+int(duration*rate)]
 def spectrum(slot):
  y=segment(slot);return np.fft.rfftfreq(len(y),1/rate),abs(np.fft.rfft((y-y.mean())*np.hanning(len(y))))
 spectra={s:spectrum(s) for s in [0,24,25,26]};rows=[]
 for note in range(32):
  expected=130.81278265*2**(note/12);row=dict(note=note,expected_hz=expected)
  for slot,name in [(24,'all32'),(25,'upper16'),(26,'lower16')]:
   f,z=spectra[slot];indices=np.where(abs(f-expected)<2)[0];k=int(indices[np.argmax(z[indices])]);noise=np.median(z[(abs(f-expected)>3)&(abs(f-expected)<6)])
   row[name+'_peak_hz']=float(f[k]);row[name+'_local_snr_db']=float(20*np.log10(max(float(z[k]),1e-20)/max(float(noise),1e-20)))
   row[name+'_is_local_max']=bool(k>0 and k<len(z)-1 and z[k]>z[k-1] and z[k]>z[k+1])
  rows.append(row)
 with (out/'frequency-peaks.csv').open('w',newline='') as stream:w=csv.DictWriter(stream,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
 # Preserve relative captured gain. No per-timbre normalization hides volume differences.
 audition=np.concatenate([np.concatenate([segment(s,.02,1.8),np.zeros(int(.3*rate))]) for s in [1,3,5,7]])
 with wave.open(str(raw/'four-dry-timbres.wav'),'wb') as stream:stream.setparams((1,2,rate,0,'NONE','not compressed'));stream.writeframes((np.clip(audition,-1,1)*32767).astype('<i2').tobytes())
 records={r['slot']:r for r in report['records']}
 summary=dict(all32_local_peaks_over10db=sum(r['all32_is_local_max'] and r['all32_local_snr_db']>=10 for r in rows),minimum_local_snr_db=min(r['all32_local_snr_db'] for r in rows),volume80_minus160_db=records[10]['rms_dbfs']-records[9]['rms_dbfs'],volume40_minus160_db=records[11]['rms_dbfs']-records[9]['rms_dbfs'],restored160_minus_initial_db=records[13]['rms_dbfs']-records[9]['rms_dbfs'],chorus_minus_dry_db=records[16]['rms_dbfs']-records[15]['rms_dbfs'],bass_minus_strings_db=records[7]['rms_dbfs']-records[5]['rms_dbfs'],note='Local spectral peaks plus UART voice counts support this diagnostic capture; shared harmonics and PC processing mean this is not standalone proof of32 independently audible voices or electrical DAC rate')
 (out/'analysis-summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
