"""Assemble actual FPGA PCM chunks; never interpret waveform telemetry as recording."""
import io,re,wave
class RecordingStore:
 def __init__(self):self.record_id=None;self.flags=0;self.chunks={};self.last_chunk=None;self.metadata={}
 def ingest(self,text):
  line=text.strip()
  if len(line)!=95 or not re.fullmatch(r'A[0-9A-Fa-f]{94}',line):return False
  rid=int(line[1:5],16);chunk=int(line[5:7],16);flags=int(line[7:9],16)
  if chunk>=128 or flags not in (0,1,2) or line[9:15].upper()!='100008':return False
  data=bytes.fromhex(line[20:84])
  if sum(data)&65535!=int(line[84:88],16):return False
  if self.record_id!=rid:self.record_id=rid;self.chunks={}
  self.metadata=dict(score_length=int(line[15:17],16),score_ready=line[17]=='1',mapped_note=int(line[18:20],16),adsr_enabled=line[88]=='1',adsr_config=line[89:94],metadata_version=line[94])
  self.flags=flags;self.last_chunk=chunk
  if flags==2:self.chunks[chunk]=data
  return True
 def status(self):return dict(id=self.record_id,flags=self.flags,last_chunk=self.last_chunk,chunks=len(self.chunks),complete=len(self.chunks)==128,sample_rate_numerator=46875,sample_rate_denominator=8,format='signed8 mono',applied=self.metadata,duration_seconds=4096*8/46875)
 def wav(self):
  if len(self.chunks)!=128:raise ValueError('Recording incomplete')
  data=b''.join(self.chunks[i] for i in range(128));out=io.BytesIO()
  with wave.open(out,'wb') as w:
   w.setparams((1,1,5859,0,'NONE','not compressed'));w.writeframes(bytes(x^128 for x in data))
  return out.getvalue()
