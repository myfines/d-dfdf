"""CanMV IDE: Run this entire file. Uses the official model/classes on SD.

No UART, note triggering, main.py replacement, or FPGA changes.
OPEN_MIN/MAX are provisional ratios, not a calibrated volume control.
"""
import math


class PinchTracker:
    OPEN_MIN = 0.15
    OPEN_MAX = 1.30

    def __init__(self):
        self.reset()

    def reset(self):
        self.frames = 0
        self.smooth = None
        self.closed = False
        self.center = None

    def invalid(self, status):
        self.reset()
        return dict(status=status, valid=False, raw=None, smooth=None,
                    value=None, closed=False)

    def update(self, hands, scores, dt_ms):
        if not hands:
            return self.invalid('NO HAND')
        if len(hands) != 1:
            return self.invalid('MULTI HAND')
        if len(scores) != 1 or not 0.35 <= float(scores[0]) <= 1:
            return self.invalid('LOW CONF')
        p = hands[0]
        if len(p) != 42 or any(not math.isfinite(float(x)) or abs(float(x)) > 4096 for x in p):
            return self.invalid('BAD GEOMETRY')
        def distance(a, b):
            return math.sqrt((float(p[a*2])-float(p[b*2]))**2 +
                             (float(p[a*2+1])-float(p[b*2+1]))**2)
        palm = distance(5, 17)
        if palm < 20:
            return self.invalid('BAD GEOMETRY')
        raw = distance(4, 8) / palm
        if raw > 4:
            return self.invalid('BAD GEOMETRY')
        center = ((float(p[10])+float(p[34]))/2,
                  (float(p[11])+float(p[35]))/2)
        if self.center is not None:
            jump = math.sqrt(sum((a-b)**2 for a,b in zip(center,self.center)))
            if jump > max(120, palm*0.75):
                self.reset()
        self.center = center
        self.frames += 1
        alpha = 1-math.exp(-max(1, dt_ms)/120.0)
        self.smooth = raw if self.smooth is None else self.smooth+alpha*(raw-self.smooth)
        # Schmitt thresholds on the smoothed ratio; this is a status only.
        if self.smooth < 0.23:
            self.closed = True
        elif self.smooth > 0.33:
            self.closed = False
        valid = self.frames >= 3
        value = max(0.0, min(1.0, (self.smooth-self.OPEN_MIN)/(self.OPEN_MAX-self.OPEN_MIN)))
        return dict(status='TRACK' if valid else 'WARMUP', valid=valid,
                    raw=raw, smooth=self.smooth, value=value if valid else None,
                    closed=self.closed)


def main():
    import time
    import gc
    import os
    # Reuse vendor classes, but never execute the vendor infinite main loop.
    path = '/sdcard/k230_hand_keypoint_official.py'
    with open(path) as f:
        source = f.read()
    marker = 'if __name__ == "__main__":'
    if marker not in source:
        raise RuntimeError('Unsupported vendor source: missing main boundary')
    ns = {'__name__': 'yahboom_hand_reference'}
    exec(compile(source.split(marker, 1)[0], path, 'exec'), ns)
    pl = ns['PipeLine'](rgb888p_size=[640,480], display_size=[640,480], display_mode='lcd')
    hkd = None
    tracker = PinchTracker()
    try:
        pl.create()
        # Coordinates must use the same equal-aspect display and sensor geometry.
        if list(pl.display_size) != [640,480]:
            raise RuntimeError('Expected 640x480 display for distance geometry')
        hkd = ns['HandKeyPointDet'](
            '/sdcard/kmodel/hand_det.kmodel', '/sdcard/kmodel/handkp_det.kmodel',
            det_input_size=[512,512], kp_input_size=[256,256], labels=['hand'],
            anchors=[26,27,53,52,75,71,80,99,106,82,99,134,140,113,161,172,245,276],
            confidence_threshold=0.35, nms_threshold=0.5,
            rgb888p_size=[640,480], display_size=[640,480])
        print('PINCH_V1: seq,status,valid,hands,det_conf,raw_ratio,smooth_ratio,open_pct,closed,loop_ms')
        print('PREVIEW ONLY; pct provisional; no UART or note output')
        previous = time.ticks_ms()
        last_print = previous
        sequence = 0
        while True:
            os.exitpoint()
            start = time.ticks_ms()
            boxes, hands = hkd.run(pl.get_frame())
            now = time.ticks_ms()
            dt = time.ticks_diff(now, previous)
            previous = now
            scores = [float(b[1]) for b in boxes]
            r = tracker.update(hands, scores, dt)
            hkd.draw_result(pl, boxes, hands)
            color = (255,0,255,0) if r['valid'] else (255,255,180,0)
            pct = int(r['value']*100+0.5) if r['valid'] else None
            text = '%s  OPEN %s' % (r['status'], ('%d%%' % pct) if pct is not None else '--')
            pl.osd_img.draw_string_advanced(10, 10, 28, text, color=color)
            pl.osd_img.draw_rectangle(10, 48, 300, 18, color=color, thickness=2)
            if pct is not None:
                if pct > 0:
                    pl.osd_img.draw_rectangle(12,50,max(1,int(296*pct/100)),14,color=color,fill=True)
                p = hands[0]
                pl.osd_img.draw_line(int(p[8]),int(p[9]),int(p[16]),int(p[17]),color=(255,0,255,255),thickness=3)
            pl.show_image()
            sequence += 1
            if time.ticks_diff(now, last_print) >= 200:
                def number(v):
                    return '--' if v is None else '%.3f' % v
                print('PINCH,%d,%s,%d,%d,%s,%s,%s,%s,%d,%d' % (
                    sequence,r['status'],r['valid'],len(hands),
                    number(scores[0]) if len(scores)==1 else '--',
                    number(r['raw']),number(r['smooth']),str(pct) if pct is not None else '--',
                    r['closed'],time.ticks_diff(time.ticks_ms(),start)))
                last_print = now
            gc.collect()
    finally:
        try:
            if hkd is not None:
                hkd.hand_det.deinit()
                hkd.hand_kp.deinit()
        finally:
            pl.destroy()


if __name__ == '__main__':
    main()
