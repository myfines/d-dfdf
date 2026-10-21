"""Pin-visible equivalence for the ULPI command decode timing refactor."""
import random
import unittest
from amaranth import Module, ClockDomain
from amaranth.sim import Simulator
from luna.gateware.interface.ulpi import ULPITransmitTranslator as Original
from luna_ulpi_timing import ULPITransmitTranslator as Optimized


class ULPITimingTest(unittest.TestCase):
    def test_complete_translator_shared_bus(self):
        from types import SimpleNamespace as NS
        from amaranth import Signal
        from luna.gateware.interface.ulpi import UTMITranslator as OriginalBus
        from luna_ulpi_timing import UTMITranslator as OptimizedBus
        def bus():
            return NS(data=NS(i=Signal(8), o=Signal(8), oe=Signal()),
                      dir=NS(i=Signal()), nxt=NS(i=Signal()), stp=NS(o=Signal()))
        a, b = bus(), bus()
        m = Module()
        m.domains.usb = ClockDomain('usb')
        m.submodules.original = original = OriginalBus(ulpi=a, handle_clocking=False)
        m.submodules.optimized = optimized = OptimizedBus(ulpi=b, handle_clocking=False)
        async def bench(ctx):
            rng = random.Random(5102)
            for cycle in range(6000):
                direction = int(cycle % 101 >= 85)
                for port, value in [('tx_data', rng.randrange(256)),
                                    ('tx_valid', int(cycle % 31 < 24)),
                                    ('op_mode', (cycle // 300) % 2 * 2),
                                    ('xcvr_select', (cycle // 700) % 2),
                                    ('term_select', (cycle // 1000) % 2)]:
                    ctx.set(getattr(original, port), value)
                    ctx.set(getattr(optimized, port), value)
                nxt, data = rng.randrange(2), rng.randrange(256)
                for physical in (a, b):
                    ctx.set(physical.dir.i, direction)
                    ctx.set(physical.nxt.i, nxt)
                    ctx.set(physical.data.i, data)
                for name in ['tx_ready', 'rx_data', 'rx_valid', 'rx_active', 'busy']:
                    self.assertEqual(ctx.get(getattr(original, name)), ctx.get(getattr(optimized, name)), (cycle, name))
                self.assertEqual(ctx.get(a.data.oe), ctx.get(b.data.oe), cycle)
                self.assertEqual(ctx.get(a.stp.o), ctx.get(b.stp.o), cycle)
                if not direction:
                    self.assertEqual(ctx.get(a.data.o), ctx.get(b.data.o), cycle)
                await ctx.tick('usb')
        sim = Simulator(m)
        sim.add_clock(1 / 60e6, domain='usb')
        sim.add_testbench(bench)
        sim.run()

    def test_transmitter_pin_equivalence(self):
        m = Module()
        m.domains.usb = ClockDomain('usb')
        m.submodules.original = original = Original()
        m.submodules.optimized = optimized = Optimized()

        async def bench(ctx):
            rng = random.Random(230)
            for cycle in range(3000):
                for name, value in [('tx_data', rng.randrange(256)),
                                    ('tx_valid', rng.randrange(2)),
                                    ('op_mode', rng.choice([0, 2])),
                                    ('bus_idle', rng.randrange(2)),
                                    ('ulpi_nxt', rng.randrange(2))]:
                    ctx.set(getattr(original, name), value)
                    ctx.set(getattr(optimized, name), value)
                    if name == 'bus_idle': ctx.set(optimized.data_idle, value)
                for name in ['tx_ready', 'ulpi_out_req', 'ulpi_stp', 'busy']:
                    self.assertEqual(ctx.get(getattr(original, name)),
                                     ctx.get(getattr(optimized, name)), (cycle, name))
                # Data is selected onto the shared bus only while out_req is set.
                if ctx.get(original.ulpi_out_req) and ctx.get(original.bus_idle):
                    self.assertEqual(ctx.get(original.ulpi_data_out),
                                     ctx.get(optimized.ulpi_data_out), cycle)
                await ctx.tick('usb')

        sim = Simulator(m)
        sim.add_clock(1 / 60e6, domain='usb')
        sim.add_testbench(bench)
        sim.run()


if __name__ == '__main__':
    unittest.main()
