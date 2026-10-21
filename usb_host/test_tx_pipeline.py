import unittest
from types import SimpleNamespace as NS
from amaranth import Module, Signal, ClockDomain
from amaranth.sim import Simulator
from utmi_tx_pipeline import UTMITxPipeline


class TxPipelineTest(unittest.TestCase):
    def test_stalls_packet_boundaries_and_registered_ready(self):
        phy = NS(tx_data=Signal(8), tx_valid=Signal(), tx_ready=Signal(),
                 op_mode=Signal(2), xcvr_select=Signal(2), term_select=Signal())
        m = Module()
        m.domains.usb = ClockDomain('usb')
        m.submodules.bridge = bridge = UTMITxPipeline(phy)
        expected = [list(range(17)), [0x80, 0xFF], list(range(40, 65))]
        received = []
        current = []
        packet_index = byte_index = 0
        gap = False
        async def bench(ctx):
            nonlocal packet_index, byte_index, gap, current
            for cycle in range(1000):
                valid = packet_index < len(expected) and not gap
                ctx.set(bridge.tx_valid, valid)
                if valid:
                    ctx.set(bridge.tx_data, expected[packet_index][byte_index])
                ctx.set(phy.tx_ready, 0)
                upstream_ready = ctx.get(bridge.tx_ready)
                ready = cycle >= 70 and cycle % 7 not in (0, 1, 2)
                ctx.set(phy.tx_ready, ready)
                self.assertEqual(upstream_ready, ctx.get(bridge.tx_ready), 'PHY ready combinational path')
                if ctx.get(phy.tx_valid):
                    if ready:
                        current.append(ctx.get(phy.tx_data))
                elif current:
                    received.append(current)
                    current = []
                if gap:
                    gap = False
                elif valid and upstream_ready:
                    byte_index += 1
                    if byte_index == len(expected[packet_index]):
                        packet_index += 1
                        byte_index = 0
                        gap = True
                await ctx.tick('usb')
            self.assertEqual(received, expected)
        sim = Simulator(m)
        sim.add_clock(1 / 60e6, domain='usb')
        sim.add_testbench(bench)
        sim.run()


if __name__ == '__main__':
    unittest.main()
