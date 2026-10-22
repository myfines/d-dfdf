"""UART1 TX-only gesture candidate; no board writes or USB data transport."""
from usb_gesture_sender import write_frame, V2_SHA256
from gesture_protocol import encode
from usb_gesture_state import gesture_fields

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
