import unittest
from analyze_adsr_capture import transition_interval
class TransitionTests(unittest.TestCase):
 def test_linear_rise_and_fall(self):
  ramp=[i/20 for i in range(21)]+[1]*79
  self.assertAlmostEqual(transition_interval(ramp,0,1,True),.32)
  self.assertAlmostEqual(transition_interval([1-v for v in ramp],1,0,False),.32)
 def test_fast_and_missing(self):
  self.assertEqual(transition_interval([0]*100,1,0,False),0)
  self.assertIsNone(transition_interval([0]*100,0,1,True))
  self.assertIsNone(transition_interval([0]*100,0,0,True))
if __name__=='__main__':unittest.main()
