"""Bounded RAM-only preview test, assembled by scripts/k230-usb-stream-probe.py.

Not a boot program. Requires an exclusive plain CDC/REPL session, never USBDBG.
The host prepends gesture_protocol.py and usb_gesture_state.py in RAM.
"""
def run_usb_gesture_probe():
    import time,usb,_thread
    with open('/sdcard/pinch_preview_v2.py') as f:
        source=f.read()
    ns={'__name__':'temporary_usb_preview'}
    exec(compile(source,'/sdcard/pinch_preview_v2.py','exec'),ns)
    ns['print']=lambda *a,**kw:None
    base=ns['PinchTracker']
    shared={'sample':(False,0,0,0),'at':0,'started':False,'done':False,'abort':False,'error':None}
    lock=_thread.allocate_lock()
    class ProbeDone(Exception): pass

    def sender():
        u=usb.Serial('/dev/ttyGS0')
        try:
            if not u.open(): raise RuntimeError('ttyGS0 open failed')
            print('BINARY_TEST_BEGIN')
            time.sleep_ms(500)
            start=time.ticks_ms();deadline=start;sent=0;late=0
            for index in range(300):
                while True:
                    delay=time.ticks_diff(deadline,time.ticks_ms())
                    if delay<=0:break
                    time.sleep_ms(min(5,delay))
                with lock:
                    fields=shared['sample'];age=time.ticks_diff(time.ticks_ms(),shared['at']);abort=shared['abort']
                if abort: break
                if not 0<=age<=FRESH_MS: fields=(False,0,0,0)
                packet=encode(index&255,*fields)
                written=0;write_start=time.ticks_ms()
                while written<len(packet):
                    n=u.write(packet[written:])
                    if n is not None and n>0: written+=n
                    if time.ticks_diff(time.ticks_ms(),write_start)>25:
                        raise RuntimeError('CDC write timeout')
                    if written<len(packet):time.sleep_ms(1)
                sent+=1;deadline=time.ticks_add(deadline,50)
                if time.ticks_diff(time.ticks_ms(),deadline)>50:
                    late+=1;deadline=time.ticks_add(time.ticks_ms(),50)
            elapsed=time.ticks_diff(time.ticks_ms(),start)
            u.close()
            print('BINARY_TEST_END')
            print('USB_SEND_STATS',sent,elapsed,late)
        except Exception as e:
            shared['error']=repr(e)
        finally:
            try:u.close()
            except Exception:pass
            shared['done']=True

    class ObservedTracker(base):
        def update(self,hands,scores,dt_ms):
            if shared['done']:raise ProbeDone()
            r=super().update(hands,scores,dt_ms)
            with lock:
                shared['sample']=gesture_fields(r,hands,scores,0)
                shared['at']=time.ticks_ms()
            if not shared['started']:
                shared['started']=True
                _thread.start_new_thread(sender,())
            return r
    ns['PinchTracker']=ObservedTracker
    try:
        ns['main']()
    except ProbeDone:pass
    finally:
        shared['abort']=True
        end=time.ticks_add(time.ticks_ms(),2000)
        while shared['started'] and not shared['done'] and time.ticks_diff(end,time.ticks_ms())>0:
            time.sleep_ms(10)
    if shared['error']:raise RuntimeError(shared['error'])

run_usb_gesture_probe()
