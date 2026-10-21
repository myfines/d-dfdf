"""Build a standalone candidate on the PC; never open or write a board."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def build(output):
    sender=(ROOT/'k230/usb_gesture_sender.py').read_text(encoding='utf-8')
    imports=('from gesture_protocol import encode\n','from usb_gesture_state import gesture_fields, FRESH_MS\n')
    for line in imports:
        if sender.count(line)!=1:raise RuntimeError('Unexpected sender imports')
        sender=sender.replace(line,'')
    parts=[(ROOT/'k230'/name).read_text(encoding='utf-8') for name in ('gesture_protocol.py','usb_gesture_state.py')]
    data=('# Generated candidate. NOT deployed. Exclusive CDC only.\n'+'\n'.join(parts+[sender])).encode()
    compile(data,str(output),'exec')
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_bytes(data)
    manifest={'candidate':str(output),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
              'deployed':False,'source_sha256':{name:hashlib.sha256((ROOT/'k230'/name).read_bytes()).hexdigest() for name in ('gesture_protocol.py','usb_gesture_state.py','usb_gesture_sender.py')}}
    output.with_suffix('.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    return manifest

if __name__=='__main__':
    print(json.dumps(build(ROOT/'build/k230/usb_gesture_sender_standalone.py'),indent=2))
