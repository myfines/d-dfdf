import unittest
from usb_gesture_state import gesture_fields

class StateTests(unittest.TestCase):
    def test_invalid_and_stale_zero(self):
        for status,valid,age in [('HOLD',False,10),('NO HAND',False,0),('TRACK',True,151),('TRACK',True,-1)]:
            self.assertEqual(gesture_fields({'status':status,'valid':valid,'value':.7},[[100]*42],[.9],age),(False,0,0,0))
    def test_clamp_and_vertical_definition(self):
        p=[100]*42;p[11]=100;p[35]=379
        self.assertEqual(gesture_fields({'status':'TRACK','valid':True,'value':1.3},[p],[.955],0),(True,1000,500,96))
    def test_invalid_geometry_and_multi(self):
        r={'status':'TRACK','valid':True,'value':.5}
        self.assertEqual(gesture_fields(r,[[1]*42]*2,[.9]*2,0),(False,0,0,0))
        p=[1]*42;p[11]=float('nan')
        self.assertEqual(gesture_fields(r,[p],[.9],0),(False,0,0,0))

if __name__=='__main__':unittest.main()
