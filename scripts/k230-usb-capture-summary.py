"""Offline verification of captured raw CDC bytes; never opens a USB device."""
import json
from pathlib import Path
import re
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'k230'))
from usb_stream import FrameStream

def analyze(path):
    raw=path.read_bytes()
    begin=re.search(rb'BINARY_TEST_BEGIN\r+\n',raw)
    end=raw.find(b'BINARY_TEST_END\r',begin.end() if begin else 0)
    if begin is None: return {'file':path.name,'error':'no begin marker'}
    parser=FrameStream()
    payload=raw[begin.end():end if end>=0 else len(raw)]
    frames=[]
    for i in range(0,len(payload),17):frames.extend(parser.feed(payload[i:i+17]))
    valid=[f for f in frames if f['valid']]
    stats=re.search(rb'USB_SEND_STATS (\d+) (\d+) (\d+)',raw[end:]) if end>=0 else None
    result=dict(file=path.name,complete=end>=0,bytes=len(payload),frames=len(frames),valid_frames=len(valid),
                crc_errors=parser.crc_errors,field_errors=parser.field_errors,discarded=parser.discarded,trailing=len(parser.buffer),
                sequence_gaps=sum(b['seq']!=((a['seq']+1)&255) for a,b in zip(frames,frames[1:])),
                invalid_zero=all(f['pinch']==f['y']==f['confidence']==0 for f in frames if not f['valid']),
                valid_confidence_ge60=sum(f['confidence']>=60 for f in valid),
                valid_ranges={k:[min(f[k] for f in valid),max(f[k] for f in valid)] for k in ('pinch','y','confidence')} if valid else {},
                first=frames[:3],last=frames[-2:])
    if stats:
        n,elapsed,late=map(int,stats.groups())
        result.update(sender_elapsed_ms=elapsed,effective_hz=(n-1)*1000/elapsed if elapsed else None,late_reschedules=late)
    return result

if __name__=='__main__':
    logs=ROOT/'logs/20261021-k230-usb'
    results=[analyze(p) for p in sorted(logs.glob('*-capture.bin'))]
    (logs/'capture-summary.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    for r in results:print(json.dumps({k:v for k,v in r.items() if k not in ('first','last','valid_ranges')},ensure_ascii=True))
