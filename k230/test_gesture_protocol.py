import unittest
from gesture_protocol import encode, decode, crc16

class ProtocolTest(unittest.TestCase):
 def test_known_crc(self):
  self.assertEqual(crc16(b"123456789"),0x29b1)
 def test_roundtrip_and_crc(self):
  packet=encode(255,True,750,250,95)
  self.assertEqual(len(packet),12)
  self.assertEqual(decode(packet),(255,True,750,250,95))
  for i in range(12):
   for bit in range(8):
    bad=bytearray(packet);bad[i]^=1<<bit
    with self.assertRaises(ValueError):decode(bad)
 def test_invalid_and_no_hand(self):
  for values in [(0,True,1001,0,50),(0,True,0,-1,50),(0,True,0,0,101),(256,True,0,0,0)]:
   with self.assertRaises(ValueError):encode(*values)
  self.assertEqual(decode(encode(0,False,0,0,0)),(0,False,0,0,0))
  with self.assertRaises(ValueError):decode(b'')

if __name__=='__main__':unittest.main()
