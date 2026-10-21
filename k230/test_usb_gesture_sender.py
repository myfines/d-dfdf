import unittest
from gesture_protocol import decode
from usb_gesture_sender import PacketState, write_frame

class SenderTests(unittest.TestCase):
    def sample(self,confidence=.75):
        p=[100.0]*42;p[11]=100;p[35]=379
        return {'status':'TRACK','valid':True,'value':.75},[p],[confidence]

    def test_low_confidence_is_zero_and_threshold_is_unchanged(self):
        state=PacketState()
        state.publish(*self.sample(.599),100)
        self.assertEqual(decode(state.next_frame(100,lambda a,b:a-b)),(0,False,0,0,0))
        state.publish(*self.sample(.60),100)
        self.assertEqual(decode(state.next_frame(101,lambda a,b:a-b)),(1,True,750,500,60))

    def test_stale_hold_and_wrap(self):
        state=PacketState();state.sequence=255
        state.publish(*self.sample(),100)
        self.assertEqual(decode(state.next_frame(251,lambda a,b:a-b)),(255,False,0,0,0))
        r,h,s=self.sample();r['status']='HOLD';r['valid']=False
        state.publish(r,h,s,252)
        self.assertEqual(decode(state.next_frame(252,lambda a,b:a-b)),(0,False,0,0,0))

    def test_partial_write_preserves_bytes(self):
        class Stream:
            def __init__(self):self.data=bytearray()
            def write(self,data):
                n=min(3,len(data));self.data.extend(data[:n]);return n
        stream=Stream();clock=[0]
        write_frame(stream,b'123456789012',lambda:clock[0],lambda a,b:a-b,lambda n:clock.__setitem__(0,clock[0]+n))
        self.assertEqual(stream.data,b'123456789012')

    def test_stalled_write_times_out(self):
        class Stream:
            def write(self,data):return None
        clock=[0]
        with self.assertRaises(OSError):
            write_frame(Stream(),b'123456789012',lambda:clock[0],lambda a,b:a-b,lambda n:clock.__setitem__(0,clock[0]+n))
        self.assertLessEqual(clock[0],25)

    def test_eagain_retry_and_invalid_write_length(self):
        class Stream:
            def __init__(self):self.calls=0
            def write(self,data):
                self.calls+=1
                if self.calls==1:raise OSError(11)
                return len(data)
        clock=[0];stream=Stream()
        write_frame(stream,b'123456789012',lambda:clock[0],lambda a,b:a-b,lambda n:clock.__setitem__(0,clock[0]+n))
        self.assertEqual(stream.calls,2)
        class Broken:
            def write(self,data):return 13
        with self.assertRaises(OSError):write_frame(Broken(),b'123456789012',lambda:0,lambda a,b:a-b,lambda n:None)

    def test_standalone_build_has_no_external_codec_import(self):
        import importlib.util,pathlib,tempfile
        path=pathlib.Path(__file__).resolve().parents[1]/'scripts/build-k230-usb-sender.py'
        spec=importlib.util.spec_from_file_location('bundle_builder',path)
        builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
        with tempfile.TemporaryDirectory() as directory:
            output=pathlib.Path(directory)/'sender.py';manifest=builder.build(output)
            source=output.read_text()
            self.assertNotIn('from gesture_protocol import',source)
            self.assertNotIn('from usb_gesture_state import',source)
            ns={'__name__':'review_only'};exec(compile(source,str(output),'exec'),ns)
            state=ns['PacketState']();state.publish(*self.sample(.59),0)
            self.assertEqual(decode(state.next_frame(0,lambda a,b:a-b)),(0,False,0,0,0))
            self.assertFalse(manifest['deployed'])

if __name__=='__main__':unittest.main()
