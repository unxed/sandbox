/* SPDX-License-Identifier: MIT */
/* Self-extracting launcher. Runtime libraries remain separate LGPL files. */
#define _GNU_SOURCE
#include <elf.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#define TRAILER_BYTES 256
#define MAGIC "FSWINE-BUNDLE-1"
static void die(const char *message) { fprintf(stderr,"FastStone bundle: %s: %s\n",message,strerror(errno)); exit(1); }
static void invalid(const char *message) { fprintf(stderr,"FastStone bundle: %s\n",message); exit(1); }
static void pathcat(char *out, const char *a, const char *b)
{
    if (snprintf(out,PATH_MAX,"%s/%s",a,b)>=PATH_MAX) invalid("path is too long");
}
static void mkdirs(const char *path)
{
    char copy[PATH_MAX], *p;
    struct stat st;
    if (strlen(path)>=sizeof(copy)) invalid("cache path is too long");
    strcpy(copy,path);
    for(p=copy+1; ;p++)
    {
        if (*p!='/' && *p) continue;
        char saved=*p; *p=0;
        if (mkdir(copy,0700)<0 && errno!=EEXIST) die("create cache directory");
        if (stat(copy,&st)<0 || !S_ISDIR(st.st_mode)) invalid("cache parent is not a directory");
        *p=saved; if(!saved) break;
    }
}
static void copy_range(int input, off_t offset, size_t size, const char *output, mode_t mode)
{
    char buffer[65536];
    int fd=open(output,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,mode);
    if(fd<0) die("create extraction file");
    while(size)
    {
        size_t wanted=size<sizeof(buffer)?size:sizeof(buffer);
        ssize_t n=pread(input,buffer,wanted,offset);
        if(n<=0) die("read bundle payload");
        for(ssize_t at=0; at<n;)
        {
            ssize_t written=write(fd,buffer+at,n-at);
            if(written<=0) die("write extracted payload");
            at+=written;
        }
        offset+=n; size-=n;
    }
    if(fsync(fd)<0 || close(fd)<0) die("finish extraction file");
}
static int spawn(char *const argv[], int stdout_fd)
{
    int status;
    pid_t child=fork();
    if(child<0) die("start unpacker");
    if(!child)
    {
        if(stdout_fd>=0 && dup2(stdout_fd,STDOUT_FILENO)<0) _exit(126);
        execv(argv[0],argv); perror("FastStone bundle unpacker"); _exit(127);
    }
    while(waitpid(child,&status,0)<0) if(errno!=EINTR) die("wait for unpacker");
    return WIFEXITED(status)?WEXITSTATUS(status):128;
}
static void check_digest(const char *busybox, const char *archive, const char *wanted)
{
    int pipefd[2], status;
    char result[128]={0};
    char *const args[]={(char *)busybox,"sha256sum",(char *)archive,NULL};
    if(pipe(pipefd)<0) die("create checksum pipe");
    status=spawn(args,pipefd[1]); close(pipefd[1]);
    ssize_t n=read(pipefd[0],result,sizeof(result)-1); close(pipefd[0]);
    if(status || n<64 || strncmp(result,wanted,64)) invalid("payload checksum failed; download the bundle again");
}
static void relocate(const char *root)
{
    char manifest[PATH_MAX], target[PATH_MAX], loader[PATH_MAX], line[PATH_MAX];
    pathcat(loader,root,"lib/ld-linux-x86-64.so.2");
    pathcat(manifest,root,"elf-interpreters.txt");
    FILE *f=fopen(manifest,"r");
    if(!f) die("open interpreter manifest");
    while(fgets(line,sizeof(line),f))
    {
        Elf64_Ehdr eh;
        Elf64_Phdr ph;
        char interpreter[1024];
        line[strcspn(line,"\n")]=0;
        if(!*line || *line=='/' || strstr(line,"..")) invalid("invalid interpreter manifest");
        pathcat(target,root,line);
        int fd=open(target,O_RDWR|O_NOFOLLOW);
        if(fd<0) die("open runtime executable");
        if(pread(fd,&eh,sizeof(eh),0)!=sizeof(eh) || memcmp(eh.e_ident,ELFMAG,SELFMAG) ||
           eh.e_ident[EI_CLASS]!=ELFCLASS64 || eh.e_phentsize!=sizeof(ph)) invalid("invalid runtime ELF");
        int found=0;
        for(unsigned i=0;i<eh.e_phnum;i++)
        {
            if(pread(fd,&ph,sizeof(ph),eh.e_phoff+i*sizeof(ph))!=sizeof(ph)) die("read ELF headers");
            if(ph.p_type!=PT_INTERP) continue;
            if(ph.p_filesz>sizeof(interpreter) || strlen(loader)+1>ph.p_filesz) invalid("cache path exceeds reserved ELF interpreter space");
            memset(interpreter,0,ph.p_filesz); strcpy(interpreter,loader);
            if(pwrite(fd,interpreter,ph.p_filesz,ph.p_offset)!=(ssize_t)ph.p_filesz) die("relocate runtime interpreter");
            found=1; break;
        }
        close(fd);
        if(!found) invalid("runtime executable has no interpreter");
    }
    fclose(f);
}
int main(int argc, char **argv)
{
    char self[PATH_MAX], trailer[TRAILER_BYTES+1], magic[32], digest[65];
    char base[PATH_MAX], cache[PATH_MAX], lockpath[PATH_MAX], ready[PATH_MAX];
    char staging[PATH_MAX], busybox[PATH_MAX], archive[PATH_MAX], launch[PATH_MAX];
    unsigned long long bo,bs,po,ps;
    struct stat st;
    ssize_t n=readlink("/proc/self/exe",self,sizeof(self)-1);
    if(n<0 || n>=(ssize_t)sizeof(self)-1) die("find executable through /proc/self/exe");
    self[n]=0;
    int input=open(self,O_RDONLY);
    if(input<0 || fstat(input,&st)<0) die("open bundle");
    if(st.st_size<TRAILER_BYTES || pread(input,trailer,TRAILER_BYTES,st.st_size-TRAILER_BYTES)!=TRAILER_BYTES) invalid("missing payload trailer");
    trailer[TRAILER_BYTES]=0;
    if(sscanf(trailer,"%31s %llu %llu %llu %llu %64s",magic,&bo,&bs,&po,&ps,digest)!=6 ||
       strcmp(magic,MAGIC) || strlen(digest)!=64 || bo<4096 || bs<1024 || bs>10000000 ||
       po!=bo+bs || ps>4000000000ULL || po+ps!=(unsigned long long)st.st_size-TRAILER_BYTES) invalid("corrupt bundle trailer");
    for(int i=0;i<64;i++) if(!((digest[i]>='0'&&digest[i]<='9')||(digest[i]>='a'&&digest[i]<='f'))) invalid("invalid bundle digest");
    const char *override=getenv("FASTSTONE_CACHE_HOME"), *xdg=getenv("XDG_CACHE_HOME"), *home=getenv("HOME");
    int path_length;
    if(override && *override) path_length=snprintf(base,sizeof(base),"%s",override);
    else if(xdg && *xdg) path_length=snprintf(base,sizeof(base),"%s/faststone-wine",xdg);
    else if(home && *home) path_length=snprintf(base,sizeof(base),"%s/.cache/faststone-wine",home);
    else { invalid("HOME or XDG_CACHE_HOME must be set"); return 1; }
    if(path_length<0 || path_length>=PATH_MAX) invalid("cache path is too long");
    if(base[0]!='/') invalid("cache directory must be an absolute path");
    mkdirs(base);
    pathcat(cache,base,digest); pathcat(lockpath,base,"runtime.lock");
    pathcat(ready,cache,".ready");
    int lock=open(lockpath,O_CREAT|O_RDWR|O_NOFOLLOW,0600);
    if(lock<0 || flock(lock,LOCK_EX)<0) die("lock runtime cache");
    if(access(ready,R_OK))
    {
        if(access(cache,F_OK)==0) invalid("incomplete cache entry; choose another FASTSTONE_CACHE_HOME");
        pathcat(staging,base,".extract-XXXXXX");
        if(!mkdtemp(staging)) die("create extraction directory");
        pathcat(busybox,staging,"busybox-bootstrap"); pathcat(archive,staging,"payload.tar.gz");
        copy_range(input,bo,bs,busybox,0700); copy_range(input,po,ps,archive,0600);
        check_digest(busybox,archive,digest);
        char *const args[]={busybox,"tar","-xzof",archive,"-C",staging,NULL};
        if(spawn(args,-1)) invalid("runtime extraction failed");
        unlink(archive); unlink(busybox);
        if(rename(staging,cache)<0) die("publish runtime cache");
        relocate(cache);
        int fd=open(ready,O_WRONLY|O_CREAT|O_EXCL,0600);
        if(fd<0) die("mark runtime ready");
        close(fd);
    }
    close(input); flock(lock,LOCK_UN); close(lock);
    pathcat(busybox,cache,"bin/busybox"); pathcat(launch,cache,"launch.sh");
    setenv("FASTSTONE_RUNTIME",cache,1);
    /* Relative DT_RPATH belongs to each ELF object and does not leak to host
     * applications launched by Wine. Do not inject code paths into their env. */
    unsetenv("LD_LIBRARY_PATH");
    unsetenv("GCONV_PATH");
    char **args=calloc(argc+3,sizeof(*args));
    if(!args) die("allocate arguments");
    args[0]=busybox; args[1]="sh"; args[2]=launch;
    for(int i=1;i<argc;i++) args[i+2]=argv[i];
    execv(busybox,args); die("start runtime");
    return 1;
}
