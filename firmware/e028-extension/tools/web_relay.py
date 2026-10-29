"""Authenticated browser/ESP HTTP relay. Credentials stay outside the repository."""
import argparse,hmac,json,re,time,threading
from recording_store import RecordingStore
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
class Controller:
 def __init__(self):
  self.recording=RecordingStore();self.pending=[];self.keymaps={};self.map_cursor=0;self.map_reset_pending=False;self.lock=threading.Lock();self.device_at=0;self.active_at=0;self.telemetry='';self.values={'G':'00000000','V':'40','T':'00','F':'00','S':'00','B':'2000','X':'00','Y':'80','M':'00000000','R':'00','H':'00','D':'00'}
 def set_command(self,line):
  if not re.fullmatch(r'(?:[MGUWC][0-9A-Fa-f]{8}|B[0-9A-Fa-f]{4}|[VTEKPQLXYFSRHD][0-9A-Fa-f]{2})',line):return False
  if line[0]=='G' and int(line[1:],16)!=0:
   v=int(line[1:],16)
   if v>>28!=1 or (v&255)!=((v>>24)^(v>>16)^(v>>8))&255:return False
  if line[0]=='U' and int(line[1:],16)!=0:
   v=int(line[1:],16)
   if v>>24!=16 or (v>>16)&255>31 or (v>>8)&255>31 or (v&255)!=((v>>24)^(v>>16)^(v>>8))&255:return False
  if line[0] in 'WC':
   v=int(line[1:],16);a,b,c,d=(v>>24)&255,(v>>16)&255,(v>>8)&255,v&255
   if line[0]=='W':
    if d!=(a^b^c) or not ((a<64 and (b<32 or b==255) and c>0) or (a==255 and ((b==0 and c==0) or (b==1 and 1<=c<=64)))):return False
   elif v!=0 and (a!=16 or d!=(a^b^c) or not ((b==1 and c==0) or (b==2 and c<128))):return False
  with self.lock:
   if time.monotonic()-self.device_at>10:return False
   k=line[0]
   if k=='L':
    self.active_at=0;self.pending.clear();self.values.update(M='00000000',R='00',D='00',H='00');self.values.pop('C',None)
   else:
    self.active_at=time.monotonic()
    if k=='W' or (k=='C' and int(line[1:],16)==0x10010011):
     if len(self.pending)>=128:return False
     if k=='C':self.values.pop('C',None)
     self.pending.append(line.upper())
    elif k=='U':
     if int(line[1:],16)==0:self.keymaps.clear();self.values['U']='00000000';self.map_reset_pending=True
     else:self.values.pop('U',None);self.keymaps[(int(line[1:],16)>>16)&255]=line.upper()
    elif k not in 'Q':self.values[k]=line[1:].upper()
   return True
 def poll(self,telemetry):
  with self.lock:
   self.device_at=time.monotonic();self.telemetry=telemetry[:256];self.recording.ingest(telemetry)
   if time.monotonic()-self.active_at>5:return 'L00\nZ00\n'
   maps=list(self.keymaps.values());extra='U00000000\n' if self.map_reset_pending and 'U' not in self.values else '';self.map_reset_pending=False
   for _ in range(min(4,len(maps))):
    extra+=maps[self.map_cursor%len(maps)]+'\n';self.map_cursor+=1
   queued=''.join(x+'\n' for x in self.pending[:4]);del self.pending[:4]
   return ''.join(k+v+'\n' for k,v in self.values.items())+extra+queued+'Z00\n'
 def status(self):
  with self.lock:return {'online':time.monotonic()-self.device_at<5,'age':round(time.monotonic()-self.device_at,2),'telemetry':self.telemetry,'transport':'ESP outbound HTTP (legacy AT)' ,'version':'device telemetry authoritative','recording':self.recording.status(),'queued_commands':len(self.pending)}
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
   if self.path=='/api/recording.wav' and self.authorized():
    with control.lock:
     try:data=control.recording.wav()
     except ValueError:return self.respond(409,'Recording incomplete')
    return self.respond(200,data,'audio/wav')
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
