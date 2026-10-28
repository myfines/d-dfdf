import argparse,json
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--config',required=True);ap.add_argument('--output',required=True);args=ap.parse_args();cfg=json.loads(Path(args.config).read_text())
def quote(v):
 if any(c in v for c in '\r\n\x00'):raise ValueError('Invalid AT string')
 return v.replace('\\','\\\\').replace('"','\\"')
head=(f"POST /device/{cfg['device_token']} HTTP/1.1\r\nHost: {cfg['host']}\r\nContent-Length: 96\r\nContent-Type: text/plain\r\nConnection: keep-alive\r\n\r\n").encode()
commands=[b'AT+GMR\r\n',b'ATE0\r\n',b'AT+CWMODE_CUR=1\r\n',f'AT+CWJAP_CUR="{quote(cfg["ssid"])}","{quote(cfg["password"])}"\r\n'.encode(),b'AT+CIPMUX=1\r\n',f'AT+CIPSTART=0,"{cfg.get('device_protocol','SSL')}","{cfg["host"]}",{cfg.get('device_port',443)}\r\n'.encode(),f'AT+CIPSEND=0,{len(head)+96}\r\n'.encode(),head,b'AT+CIPCLOSE=0\r\n']
rom=b''.join(commands);offs=[];off=0
for data in commands:offs.append(off);off+=len(data)
v='`timescale 1ns/1ps\nmodule esp_cloud_config(input wire clk,input wire[3:0] section,input wire[9:0] index,output reg[7:0] data,output reg[9:0] length);\nreg[9:0] offset;reg[7:0] rom[0:%d];\ninitial begin\n'%(len(rom)-1)
v+='\n'.join(f"rom[{i}]=8'h{b:02x};" for i,b in enumerate(rom))+'\nend\nalways @* begin case(section)\n'
v+='\n'.join(f"{i}:begin offset={o};length={len(d)};end" for i,(o,d) in enumerate(zip(offs,commands)))+'\ndefault:begin offset=0;length=4;end\nendcase end\nalways @(posedge clk)data<=rom[offset+index];\nendmodule\n'
Path(args.output).write_text(v);print('Private cloud ROM generated; credentials omitted from output')
