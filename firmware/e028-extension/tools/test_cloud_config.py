import unittest,tempfile,subprocess,sys,json,re
from pathlib import Path
class ConfigTests(unittest.TestCase):
 def test_transport_selection(self):
  with tempfile.TemporaryDirectory() as d:
   p=Path(d);c={'ssid':'test','password':'test-only','host':'example.com','device_token':'demo','device_protocol':'TCP','device_port':80};(p/'c.json').write_text(json.dumps(c))
   subprocess.run([sys.executable,str(Path(__file__).with_name('build_cloud_config.py')),'--config',str(p/'c.json'),'--output',str(p/'rom.v')],check=True,capture_output=True)
   b=bytes(int(x,16) for x in re.findall(r"8'h([0-9a-f]{2})",(p/'rom.v').read_text()))
   self.assertIn(b'AT+CIPSTART=0,"TCP","example.com",80\r\n',b)
if __name__=='__main__':unittest.main()
