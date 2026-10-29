"""Bounded real DAC/Realtek capture; temporary SRAM E043, restore E045 in finally.
USB UART supplies sequence markers only; host timing is not latency evidence.
"""
import argparse,hashlib,json,subprocess,time,wave,threading
from pathlib import Path
import numpy as np
import sounddevice as sd
import serial

ROOT=Path(__file__).resolve().parents[1]
PRIVATE=Path('E:/gaoyun/private/esp-web')
OUT=ROOT/'docs/e043-audio-acceptance'
RAW=PRIVATE/'e043-audio'
CLI='E:/gaoyun/tools/gowin/programmer1.9.11.03Education(2536).Win64/Programmer/bin/programmer_cli.exe'
COMMON=[CLI,'--device','GW2A-18C','--cable-index','1','--frequency','2.5MHz']
LABELS=['idle','piano-dry','piano-release','organ-dry','organ-release','strings-dry','strings-release','bass-dry','bass-release','volume160','volume80','volume40','volume0','volume160-restored','release','organ-dry-reference','chorus','chorus-tail','delay','delay-tail','reverb','reverb-tail','four-notes','four-release','32-notes','upper16','lower16','release','explicit-vibrato80','vibrato-release','idle-final']

def deploy(project,expected,label,code):
    fs=PRIVATE/'build'/project/'impl/pnr'/(project+'.fs')
    sha=hashlib.sha256(fs.read_bytes()).hexdigest()
    if sha.lower()!=expected.lower():raise RuntimeError('artifact hash mismatch '+project)
    result=subprocess.run(COMMON+['--operation_index','2','--fsFile',str(fs)],capture_output=True,timeout=30)
    data=result.stdout+result.stderr;(OUT/(label+'.txt')).write_bytes(data)
    if result.returncode or b'100%' not in data or ('0x0000'+code).encode() not in data or b'0x00006020' not in data:raise RuntimeError('deployment failed '+label)
    print(label+' programmed '+code+' sha256='+sha,flush=True)

def main():
    global OUT,RAW
    parser=argparse.ArgumentParser();parser.add_argument('--project',default='audio_delivery_probe');parser.add_argument('--code',default='E043');parser.add_argument('--attenuation',type=int,default=16);parser.add_argument('--device',type=int,default=1);parser.add_argument('--tag',default='e043-audio-acceptance');parser.add_argument('--raw-wasapi',action='store_true');parser.add_argument('--restore-code',choices=['E045','E047'],default='E045');args=parser.parse_args()
    if args.project not in ['audio_delivery_probe','audio_delivery_probe_gain4','audio_delivery_probe_e048'] or args.code not in ['E043','E044','E048'] or args.attenuation not in [4,16] or '/' in args.tag or '\\' in args.tag:raise ValueError('probe arguments')
    OUT=ROOT/'docs'/args.tag;RAW=PRIVATE/args.tag
    OUT.mkdir(exist_ok=True);RAW.mkdir(exist_ok=True)
    fs=PRIVATE/'build'/args.project/'impl/pnr'/(args.project+'.fs')
    probe_sha=hashlib.sha256(fs.read_bytes()).hexdigest()
    restore_project='instrument_'+args.restore_code.lower()+'_ap'
    restore=json.loads((ROOT/'docs'/(args.restore_code.lower()+'-regression')/'manifest.json').read_text())['artifact_sha256']
    sd.check_input_settings(device=args.device,channels=1,samplerate=48000)
    chunks=[];markers=[];audio_status=[];stop=threading.Event();bad=[0]
    def callback(data,frames,stamp,status):
        if status:audio_status.append(str(status))
        chunks.append(data[:,0].copy())
    with serial.Serial('COM13',115200,timeout=.05) as port:
        def reader():
            pending=bytearray()
            while not stop.is_set():
                pending.extend(port.read(256))
                while len(pending)>=9:
                    if pending[0]!=0xa5:del pending[0];continue
                    p=bytes(pending[:9]);check=0
                    for b in p[:8]:check^=b
                    if check!=p[8] or p[1]>30 or p[2]>1:bad[0]+=1;del pending[0];continue
                    del pending[:9]
                    markers.append(dict(t=time.monotonic(),slot=p[1],frame=(p[2]<<16)|(p[3]<<8)|p[4],digital_peak=(p[5]<<8)|p[6],voices=p[7]))
        thread=threading.Thread(target=reader);thread.start()
        try:
            if args.raw_wasapi:
                from raw_wasapi_capture import RawCapture
                capture_stream=RawCapture(callback)
            else:capture_stream=sd.InputStream(device=args.device,samplerate=48000,channels=1,dtype='float32',callback=callback)
            with capture_stream:
                t0=time.monotonic()
                try:
                    # Drivers may accept settings yet never deliver callbacks (observed WDM-KS).
                    preflight=time.monotonic()+2
                    while not chunks and time.monotonic()<preflight:time.sleep(.05)
                    if not chunks:raise RuntimeError('audio driver delivered no samples; reject before probe deployment')
                    deploy(args.project,probe_sha,'probe-sram',args.code)
                    end=t0+85
                    while time.monotonic()<end:
                        if markers and markers[-1]['slot']==30:time.sleep(1);break
                        time.sleep(.1)
                    if not markers or markers[-1]['slot']<30:raise RuntimeError('probe sequence/marker incomplete')
                finally:
                    # Stop recording before restore and preserve the raw waveform even on failure.
                    stop.set();thread.join(2)
            x=np.concatenate(chunks) if chunks else np.array([],dtype=np.float32)
            wav=RAW/'capture.wav'
            with wave.open(str(wav),'wb') as w:
                w.setparams((1,2,48000,0,'NONE','not compressed'));w.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
            (RAW/'markers.json').write_text(json.dumps(markers))
            if not len(x):raise RuntimeError('no recorded samples')
            anchors=[m['t']-t0-m['slot']*2-m['frame']/46875 for m in markers if 5<=m['slot']<=29]
            offset=float(np.median(anchors));rows=[]
            for slot,label in enumerate(LABELS[:30]):
                a=int((offset+slot*2+.65)*48000);b=a+int(.9*48000)
                y=x[a:b].astype(float)
                if a<0 or len(y)!=b-a:raise RuntimeError('capture window missing '+label)
                spectrum=abs(np.fft.rfft((y-y.mean())*np.hanning(len(y))))
                frequencies=np.fft.rfftfreq(len(y),1/48000)
                rms=float(np.sqrt(np.mean(y*y)))
                row=dict(slot=slot,label=label,rms_dbfs=float(20*np.log10(max(rms,1e-12))),peak=float(max(abs(y))),clipped_fraction=float(np.mean(abs(y)>=.99)),digital_peak=max([m['digital_peak'] for m in markers if m['slot']==slot] or [0]),voices=max([m['voices'] for m in markers if m['slot']==slot] or [0]))
                if slot in [1,3,5,7,9,10,11,13,15,16,18,20,28]:
                    candidates=np.where(abs(frequencies-261.625565)<20)[0];k=candidates[np.argmax(spectrum[candidates])]
                    delta=0.
                    if 0<k<len(spectrum)-1:
                        z=np.log(np.maximum(spectrum[k-1:k+2],1e-30));den=z[0]-2*z[1]+z[2]
                        if abs(den)>1e-12:delta=float(.5*(z[0]-z[2])/den)
                    hz=float((k+delta)*48000/len(y));row['fundamental_candidate_hz']=hz
                    row['harmonics_db_relative']=[]
                    base=float(max(spectrum[candidates]))
                    for harmonic in range(1,7):
                        band=abs(frequencies-hz*harmonic)<4
                        row['harmonics_db_relative'].append(float(20*np.log10(max(float(max(spectrum[band])),1e-20)/max(base,1e-20))))
                    # Phase-derived frequency variation around one isolated fundamental.
                    from scipy.signal import butter,sosfiltfilt,hilbert
                    filtered=sosfiltfilt(butter(4,[235,290],btype='bandpass',fs=48000,output='sos'),y)
                    z=hilbert(filtered);phase=np.unwrap(np.angle(z));step=960
                    pitches=[float((phase[j+step]-phase[j])*48000/(2*np.pi*step)) for j in range(4800,len(y)-step-4800,step)]
                    row['pitch_20ms_p05_p95_hz']=[float(np.percentile(pitches,5)),float(np.percentile(pitches,95))]
                rows.append(row);print(json.dumps(row),flush=True)
            report=dict(source=args.code+' isolated production synth/FX/I2S to physical Realtek mic input',device=args.device,probe_sha256=probe_sha,raw_sha256=hashlib.sha256(wav.read_bytes()).hexdigest(),markers=len(markers),bad_markers=bad[0],pc_audio_status=audio_status,dac_capture_attenuation=args.attenuation,pc_sample_rate=48000,nominal_dac_sample_rate=46875,sequence_offset_seconds=offset,alignment='UART host sequence markers; not input-to-analog latency measurement',limitations=['PC mic AGC/noise/frequency response may affect amplitude and harmonic ratios','volume stimuli are injected control values, not physical K230 input','32-note peaks require separate provenance/FFT assessment','not proof of physical LRCK rate or phone UI acceptance'],records=rows)
            report['raw_wasapi']=args.raw_wasapi
            if args.raw_wasapi:report['mix_format']=capture_stream.format
            (OUT/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
        finally:
            stop.set();thread.join(2)
            sd.stop()
            deploy(restore_project,restore,'restore-'+args.restore_code.lower(),args.restore_code)
            for op,expected in [(73,('0x0000'+args.restore_code).encode()),(74,b'0x00006020')]:
                r=subprocess.run(COMMON+['--operation_index',str(op)],capture_output=True,timeout=12);data=r.stdout+r.stderr;(OUT/('restore-read'+str(op)+'.txt')).write_bytes(data)
                if r.returncode or expected not in data:raise RuntimeError('restore read failed '+str(op))
            print('Restored full '+args.restore_code+', independent '+args.restore_code+'/6020 read; Flash unchanged',flush=True)

if __name__=='__main__':main()
