"""Local demo AP client; renew a 5-second volume lease, no FPGA flashing."""
import argparse,socket,time

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--host',default='192.168.4.1')
    p.add_argument('--port',type=int,default=9000)
    p.add_argument('--volume',type=int,default=255,help='0..255')
    p.add_argument('--seconds',type=float,default=15)
    a=p.parse_args()
    if not 0<=a.volume<=255 or not 0<a.seconds<=3600:p.error('volume 0..255; seconds >0 and <=3600')
    packet=f'V{a.volume:02X}\n'.encode('ascii')
    with socket.create_connection((a.host,a.port),timeout=3) as s:
        print('TCP connected; command sent without application ACK. Audio is not yet verified.')
        end=time.monotonic()+a.seconds
        while time.monotonic()<end:
            s.sendall(packet)
            time.sleep(min(1,max(0,end-time.monotonic())))
    print('Closed; FPGA should return to local volume within 5 seconds. Verify on hardware.')

if __name__=='__main__':main()
