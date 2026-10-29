"""Explicit temporary SRAM probe deployment, PC capture, then restore selected instrument.

No Flash operation. Raw recording stays outside the repository. Deployment
hashes are checked against manifests prepared after successful timing builds.
"""
import argparse
import hashlib
import json
import subprocess
import time
import wave
from pathlib import Path

import numpy as np
import sounddevice as sd

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = Path('E:/gaoyun/private/esp-web')
OUT = ROOT / 'docs/e033-regression'
CLI = 'E:/gaoyun/tools/gowin/programmer1.9.11.03Education(2536).Win64/Programmer/bin/programmer_cli.exe'
COMMON = [CLI, '--device', 'GW2A-18C', '--cable-index', '1', '--frequency', '2.5MHz']


def deploy(project, manifest_name, label):
    fs = PRIVATE / 'build' / project / 'impl/pnr' / (project + '.fs')
    expected = json.loads((OUT / manifest_name).read_text())['artifact_sha256']
    assert hashlib.sha256(fs.read_bytes()).hexdigest() == expected
    try:
        result = subprocess.run(COMMON + ['--operation_index', '2', '--fsFile', str(fs)],
                                capture_output=True, timeout=25)
    except subprocess.TimeoutExpired as exc:
        (OUT / (label + '.log')).write_bytes((exc.stdout or b'') + (exc.stderr or b''))
        raise RuntimeError(label + ' timed out; process stopped') from exc
    text = result.stdout + result.stderr
    (OUT / (label + '.log')).write_bytes(text)
    if result.returncode or b'100%' not in text:
        raise RuntimeError(label + ' failed; inspect retained log')
    return time.monotonic()


def main():
    global OUT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', choices=['E033','E034'], default='E033')
    version = parser.parse_args().version
    OUT = ROOT / ('docs/'+version.lower()+'-regression')
    raw_dir = PRIVATE / ('autonomous-'+version.lower()+'-20261029-lowgain')
    raw_dir.mkdir(exist_ok=True)
    # A known PC input, explicitly selected in prior physical tests.
    sd.check_input_settings(device=1, channels=1, samplerate=48000)
    seconds = 48
    start = time.monotonic()
    samples = sd.rec(seconds * 48000, samplerate=48000, channels=1,
                     device=1, dtype='float32')
    rows = []
    try:
        finished = deploy('audio_regression', 'probe-lowgain-manifest.json', '20261029-autonomous-lowgain-SRAM')
        print('Probe loaded; recording bounded sequence', flush=True)
        sd.wait()
        x = samples[:, 0]
        wav = raw_dir / 'capture.wav'
        with wave.open(str(wav), 'wb') as stream:
            stream.setparams((1, 2, 48000, 0, 'NONE', 'not compressed'))
            stream.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())
        # CLI completion is an approximate boot reference, not a measured
        # electrical trigger. Stay well inside each two-second slot.
        # Command completion can lag configuration release. Align to the
        # first sustained acoustic onset, whose scheduled slot is 1.
        # This is relative sequence alignment, NOT electrical latency.
        windows = x[:(len(x)//960)*960].reshape(-1, 960)
        levels = np.sqrt(np.mean(windows.astype(float)**2, axis=1))
        onset = None
        for index in range(150, len(levels)-5):
            if np.all(levels[index:index+5] > .02):
                onset = index*.02
                break
        if onset is None:
            raise RuntimeError('No sustained acoustic onset; reject measurement')
        offset = onset-2
        labels = ['idle', 'C4-center', 'C4-up', 'C4-down', 'C4-center-repeat',
                  'release', 'dry-attack', 'dry-settled', 'delay-settled', 'delay-release',
                  'reverb', 'reverb-release', 'chorus', 'chorus-release',
                  'four-note-chord', 'chord-release', '32-notes', '32-release', 'idle-final']
        for slot, label in enumerate(labels):
            a = int((offset + 2 * slot + .6) * 48000)
            b = int((offset + 2 * slot + 1.4) * 48000)
            segment = x[a:b].astype(float)
            if len(segment) != b-a:
                raise RuntimeError('capture shorter than sequence')
            rms = np.sqrt(np.mean(segment * segment))
            spectrum = abs(np.fft.rfft((segment-segment.mean()) * np.hanning(len(segment))))
            freqs = np.fft.rfftfreq(len(segment), 1/48000)
            spectrum[freqs < 50] = 0
            row = dict(slot=slot, label=label, rms_dbfs=float(20*np.log10(max(rms, 1e-12))),
                       peak=float(max(abs(segment))),
                       clipped_fraction=float(np.mean(abs(segment) >= .99)),
                       dominant_hz=float(freqs[int(np.argmax(spectrum))]))
            if slot in [1, 2, 3, 4, 6, 7, 8, 10, 12]:
                expected = 293.664768 if slot == 2 else 233.081881 if slot == 3 else 261.625565
                indices = np.where(abs(freqs-expected) < 15)[0]
                k = indices[int(np.argmax(spectrum[indices]))]
                # Parabolic FFT interpolation; uncertainty still depends on
                # input noise/AGC, not merely FFT resolution.
                delta = 0.
                if 0 < k < len(spectrum)-1:
                    logmag = np.log(np.maximum(spectrum[k-1:k+2], 1e-30))
                    denom = logmag[0]-2*logmag[1]+logmag[2]
                    if abs(denom) > 1e-12:
                        delta = float(.5*(logmag[0]-logmag[2])/denom)
                hz = float((k+delta)*48000/len(segment))
                row.update(expected_hz=expected, fundamental_candidate_hz=hz,
                           candidate_error_cents=float(1200*np.log2(hz/expected)))
            rows.append(row)
            print(json.dumps(row), flush=True)
        report = dict(probe='E03A autonomous isolated synth/fx/I2S, not full instrument',
                      pc_sample_rate=48000, dac_sample_rate_design=46875,
                      timing_reference='first sustained acoustic onset minus scheduled 2s; no latency claim',
                      acoustic_onset_seconds=onset,
                      raw_sha256=hashlib.sha256(wav.read_bytes()).hexdigest(),
                      caution='Realtek mic AGC/noise possible; candidates require signal provenance verification',
                      records=rows)
        (OUT / 'autonomous-recording-lowgain.json').write_text(json.dumps(report, indent=2))
    finally:
        sd.stop()
        deploy('instrument_'+version.lower(), 'build-manifest.json', '20261029-restore-'+version)
        for op in [73, 74]:
            result = subprocess.run(COMMON+['--operation_index', str(op)],
                                    capture_output=True, timeout=12)
            (OUT / ('20261029-restore-read'+str(op)+'.log')).write_bytes(result.stdout+result.stderr)
            print((result.stdout+result.stderr).decode(errors='replace')[-450:], flush=True)
            expected = ('0x0000'+version).encode() if op == 73 else b'0x00006020'
            if result.returncode or expected not in result.stdout+result.stderr:
                raise RuntimeError('Independent restore read failed: '+str(op))


if __name__ == '__main__':
    main()
