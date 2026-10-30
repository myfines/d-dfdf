import unittest
import numpy as np
from analyze_delivery_audio import transition_windows


class DeliveryTransitionsTest(unittest.TestCase):
    def test_early_transition_clipping_is_not_hidden_by_clean_steady_window(self):
        samples=np.zeros(8000)
        samples[2050:2060]=1.0
        rows=transition_windows(samples,1000,0,slots=4)
        self.assertEqual(rows[1]['near_fullscale_samples'],10)
        self.assertEqual(rows[0]['near_fullscale_samples'],0)
        self.assertEqual(rows[1]['steady_near_fullscale_samples'],0)

    def test_incomplete_window_is_explicit(self):
        rows=transition_windows(np.zeros(2500),1000,0,slots=2)
        self.assertTrue(rows[0]['complete'])
        self.assertFalse(rows[1]['complete'])


if __name__=='__main__':
    unittest.main()
