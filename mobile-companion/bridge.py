"""Loopback-only command recorder. Does NOT drive or synthesize on an FPGA."""
import argparse,json,time
from http.server import BaseHTTPRequestHandler,HTTPServer
from pathlib import Path

TYPES={'note_on','note_off','preset','bend','brightness','all_off'}
def validate(event):
 if not isinstance(event,dict) or event.get('version')!=1 or event.get('type') not in TYPES:return False
 key=event.get('key');value=event.get('value')
 if type(key) is not int or type(value) not in (int,float):return False
 if event['type'] in ('note_on','note_off'):return 0<=key<8 and value in (0,1)
 if event['type']=='preset':return value in (0,1,2)
 if event['type']=='bend':return -2<=value<=2
 if event['type']=='brightness':return 0<=value<=1
 return key==-1 and value==0

def main():
 p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8765);p.add_argument('--log',type=Path,default=Path('phone-events.jsonl'));a=p.parse_args()
 class Handler(BaseHTTPRequestHandler):
  def do_POST(self):
   try:
    size=int(self.headers.get('Content-Length','0'))
    if self.path!='/event' or not 0<size<=2048:raise ValueError('request')
    event=json.loads(self.rfile.read(size))
    if not validate(event):raise ValueError('event')
    a.log.parent.mkdir(parents=True,exist_ok=True)
    with a.log.open('a',encoding='utf-8') as f:f.write(json.dumps({'host_time':time.time(),'event':event,'fpga_connected':False})+'\n')
    self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(b'{"received":true,"fpga_connected":false}')
   except (ValueError,TypeError):self.send_error(400)
  def log_message(self,*args):pass
 print(f'Development command recorder http://127.0.0.1:{a.port}/event; FPGA NOT connected',flush=True)
 HTTPServer(('127.0.0.1',a.port),Handler).serve_forever()
if __name__=='__main__':main()
