"""PC-side streaming verifier; CRC uses CPython's independent binascii implementation."""
import binascii

class FrameStream:
    def __init__(self):
        self.buffer=bytearray()
        self.crc_errors=0
        self.field_errors=0
        self.discarded=0

    def feed(self,data):
        self.buffer.extend(data)
        frames=[]
        while len(self.buffer)>=2:
            i=self.buffer.find(b'\xa5\x5a')
            if i<0:
                keep=1 if self.buffer[-1]==0xa5 else 0
                self.discarded+=len(self.buffer)-keep
                self.buffer[:]=self.buffer[-1:] if keep else b''
                break
            if i:
                self.discarded+=i;del self.buffer[:i]
            if len(self.buffer)<12: break
            f=bytes(self.buffer[:12])
            if binascii.crc_hqx(f[2:10],0xffff)!=int.from_bytes(f[10:12],'big'):
                self.crc_errors+=1;del self.buffer[0];continue
            seq,valid,pinch,y,conf=f[3],f[4],int.from_bytes(f[5:7],'big'),int.from_bytes(f[7:9],'big'),f[9]
            if f[2]!=1 or valid not in (0,1) or pinch>1000 or y>1000 or conf>100:
                self.field_errors+=1;del self.buffer[0];continue
            frames.append(dict(seq=seq,valid=valid,pinch=pinch,y=y,confidence=conf,hex=f.hex()))
            del self.buffer[:12]
        return frames
