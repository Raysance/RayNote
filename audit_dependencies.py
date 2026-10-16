#!/usr/bin/env python3
"""Bounded native-call and editor-source dependency audit for the pinned input.
This is evidence for Notes-only isolation, not a whole-program reachability proof.
"""
from pathlib import Path
import struct,json,bisect,collections,re,argparse,hashlib,subprocess,shutil
from html.parser import HTMLParser
from extract import EXPECTED
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source',type=Path,default=Path('/Applications/Raycast.app'))
args=parser.parse_args()
source=args.source.resolve();host=Path(__file__).resolve().parent
b=(source/'Contents/MacOS/Raycast').read_bytes()
assert hashlib.sha256(b).hexdigest()==EXPECTED,'Unsupported source binary'
base=0x100000000
u=lambda p:struct.unpack_from('<I',b,p)[0]
q=lambda p:struct.unpack_from('<Q',b,p)[0]
sections={};libs=[];o=32;fixups=func=None
for _ in range(u(16)):
 cmd,size=struct.unpack_from('<II',b,o)
 if cmd==0x19:
  for i in range(u(o+64)):
   s=o+72+i*80;name=b[s:s+16].rstrip(b'\0').decode();addr,n,off=struct.unpack_from('<QQI',b,s+32);sections[name]=(addr,n,off)
 if cmd in {0xc,0x80000018,0x8000001f,0x80000023}:libs.append(b[o+u(o+8):o+size].split(b'\0',1)[0].decode())
 if cmd==0x80000034:fixups=u(o+8)
 if cmd==0x26:func=(u(o+8),u(o+12))
 o+=size
imports_off,symbols_off,count,fmt=struct.unpack_from('<IIII',b,fixups+8);assert fmt==1
imports=[]
for i in range(count):
 raw=u(fixups+imports_off+i*4);namepos=fixups+symbols_off+(raw>>9);name=b[namepos:b.index(0,namepos)].decode();imports.append((raw&255,name))
slot_imports={}
starts_image=fixups+u(fixups+4)
for segment_index in range(u(starts_image)):
 relative=u(starts_image+4+segment_index*4)
 if not relative:continue
 info=starts_image+relative
 page_size,pointer_format=struct.unpack_from('<HH',b,info+4)
 segment_offset=q(info+8);page_count=struct.unpack_from('<H',b,info+20)[0]
 assert pointer_format in {2,6},pointer_format
 for page_index in range(page_count):
  page_start=struct.unpack_from('<H',b,info+22+page_index*2)[0]
  if page_start==0xffff:continue
  chain_starts=[]
  if page_start&0x8000:
   overflow=page_start&0x7fff
   while True:
    value=struct.unpack_from('<H',b,info+22+overflow*2)[0];chain_starts.append(value&0x7fff);overflow+=1
    if value&0x8000:break
  else:chain_starts=[page_start]
  for chain in chain_starts:
   position=segment_offset+page_index*page_size+chain
   while True:
    raw=q(position)
    if raw>>63:
     index=raw&0xffffff;assert index<len(imports)
     slot_imports[base+position]=index
    step=(raw>>51)&0xfff
    if not step:break
    position+=step*4
stub_addr,stub_size,stub_off=sections['__stubs'];stubs={}
for i in range(stub_size//12):
 p=stub_off+i*12;pc=stub_addr+i*12;w1,w2=struct.unpack_from('<II',b,p)
 if w1&0x9f00001f==0x90000010:
  imm=((w1>>5)&0x7ffff)<<2|((w1>>29)&3);imm=imm-(1<<21) if imm&(1<<20) else imm
  slot=(pc&~4095)+imm*4096+((w2>>10)&4095)*8
  if slot in slot_imports:stubs[pc]=imports[slot_imports[slot]]
start,size=func;pos=start;value=0;shift=0;address=base;starts=[]
while pos<start+size:
 v=b[pos];pos+=1;value|=(v&127)<<shift
 if v&128:shift+=7;continue
 if value==0:break
 address+=value;starts.append(address);value=shift=0
text_addr,text_size,text_off=sections['__text'];ends=starts[1:]+[text_addr+text_size]
starts=[s for s in starts if text_addr<=s<text_addr+text_size]
roots=[i for i,a in enumerate(starts) if any(lo<=a<hi for lo,hi in [(0x100a49000,0x100aade00),(0x100308220,0x100309130),(0x1015a0000,0x1015ae000),(0x10110f91c,0x10110fd9c)])]
host_addresses=set()
for name in ['native_main.m','native_settings.h','gui_support.h']:
 host_addresses.update(int(x,16) for x in re.findall(r'0x[0-9a-fA-F]{9,}',(host/name).read_text()))
for address in [0x100d08dd0,0x100d2e488,0x100aa9228]:
 host_addresses.add(address)
for address in host_addresses:
 if text_addr<=address<text_addr+text_size:
  index=bisect.bisect_right(starts,address)-1
  if index>=0 and index not in roots:roots.append(index)
root_set=set(roots);queue=collections.deque(roots);seen=set();foreign=[];indirect=0;directforeign=[]
while queue:
 i=queue.popleft()
 if i in seen:continue
 seen.add(i);a=starts[i];end=starts[i+1] if i+1<len(starts) else text_addr+text_size
 # Track local ADRP/LDR materializations of chained imports and direct stubs.
 pages={}
 for p in range(a-base,end-base,4):
  w=u(p);pc=base+p
  if w&0x9f000000==0x90000000:
   imm=((w>>5)&0x7ffff)<<2|((w>>29)&3);imm=imm-(1<<21) if imm&(1<<20) else imm
   pages[w&31]=((pc&~4095)+imm*4096,pc)
  elif w&0xff000000==0x91000000:
   reg=(w>>5)&31
   if reg in pages and pc-pages[reg][1]<=32:
    immediate=((w>>10)&4095)<<(12 if (w>>22)&1 else 0)
    pages[w&31]=(pages[reg][0]+immediate,pc)
  elif w&0xffc00000==0xf9400000:
   reg=(w>>5)&31
   if reg in pages and pc-pages[reg][1]<=32:
    slot=pages[reg][0]+((w>>10)&4095)*8
    if slot in slot_imports:
     lib,name=imports[slot_imports[slot]]
     if lib in {4,5}:foreign.append({'function':hex(a),'at':hex(pc),'kind':'chained-import-slot','library':libs[lib-1],'symbol':name})
  if w&0xfc000000 in {0x94000000,0x14000000}:
   imm=w&0x3ffffff;imm=imm-(1<<26) if imm&(1<<25) else imm;target=pc+imm*4
   if target in stubs:
    lib,name=stubs[target]
    if lib in {4,5}:
     item={'function':hex(a),'at':hex(pc),'kind':'stub','library':libs[lib-1],'symbol':name};foreign.append(item)
     if i in root_set:directforeign.append(item)
   elif text_addr<=target<text_addr+text_size:
    j=bisect.bisect_right(starts,target)-1
    if j>=0 and j not in seen:queue.append(j)
  elif w&0xfffffc1f in {0xd63f0000,0xd61f0000}:indirect+=1
assert len(stubs)==stub_size//12,'Unresolved function stubs make this audit incomplete'
class EntryHTML(HTMLParser):
 def __init__(self):super().__init__();self.refs=[];self.preloads=[]
 def handle_starttag(self,tag,attributes):
  attrs=dict(attributes)
  if tag=='script' and attrs.get('src'):self.refs.append(attrs['src'])
  if tag=='link' and attrs.get('href'):
   self.refs.append(attrs['href'])
   if attrs.get('rel')=='modulepreload':self.preloads.append(attrs['href'])
web=source/'Contents/Resources/RaycastWeb_RaycastWeb.bundle/Contents/Resources'
entry=EntryHTML();entry.feed((web/'index.html').read_text())
files={'index.html'};pending=list(entry.refs)
while pending:
 ref=pending.pop();path=(web/ref).resolve()
 assert web in path.parents and path.is_file(),ref
 relative=str(path.relative_to(web))
 if relative in files:continue
 files.add(relative)
 if path.suffix=='.css':
  for url in re.findall(r'url\((.*?)\)',path.read_text()):
   target=(path.parent/url.strip('\"\'')).resolve()
   assert web in target.parents and target.is_file()
   pending.append(str(target.relative_to(web)))
node=shutil.which('node')
if not node:raise SystemExit('Node.js is required to parse the bundled ES module without executing it')
js=web/'js/index.js'
code="const fs=require('node:fs'),vm=require('node:vm');const m=new vm.SourceTextModule(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(JSON.stringify(m.dependencySpecifiers));"
parsed=subprocess.run([node,'--experimental-vm-modules','-e',code,str(js)],check=True,capture_output=True,text=True)
module_dependencies=json.loads(parsed.stdout)
assert not module_dependencies,'Additional ES module dependencies require explicit review'
web_report={
 'entry':'index.html','static_files':[{'path':name,'sha256':hashlib.sha256((web/name).read_bytes()).hexdigest()} for name in sorted(files)],
 'es_module_imports':module_dependencies,'module_preload_links':entry.preloads,
 'embedded_highlighter':{'Highlight.js_marker': 'Highlight.js' in js.read_text(),'highlightAuto_marker':'highlightAuto' in js.read_text()},
 'scope':'HTML script/style links, CSS URLs, and V8-parsed static ESM imports. Runtime WebKit bridge calls and computed resource requests remain outside this static closure.'}
result={
 'source_sha256':EXPECTED,
 'native':{
 'scope':'Known Notes controllers/actions/model/find, recovery, repository and sync-provider intervals, plus explicit host bootstrap calls and original application/delegate initializers. Direct branches and local chained-import materializations only.',
 'whole_program_dependency_proof':False,
 'limitations':['Indirect dispatch and callbacks are counted but not resolved.','Metadata/vtable edges and all computed addresses are not exhaustively modeled.','This analysis does not cover the full original launcher feature set.'],
 'root_intervals':[['0x100a49000','0x100aade00'],['0x100308220','0x100309130'],['0x1015a0000','0x1015ae000'],['0x10110f91c','0x10110fd9c']],
 'root_functions':len(roots),'resolved_stub_count':len(stubs),'stub_count':stub_size//12,
 'bound_pointer_slots':len(slot_imports),'all_function_starts':len(starts),
 'reachable_functions_by_direct_branches':len(seen),'encountered_indirect_calls_or_branches':indirect,
 'direct_root_foreign_refs':directforeign,'transitive_direct_foreign_refs':foreign,
 'foreign_imports':dict(collections.Counter(libs[l-1] for l,n in imports if l in {4,5}))},
 'editor':web_report,
 'interpretation':'Static evidence supports Notes-only isolation; runtime load/UI/export/restart tests are separate required evidence. Zero references here is not an absolute absence proof.'}
print(json.dumps(result,indent=2)+'\n')
