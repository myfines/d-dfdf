"""Candidate K230 CDC host engine on external BSD-licensed guh primitives.
No board pinout/clocking. This is not a deployable Tang Primer top.
"""
from amaranth import *
from amaranth.lib import stream, wiring
from amaranth.lib.memory import Memory
from amaranth.lib.cdc import ResetInserter
from amaranth.lib.wiring import Out
from guh.usbh.enumerator import USBHostEnumerator
from utmi_tx_pipeline import UTMITxPipeline
from luna_ulpi_timing import UTMITranslator
from guh.usbh.descriptor import USBDescriptorParser, EndpointFilter
from guh.usbh.sie import TransferType, TransferResponse, DataPID
from guh.protocol.descriptors import EndpointTransferType, InterfaceClass

class K230CDCHost(wiring.Component):
 data: Out(stream.Signature(unsigned(8)))
 ready: Out(1)
 diagnostic: Out(unsigned(16))
 def __init__(self,*,bus=None,handle_clocking=True):
  self.enumerator=USBHostEnumerator(bus=None,handle_clocking=handle_clocking,device_address=0x12,config_number=1,
   parser=USBDescriptorParser(endpoint_filter=EndpointFilter.IN,transfer_type=EndpointTransferType.BULK,interface_class=InterfaceClass.CDC_DATA),rx_fifo_depth=1024)
  sie=self.enumerator.sie
  if bus is not None: sie.utmi=UTMITranslator(ulpi=bus,handle_clocking=handle_clocking)
  sie.utmi=UTMITxPipeline(sie.utmi,elaborate_downstream=bus is not None)
  sie.translator=sie.utmi
  super().__init__()
 @property
 def sie(self):return self.enumerator.sie
 def elaborate(self,platform):
  m=Module();m.submodules.enum=enum=self.enumerator;c=enum.ctrl
  phy=self.sie.utmi;status=self.sie.ctrl.status
  m.d.comb+=self.diagnostic.eq(Cat(phy.line_state,enum.status.speed,
   enum.status.enumerated,enum.parser.o.valid,self.sie.reset_ctrl.reset_active,
   status.disconnected,status.response.as_value(),status.idle,
   phy.rx_active,phy.rx_error,phy.tx_valid))
  phase=Signal();index=Signal(4);pid=Signal(DataPID,init=DataPID.DATA0)
  watchdog=Signal(range(180000000));last_sof=Signal(11)
  m.submodules.packet=packet=Memory(shape=unsigned(8),depth=512,init=[])
  wp=packet.write_port(domain='usb');rp=packet.read_port(domain='comb')
  count=Signal(range(513));out_index=Signal(9);good=Signal();overflow=Signal()
  m.d.usb+=watchdog.eq(watchdog+1)
  setup0=Array(Const(b,8) for b in bytes.fromhex('2120000000000700'))
  setup1=Array(Const(b,8) for b in bytes.fromhex('2122030000000000'))
  coding=Array(Const(b,8) for b in bytes.fromhex('00c20100000008'))
  m.d.comb+=[c.xfer.dev_addr.eq(enum.status.dev_addr),c.rxs.ready.eq(1)]
  def issue(kind,data_pid,next_state):
   with m.If(c.status.idle):
    m.d.comb+=[c.xfer.start.eq(1),c.xfer.type.eq(kind),c.xfer.data_pid.eq(data_pid)]
    m.next=next_state
  def ack(next_state):
   with m.If(c.status.idle):
    with m.If(c.status.response==TransferResponse.ACK):
     m.d.usb+=watchdog.eq(0);m.next=next_state
    with m.Elif(c.status.response!=TransferResponse.NONE):m.next='FAULT'
  with m.FSM(domain='usb'):
   with m.State('ENUM'):
    with m.If(enum.status.enumerated & enum.parser.o.valid):m.next='LOAD_SETUP'
   with m.State('LOAD_SETUP'):
    m.d.comb+=[c.txs.valid.eq(1),c.txs.payload.eq(Mux(phase,setup1[index],setup0[index]))]
    with m.If(c.txs.ready):
     m.d.usb+=index.eq(index+1)
     with m.If(index==7):m.d.usb+=index.eq(0);m.next='SETUP'
   with m.State('SETUP'):issue(TransferType.SETUP,DataPID.DATA0,'WAIT_SETUP')
   with m.State('WAIT_SETUP'):
    with m.If(c.status.idle):
     with m.If(c.status.response==TransferResponse.ACK):
      m.d.usb+=watchdog.eq(0)
      with m.If(phase):m.next='STATUS'
      with m.Else():m.next='LOAD_DATA'
     with m.Elif(c.status.response!=TransferResponse.NONE):m.next='FAULT'
   with m.State('LOAD_DATA'):
    m.d.comb+=[c.txs.valid.eq(1),c.txs.payload.eq(coding[index])]
    with m.If(c.txs.ready):
     m.d.usb+=index.eq(index+1)
     with m.If(index==6):m.d.usb+=index.eq(0);m.next='OUT'
   with m.State('OUT'):issue(TransferType.OUT,DataPID.DATA1,'WAIT_OUT')
   with m.State('WAIT_OUT'):ack('STATUS')
   with m.State('STATUS'):issue(TransferType.IN,DataPID.DATA1,'WAIT_STATUS')
   with m.State('WAIT_STATUS'):
    with m.If(c.status.idle):
     with m.If(c.status.response==TransferResponse.ACK):
      m.d.usb+=watchdog.eq(0)
      with m.If(phase):m.next='POLL'
      with m.Else():m.d.usb+=phase.eq(1);m.next='LOAD_SETUP'
     with m.Elif(c.status.response==TransferResponse.NAK):m.next='STATUS'
     with m.Elif(c.status.response!=TransferResponse.NONE):m.next='FAULT'
   with m.State('POLL'):
    m.d.comb+=self.ready.eq(1)
    with m.If(c.status.idle & (c.status.sof_frame!=last_sof)):
     m.d.usb+=[last_sof.eq(c.status.sof_frame),count.eq(0),out_index.eq(0),overflow.eq(0)]
     m.d.comb+=c.xfer.ep_addr.eq(enum.parser.o.i_endp.number)
     issue(TransferType.IN,pid,'WAIT_POLL')
   with m.State('WAIT_POLL'):
    m.d.comb+=self.ready.eq(1)
    with m.If(c.rxs.valid):
     with m.If(count<512):m.d.comb+=[wp.en.eq(1),wp.addr.eq(count),wp.data.eq(c.rxs.payload)];m.d.usb+=count.eq(count+1)
     with m.Else():m.d.usb+=overflow.eq(1)
    with m.If(c.status.idle & (c.status.response!=TransferResponse.NONE)):
     m.d.usb+=good.eq(c.status.response==TransferResponse.ACK)
     with m.Switch(c.status.response):
      with m.Case(TransferResponse.ACK):m.d.usb+=[pid.eq(Mux(pid==DataPID.DATA0,DataPID.DATA1,DataPID.DATA0)),watchdog.eq(0)];m.next='FINISH'
      with m.Case(TransferResponse.NAK):m.d.usb+=watchdog.eq(0);m.next='FINISH'
      with m.Default():m.next='FAULT'
   with m.State('FINISH'):
    m.d.comb+=self.ready.eq(1)
    # Drain the SIE FIFO before deciding whether to commit this USB packet.
    with m.If(c.rxs.valid):
     with m.If(count<512):m.d.comb+=[wp.en.eq(1),wp.addr.eq(count),wp.data.eq(c.rxs.payload)];m.d.usb+=count.eq(count+1)
     with m.Else():m.d.usb+=overflow.eq(1)
    with m.Else():
     with m.If(good & ~overflow & (count!=0)):m.next='DELIVER'
     with m.Else():m.next='POLL'
   with m.State('DELIVER'):
    m.d.comb+=[self.ready.eq(1),rp.addr.eq(out_index),self.data.payload.eq(rp.data),self.data.valid.eq(1)]
    with m.If(self.data.ready):
     m.d.usb+=out_index.eq(out_index+1)
     with m.If(out_index==count-1):m.next='POLL'
   with m.State('FAULT'):
    m.d.usb+=watchdog.eq(179999999)
  return ResetInserter({'usb':(watchdog==179999999)|c.status.disconnected})(m)
