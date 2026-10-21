"""Packet-level integration test. Requires pinned external guh + LUNA; no hardware."""
import unittest
from amaranth import *
from amaranth.sim import Simulator
from guh.usbh.types import USBHostSpeed
from guh.util import test_util
from cdc_host import K230CDCHost
from fake_k230 import FakeK230

class CDCTest(unittest.TestCase):
 def run_cdc(self,split=False,delay=False,stall=False,wide=False):
  test_util.patch_usb_timing_for_simulation()
  m=Module();host=K230CDCHost();device=FakeK230(split=split,wide=wide)
  m.submodules.host=DomainRenamer({'usb':'sync'})(host)
  m.submodules.device=DomainRenamer({'usb':'sync'})(device)
  events=test_util.connect_utmi(m,host.sie.utmi.downstream,device.utmi)
  received=[]
  async def bench(ctx):
   ctx.set(host.data.ready,1)
   ctx.set(device.control.stall,int(stall))
   if delay:ctx.set(device.enable,0)
   ticks_ready=0;nak_seen=False;seen_ready=False;held=None
   for cycle in range(160000):
    await ctx.tick()
    is_ready=bool(ctx.get(host.ready))
    if seen_ready and not stall:self.assertTrue(is_ready,'ready dropped between packets')
    seen_ready |= is_ready
    if is_ready:ticks_ready+=1
    accepting=(cycle%5)!=0
    ctx.set(host.data.ready,int(accepting))
    if delay and ticks_ready>10000:ctx.set(device.enable,1)
    from guh.usbh.sie import TransferResponse
    if ctx.get(host.enumerator.ctrl.status.response)==TransferResponse.NAK:nak_seen=True
    if ctx.get(host.data.valid):
     payload=ctx.get(host.data.payload)
     if held is not None:self.assertEqual(payload,held,'backpressure payload changed')
     held=None if accepting else payload
     if accepting:received.append(payload)
    if stall and ctx.get(device.control.stall_seen):
     for _ in range(200):await ctx.tick()
     self.assertFalse(ctx.get(host.ready));self.assertEqual(received,[]);return
    if len(received)>=len(device.packets):break
   if delay:self.assertTrue(nak_seen,'No NAK exercised')
   self.assertTrue(ctx.get(host.ready),'CDC init incomplete')
   self.assertEqual(ctx.get(host.enumerator.status.speed),USBHostSpeed.HIGH)
   self.assertEqual(ctx.get(host.enumerator.parser.o.i_endp.number),1)
   self.assertEqual(ctx.get(device.control.line_coding),int.from_bytes(bytes.fromhex('00c20100000008'),'little'))
   self.assertEqual(ctx.get(device.control.lines),3)
   self.assertEqual(received,list(device.packets))
   from gesture_protocol import decode
   self.assertEqual(decode(bytes(received[:12])),(0,True,750,250,95))
   self.assertEqual(decode(bytes(received[12:24])),(1,True,750,250,95) if wide else (1,False,0,0,0))
   from pathlib import Path
   Path('E:/gaoyun/tools/smoke/usb-gesture-received.hex').write_text(''.join('%02x\n'%b for b in received[:24]))
  sim=Simulator(m);sim.add_clock(1/60e6);sim.add_testbench(bench)
  sim.add_process(test_util.make_packet_capture_process(host.sie.utmi.downstream,device.utmi,events,'k230-cdc-%d%d%d%d.pcap'%(split,delay,stall,wide)))
  sim.run()

 def test_high_speed_cdc(self):self.run_cdc()
 def test_fragmented_gesture_and_nak(self):self.run_cdc(split=True,delay=True)
 def test_full_512_bulk_and_backpressure(self):self.run_cdc(wide=True)
 def test_class_stall_no_data(self):self.run_cdc(stall=True)

if __name__=='__main__':unittest.main()
