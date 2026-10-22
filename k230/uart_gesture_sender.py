"""UART1 TX-only gesture candidate; no board writes or USB data transport."""
from usb_gesture_sender import PacketState, write_frame, V2_SHA256

UART_TX_PIN=9
UART_BAUD=115200

def open_uart_tx(machine_module):
    fpioa=machine_module.FPIOA()
    fpioa.set_function(UART_TX_PIN,fpioa.UART1_TXD,ie=0,oe=1,pu=1)
    uart=machine_module.UART
    return uart(uart.UART1,baudrate=UART_BAUD,bits=uart.EIGHTBITS,
                parity=uart.PARITY_NONE,stop=uart.STOPBITS_ONE)

class UartLink:
    def __init__(self,port):self.port=port
    def send(self,packet,ticks_ms,ticks_diff,sleep_ms):
        # Shared bounded partial-write algorithm; binary only, never add CR/LF.
        write_frame(self.port,packet,ticks_ms,ticks_diff,sleep_ms)
    def close(self):self.port.deinit()

def run():
    import time,machine,_thread,ubinascii
    try:import uhashlib as hashlib
    except ImportError:import hashlib
    state=PacketState();lock=_thread.allocate_lock()
    control={'started':False,'done':False,'stop':False,'error':None,'accepted':0}

    class SenderStopped(Exception):pass

    def transmit():
        link=None
        try:
            link=UartLink(open_uart_tx(machine))
            deadline=time.ticks_ms();last_report=deadline
            while not control['stop']:
                remaining=time.ticks_diff(deadline,time.ticks_ms())
                if remaining>0:
                    time.sleep_ms(min(5,remaining));continue
                with lock:
                    packet=state.next_frame(time.ticks_ms(),time.ticks_diff)
                link.send(packet,time.ticks_ms,time.ticks_diff,time.sleep_ms)
                control['accepted']+=1
                now=time.ticks_ms()
                if time.ticks_diff(now,last_report)>=1000:
                    # Ordinary console/IDE output, never sent through UART1.
                    print('UART_GESTURE accepted=%d seq=%d valid=%d confidence=%d' %
                          (control['accepted'],packet[3],packet[4],packet[9]))
                    last_report=now
                deadline=time.ticks_add(deadline,50)
                if time.ticks_diff(now,deadline)>50:
                    deadline=time.ticks_add(now,50)
        except BaseException as exc:
            control['error']='UART1 '+repr(exc)
        finally:
            if link is not None:
                try:link.close()
                except BaseException:pass
            control['done']=True

    try:
        path='/sdcard/pinch_preview_v2.py'
        with open(path,'rb') as source_file:source=source_file.read()
        if ubinascii.hexlify(hashlib.sha256(source).digest()).decode()!=V2_SHA256:
            raise RuntimeError('V2 source hash mismatch')
        namespace={'__name__':'uart_gesture_preview'}
        exec(compile(source,path,'exec'),namespace)
        base=namespace['PinchTracker']

        class ObservedTracker(base):
            def update(self,hands,scores,dt_ms):
                if control['done']:raise SenderStopped()
                result=super().update(hands,scores,dt_ms)
                with lock:
                    state.publish(result,hands,scores,time.ticks_ms())
                    uart_valid=state.fields[0]
                if not control['started']:
                    _thread.start_new_thread(transmit,())
                    control['started']=True
                if result['valid'] and not uart_valid:
                    result=dict(result)
                    result.update(status='UART LOW CONF',valid=False,value=None)
                return result

        namespace['PinchTracker']=ObservedTracker
        print('UART_GESTURE candidate: UART1 IO9/TX1 115200 8N1; RX unwired')
        namespace['main']()
    except BaseException as exc:
        if control['error'] is None:control['error']=repr(exc)
    finally:
        control['stop']=True
        deadline=time.ticks_add(time.ticks_ms(),2000)
        while control['started'] and not control['done'] and time.ticks_diff(deadline,time.ticks_ms())>0:
            time.sleep_ms(10)
    globals()['LAST_UART_ERROR']=control['error']
    print('UART_GESTURE stopped; FPGA lease must expire; error=',control['error'])
    return control['error']

if __name__=='__main__':run()
