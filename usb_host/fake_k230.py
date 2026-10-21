"""Independent simulated CDC device with captured K230 HS descriptors.
Not a model of K230 firmware/AI; tests host requests and packet transport only.
"""
from amaranth import *
from luna.gateware.interface.utmi import UTMIInterface
from luna.gateware.usb.usb2.control import USBControlEndpoint
from luna.gateware.usb.usb2.request import USBRequestHandler
from luna.usb2 import USBDevice, USBStreamInEndpoint
from usb_protocol.emitters import DeviceDescriptorCollection

class CDCControl(USBRequestHandler):
 def __init__(self):
  super().__init__();self.lines=Signal(16);self.line_coding=Signal(56);self.stall=Signal();self.stall_seen=Signal()
 def elaborate(self,platform):
  m=Module();i=self.interface;s=i.setup;count=Signal(range(8));claimed=Signal();request=Signal(8)
  m.d.comb+=i.claim.eq((s.type==1)&(s.recipient==1)&(s.index==0))
  with m.If(s.received):
   m.d.usb+=[claimed.eq((s.type==1)&(s.recipient==1)&(s.index==0)),request.eq(s.request),count.eq(0)]
   with m.If((s.type==1)&(s.request==0x22)&(s.length==0)):m.d.usb+=self.lines.eq(s.value)
  with m.If(claimed):
   with m.If((request==0x20)&i.rx.valid&i.rx.next):
    m.d.usb+=[self.line_coding.word_select(count,8).eq(i.rx.payload),count.eq(count+1)]
   with m.If(i.rx_ready_for_response):
    with m.If(self.stall):m.d.comb+=i.handshakes_out.stall.eq(1);m.d.usb+=self.stall_seen.eq(1)
    with m.Else():m.d.comb+=i.handshakes_out.ack.eq(1)
   with m.If(i.status_requested):m.d.comb+=self.send_zlp()
  return m

class FakeK230(Elaboratable):
 def __init__(self,split=False,wide=False):
  self.utmi=UTMIInterface();self.control=CDCControl();self.enable=Signal(init=1);self.split=split
  import sys
  from pathlib import Path
  sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'k230'))
  from gesture_protocol import encode
  self.packets=(b"".join(encode(i,True,750,250,95)for i in range(43)) if wide else encode(0,True,750,250,95)+encode(1,False,0,0,0))
 def elaborate(self,platform):
  m=Module();usb=USBDevice(bus=self.utmi);usb.always_fs=False;usb.data_clock=60e6;m.submodules.usb=usb
  descriptors=DeviceDescriptorCollection()
  descriptors.add_descriptor(bytes.fromhex('12010002ef0201400912d1ab000101020301'))
  descriptors.add_descriptor(bytes.fromhex('0902690003010080fa080b000202020100090400000102020102052400100105240100010424020205240600010705820308000a09040100020a00000007050102000200070581020002000904020003060101000705030200020007058302000200070584031c0006'))
  ep0=USBControlEndpoint(utmi=self.utmi,max_packet_size=64);ep0.add_standard_request_handlers(descriptors);ep0.add_request_handler(self.control);usb.add_endpoint(ep0)
  endpoint=USBStreamInEndpoint(endpoint_number=1,max_packet_size=512);usb.add_endpoint(endpoint)
  index=Signal(range(len(self.packets)+1));rom=Array(Const(b,8)for b in self.packets)
  m.d.comb+=[usb.connect.eq(1),usb.full_speed_only.eq(0),endpoint.stream.valid.eq(self.enable&self.control.lines[0]&(index<len(self.packets))),endpoint.stream.payload.eq(rom[index]),endpoint.stream.last.eq((index==len(self.packets)-1)|((index==5) if self.split else 0))]
  with m.If(endpoint.stream.valid&endpoint.stream.ready):m.d.usb+=index.eq(index+1)
  return m
