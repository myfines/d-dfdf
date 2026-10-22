"""Build a standalone UART candidate on the PC; never access connected devices."""
import ast
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def build(output):
    shared=(ROOT/'k230/usb_gesture_sender.py').read_text(encoding='utf-8')
    wanted={'MIN_CONFIDENCE','V2_SHA256','PacketState','write_frame'}
    pieces=[];found=set()
    for node in ast.parse(shared).body:
        name=None
        if isinstance(node,(ast.ClassDef,ast.FunctionDef)):name=node.name
        elif isinstance(node,ast.Assign) and len(node.targets)==1 and isinstance(node.targets[0],ast.Name):name=node.targets[0].id
        if name in wanted:
            pieces.append(ast.get_source_segment(shared,node));found.add(name)
    if found!=wanted:raise RuntimeError('Shared sender definitions changed')
    uart=(ROOT/'k230/uart_gesture_sender.py').read_text(encoding='utf-8')
    line='from usb_gesture_sender import PacketState, write_frame, V2_SHA256\n'
    if uart.count(line)!=1:raise RuntimeError('Unexpected UART imports')
    uart=uart.replace(line,'')
    source=['# Generated UART candidate. NOT deployed.\n']
    source.extend((ROOT/'k230'/name).read_text(encoding='utf-8') for name in ('gesture_protocol.py','usb_gesture_state.py'))
    # Retain the tested shared algorithm, with transport-appropriate error labels.
    source.extend(part.replace('CDC write','UART write').replace('CDC write length','UART write length') for part in pieces)
    source.append(uart)
    data=('\n'.join(source)).encode()
    compile(data,str(output),'exec')
    output.parent.mkdir(parents=True,exist_ok=True);output.write_bytes(data)
    names=('gesture_protocol.py','usb_gesture_state.py','usb_gesture_sender.py','uart_gesture_sender.py')
    manifest=dict(candidate=str(output),bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),deployed=False,
                  uart=1,tx_gpio=9,rx_wired=False,baudrate=115200,bits=8,parity=None,stop=1,
                  source_sha256={name:hashlib.sha256((ROOT/'k230'/name).read_bytes()).hexdigest() for name in names})
    output.with_suffix('.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    return manifest

if __name__=='__main__':print(json.dumps(build(ROOT/'build/k230/uart_gesture_sender_standalone.py'),indent=2))
