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
