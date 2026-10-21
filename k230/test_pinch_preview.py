import unittest
from pinch_preview import PinchTracker


def hand(scale=1, gap=50):
    p = [100.0, 100.0] * 21
    for index, x, y in ((4, 100, 100), (8, 100 + gap, 100),
                        (5, 100, 150), (17, 200, 150)):
        p[2*index:2*index+2] = [x*scale, y*scale]
    return p


class PinchTests(unittest.TestCase):
    def ready(self, tracker, points):
        for _ in range(3):
            r = tracker.update([points], [0.9], 50)
        self.assertTrue(r['valid'])
        return r

    def test_scale_invariance(self):
        a = self.ready(PinchTracker(), hand())
        b = self.ready(PinchTracker(), hand(2))
        self.assertAlmostEqual(a['raw'], b['raw'])
        self.assertAlmostEqual(a['value'], b['value'])

    def test_loss_invalidates_and_requires_reacquisition(self):
        t = PinchTracker()
        self.ready(t, hand())
        r = t.update([], [], 50)
        self.assertEqual(r['status'], 'NO HAND')
        self.assertIsNone(r['value'])
        self.assertFalse(t.update([hand()], [0.9], 50)['valid'])

    def test_multi_low_confidence_and_degenerate(self):
        t = PinchTracker()
        for points, scores, status in (([hand(), hand()], [.9,.9], 'MULTI HAND'),
                                       ([hand()], [.1], 'LOW CONF'),
                                       ([[0]*42], [.9], 'BAD GEOMETRY')):
            r = t.update(points, scores, 50)
            self.assertEqual(r['status'], status)
            self.assertFalse(r['valid'])

    def test_smoothing_and_hysteresis(self):
        t = PinchTracker()
        self.ready(t, hand(gap=10))
        self.assertTrue(t.closed)
        for _ in range(20): r = t.update([hand(gap=28)], [.9], 50)
        self.assertTrue(t.closed)
        r = t.update([hand(gap=100)], [.9], 50)
        self.assertFalse(t.closed)
        self.assertLess(r['smooth'], r['raw'])
        for _ in range(30): r = t.update([hand(gap=100)], [.9], 50)
        self.assertAlmostEqual(r['smooth'], 1.0, places=3)

    def test_large_position_jump_rewarms(self):
        t = PinchTracker()
        self.ready(t, hand())
        p = [v+250 for v in hand()]
        self.assertEqual(t.update([p], [.9], 50)['status'], 'WARMUP')


if __name__ == '__main__':
    unittest.main()
