"""Read USB hub connection/descriptor IOCTLs on Windows; no driver replacement."""
import ctypes as C
from ctypes import wintypes as W
import json
import pathlib
import struct
import sys
import uuid

setup = C.WinDLL('setupapi', use_last_error=True)
kernel = C.WinDLL('kernel32', use_last_error=True)
class GUID(C.Structure):
    _fields_ = [('raw', C.c_ubyte * 16)]
class INTERFACE(C.Structure):
    _fields_ = [('cbSize', W.DWORD), ('guid', GUID), ('flags', W.DWORD), ('reserved', C.c_void_p)]
setup.SetupDiGetClassDevsW.argtypes = [C.POINTER(GUID), W.LPCWSTR, W.HWND, W.DWORD]
setup.SetupDiGetClassDevsW.restype = C.c_void_p
setup.SetupDiEnumDeviceInterfaces.argtypes = [C.c_void_p, C.c_void_p, C.POINTER(GUID), W.DWORD, C.POINTER(INTERFACE)]
setup.SetupDiGetDeviceInterfaceDetailW.argtypes = [C.c_void_p, C.POINTER(INTERFACE), C.c_void_p, W.DWORD, C.POINTER(W.DWORD), C.c_void_p]
setup.SetupDiDestroyDeviceInfoList.argtypes = [C.c_void_p]
kernel.CreateFileW.argtypes = [W.LPCWSTR, W.DWORD, W.DWORD, C.c_void_p, W.DWORD, W.DWORD, W.HANDLE]
kernel.CreateFileW.restype = W.HANDLE
kernel.DeviceIoControl.argtypes = [W.HANDLE, W.DWORD, C.c_void_p, W.DWORD, C.c_void_p, W.DWORD, C.POINTER(W.DWORD), C.c_void_p]
kernel.CloseHandle.argtypes = [W.HANDLE]
INVALID = C.c_void_p(-1).value

def ioctl(handle, code, data, size):
    buf = C.create_string_buffer(size)
    C.memmove(buf, data, len(data))
    count = W.DWORD()
    if not kernel.DeviceIoControl(handle, code, buf, size, buf, size, C.byref(count), None):
        raise C.WinError(C.get_last_error())
    return buf.raw[:count.value]

def hubs():
    guid = GUID((C.c_ubyte * 16).from_buffer_copy(uuid.UUID('f18a0e88-c30c-11d0-8815-00a0c906bed8').bytes_le))
    devices = setup.SetupDiGetClassDevsW(C.byref(guid), None, None, 0x12)
    if devices == INVALID: raise C.WinError(C.get_last_error())
    try:
        index = 0
        while True:
            interface = INTERFACE(); interface.cbSize = C.sizeof(interface)
            if not setup.SetupDiEnumDeviceInterfaces(devices, None, C.byref(guid), index, C.byref(interface)):
                if C.get_last_error() == 259: break
                raise C.WinError(C.get_last_error())
            needed = W.DWORD()
            setup.SetupDiGetDeviceInterfaceDetailW(devices, C.byref(interface), None, 0, C.byref(needed), None)
            detail = C.create_string_buffer(needed.value)
            C.cast(detail, C.POINTER(W.DWORD))[0] = 8 if C.sizeof(C.c_void_p) == 8 else 6
            if not setup.SetupDiGetDeviceInterfaceDetailW(devices, C.byref(interface), detail, needed.value, None, None):
                raise C.WinError(C.get_last_error())
            yield C.wstring_at(C.addressof(detail) + 4)
            index += 1
    finally:
        setup.SetupDiDestroyDeviceInfoList(devices)

def descriptor(handle, port, dtype, index=0, lang=0, length=4096):
    request = struct.pack('<IBBHHH', port, 0x80, 6, dtype << 8 | index, lang, length)
    raw = ioctl(handle, 0x220410, request, 12 + length)
    return raw[12:]

def main():
    results, errors = [], []
    for path in hubs():
        handle = kernel.CreateFileW(path, 0x40000000, 3, None, 3, 0, None)
        if handle == INVALID:
            errors.append({'hub': path, 'error': str(C.WinError(C.get_last_error()))}); continue
        try:
            ports = ioctl(handle, 0x220408, b'\0'*4, 80)[6]
            for port in range(1, ports+1):
                try:
                    raw = ioctl(handle, 0x220448, struct.pack('<I', port), 4096)
                    if len(raw) < 35: continue
                    dev = raw[4:22]
                    vid, pid = struct.unpack_from('<HH', dev, 8)
                    if (vid, pid) != (0x1209, 0xabd1): continue
                    item = {'hub':path,'port':port,'vid':hex(vid),'pid':hex(pid),
                            'device_descriptor_hex':dev.hex(),'connection_info_hex':raw.hex(),
                            'current_configuration':raw[22], 'speed_code':raw[23],
                            'device_address':struct.unpack_from('<H',raw,25)[0],
                            'speed':{0:'low',1:'full',2:'high',3:'super'}.get(raw[23],'unknown'),
                            'connection_status':struct.unpack_from('<I',raw,31)[0]}
                    config = descriptor(handle,port,2, length=9)
                    total = struct.unpack_from('<H',config,2)[0]
                    config = descriptor(handle,port,2,length=total)
                    item['configuration_descriptor_hex'] = config.hex()
                    for name,dtype,length in [('device_qualifier',6,10),('other_speed_configuration',7,9),('supported_languages',3,255)]:
                        try:
                            extra=descriptor(handle,port,dtype,length=length)
                            if dtype==7:
                                extra=descriptor(handle,port,dtype,length=struct.unpack_from('<H',extra,2)[0])
                            item[name+'_hex']=extra.hex()
                        except (OSError,struct.error) as exc:
                            item[name+'_error']=str(exc)
                    parts=[]; offset=0
                    while offset < len(config):
                        n=config[offset]
                        if n<2 or offset+n>len(config): raise ValueError('malformed descriptor')
                        b=config[offset:offset+n]; part={'offset':offset,'type':b[1],'hex':b.hex()}
                        if b[1]==4: part.update(interface=b[2],alternate=b[3],endpoints=b[4],class_code=b[5],subclass=b[6],protocol=b[7])
                        if b[1]==5: part.update(address=hex(b[2]),transfer_type=b[3]&3,max_packet_size=struct.unpack_from('<H',b,4)[0],interval=b[6])
                        parts.append(part); offset+=n
                    item['descriptors']=parts
                    item['strings']={}
                    for idx in set(dev[14:17]):
                        if idx:
                            try: item['strings'][idx]=descriptor(handle,port,3,idx,0x409,255).hex()
                            except OSError as exc: item['strings'][idx]={'error':str(exc)}
                    results.append(item)
                except (OSError,ValueError) as exc:
                    errors.append({'hub':path,'port':port,'error':str(exc)})
        finally:
            kernel.CloseHandle(handle)
    output={'devices':results,'errors':errors}
    target=pathlib.Path(sys.argv[1]); target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(output,indent=2),encoding='utf-8')
    for d in results:
        print(json.dumps({k:v for k,v in d.items() if k not in ('connection_info_hex','hub','strings')},indent=2))
    print('ERRORS',json.dumps(errors))
    if not results: raise SystemExit('Target not found')

if __name__=='__main__': main()
