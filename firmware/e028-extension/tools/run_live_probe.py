"""Bounded real-input observation. SRAM only; restore E049 in finally."""
import argparse
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path
import serial

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = Path('E:/gaoyun/private/esp-web')
RESTORE_SHA = 'e9148e835c0dc08b764a16039bb6696e025b285967bbf6f4129d96d5175a6790'
CLI = 'E:/gaoyun/tools/gowin/programmer1.9.11.03Education(2536).Win64/Programmer/bin/programmer_cli.exe'
COMMON = [CLI, '--device', 'GW2A-18C', '--cable-index', '1', '--frequency', '2.5MHz']


def decode(text):
    match = re.fullmatch(r'Z([0-9A-F]{16})', text.strip())
    if not match:
        return None
    b = bytes.fromhex(match[1])
    kind = b[0]
    if kind not in range(0xE0, 0xE8):
        return None
    row = {'kind': hex(kind), 'hex': match[1]}
    if kind == 0xE0:
        for bit, name in enumerate(['gesture_active', 'oled_online', 'optical_error', 'optical_valid', 'adc_error', 'adc_valid', 'remote_active', 'armed']):
            row[name] = bool(b[1] & (1 << bit))
        row.update(axis_x=int.from_bytes(b[2:4], 'big'), axis_y=int.from_bytes(b[4:6], 'big'), optical_raw=b[6], panel_keys_n=b[7])
    elif kind == 0xE1:
        row.update(sequence=b[1], confidence=b[2], pinch=int.from_bytes(b[3:5], 'big'), height=int.from_bytes(b[5:7], 'big'), gesture_gain=b[7])
    elif kind == 0xE2:
        bend=int.from_bytes(b[5:7], 'big')
        row.update(expression=b[1], brightness=b[2], remote_volume=b[3], vibrato=b[4], bend=bend-16384 if bend & 8192 else bend, brightness_owned=bool(b[7] & 2), bend_owned=bool(b[7] & 1))
    elif kind == 0xE3:
        row.update(gate_mask=int.from_bytes(b[1:5], 'big'), voices=b[5], screen=b[6], effects=b[7])
    elif kind == 0xE4:
        row.update(command_count=int.from_bytes(b[1:3], 'big'), last_raw_kind=b[3], last_raw_value=int.from_bytes(b[4:8], 'big'))
    elif kind == 0xE5:
        row.update(left=int.from_bytes(b[1:3], 'big', signed=True), right=int.from_bytes(b[3:5], 'big', signed=True), voices=b[5], page=b[6], led=b[7])
    return row


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--seconds', type=int, default=90)
    args=parser.parse_args()
    if not 10 <= args.seconds <= 300:
        parser.error('seconds must be 10..300')
    out=ROOT/'docs/full-system-live-20261030'
    out.mkdir(exist_ok=True)
    probe=PRIVATE/'build/live_observer_e051/impl/pnr/live_observer_e051.fs'
    restore=PRIVATE/'build/instrument_e049_ap/impl/pnr/instrument_e049_ap.fs'
    manifest=json.loads((out/'build.json').read_text(encoding='utf-8'))
    for path, expected in [(probe, manifest['artifact_sha256']), (restore, RESTORE_SHA), (ROOT/'src/instrument_core.v', manifest['source_core_sha256'])]:
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError('preflight hash mismatch: '+str(path))

    def operation(arguments, name):
        result=subprocess.run(COMMON+arguments, capture_output=True, timeout=40)
        raw=result.stdout+result.stderr
        (out/name).write_bytes(raw)
        if result.returncode or b'Error:' in raw:
            raise RuntimeError('programmer failed: '+name)
        return raw

    def deploy(path, name):
        raw=operation(['--operation_index','2','--fsFile',str(path)],name)
        if b'100%' not in raw:
            raise RuntimeError('SRAM download incomplete: '+name)

    scan=operation(['--scan'],'scan.log')
    if b'0x0000081B' not in scan or b'1 device(s) found' not in scan:
        raise RuntimeError('unexpected device')
    rows=[]
    raw=bytearray()
    report={'seconds':args.seconds,'limitation':'Real inputs retained; periodic snapshots are not a lossless event trace, physical latency measurement or visual display inspection.'}
    try:
        stream=serial.Serial()
        stream.port='COM13';stream.baudrate=115200;stream.timeout=.1;stream.dtr=False;stream.rts=False
        with stream:
            deploy(probe,'probe-sram.log')
            print('E051 live observer running; enable peripherals once, then operate real inputs.',flush=True)
            start=time.monotonic()
            while time.monotonic()-start < args.seconds:
                line=stream.readline(256)
                raw.extend(line)
                row=decode(line.decode('ascii',errors='replace'))
                if row:
                    row['host_seconds']=time.monotonic()-start
                    rows.append(row)
        report.update(snapshots=len(rows),armed_seen=any(r.get('armed') for r in rows),oled_ack_seen=any(r.get('oled_online') for r in rows),optical_valid_seen=any(r.get('optical_valid') for r in rows),adc_valid_seen=any(r.get('adc_valid') for r in rows),gesture_seen=any(r.get('gesture_active') for r in rows),remote_seen=any(r.get('remote_active') for r in rows))
        if not rows:
            raise RuntimeError('no live observations')
    finally:
        (PRIVATE/'full-system-live-20261030-uart.txt').write_bytes(raw)
        (out/'snapshots.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
        deploy(restore,'restore-e049.log')
        for op, expected in [(73,b'0x0000E049'),(74,b'0x00006020')]:
            if expected not in operation(['--operation_index',str(op)],'restore-read'+str(op)+'.log'):
                raise RuntimeError('restore identity mismatch')
        report['restored_E049_6020']=True
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report),flush=True)


if __name__ == '__main__':
    main()
