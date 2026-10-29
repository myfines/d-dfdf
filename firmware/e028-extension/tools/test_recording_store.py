import unittest
from recording_store import RecordingStore

def packet(record=1,chunk=0,flags=2,data=None):
 data=bytes(range(32)) if data is None else data
 return 'A%04X%02X%02X10000800000'%(record,chunk,flags)+data.hex().upper()+'%04X'%(sum(data)&65535)+'0000000\n'
class RecordingTests(unittest.TestCase):
 def test_integrity_and_export(self):
  r=RecordingStore();self.assertTrue(r.ingest(packet()));self.assertEqual(r.status()['chunks'],1)
  self.assertFalse(r.ingest(packet()[:30]+'Z'+packet()[31:]));self.assertEqual(r.status()['chunks'],1)
  self.assertFalse(r.ingest(packet().replace('01F0','01F1')))
  for i in range(1,128):self.assertTrue(r.ingest(packet(chunk=i)))
  w=r.wav();self.assertEqual(w[:4],b'RIFF');self.assertEqual(len(w),4140);self.assertEqual(w[44:76],bytes(x^128 for x in range(32)))
 def test_new_capture_and_incomplete(self):
  r=RecordingStore();r.ingest(packet());r.ingest(packet(record=2,flags=1));self.assertEqual(r.status()['chunks'],0)
  with self.assertRaises(ValueError):r.wav()
if __name__=='__main__':unittest.main()
