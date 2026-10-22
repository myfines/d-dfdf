# Generated UART candidate. NOT deployed.

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

V2_SHA256='ae9593ed7a9e610cd1f121d6f825f03e0797fed995b6e73bad259ab8f94371d2'
def write_frame(stream,packet,ticks_ms,ticks_diff,sleep_ms):
    start=ticks_ms();offset=0
    while offset<len(packet):
        if ticks_diff(ticks_ms(),start)>=25:
            raise OSError('UART write timeout')
        try:
            count=stream.write(packet[offset:])
        except OSError as exc:
            if not exc.args or exc.args[0]!=11:raise
            count=None
        if count is not None:
            if not isinstance(count,int) or count<0 or count>len(packet)-offset:
                raise OSError('Invalid UART write length')
            offset+=count
        if offset<len(packet):sleep_ms(1)
"""UART1 TX-only gesture candidate; no board writes or USB data transport."""

UART_TX_PIN=9
UART_RX_PIN=10
UART_BAUD=115200

def open_uart_tx(machine_module):
    fpioa=machine_module.FPIOA()
    fpioa.set_function(UART_TX_PIN,fpioa.UART1_TXD,ie=0,oe=1,pu=1)
    # CanMV UART requires an RX mux even for write-only use; IO10 stays unwired.
    fpioa.set_function(UART_RX_PIN,fpioa.UART1_RXD,ie=1,oe=0,pu=1)
    uart=machine_module.UART
    return uart(uart.UART1,baudrate=UART_BAUD,bits=uart.EIGHTBITS,
                parity=uart.PARITY_NONE,stop=uart.STOPBITS_ONE)

class UartLink:
    def __init__(self,port):self.port=port
    def send(self,packet,ticks_ms,ticks_diff,sleep_ms):
        # Shared bounded partial-write algorithm; binary only, never add CR/LF.
        write_frame(self.port,packet,ticks_ms,ticks_diff,sleep_ms)
    def close(self):self.port.deinit()

class FrameSender:
    """Exactly one fresh packet per completed tracker update; no replay timer."""
    def __init__(self,link,ticks_ms,ticks_diff,sleep_ms):
        self.link=link;self.ticks_ms=ticks_ms;self.ticks_diff=ticks_diff
        self.sleep_ms=sleep_ms;self.sequence=0;self.accepted=0

    def send_result(self,result,hands,scores):
        fields=gesture_fields(result,hands,scores,0)
        # Tracker owns .30 acquisition/.18 retention; never substitute its score.
        if fields[0] and not .18<=float(scores[0])<=1:
            fields=(False,0,0,0)
        packet=encode(self.sequence,*fields)
        self.link.send(packet,self.ticks_ms,self.ticks_diff,self.sleep_ms)
        self.sequence=(self.sequence+1)&255;self.accepted+=1
        return packet


def run():
    import time,machine,ubinascii
    try:import uhashlib as hashlib
    except ImportError:import hashlib
    link=None;error=None
    try:
        path='/sdcard/pinch_preview_v2.py'
        with open(path,'rb') as source_file:source=source_file.read()
        if ubinascii.hexlify(hashlib.sha256(source).digest()).decode()!=V2_SHA256:
            raise RuntimeError('V2 source hash mismatch')
        namespace={'__name__':'uart_gesture_preview'}
        exec(compile(source,path,'exec'),namespace)
        link=UartLink(open_uart_tx(machine))
        sender=FrameSender(link,time.ticks_ms,time.ticks_diff,time.sleep_ms)
        base=namespace['PinchTracker']
        report=[time.ticks_ms()]

        class ObservedTracker(base):
            def update(self,hands,scores,dt_ms):
                result=super().update(hands,scores,dt_ms)
                packet=sender.send_result(result,hands,scores)
                now=time.ticks_ms()
                if time.ticks_diff(now,report[0])>=1000:
                    raw=scores[0] if len(scores)==1 else None
                    print('UART_GESTURE accepted=%d seq=%d valid=%d confidence=%d status=%s raw=%s loop_dt=%d' %
                          (sender.accepted,packet[3],packet[4],packet[9],result['status'],str(raw),dt_ms))
                    report[0]=now
                return result

        namespace['PinchTracker']=ObservedTracker
        print('UART_GESTURE synchronous: one packet/frame; IO9 TX; IO10 input unwired')
        namespace['main']()
    except BaseException as exc:
        error=repr(exc)
    finally:
        if link is not None:
            try:link.close()
            except BaseException as exc:
                if error is None:error=repr(exc)
    globals()['LAST_UART_ERROR']=error
    print('UART_GESTURE stopped; FPGA lease must expire; error=',error)
    return error

if __name__=='__main__':run()
