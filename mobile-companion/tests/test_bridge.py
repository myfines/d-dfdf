import importlib.util,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('bridge',Path(__file__).resolve().parents[1]/'bridge.py');bridge=importlib.util.module_from_spec(spec);spec.loader.exec_module(bridge)
class ProtocolTest(unittest.TestCase):
 def test_notes(self):
  for key in range(8):self.assertTrue(bridge.validate({'version':1,'type':'note_on','key':key,'value':1}))
  self.assertFalse(bridge.validate({'version':1,'type':'note_on','key':8,'value':1}))
 def test_invalid(self):
  for event in [None,{},[],{'version':2,'type':'all_off','key':-1,'value':0},{'version':1,'type':'brightness','key':-1,'value':2}]:self.assertFalse(bridge.validate(event))
 def test_controls(self):
  for kind,value in [('preset',2),('bend',-2),('brightness',1),('all_off',0)]:self.assertTrue(bridge.validate({'version':1,'type':kind,'key':-1,'value':value}))
 def test_reject_boolean_note_key(self):
  self.assertFalse(bridge.validate({'version':1,'type':'note_on','key':True,'value':1}))
if __name__=='__main__':unittest.main()
