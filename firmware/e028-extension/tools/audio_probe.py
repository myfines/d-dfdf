"""Explicit opt-in DAC recording probe. Defaults to plan-only; never flashes FPGA."""
import argparse, json, math, socket, time, wave
from pathlib import Path
import numpy as np

def metrics(samples, rate):
    x=np.asarray(samples,dtype=float).reshape(-1)
    if not len(x): raise ValueError('empty recording')
    centered=x-x.mean()
    power=np.abs(np.fft.rfft(centered*np.hanning(len(x))))
    freq=np.fft.rfftfreq(len(x),1/rate)
    # This reports dominant peak, not a guaranteed fundamental of rich timbres.
    power[freq<40]=0
    k=int(np.argmax(power))
    rms=float(np.sqrt(np.mean(x*x)))
    return dict(rms_dbfs=20*math.log10(max(rms,1e-12)),peak=float(np.max(np.abs(x))),
                dc=float(x.mean()),clipped_fraction=float(np.mean(np.abs(x)>=.99)),
                dominant_hz=float(freq[k]),samples=len(x))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run',action='store_true')
    p.add_argument('--list-devices',action='store_true')
    p.add_argument('--host',default='192.168.4.1');p.add_argument('--port',type=int,default=9000)
    p.add_argument('--device',type=int);p.add_argument('--output',type=Path,default=Path('audio-probe'))
    args=p.parse_args()
    if args.list_devices:
        import sounddevice as sd
        print(sd.query_devices());return
    sequence=[('idle',0,0,1.0)]
    for t in range(4):
        sequence.extend([(f'timbre{t}-C4',t,1<<12,1.2),(f'timbre{t}-release',t,0,.5)])
    sequence.extend([('four-note-chord',0,sum(1<<n for n in [12,16,19,23]),1.2),('final-idle',0,0,.6)])
    if not args.run:
        print(json.dumps(sequence,indent=2));return
    if args.device is None:p.error('--device is required: select the physically connected input explicitly')
    import sounddevice as sd
    rate=48000
    sd.check_input_settings(device=args.device,channels=1,samplerate=rate)
    args.output.mkdir(parents=True,exist_ok=True)
    records=[]
    with socket.create_connection((args.host,args.port),timeout=3) as link:
        def send(text):link.sendall((text+'\n').encode('ascii'))
        try:
            for c in ['R00','H00','D00','M00000000','F00','V40','X00','B2000','Y80']:send(c)
            for name,t,mask,seconds in sequence:
                audio=sd.rec(int((seconds+.1)*rate),samplerate=rate,channels=1,device=args.device,dtype='float32')
                stamp=time.monotonic();send(f'T{t:02X}');send(f'M{mask:08X}')
                sd.wait();audio=audio[:,0]
                pcm=(np.clip(audio,-1,1)*32767).astype('<i2')
                with wave.open(str(args.output/(name+'.wav')),'wb') as w:
                    w.setparams((1,2,rate,0,'NONE','not compressed'));w.writeframes(pcm.tobytes())
                row=dict(name=name,timbre=t,mask=f'{mask:08X}',host_command_time=stamp,**metrics(audio,rate))
                records.append(row);print(json.dumps(row))
                (args.output/'report.json').write_text(json.dumps(dict(source='physical PC audio input',
                    note='Host timestamps are not end-to-end latency evidence; microphone AGC can alter amplitude',records=records),indent=2),encoding='utf-8')
        finally:
            for c in ['M00000000','R00','H00','D00','L00']:
                try:send(c)
                except OSError:pass
            sd.stop()
if __name__=='__main__':main()
