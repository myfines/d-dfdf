import unittest
from gesture_protocol import encode
from usb_stream import FrameStream

class StreamTests(unittest.TestCase):
    def test_fragment_merge_and_wrap(self):
        data=encode(255,True,1000,0,100)+encode(0,False,0,0,0)
        s=FrameStream(); got=[]
        for n in (data[:1],data[1:7],data[7:]): got.extend(s.feed(n))
        self.assertEqual([x['seq'] for x in got],[255,0])
        self.assertEqual(s.crc_errors,0)

    def test_corruption_noise_and_recovery(self):
        bad=bytearray(encode(1,True,10,20,90));bad[6]^=1
        s=FrameStream()
        got=s.feed(b'noise'+bad+encode(2,True,30,40,95))
        self.assertEqual(len(got),1)
        self.assertEqual(got[0]['pinch'],30)
        self.assertEqual(s.crc_errors,1)

    def test_independent_standard_crc_and_range(self):
        import binascii
        self.assertEqual(binascii.crc_hqx(b'123456789',0xffff),0x29b1)
        bad=bytearray(encode(0,True,0,0,90));bad[5:7]=b'\x03\xe9'
        crc=binascii.crc_hqx(bad[2:10],0xffff);bad[10:]=crc.to_bytes(2,'big')
        s=FrameStream();self.assertEqual(s.feed(bad),[])
        self.assertEqual(s.field_errors,1)

if __name__=='__main__': unittest.main()
