#!/usr/bin/env python3
"""Prepare a disposable offline Linux guest for Wine GUI integration tests."""
import os,pathlib,re,shutil,subprocess
w=pathlib.Path(__file__).resolve().parents[3];r=w/'vm-root';r.mkdir(exist_ok=True)
runtime=pathlib.Path(os.environ.get('VM_WINE_ROOT',str(w/'wine-image-build')))
for name in ('bin','dev','proc','sys','tmp','work','etc','root','modules','var/cache/fontconfig','root/.cache/fontconfig'):(r/name).mkdir(parents=True,exist_ok=True)
shutil.copy2('/usr/bin/busybox',r/'bin/busybox')
for app in ('sh','mount','mkdir','cat','echo','sleep','insmod','poweroff','ls','ln','chmod','dmesg','uname'):
 d=r/'bin'/app
 if not d.exists():d.symlink_to('busybox')
seen=set()
def copy(path):
 path=pathlib.Path(path)
 if not path.is_file() or path in seen:return
 seen.add(path);target=r/path.relative_to('/');target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path.resolve(),target)
 out=subprocess.run(['ldd',str(path)],capture_output=True,text=True).stdout
 for dep in re.findall(r'(?:=>\s*)?(/[^\s]+)',out):copy(dep)
for exe in ('/usr/bin/Xvfb','/usr/bin/xkbcomp','/usr/bin/fc-cache','/usr/bin/openbox'):copy(exe)
config=runtime/'include/config.h'
sonames=set(re.findall(r'#define SONAME_\w+ "([^"]+)"',config.read_text())) if config.exists() else set()
# Installed Wine binaries retain SONAME strings for libraries loaded on demand.
for binary in runtime.rglob('*.so'):
 if binary.is_file():
  sonames.update(re.findall(rb'lib[A-Za-z0-9_+.-]+\.so(?:\.[0-9]+)*',binary.read_bytes()))
sonames={s.decode() if isinstance(s,bytes) else s for s in sonames}
cache=subprocess.run(['ldconfig','-p'],capture_output=True,text=True).stdout
for soname in sonames:
 for line in cache.splitlines():
  if line.strip().startswith(soname+' ') and 'x86-64' in line:
   copy(line.split(' => ')[-1]);break
for so in runtime.rglob('*.so'):
 if not so.is_file():continue
 for dep in re.findall(r'(?:=>\s*)?(/[^\s]+)',subprocess.run(['ldd',str(so)],capture_output=True,text=True).stdout):copy(dep)
for source in ('/usr/share/X11/xkb','/usr/share/fonts/truetype','/usr/share/fontconfig','/etc/fonts','/etc/xdg/openbox','/usr/share/openbox','/usr/share/themes'):
 if pathlib.Path(source).exists():shutil.copytree(source,r/source.lstrip('/'),dirs_exist_ok=True,symlinks=False)
(r/'etc/passwd').write_text('root:x:0:0:root:/root:/bin/sh\n');(r/'etc/group').write_text('root:x:0:\n');(r/'etc/nsswitch.conf').write_text('passwd: files\ngroup: files\nhosts: files\n');(r/'etc/hosts').write_text('127.0.0.1 localhost\n');(r/'tmp').chmod(0o1777)
for module in ('netfs','9pnet','9pnet_virtio','9p'):
 src=next((w/'vm-kernel-verified').rglob(module+'.ko.zst'))
 with (r/'modules'/(module+'.ko')).open('wb') as f:subprocess.run(['zstd','-dc',str(src)],stdout=f,check=True)
shutil.copy2(pathlib.Path(__file__).with_name('init.sh'),r/'init');(r/'init').chmod(0o755)
command='find . -print0 | /usr/bin/busybox cpio --null -o -H newc 2>/dev/null | gzip -1 > ../vm-initrd-v2.gz'
subprocess.run(command,shell=True,cwd=r,check=True)
print('Guest dependency files:',len(seen))
