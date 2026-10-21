# Generated candidate. NOT deployed. Exclusive CDC only.
"""Transport-independent gesture V1 codec. MicroPython compatible; no UART setup.
Frame: A5 5A, version=1, seq, valid, pinch BE16, y BE16, confidence, CRC BE16.
CRC16-CCITT-FALSE covers bytes 2..9 (poly1021, initFFFF, no reflection/xor).
"""
def crc16(data):
 crc=0xffff
 for byte in data:
  crc ^= byte << 8
  for _ in range(8):
   crc=((crc << 1)^0x1021 if crc & 0x8000 else crc << 1)&0xffff
 return crc

def encode(seq, valid, pinch, y, confidence):
 for value,maximum in ((seq,255),(pinch,1000),(y,1000),(confidence,100)):
  if not isinstance(value,int) or not 0<=value<=maximum:raise ValueError('gesture field range')
 if valid not in (False,True):raise ValueError('valid flag')
 body=bytes((1,seq,int(valid),pinch>>8,pinch&255,y>>8,y&255,confidence))
 crc=crc16(body)
 return b'\xa5\x5a'+body+bytes((crc>>8,crc&255))

def decode(frame):
 if len(frame)!=12 or frame[:2]!=b'\xa5\x5a':raise ValueError('frame length/sync')
 if frame[2]!=1 or frame[4] not in (0,1):raise ValueError('version/flags')
 if crc16(frame[2:10])!=((frame[10]<<8)|frame[11]):raise ValueError('CRC')
 result=(frame[3],bool(frame[4]),(frame[5]<<8)|frame[6],(frame[7]<<8)|frame[8],frame[9])
 encode(*result)
 return result

"""Map only fresh TRACK results; coordinates are 640x480 preview pixels."""
import math
FRESH_MS=150

def gesture_fields(result,hands,scores,age_ms):
    invalid=(False,0,0,0)
    if not 0<=age_ms<=FRESH_MS or not result.get('valid') or result.get('status')!='TRACK':
        return invalid
    if len(hands)!=1 or len(scores)!=1 or hands[0] is None or len(hands[0])!=42:
        return invalid
    p=hands[0]
    try:
        value=float(result['value']);y=(float(p[11])+float(p[35]))/2;confidence=float(scores[0])
        if not all(math.isfinite(v) for v in (value,y,confidence)): return invalid
        return (True,int(max(0,min(1,value))*1000+.5),
                int(max(0,min(479,y))*1000/479+.5),
                int(max(0,min(1,confidence))*100+.5))
    except (KeyError,ValueError,TypeError,OverflowError):
        return invalid

"""Candidate exclusive-CDC sender. Not deployed; build a standalone file first.

No UART, USB configuration, firmware, SD writes, or USBDBG operations.
Requires the installed, matched V2/vendor source and models on SD.
"""

MIN_CONFIDENCE=.60
V2_SHA256='ae9593ed7a9e610cd1f121d6f825f03e0797fed995b6e73bad259ab8f94371d2'

class PacketState:
    def __init__(self):
        self.sequence=0
        self.fields=(False,0,0,0)
        self.sample_at=None

    def publish(self,result,hands,scores,now_ms):
        fields=gesture_fields(result,hands,scores,0)
        # Gate the original floating score, not a rounded-up value or tracker substitute.
        if not fields[0] or len(scores)!=1 or float(scores[0])<MIN_CONFIDENCE:
            fields=(False,0,0,0)
        self.fields=fields
        self.sample_at=now_ms

    def next_frame(self,now_ms,ticks_diff):
        fields=self.fields
        if self.sample_at is None or not 0<=ticks_diff(now_ms,self.sample_at)<=FRESH_MS:
            fields=(False,0,0,0)
        packet=encode(self.sequence,*fields)
        self.sequence=(self.sequence+1)&255
        return packet

def write_frame(stream,packet,ticks_ms,ticks_diff,sleep_ms):
    start=ticks_ms();offset=0
    while offset<len(packet):
        if ticks_diff(ticks_ms(),start)>=25:
            raise OSError('CDC write timeout')
        try:
            count=stream.write(packet[offset:])
        except OSError as exc:
            if not exc.args or exc.args[0]!=11:raise
            count=None
        if count is not None:
            if not isinstance(count,int) or count<0 or count>len(packet)-offset:
                raise OSError('Invalid CDC write length')
            offset+=count
        if offset<len(packet):sleep_ms(1)

def run(park_on_failure=True):
    import sys,time,os,usb,_thread,ubinascii
    from io import IOBase
    try:import uhashlib as hashlib
    except ImportError:import hashlib

    class SilentStream(IOBase):
        def write(self,data):return len(data)
        def flush(self):pass
        @property
        def buffer(self):return self

    class SenderStopped(Exception):pass

    # Python stdout is silenced before sensor initialization; native diagnostics may
    # bypass this. No guarantee of a text-free wire across native faults/reset.
    previous_stdout,previous_stderr=sys.stdout,sys.stderr
    silent=SilentStream()
    sys.stdout= silent
    sys.stderr= silent
    state=PacketState();lock=_thread.allocate_lock()
    control={'started':False,'done':False,'stop':False,'error':None}

    def transmit():
        channel=None
        try:
            channel=usb.Serial('/dev/ttyGS0')
            if not channel.open():raise OSError('CDC open failed')
            deadline=time.ticks_ms()
            while not control['stop']:
                remaining=time.ticks_diff(deadline,time.ticks_ms())
                if remaining>0:
                    time.sleep_ms(min(5,remaining));continue
                with lock:
                    packet=state.next_frame(time.ticks_ms(),time.ticks_diff)
                write_frame(channel,packet,time.ticks_ms,time.ticks_diff,time.sleep_ms)
                deadline=time.ticks_add(deadline,50)
                if time.ticks_diff(time.ticks_ms(),deadline)>50:
                    deadline=time.ticks_add(time.ticks_ms(),50)
        except BaseException as exc:
            control['error']=repr(exc)
        finally:
            if channel is not None:
                try:channel.close()
                except BaseException:pass
            control['done']=True

    try:
        path='/sdcard/pinch_preview_v2.py'
        with open(path,'rb') as source_file:source=source_file.read()
        digest=ubinascii.hexlify(hashlib.sha256(source).digest()).decode()
        if digest!=V2_SHA256:raise RuntimeError('V2 source hash mismatch')
        namespace={'__name__':'exclusive_usb_preview','print':lambda *a,**kw:None}
        exec(compile(source,path,'exec'),namespace)
        base=namespace['PinchTracker']

        class ObservedTracker(base):
            def update(self,hands,scores,dt_ms):
                if control['done']:raise SenderStopped()
                result=super().update(hands,scores,dt_ms)
                with lock:
                    state.publish(result,hands,scores,time.ticks_ms())
                    usb_valid=state.fields[0]
                if not control['started']:
                    _thread.start_new_thread(transmit,())
                    control['started']=True
                if result['valid'] and not usb_valid:
                    result=dict(result)
                    result.update(status='USB LOW CONF',valid=False,value=None)
                return result

        namespace['PinchTracker']=ObservedTracker
        namespace['main']()
    except BaseException as exc:
        control['error']=repr(exc)
    finally:
        control['stop']=True
        deadline=time.ticks_add(time.ticks_ms(),2000)
        while control['started'] and not control['done'] and time.ticks_diff(deadline,time.ticks_ms())>0:
            time.sleep_ms(10)
    # No test markers, log lines, USBDBG replies, or normal REPL return on failure.
    # Stop sending so FPGA's existing lease expires. Keep a RAM-only diagnosis.
    globals()['LAST_USB_ERROR']=control['error']
    if park_on_failure:
        while True:
            try:time.sleep_ms(100)
            except BaseException:pass
    sys.stdout,sys.stderr=previous_stdout,previous_stderr
    return control['error']

if __name__=='__main__':run()
