"""CanMV IDE: Run this entire file. Uses the official model/classes on SD.

V2: confidence hysteresis + bounded stale hold + detector diagnostics.
No UART, note triggering, main.py replacement, or FPGA changes.
OPEN_MIN/MAX are provisional ratios, not a calibrated volume control.
"""
import math


class _BasePinchTracker:
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
        if palm < 16:
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



def select_boxes(boxes, center):
    strong = [b for b in boxes if float(b[1]) >= .30]
    if strong or center is None:
        return strong
    nearby = []
    for b in boxes:
        cx,cy=(float(b[2])+float(b[4]))/2,(float(b[3])+float(b[5]))/2
        distance=math.sqrt((cx-center[0])**2+(cy-center[1])**2)
        radius=max(60, .8*max(float(b[4])-float(b[2]),float(b[5])-float(b[3])))
        if float(b[1]) >= .18 and distance <= radius:
            nearby.append((distance,b))
    return [min(nearby,key=lambda item:item[0])[1]] if nearby else []


class PinchTracker(_BasePinchTracker):
    """Fresh acquisition >=.30; tracking >=.18; HOLD is never a fresh value."""
    def reset(self):
        super().reset()
        self.last_result = None
        self.missing_ms = 0

    def gap(self, status, dt_ms):
        self.missing_ms += max(1, dt_ms)
        if self.last_result is not None and self.missing_ms <= 200:
            r = dict(self.last_result)
            r.update(status='HOLD', valid=False, age_ms=self.missing_ms, reason=status)
            return r
        return self.invalid(status)

    def update(self, hands, scores, dt_ms):
        if self.last_result is not None and self.missing_ms + max(1,dt_ms) > 200:
            self.reset()
        if not hands:
            return self.gap('NO HAND', dt_ms)
        if len(hands) != 1:
            return self.invalid('MULTI HAND')
        if len(scores) != 1 or not math.isfinite(float(scores[0])):
            return self.invalid('LOW CONF')
        p = hands[0]
        if len(p) != 42 or any(not math.isfinite(float(x)) or abs(float(x)) > 4096 for x in p):
            return self.invalid('BAD GEOMETRY')
        # Re-acquire after a discontinuity instead of trusting another hand at low confidence.
        center=((float(p[10])+float(p[34]))/2,(float(p[11])+float(p[35]))/2)
        palm=math.sqrt((float(p[10])-float(p[34]))**2+(float(p[11])-float(p[35]))**2)
        if self.center is not None:
            jump=math.sqrt(sum((a-b)**2 for a,b in zip(center,self.center)))
            if jump > max(120,palm*.75):
                self.reset()
        threshold=.18 if self.last_result is not None else .30
        if not threshold <= float(scores[0]) <= 1:
            return self.gap('LOW CONF',dt_ms)
        r=super().update(hands,[max(.35,float(scores[0]))],dt_ms)
        self.missing_ms=0
        r['age_ms']=0
        if r['valid']:
            self.last_result=dict(r)
        return r


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
    VendorHand = ns['HandKeyPointDet']
    class DiagnosticHand(VendorHand):
        def run(self, input_np):
            raw = self.hand_det.run(input_np)
            self.raw_count = len(raw)
            self.raw_peak = max([float(b[1]) for b in raw]) if len(raw) else 0
            self.geometry_rejected = 0
            boxes, hands = [], []
            for b in raw:
                x1,y1,x2,y2 = [float(v) for v in b[2:6]]
                # Only positive, in-bounds boxes of usable size; no vendor edge-width heuristic.
                if (x2-x1 < 24 or y2-y1 < 36 or x1 < 0 or y1 < 0 or x2 > 640 or y2 > 480):
                    self.geometry_rejected += 1
                    continue
                boxes.append(b)
            boxes = select_boxes(boxes,tracker.center if tracker.last_result is not None else None)
            # Multi-hand output is explicitly invalid; avoid costly keypoint inference for it.
            if len(boxes) != 1:
                return boxes, [None for _ in boxes]
            self.hand_kp.config_preprocess(boxes[0])
            return boxes, [self.hand_kp.run(input_np)]
    ns['HandKeyPointDet'] = DiagnosticHand
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
            confidence_threshold=0.18, nms_threshold=0.5,
            rgb888p_size=[640,480], display_size=[640,480])
        print('PINCH_V2: seq,status,valid,hands,det_conf,raw_ratio,smooth_ratio,open_pct,closed,loop_ms,raw_boxes,box_reject,age_ms,raw_peak')
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
            if len(hands)==1:
                hkd.draw_result(pl, boxes, hands)
            else:
                pl.osd_img.clear()
                for b in boxes:
                    pl.osd_img.draw_rectangle(int(b[2]),int(b[3]),int(b[4]-b[2]),int(b[5]-b[3]),color=(255,255,180,0),thickness=2)
            color = (255,0,255,0) if r['valid'] else (255,255,180,0)
            pct = int(r['value']*100+0.5) if r['value'] is not None else None
            text = '%s  OPEN %s' % (r['status'], ('%d%%' % pct) if pct is not None else '--')
            pl.osd_img.draw_string_advanced(10, 10, 28, text, color=color)
            pl.osd_img.draw_rectangle(10, 48, 300, 18, color=color, thickness=2)
            if pct is not None:
                if pct > 0:
                    pl.osd_img.draw_rectangle(12,50,max(1,int(296*pct/100)),14,color=color,fill=True)
                p = hands[0] if len(hands)==1 else None
                if p is not None:
                    pl.osd_img.draw_line(int(p[8]),int(p[9]),int(p[16]),int(p[17]),color=(255,0,255,255),thickness=3)
            pl.osd_img.draw_string_advanced(10,72,20,'DET %d %.2f / REJECT %d / OLD %dms' % (hkd.raw_count,hkd.raw_peak,hkd.geometry_rejected,r.get('age_ms',0)),color=color)
            pl.show_image()
            sequence += 1
            if time.ticks_diff(now, last_print) >= 200:
                def number(v):
                    return '--' if v is None else '%.3f' % v
                print('PINCH2,%d,%s,%d,%d,%s,%s,%s,%s,%d,%d,%d,%d,%d,%.3f' % (
                    sequence,r['status'],r['valid'],len(hands),
                    number(scores[0]) if len(scores)==1 else '--',
                    number(r['raw']),number(r['smooth']),str(pct) if pct is not None else '--',
                    r['closed'],time.ticks_diff(time.ticks_ms(),start),hkd.raw_count,hkd.geometry_rejected,r.get('age_ms',0),hkd.raw_peak))
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
