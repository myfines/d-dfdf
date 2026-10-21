"""Buffered UTMI TX with explicit EOP words and no PHY-to-source ready path."""
from amaranth import Elaboratable, Module, Signal, DomainRenamer, Cat
from amaranth.lib.fifo import SyncFIFOBuffered


class UTMITxPipeline(Elaboratable):
    def __init__(self, downstream, *, elaborate_downstream=False):
        self.downstream = downstream
        self.elaborate_downstream = elaborate_downstream
        self.tx_data = Signal(8)
        self.tx_valid = Signal()
        self.tx_ready = Signal()
        self.op_mode = Signal(2)
        self.xcvr_select = Signal(2)
        self.term_select = Signal()

    def __getattr__(self, name):
        return getattr(self.downstream, name)

    def elaborate(self, platform):
        m = Module()
        if self.elaborate_downstream:
            m.submodules.phy = self.downstream
        # Explicit EOP words preserve packet gaps even if PHY backpressure spans
        # multiple packets. Upstream ready depends on occupancy, never PHY NXT.
        fifo = SyncFIFOBuffered(width=9, depth=4)
        m.submodules.queue = DomainRenamer('usb')(fifo)
        in_packet = Signal()
        end_pending = Signal()
        end_word = end_pending | (in_packet & ~self.tx_valid)
        m.d.comb += [
            self.tx_ready.eq(fifo.w_rdy & ~end_pending),
            fifo.w_en.eq(fifo.w_rdy & (end_word | self.tx_valid)),
            fifo.w_data.eq(Cat(self.tx_data, ~end_word)),
            self.downstream.tx_valid.eq(fifo.r_rdy & fifo.r_data[8]),
            self.downstream.tx_data.eq(fifo.r_data[:8]),
            fifo.r_en.eq(fifo.r_rdy & (~fifo.r_data[8] | self.downstream.tx_ready))]
        m.d.usb += [self.downstream.op_mode.eq(self.op_mode),
                    self.downstream.xcvr_select.eq(self.xcvr_select),
                    self.downstream.term_select.eq(self.term_select)]
        with m.If(end_word):
            m.d.usb += [end_pending.eq(~fifo.w_rdy), in_packet.eq(0)]
        with m.Elif(self.tx_valid & self.tx_ready):
            m.d.usb += in_packet.eq(1)
        return m
