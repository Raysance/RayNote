#!/usr/bin/env python3
"""Extract the installed ARM64 Raycast 1.104.31 Notes UI, without its main entry point.
The original application is read only. No decompiled Swift source is claimed.
"""
from pathlib import Path
import argparse,hashlib,json,plistlib,shutil,struct,subprocess,tempfile
from prune_resources import prune
EXPECTED='c8ff6219fa4122ca35c646fa23638a219c69abcc6d2db81bf6931a92cbec1e95'
ROOT=Path(__file__).resolve().parent

def run(*args):subprocess.run(list(map(str,args)),check=True)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--source',type=Path,default=Path('/Applications/Raycast.app'))
 parser.add_argument('--output',type=Path,default=ROOT/'dist'/'RayNote.app')
 args=parser.parse_args();source=args.source.resolve();app=args.output.resolve()
 original=source/'Contents/MacOS/Raycast'
 if digest(original)!=EXPECTED:raise SystemExit('Unsupported Raycast binary. Expected the locally inspected ARM64 1.104.31 build; refusing address patches.')
 if app.exists():raise SystemExit(f'Output already exists: {app}. Choose a new --output path.')
 if app==source or source in app.parents:raise SystemExit('Output must be separate from the original application.')
 contents=app/'Contents';macos=contents/'MacOS';macos.mkdir(parents=True)
 for name in ['Resources','Frameworks']:
  shutil.copytree(source/'Contents'/name,contents/name,symlinks=True)
 resource_report=prune(contents/'Resources')
 module=macos/'NotesCore';shutil.copy2(original,module)
 run('codesign','--remove-signature',module)
 b=bytearray(module.read_bytes());header=list(struct.unpack_from('<8I',b));old_size=header[5]
 commands=[];o=32;removed=[]
 for _ in range(header[4]):
  cmd,size=struct.unpack_from('<II',b,o);raw=b[o:o+size]
  name=bytes(raw[8:24]).rstrip(b'\0') if cmd==0x19 else b''
  if name==b'__PAGEZERO' or cmd in [0xe,0x80000028]:removed.append({'command':hex(cmd),'segment':name.decode()})
  else:commands.append(raw)
  o+=size
 header[3]=8;header[4]=len(commands);header[5]=sum(map(len,commands));header[6]&=~0x200000
 struct.pack_into('<8I',b,0,*header)
 joined=b''.join(commands);b[32:32+old_size]=joined+b'\0'*(old_size-len(joined))
 for raw in commands:
  if struct.unpack_from('<I',raw)[0]==0x80000034:
   offset=struct.unpack_from('<I',raw,8)[0];starts=offset+struct.unpack_from('<I',b,offset+4)[0]
   count=struct.unpack_from('<I',b,starts)[0];entries=list(struct.unpack_from('<'+str(count)+'I',b,starts+4))
   assert entries[0]==0
   struct.pack_into('<I',b,starts,count-1);struct.pack_into('<'+str(count-1)+'I',b,starts+4,*entries[1:])
 original_bytes=original.read_bytes();patches=[]
 def patch(addr,words,reason):
  p=addr-0x100000000;new=struct.pack('<'+'I'*len(words),*words);old=original_bytes[p:p+len(new)]
  assert b[p:p+len(new)]==old,hex(addr)
  b[p:p+len(new)]=new;patches.append(dict(address=hex(addr),before=old.hex(),after=new.hex(),reason=reason))
 def branch(addr,target,reason):patch(addr,[0x14000000|((target-addr)//4&0x3ffffff)],reason)
 branch(0x100a4e1cc,0x100a4e220,'Notes create action: remove local five-note branch')
 branch(0x100a4e6f4,0x100a4e748,'Notes duplicate action: remove local five-note branch')
 branch(0x100a54da4,0x100a54df8,'Notes command create: remove local five-note branch')
 branch(0x100a72f60,0x100a72fb4,'Notes restore: remove local five-note branch')
 patch(0x100a7bd78,[0x52800000,0xd65f03c0],'Notes-only over-limit predicate returns false')
 branch(0x100a6f388,0x100a6f39c,'Use original uncapped Notes list display')
 branch(0x100a8fb30,0x100a8f7e0,'Original Notes window New Note: bypass local count <= 4 condition')
 patch(0x100a93d90,[0xd503201f],'Original Notes window alternate create: remove count > 4 upsell branch')
 patch(0x100a8ff50,[0xd503201f],'Original Notes window: remove local count >= 5 upsell branch')
 patch(0x100a7dad8,[0x52800000,0xd65f03c0],'Notes-only read-only predicate returns false')
 # Redirect the original Notes settings closure to a host callback through an
 # otherwise-unused import slot. All actual preferences controls stay native.
 pc=0x100a646c4;target=0x102b93440;delta=((target&~4095)-(pc&~4095))//4096
 adrp=0x90000010|((delta&3)<<29)|(((delta>>2)&0x7ffff)<<5)
 ldr=0xf9400210|(((target&4095)//8)<<10)
 patch(pc,[adrp,ldr,0xd61f0200],'Notes settings closure opens original Notes preferences form in independent host')
 module.write_bytes(b);run('codesign','--force','--sign','-',module)
 old=plistlib.loads((source/'Contents/Info.plist').read_bytes())
 info={k:old[k] for k in ['LSMinimumSystemVersion','NSHighResolutionCapable'] if k in old}
 info.update(CFBundleIdentifier='local.notes.native-extracted',CFBundleExecutable='RayNote',CFBundleName='RayNote',CFBundleDisplayName='RayNote',CFBundleIconFile='RayNote.icns',CFBundlePackageType='APPL',CFBundleVersion='2',CFBundleShortVersionString='0.2.0',LSUIElement=False,NSPrincipalClass='NSApplication',NSHumanReadableCopyright='Original components retain their respective ownership.')
 (contents/'Info.plist').write_bytes(plistlib.dumps(info));(contents/'PkgInfo').write_bytes(b'APPL????')
 with tempfile.TemporaryDirectory(prefix='native-notes-build-') as tmp:
  tmp=Path(tmp);objects=[]
  iconset=tmp/'RayNote.iconset'
  run('swift',ROOT/'scripts/make-icon.swift',iconset)
  run('iconutil','-c','icns',iconset,'-o',contents/'Resources/RayNote.icns')
  for file in ['native_main.m','credentials.m','swift_bridge.S']:
   out=tmp/(Path(file).stem+'.o');cmd=['clang','-Wno-deprecated-declarations','-I',str(ROOT)]
   if file.endswith('.m'):cmd+=['-fobjc-arc']
   run(*cmd,'-c',ROOT/file,'-o',out);objects.append(out)
  run('clang',*objects,'-framework','AppKit','-framework','Foundation','-framework','Security','-lsandbox','-Wl,-rpath,@executable_path/../Frameworks','-o',macos/'RayNote')
 manifest=dict(source_version='1.104.31',source_sha256=EXPECTED,module_sha256=digest(module),load_command_changes=removed,notes_patches=patches,credentials='Private local credential file (0600) holding generated database/cache keys; not system-Keychain protected',network='Denied by per-process sandbox',ui='Original RaycastNotesWindow and RaycastNotesViewController, original bundled web editor')
 (contents/'Resources'/'ExtractionManifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (contents/'Resources'/'ResourceManifest.json').write_text(json.dumps(resource_report,indent=2)+'\n')
 run('codesign','--force','--deep','--sign','-',app)
 run('codesign','--verify','--deep','--strict',app)
 assert digest(original)==EXPECTED,'Original binary changed unexpectedly'
 print('BUILT',app)
if __name__=='__main__':main()
