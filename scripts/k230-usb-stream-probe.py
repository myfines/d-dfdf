"""Temporary RAM-only CDC test. Requires IDE closed. Never sends USBDBG commands."""
import argparse
import json
import pathlib
import re
import sys
import time
import serial

ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'k230'))
from usb_stream import FrameStream

def collect(s,seconds):
    data=bytearray();end=time.monotonic()+seconds
    while time.monotonic()<end: data.extend(s.read(4096))
    return bytes(data)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--port',default='COM9');ap.add_argument('--source');ap.add_argument('--gesture',action='store_true');ap.add_argument('--frames',type=int,default=300);ap.add_argument('--duration',type=float,default=7);ap.add_argument('--name',default='synthetic');ap.add_argument('--baud',type=int,default=12000000)
    args=ap.parse_args();logs=ROOT/'logs/20261021-k230-usb';logs.mkdir(exist_ok=True)
    codec=(ROOT/'k230/gesture_protocol.py').read_text()
    code=codec+"""
import usb,time
u=usb.Serial('/dev/ttyGS0')
if not u.open(): raise RuntimeError('ttyGS0 open failed')
print('BINARY_TEST_BEGIN')
time.sleep_ms(500)
for seq in range(40):
 packet=encode(seq,True,seq*25,1000-seq*25,95)
 n=u.write(packet)
 if n!=12: raise RuntimeError('short write '+str(n))
 time.sleep_ms(50)
u.close()
print('BINARY_TEST_END')
"""
    if args.source: code=pathlib.Path(args.source).read_text(encoding='utf-8-sig')
    if args.gesture:
        code=codec+'\n'+(ROOT/'k230/usb_gesture_state.py').read_text()+'\n'+(ROOT/'k230/usb_gesture_preview_probe.py').read_text()
        code=code.replace('range(300)','range(%d)' % args.frames)
    with serial.Serial(args.port,args.baud,timeout=.1) as s:
        s.dtr=True
        initial=collect(s,1)
        s.write(b'\x03\r\n');initial+=collect(s,1)
        # Verify actual output, not just the echoed command, before binary execution.
        s.write(b"print('RAW_'+'PROBE_OK')\r\n")
        initial+=collect(s,1)
        (logs/(args.name+'-handshake.bin')).write_bytes(initial)
        if b'RAW_PROBE_OK' not in initial or b'>>> ' not in initial:
            raise RuntimeError('REPL mode not proven; binary test refused')
        s.write(b'\x01');raw_banner=collect(s,.5)
        if b'raw REPL' not in raw_banner or not raw_banner.rstrip().endswith(b'>'):
            raise RuntimeError('Raw REPL handshake failed: '+repr(raw_banner))
        program=code.encode()
        for i in range(0,len(program),128):
            s.write(program[i:i+128]);s.flush();time.sleep(.01)
        s.write(b'\x04');s.flush()
        raw=collect(s,args.duration)
        s.write(b'\x02')
    (logs/(args.name+'-capture.bin')).write_bytes(raw)
    # Echo contains backslash escapes, not actual BEGIN newline; match the emitted line.
    begin=re.search(rb'BINARY_TEST_BEGIN\r+\n',raw)
    end=raw.find(b'BINARY_TEST_END\r',begin.end() if begin else 0)
    if begin is None or end<0:
        print('capture_bytes',len(raw),'begin_found',begin is not None,'trailer',repr(raw[-100:]));raise RuntimeError('Missing bounded stream markers')
    payload=raw[begin.end():end]
    parser=FrameStream();frames=[]
    # Deliberately feed boundaries unrelated to USB or frame boundaries.
    for i in range(0,len(payload),17): frames.extend(parser.feed(payload[i:i+17]))
    gaps=[(a['seq'],b['seq']) for a,b in zip(frames,frames[1:]) if b['seq']!=((a['seq']+1)&255)]
    summary=dict(frames=len(frames),valid_frames=sum(f['valid'] for f in frames),crc_errors=parser.crc_errors,field_errors=parser.field_errors,discarded=parser.discarded,trailing=len(parser.buffer),sequence_gaps=gaps,bytes=len(payload),first=frames[:3],last=frames[-2:])
    stats=re.search(rb'USB_SEND_STATS (\d+) (\d+) (\d+)',raw[end:])
    if stats:
        sent,elapsed,late=map(int,stats.groups())
        summary.update(sender_elapsed_ms=elapsed,sender_late_reschedules=late,effective_hz=(sent-1)*1000/elapsed if elapsed else None)
    (logs/(args.name+'-frames.json')).write_text(json.dumps(dict(summary=summary,frames=frames),indent=2),encoding='utf-8')
    print(json.dumps(summary,indent=2))
    if not frames or parser.crc_errors or parser.field_errors or gaps or parser.discarded or parser.buffer:
        raise RuntimeError('Stream validation failed')
    if len(frames)!=(args.frames if args.gesture else 40) and not args.source: raise RuntimeError('Unexpected frame count')

if __name__=='__main__':main()
