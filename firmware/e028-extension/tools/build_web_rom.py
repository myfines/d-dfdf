from pathlib import Path
import gzip
ROOT=Path(__file__).resolve().parents[1]
def response(body,status='200 OK',ctype='text/plain',extra=''):
 return (f'HTTP/1.1 {status}\r\nContent-Type: {ctype}; charset=utf-8\r\nContent-Length: {len(body)}\r\nCache-Control: no-store\r\nConnection: close\r\n{extra}\r\n'.encode()+body)
page=response(gzip.compress((ROOT/'web/index.html').read_bytes(),mtime=0),ctype='text/html',extra='Content-Encoding: gzip\r\n')
parts=[page,response(b'OK\n'),response(b' '*96)[:-96],response(b'Invalid request\n','400 Bad Request')]
assert len(page)<=2048, 'ESP8266 AT CIPSEND limit'
rom=b''.join(parts);offset=0;sizes=[]
for name,data in zip(['PAGE','ACK','STATUS','BAD'],parts):
 sizes.append(f' localparam HTTP_{name}_OFFSET={offset}, HTTP_{name}_LENGTH={len(data)};');offset+=len(data)
text='`timescale 1ns/1ps\nmodule esp_http_rom(input wire clk,input wire[13:0] address,output reg[7:0] data);\nreg[7:0] rom[0:%d];\ninitial begin\n'%(len(rom)-1)
text+='\n'.join(f"rom[{i}]=8'h{b:02x};" for i,b in enumerate(rom))+'\nend\nalways @(posedge clk)data<=rom[address];\nendmodule\n'
(ROOT/'src/esp_http_rom.v').write_text(text)
p=ROOT/'src/esp_at_control.v';s=p.read_text();import re
for name,line in zip(['PAGE','ACK','STATUS','BAD'],sizes):
 s=re.sub(r'\s*localparam HTTP_'+name+r'_OFFSET=\d+, HTTP_'+name+r'_LENGTH=\d+;', '\n'+line,s)
p.write_text(s)
print('gzip HTTP response bytes',len(page),'ROM',len(rom))
