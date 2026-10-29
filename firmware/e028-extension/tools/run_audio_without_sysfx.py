"""Temporarily disable Windows recording system effects via documented endpoint
property, run the bounded capture, then restore the exact previous property.
"""
import ctypes,json,subprocess,sys
from pathlib import Path
from comtypes import GUID
from pycaw.pycaw import AudioUtilities
from pycaw.api.mmdeviceapi.depend.structures import PROPERTYKEY,PROPVARIANT

root=Path(__file__).resolve().parents[1]
out=root/'docs/e044-no-sysfx';out.mkdir(exist_ok=True)
mic=AudioUtilities.GetMicrophone();store=mic.OpenPropertyStore(2)
key=PROPERTYKEY(GUID('{1da5d803-d492-4edd-8c23-e0c0ffee7f0e}'),5)
old=store.GetValue(ctypes.byref(key))
if old.vt not in [0,19]:raise RuntimeError('unexpected original property type; do not modify')
snapshot=dict(endpoint=mic.GetId(),original_vt=old.vt,original_value=old.union.lVal if old.vt==19 else None)
(out/'endpoint-property.json').write_text(json.dumps(snapshot,indent=2))
value=PROPVARIANT();value.vt=19;value.union.lVal=1
try:
    store.SetValue(ctypes.byref(key),ctypes.byref(value));store.Commit()
    current=store.GetValue(ctypes.byref(key));snapshot['temporary_value']=current.GetValue()
    (out/'endpoint-property.json').write_text(json.dumps(snapshot,indent=2))
    print('Disable_SysFx temporary readback:',current.GetValue(),flush=True)
    if current.vt!=19 or current.GetValue()!=1:raise RuntimeError('system effect property not applied')
    r=subprocess.run([sys.executable,str(root/'tools/run_delivery_audio_probe.py'),'--project','audio_delivery_probe_gain4','--code','E044','--attenuation','4','--device','1','--tag','e044-no-sysfx'],timeout=120)
    if r.returncode:raise RuntimeError('capture failed '+str(r.returncode))
finally:
    store.SetValue(ctypes.byref(key),ctypes.byref(old));store.Commit()
    restored=store.GetValue(ctypes.byref(key));snapshot['restored_vt']=restored.vt;snapshot['restored_value']=restored.GetValue() if restored.vt==19 else None
    (out/'endpoint-property.json').write_text(json.dumps(snapshot,indent=2))
    if restored.vt!=old.vt or (old.vt==19 and restored.GetValue()!=old.GetValue()):raise RuntimeError('endpoint property restore failed')
    print('Original recording endpoint property restored',flush=True)
