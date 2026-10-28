"""Authenticated browser/ESP HTTP relay. Credentials stay outside the repository."""
import argparse,hmac,json,re,time,threading
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
class Controller:
 def __init__(self):
  self.lock=threading.Lock();self.device_at=0;self.active_at=0;self.telemetry='';self.values={'V':'40','T':'00','F':'00','S':'00','B':'2000','X':'00','Y':'80','M':'00000000','R':'00','H':'00','D':'00'}
 def set_command(self,line):
  if not re.fullmatch(r'(?:M[0-9A-Fa-f]{8}|B[0-9A-Fa-f]{4}|[VTEKPQLXYFSRHD][0-9A-Fa-f]{2})',line):return False
  with self.lock:
   if time.monotonic()-self.device_at>10:return False
   k=line[0]
   if k=='L':self.active_at=0
   else:
    self.active_at=time.monotonic()
    if k not in 'Q':self.values[k]=line[1:].upper()
   return True
 def poll(self,telemetry):
  with self.lock:
   self.device_at=time.monotonic();self.telemetry=telemetry[:256]
   if time.monotonic()-self.active_at>5:return 'L00\nZ00\n'
   return ''.join(k+v+'\n' for k,v in self.values.items())+'Z00\n'
 def status(self):
  with self.lock:return {'online':time.monotonic()-self.device_at<5,'age':round(time.monotonic()-self.device_at,2),'telemetry':self.telemetry,'transport':'ESP outbound HTTP (legacy AT)' ,'version':'E031'}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--config',required=True);args=ap.parse_args();cfg=json.loads(Path(args.config).read_text());control=Controller();page=Path(__file__).resolve().parents[1]/'web/relay.html'
 class Handler(BaseHTTPRequestHandler):
  protocol_version='HTTP/1.1'
  def log_message(self,*args):pass # Paths can contain device credentials.
  def respond(self,code,body,ctype='text/plain'):
   if isinstance(body,str):body=body.encode()
   self.send_response(code);self.send_header('Content-Type',ctype+'; charset=utf-8');self.send_header('Content-Length',str(len(body)));self.send_header('Cache-Control','no-store');self.send_header('X-Content-Type-Options','nosniff');self.send_header('Referrer-Policy','no-referrer');self.end_headers();self.wfile.write(body)
  def authorized(self):return hmac.compare_digest(self.headers.get('Authorization',''),'Bearer '+cfg['browser_token'])
  def do_GET(self):
   if self.path.split('?',1)[0]=='/':return self.respond(200,page.read_bytes(),'text/html')
   if self.path=='/api/state' and self.authorized():return self.respond(200,json.dumps(control.status()),'application/json')
   return self.respond(401,'Unauthorized')
  def do_POST(self):
   try:n=int(self.headers.get('Content-Length','0'))
   except ValueError:return self.respond(400,'Length')
   if not 0<=n<=512:self.close_connection=True;return self.respond(413,'Too large')
   if self.headers.get('Transfer-Encoding','').lower()=='chunked':
    chunks=[];total=0
    try:
     while True:
      size=int(self.rfile.readline(64).strip().split(b';')[0],16)
      if size==0:
       if self.rfile.readline(64)!=b'\r\n':raise ValueError('Trailers unsupported')
       break
      total+=size
      if total>512:raise ValueError('Too large')
      chunks.append(self.rfile.read(size))
      if self.rfile.read(2)!=b'\r\n':raise ValueError('Chunk framing')
     body=b''.join(chunks)
    except (ValueError,OSError):
     self.close_connection=True;return self.respond(400,'Invalid chunks')
   else:body=self.rfile.read(n)
   if hmac.compare_digest(self.path,'/device/'+cfg['device_token']):return self.respond(200,control.poll(body.decode('ascii',errors='replace')))
   if not self.authorized():return self.respond(401,'Unauthorized')
   if self.path.startswith('/api/c/'):
    ok=control.set_command(self.path[7:]);return self.respond(200 if ok else 409,'OK' if ok else 'Device offline or invalid command')
   return self.respond(404,'Missing')
 ThreadingHTTPServer(('127.0.0.1',cfg['port']),Handler).serve_forever()
if __name__=='__main__':main()
