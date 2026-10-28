import unittest
import numpy as np
from audio_probe import metrics
class ProbeTest(unittest.TestCase):
 def test_sine(self):
  x=.25*np.sin(2*np.pi*440*np.arange(48000)/48000)
  m=metrics(x,48000)
  self.assertAlmostEqual(m['dominant_hz'],440);self.assertAlmostEqual(m['rms_dbfs'],-15.0515,places=3)
  self.assertEqual(m['clipped_fraction'],0)
 def test_silence(self):
  self.assertEqual(metrics(np.zeros(1000),48000)['peak'],0)
 def test_clip(self):
  self.assertEqual(metrics(np.ones(100),48000)['clipped_fraction'],1)
if __name__=='__main__':unittest.main()
