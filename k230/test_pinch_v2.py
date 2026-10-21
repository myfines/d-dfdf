import unittest
from test_pinch_preview import hand
from pinch_preview_v2 import PinchTracker, select_boxes


class ContinuityTests(unittest.TestCase):
    def acquire(self, t):
        for _ in range(3): r = t.update([hand()], [.32], 50)
        self.assertTrue(r['valid'])
        return r

    def test_confidence_hysteresis(self):
        t = PinchTracker(); self.acquire(t)
        self.assertTrue(t.update([hand()], [.20], 50)['valid'])
        fresh = PinchTracker()
        for _ in range(5): r = fresh.update([hand()], [.20], 50)
        self.assertFalse(r['valid'])

    def test_gap_is_held_but_never_fresh(self):
        t = PinchTracker(); before = self.acquire(t)
        r = t.update([], [], 70)
        self.assertEqual(r['status'], 'HOLD')
        self.assertFalse(r['valid'])
        self.assertEqual(r['value'], before['value'])
        r = t.update([hand()], [.22], 50)
        self.assertTrue(r['valid'])
        for _ in range(5): r = t.update([], [], 50)
        self.assertEqual(r['status'], 'NO HAND')
        self.assertIsNone(r['value'])
        self.assertFalse(t.update([hand()], [.22], 50)['valid'])

    def test_multi_does_not_hold_and_cannot_switch(self):
        t = PinchTracker(); self.acquire(t)
        r = t.update([hand(),hand()], [.9,.9], 50)
        self.assertEqual(r['status'], 'MULTI HAND')
        self.assertIsNone(r['value'])

    def test_return_different_location_must_rewarm(self):
        t = PinchTracker();self.acquire(t);t.update([],[],50)
        r=t.update([[x+250 for x in hand()]], [.32], 50)
        self.assertEqual(r['status'], 'WARMUP')

    def test_corrupt_geometry_never_held(self):
        t=PinchTracker();self.acquire(t)
        p=hand();p[8]=float('nan')
        r=t.update([p],[.9],50)
        self.assertEqual(r['status'],'BAD GEOMETRY')
        self.assertIsNone(r['value'])

    def test_long_frame_stall_requires_reacquisition(self):
        t=PinchTracker();self.acquire(t)
        t.update([],[],50)
        r=t.update([hand()],[.22],500)
        self.assertFalse(r['valid'])

    def test_weak_distractors_cannot_acquire_or_hide_strong_hand(self):
        weak=[0,.20,80,80,220,220]
        strong=[0,.80,70,70,240,240]
        far=[0,.22,450,300,600,450]
        self.assertEqual(select_boxes([weak,far],None),[])
        self.assertEqual(select_boxes([weak,strong,far],None),[strong])
        self.assertEqual(select_boxes([weak,far],(150,150)),[weak])
        self.assertEqual(select_boxes([strong,strong],(150,150)),[strong,strong])


if __name__ == '__main__': unittest.main()
