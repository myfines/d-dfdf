"""Read-only telemetry. Reconnect board USB before any later Flash operation."""
import argparse,json,re,time
from pathlib import Path
from datetime import datetime

def decode(line):
 m=re.fullmatch(r"IO V([01]) E([01]) X([0-9A-F]{3}) Y([0-9A-F]{3}) K([0-9A-F]) S([01]{2})",line.strip())
 if not m:return None
 v,e,x,y,k,bus=m.groups();flags=int(y,16)
 return {"io_armed":int(x,16)!=4095,"adc_ok":v=="1" and e=="0","adc_x":None if flags&2048 else int(x,16),"optical_online":bool(flags&2048),
 "optical_pressed_keys":[i for i in range(8) if not int(x,16)&(1<<i)] if flags&2048 else [],"note_page":(flags>>9)&3,
 "timbre":(flags>>7)&3,"mode":"test32" if flags&32 else "edit" if flags&64 else "play",
 "octave_down":bool(flags&16),"delay":bool(flags&8),"adsr_field":"ADSR"[(flags>>1)&3],
 "envelope_active":bool(flags&1),"pressed_keys":[i for i in range(4) if not int(k,16)&(1<<i)],"bus_snapshot":bus}

def main():
 p=argparse.ArgumentParser();p.add_argument("--port",default="COM13");p.add_argument("--seconds",type=float,default=1)
 p.add_argument("--log",type=Path);p.add_argument("--self-test",action="store_true");a=p.parse_args()
 if a.self_test:
  z=decode("IO V1 E0 X34E Y000 KF S11");assert z["adc_ok"] and z["note_page"]==0 and not z["envelope_active"]
  z=decode("IO V1 E0 X34E Y53F K7 S10");assert z["note_page"]==2 and z["timbre"]==2 and z["mode"]=="test32" and z["pressed_keys"]==[3]
  z=decode("IO V1 E0 X0FE Y801 KF S11");assert z["optical_online"] and z["optical_pressed_keys"]==[0] and z["adc_x"] is None
  assert not decode("IO V0 E0 XFFF Y000 KF S11")["io_armed"]
  assert decode("partial line") is None
  print("PASS telemetry decoder: packed modes, pages, presets and active-low keys");return
 hold=Path(__file__).resolve().parent.parent/"docs"/"hardware-hold.json"
 if hold.exists() and json.loads(hold.read_text(encoding="utf-8-sig")).get("deployment_blocked"):
  raise RuntimeError("Thermal incident unresolved; keep board supplies off. No UART access attempted.")
 if not .1<=a.seconds<=10:p.error("--seconds must be 0.1..10")
 import serial
 s=serial.Serial();s.port=a.port;s.baudrate=115200;s.timeout=.02;s.dtr=False;s.rts=False;s.open()
 try:
  end=time.monotonic()+5
  while time.monotonic()<end:
   b=s.read(max(1,s.in_waiting))
   if not b:
    time.sleep(.03)
    if not s.in_waiting:break
  buf=bytearray();end=time.monotonic()+a.seconds
  while time.monotonic()<end:buf.extend(s.read(max(1,s.in_waiting)))
 finally:s.close()
 log=a.log or Path(__file__).resolve().parent.parent/"logs"/(datetime.now().strftime("%Y%m%d-%H%M%S")+"-instrument-uart.txt")
 log.write_bytes(buf)
 rows=[z for line in buf.decode("ascii",errors="replace").splitlines() if (z:=decode(line))]
 print(json.dumps({"samples":len(rows),"last":rows[-1] if rows else None,"raw_log":str(log)},ensure_ascii=False))
if __name__=="__main__":main()
