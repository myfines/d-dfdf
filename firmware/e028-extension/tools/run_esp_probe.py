"""AT-only physical UART diagnostics; restore E049."""
import hashlib
import json
import re
import time
import argparse
from pathlib import Path
import serial
import run_e050_probe as transport


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--initializer',action='store_true');args=parser.parse_args()
    out=transport.ROOT/('docs/full-system-esp-init-20261030' if args.initializer else 'docs/full-system-esp-20261030')
    out.mkdir(exist_ok=True)
    transport.OUT=out
    probe=transport.PRIVATE/'build/esp_diagnostic_e052/impl/pnr/esp_diagnostic_e052.fs'
    manifest=json.loads((out/'build.json').read_text(encoding='utf-8'))
    if hashlib.sha256(transport.RESTORE.read_bytes()).hexdigest()!=transport.RESTORE_SHA:
        raise RuntimeError('restore artifact mismatch')
    scan=transport.operation(['--scan'],'scan.log')
    if b'0x0000081B' not in scan or b'1 device(s) found' not in scan:
        raise RuntimeError('unexpected board identity')
    rows=[]
    report={'test':'isolated physical UART, AT CRLF query only; no ESP configuration changes','limitations':'TX count proves query engine issued bytes, not electrical continuity to ESP RX. No incoming bytes cannot alone distinguish supply, wiring or baud. ready_seen here means OK was received, not hotspot configured.'}
    if args.initializer:
        report.update(test='unchanged production AT initializer; HTTP page ROM stubbed, no HTTP response claim',limitations='ready means initializer completed its command sequence; confirm SSID externally. Sensor and App paths not exercised.')
    try:
        s=serial.Serial();s.port='COM13';s.baudrate=115200;s.timeout=.1;s.dtr=False;s.rts=False
        with s:
            transport.deploy(probe,manifest['artifact_sha256'],'probe-sram.log')
            end=time.monotonic()+35;last=0
            while time.monotonic()<end:
                line=s.readline(256).decode('ascii',errors='replace').strip()
                m=re.fullmatch('Z('+('53' if args.initializer else '52')+'[0-9A-F]{14})',line)
                if not m:
                    continue
                b=bytes.fromhex(m[1]);flags=b[1]
                row={'ready':bool(flags&128),'rx_seen':bool(flags&64),'timed_out':bool(flags&32),'rx_level':bool(flags&16),'tx_level':bool(flags&8),'command_index':flags&7,'rx_count':int.from_bytes(b[2:4],'big'),'tx_count':int.from_bytes(b[4:6],'big'),'last_rx':b[6],'last_tx':b[7]}
                rows.append(row)
                if time.monotonic()-last>5:
                    print(json.dumps(row),flush=True);last=time.monotonic()
        report.update(snapshots=len(rows),ready_seen=any(r['ready'] for r in rows),maximum_rx_bytes=max((r['rx_count'] for r in rows),default=0),maximum_tx_bytes=max((r['tx_count'] for r in rows),default=0),timeout_seen=any(r['timed_out'] for r in rows),command_indices=sorted(set(r['command_index'] for r in rows)),rx_levels=sorted(set(r['rx_level'] for r in rows)))
        if not rows:
            raise RuntimeError('no diagnostics received')
    except Exception as error:
        report['error']=str(error)
        raise
    finally:
        (out/'snapshots.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
        transport.deploy(transport.RESTORE,transport.RESTORE_SHA,'restore-e049.log')
        for op,expected in [(73,b'0x0000E049'),(74,b'0x00006020')]:
            if expected not in transport.operation(['--operation_index',str(op)],'restore-read'+str(op)+'.log'):
                raise RuntimeError('restore independent read failed')
        report['restored_E049_6020']=True
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report),flush=True)


if __name__=='__main__':
    main()
