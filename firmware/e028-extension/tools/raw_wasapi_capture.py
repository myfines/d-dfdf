"""Documented per-stream WASAPI RAW capture, without changing endpoint settings.
Exposes a small context manager used by the bounded diagnostic recorder.
"""
import ctypes as c
from ctypes import wintypes as w
import threading,time
import comtypes as com
import numpy as np
from pycaw.pycaw import AudioUtilities
from pycaw.api.audioclient import IAudioClient

class Properties(c.Structure):
 _fields_=[('cbSize',w.DWORD),('bIsOffload',w.BOOL),('eCategory',c.c_int),('Options',c.c_int)]
class IAudioClient2(IAudioClient):
 _iid_=com.GUID('{726778CD-F60A-4EDA-82DE-E47610CD78AA}')
 _methods_=[com.COMMETHOD([],c.HRESULT,'IsOffloadCapable',(['in'],c.c_int,'category'),(['out'],c.POINTER(w.BOOL),'capable')),
 com.COMMETHOD([],c.HRESULT,'SetClientProperties',(['in'],c.POINTER(Properties),'properties'))]
class IAudioCaptureClient(com.IUnknown):
 _iid_=com.GUID('{C8ADBD64-E71E-48A0-A4DE-185C395CD317}')
 _methods_=[com.COMMETHOD([],c.HRESULT,'GetBuffer',(['out'],c.POINTER(c.POINTER(c.c_ubyte)),'data'),(['out'],c.POINTER(c.c_uint32),'frames'),(['out'],c.POINTER(w.DWORD),'flags'),(['out'],c.POINTER(c.c_uint64),'position'),(['out'],c.POINTER(c.c_uint64),'qpc')),
 com.COMMETHOD([],c.HRESULT,'ReleaseBuffer',(['in'],c.c_uint32,'frames')),
 com.COMMETHOD([],c.HRESULT,'GetNextPacketSize',(['out'],c.POINTER(c.c_uint32),'frames'))]

class RawCapture:
 def __init__(self,callback):self.callback=callback;self.stop=threading.Event();self.ready=threading.Event();self.error=None;self.format=None
 def __enter__(self):
  self.thread=threading.Thread(target=self.run);self.thread.start()
  if not self.ready.wait(5):raise RuntimeError('RAW capture initialization timeout')
  if self.error:self.__exit__(None,None,None);raise self.error
  return self
 def __exit__(self,*args):self.stop.set();self.thread.join(5)
 def run(self):
  com.CoInitialize();client=None;fmt=None
  try:
   mic=AudioUtilities.GetMicrophone();client=mic.Activate(IAudioClient2._iid_,com.CLSCTX_ALL,None).QueryInterface(IAudioClient2)
   props=Properties(c.sizeof(Properties),False,11,1);client.SetClientProperties(c.byref(props))
   fmt=client.GetMixFormat();f=fmt.contents
   # WAVEFORMATEX is18bytes; extensible subtype GUID starts at byte24.
   raw=c.string_at(fmt,18+f.cbSize)
   rate=f.nSamplesPerSec;channels=f.nChannels;bits=f.wBitsPerSample
   subtype=int.from_bytes(raw[24:28],'little') if f.wFormatTag==65534 else f.wFormatTag
   self.format=dict(rate=rate,channels=channels,bits=bits,subtype=subtype,raw_requested=True)
   if rate!=48000 or subtype not in [1,3] or bits not in [16,32]:raise RuntimeError('unsupported RAW mix format '+str(self.format))
   client.Initialize(0,0x00080000,1000000,0,fmt,None)
   capture=client.GetService(c.byref(IAudioCaptureClient._iid_)).QueryInterface(IAudioCaptureClient)
   client.Start();self.ready.set()
   while not self.stop.is_set():
    size=capture.GetNextPacketSize()
    if not size:time.sleep(.003);continue
    data,frames,flags,position,qpc=capture.GetBuffer()
    try:
     if flags&2:y=np.zeros((frames,1),np.float32)
     else:
      kind=c.c_float if subtype==3 else c.c_int16 if bits==16 else c.c_int32
      values=np.ctypeslib.as_array(c.cast(data,c.POINTER(kind)),shape=(frames*channels,)).copy().reshape(frames,channels)
      y=values[:,0:1].astype(np.float32)
      if subtype==1:y/=32768 if bits==16 else 2147483648
     self.callback(y,frames,None,'RAW discontinuity' if flags&1 else '')
    finally:capture.ReleaseBuffer(frames)
  except Exception as error:self.error=error;self.ready.set()
  finally:
   if client:
    try:client.Stop()
    except Exception:pass
   if fmt:c.windll.ole32.CoTaskMemFree(fmt)
   com.CoUninitialize()

if __name__=='__main__':
 chunks=[]
 with RawCapture(lambda data,*_:chunks.append(data.copy())) as stream:
  time.sleep(2);print(stream.format,'frames',sum(len(x) for x in chunks))
