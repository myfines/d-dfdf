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
