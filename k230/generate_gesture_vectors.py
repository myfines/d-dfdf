"""Generate shared codec vectors for actual serial-wire RTL simulation."""
from pathlib import Path
from gesture_protocol import encode, crc16

def repaired(frame):
 crc=crc16(frame[2:10]);frame[10]=crc>>8;frame[11]=crc&255;return frame

def generate(path):
 first=encode(254,True,750,250,95)
 corrupt=bytearray(first);corrupt[6]^=1
 unknown=bytearray(encode(1,True,1,2,90));unknown[2]=2
 over=bytearray(encode(1,True,1,2,90));over[5:7]=bytes((3,233))
 flags=bytearray(encode(1,True,1,2,90));flags[4]=2
 frames=[first,corrupt,encode(255,True,500,500,95),encode(0,True,1000,0,100),repaired(unknown),repaired(over),encode(1,False,0,0,0),encode(2,True,300,600,90),repaired(flags),encode(0,True,900,900,59)]
 Path(path).write_text(''.join('%02x\n'%b for frame in frames for b in frame))

if __name__=='__main__':
 import sys
 generate(sys.argv[1])
