"""Export ULPI host gateware; no board deployment. Run with pinned deps/PYTHONPATH."""
from pathlib import Path
from types import SimpleNamespace as NS
from amaranth import *
from amaranth.back import verilog
from cdc_host import K230CDCHost

class ExportHost(Elaboratable):
 def __init__(self):
  self.bus=NS(data=NS(i=Signal(8,name='ulpi_data_i'),o=Signal(8,name='ulpi_data_o'),oe=Signal(name='ulpi_data_oe')),dir=NS(i=Signal(name='ulpi_dir')),nxt=NS(i=Signal(name='ulpi_nxt')),stp=NS(o=Signal(name='ulpi_stp')))
  self.host=K230CDCHost(bus=self.bus,handle_clocking=False)
 def elaborate(self,platform):
  m=Module();m.domains.usb=ClockDomain('usb');m.submodules.host=self.host;return m

top=ExportHost();b=top.bus;h=top.host
ports=[ClockSignal('usb'),ResetSignal('usb'),b.data.i,b.data.o,b.data.oe,b.dir.i,b.nxt.i,b.stp.o,h.data.valid,h.data.ready,h.data.payload,h.ready]
Path('E:/gaoyun/tools/smoke/k230_usb_host_generated.v').write_text(verilog.convert(top,name='k230_usb_host_generated',ports=ports))
print('Exported E:/gaoyun/tools/smoke/k230_usb_host_generated.v')
