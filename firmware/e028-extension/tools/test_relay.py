import unittest,time
from web_relay import Controller
class RelayTests(unittest.TestCase):
 def test_offline(self):
  c=Controller();self.assertFalse(c.set_command('M00000001'))
 def test_live_and_release(self):
  c=Controller();c.poll('Gtest');self.assertTrue(c.set_command('M80000001'));self.assertIn('M80000001',c.poll('Gnext'));c.active_at=0;self.assertEqual(c.poll('Gidle'),'L00\nZ00\n')
 def test_adsr(self):
  c=Controller();c.poll('G');self.assertTrue(c.set_command('G19CDA074'));self.assertIn('G19CDA074',c.poll('G'));self.assertFalse(c.set_command('G19CDA075'))
 def test_invalid_and_stop(self):
  c=Controller();c.poll('G');self.assertFalse(c.set_command('MZZZZZZZZ'));self.assertTrue(c.set_command('M00000003'));self.assertTrue(c.set_command('L00'));self.assertEqual(c.poll('G'),'L00\nZ00\n')
 def test_keymap_replay_bounded(self):
  c=Controller();c.poll('G')
  for i in range(32):
   n=31-i;v=(16<<24)|(i<<16)|(n<<8)|(16^i^n)
   self.assertTrue(c.set_command('U%08X'%v))
  seen=set()
  for _ in range(8):
   p=c.poll('G');self.assertLess(len(p),256)
   seen.update(x for x in p.splitlines() if x.startswith('U'))
  self.assertEqual(len(seen),32)
  self.assertFalse(c.set_command('U10201F2F'))
  self.assertTrue(c.set_command('U00000000'));self.assertEqual(c.keymaps,{})
  self.assertTrue(c.set_command('U10001F0F'));p=c.poll('G');self.assertIn('U00000000',p);self.assertIn('U10001F0F',p)
class HttpTests(unittest.TestCase):
 def test_chunked_request_does_not_corrupt_keepalive(self):
  import socket,tempfile,subprocess,sys,http.client,json
  from pathlib import Path
  with tempfile.TemporaryDirectory() as d:
   sock=socket.socket();sock.bind(('127.0.0.1',0));port=sock.getsockname()[1];sock.close()
   p=Path(d)/'config.json';p.write_text(json.dumps({'port':port,'device_token':'unit-device','browser_token':'unit-browser'}))
   proc=subprocess.Popen([sys.executable,str(Path(__file__).with_name('web_relay.py')),'--config',str(p)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   try:
    for _ in range(50):
     try:
      c=http.client.HTTPConnection('127.0.0.1',port,timeout=2);c.connect();break
     except OSError:time.sleep(.02)
    c.request('POST','/api/c/M00000001',body=iter([b'abc']),encode_chunked=True)
    r=c.getresponse();self.assertEqual(r.status,401);r.read()
    c.request('GET','/');r=c.getresponse();self.assertEqual(r.status,200);r.read()
    c.request('POST','/device/unit-device',body=b'G-unit');r=c.getresponse();self.assertEqual(r.read(),b'L00\nZ00\n')
    c.close()
   finally:proc.terminate();proc.wait(timeout=3)
if __name__=='__main__':unittest.main()
