"""Relative acoustic envelope estimates; not input latency or calibrated ADSR metrology."""
import json,math,statistics
from pathlib import Path

def transition_interval(curve,start,end,rising,bin_seconds=.02):
 if abs(end-start)<1e-12:return None
 # Rising normalization0->1 or falling1->0, with independent references.
 normalized=[(v-start)/(end-start) if rising else (v-end)/(start-end) for v in curve]
 if rising:
  first=next((i for i,v in enumerate(normalized) if v>=.1),None)
  last=next((i for i,v in enumerate(normalized) if v>=.9),None)
 else:
  first=next((i for i,v in enumerate(normalized) if v<=.9),None)
  last=next((i for i,v in enumerate(normalized) if v<=.1),None)
 return None if first is None or last is None or last<first else (last-first)*bin_seconds

def main():
 out=Path(__file__).resolve().parents[1]/'docs/e035-regression'
 rows=json.loads((out/'adsr-envelope-curves.json').read_text())
 curves={r['label']:r['rms_20ms'] for r in rows}
 noise=statistics.median(curves['idle-final'][25:90])
 def signal(label):return [math.sqrt(max(v*v-noise*noise,0)) for v in curves[label]]
 def steady(label):return statistics.median(signal(label)[50:90])
 estimates={}
 for label in ['attack-fast','attack-slow']:
  curve=signal(label);reference=statistics.median(curve[50:90])
  estimates[label]=transition_interval(curve,0,reference,True)
 for label in ['decay-fast','decay-slow']:
  curve=signal(label);estimates[label]=transition_interval(curve,max(curve[:5]),statistics.median(curve[50:90]),False)
 for held,tail in [('release-short-held','release-short-tail'),('release-long-held','release-long-tail')]:
  estimates[tail]=transition_interval(signal(tail),steady(held),0,False)
 low,high=steady('sustain-low'),steady('sustain-high')
 ratio=high/low if low>0 else None
 report=dict(bin_seconds=.02,transition_definition='10->90% rise or90->10% fall of RMS envelope; zero means unresolved within20ms bin',
             interval_seconds=estimates,sustain_high_to_low_ratio=ratio,
             sustain_ratio_db=20*math.log10(ratio) if ratio else None,expected_sustain_ratio=3,
             expected_slow_attack_10_90_seconds=.8*65535/2/46875,
             expected_slow_decay_90_10_seconds=.8*(65535-64*257)/2/46875,
             expected_slow_release_90_10_seconds=.8*(128*257)/2/46875,
             limitation='Relative acoustic observation.20ms bins, noise, mic AGC and phase may bias estimates; not total physical ADSR stage times or control-to-output latency.')
 (out/'adsr-acoustic-analysis.json').write_text(json.dumps(report,indent=2))
 print(json.dumps(report,indent=2))

if __name__=='__main__':main()
