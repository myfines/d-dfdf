import unittest
from gesture_protocol import decode
from uart_gesture_sender import open_uart_tx, UartLink, PacketState

class FakeFpioa:
    UART1_TXD=91
    UART1_RXD=92
    calls=[]
    def set_function(self,*args,**kwargs):self.calls.append((args,kwargs))

class FakeUart:
    UART1=1;EIGHTBITS=8;PARITY_NONE=None;STOPBITS_ONE=1
    def __init__(self,*args,**kwargs):
        self.args=args;self.kwargs=kwargs;self.data=bytearray();self.closed=False
    def write(self,data):
        n=min(len(data),4);self.data.extend(data[:n]);return n
    def deinit(self):self.closed=True

class UartTests(unittest.TestCase):
    def test_required_rx_is_input_and_8n1_is_explicit(self):
        class Machine: FPIOA=FakeFpioa;UART=FakeUart
        FakeFpioa.calls=[]
        port=open_uart_tx(Machine)
        self.assertEqual(FakeFpioa.calls,[((9,91),dict(ie=0,oe=1,pu=1)),((10,92),dict(ie=1,oe=0,pu=1))])
        self.assertEqual(port.args,(1,))
        self.assertEqual(port.kwargs,dict(baudrate=115200,bits=8,parity=None,stop=1))

    def test_binary_partial_write_has_no_line_ending(self):
        port=FakeUart();link=UartLink(port);clock=[0]
        packet=PacketState().next_frame(0,lambda a,b:a-b)
        link.send(packet,lambda:clock[0],lambda a,b:a-b,lambda n:clock.__setitem__(0,clock[0]+n))
        self.assertEqual(bytes(port.data),packet)
        self.assertEqual(len(port.data),12)
        self.assertEqual(decode(port.data),(0,False,0,0,0))
        link.close();self.assertTrue(port.closed)

    def test_old_and_low_confidence_still_zero(self):
        state=PacketState();points=[100.0]*42
        state.publish(dict(status='TRACK',valid=True,value=.8),[points],[.59],0)
        self.assertEqual(decode(state.next_frame(1,lambda a,b:a-b)),(0,False,0,0,0))
        state.publish(dict(status='TRACK',valid=True,value=.8),[points],[.9],10)
        self.assertEqual(decode(state.next_frame(161,lambda a,b:a-b)),(1,False,0,0,0))

    def test_standalone_has_uart_but_no_usb_device_api(self):
        import importlib.util,pathlib,tempfile
        path=pathlib.Path(__file__).resolve().parents[1]/'scripts/build-k230-uart-sender.py'
        spec=importlib.util.spec_from_file_location('uart_builder',path)
        builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
        with tempfile.TemporaryDirectory() as folder:
            output=pathlib.Path(folder)/'sender.py';m=builder.build(output)
            source=output.read_text()
            self.assertNotIn('import usb',source)
            self.assertNotIn('from usb_gesture_sender import',source)
            self.assertNotIn('USBDBG',source)
            ns={'__name__':'offline_uart_review'};exec(compile(source,str(output),'exec'),ns)
            self.assertFalse(m['deployed']);self.assertIn('open_uart_tx',ns)

if __name__=='__main__':unittest.main()
