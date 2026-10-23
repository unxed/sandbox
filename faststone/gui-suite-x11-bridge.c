/* Native XTEST bridge for gui-suite.exe --external-input.
 * cc -O2 -Wall -Wextra -Werror gui-suite-x11-bridge.c -o gui-suite-x11-bridge -lX11 -ldl
 * Use only on a disposable display; argv[1..] is the Wine/driver command.
 */
#define _POSIX_C_SOURCE 200809L
#include <X11/Xlib.h>
#include <X11/keysym.h>
#include <dlfcn.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static int (*fake_key)(Display *,unsigned int,Bool,unsigned long);
static int (*fake_button)(Display *,unsigned int,Bool,unsigned long);
static int (*fake_motion)(Display *,int,int,int,unsigned long);

static KeySym virtual_key(long vk)
{
    if(vk>=65&&vk<=90)return (KeySym)('a'+vk-65);
    if(vk>=48&&vk<=57)return (KeySym)vk;
    if(vk>=112&&vk<=123)return XK_F1+vk-112;
    switch(vk){
    case 8:return XK_BackSpace;case 9:return XK_Tab;case 13:return XK_Return;
    case 16:return XK_Shift_L;case 17:return XK_Control_L;case 18:return XK_Alt_L;
    case 27:return XK_Escape;case 32:return XK_space;case 33:return XK_Prior;
    case 34:return XK_Next;case 35:return XK_End;case 36:return XK_Home;
    case 37:return XK_Left;case 38:return XK_Up;case 39:return XK_Right;case 40:return XK_Down;
    case 189:return XK_minus;default:return NoSymbol;}
}

static int input(Display *d,const char *kind,long a,long b)
{
    int result=0;
    if(!strcmp(kind,"MOVE"))result=fake_motion(d,DefaultScreen(d),(int)a,(int)b,CurrentTime);
    else if(!strcmp(kind,"KEY")){
        KeyCode code=XKeysymToKeycode(d,virtual_key(a));
        if(code)result=fake_key(d,code,b?True:False,CurrentTime);
    }else if(!strcmp(kind,"MOUSE")){
        unsigned int button=0;Bool down=False;
        switch(a){
        case 2:button=1;down=True;break;case 4:button=1;break;
        case 8:button=3;down=True;break;case 16:button=3;break;
        case 32:button=2;down=True;break;case 64:button=2;break;
        case 0x800:{
            int i,n=(int)(labs(b)/120);if(n<1)n=1;
            button=b>0?4:5;result=1;
            for(i=0;i<n;i++){
                result&=fake_button(d,button,True,CurrentTime);
                result&=fake_button(d,button,False,CurrentTime);
            }XSync(d,False);return result;
        }}
        if(button)result=fake_button(d,button,down,CurrentTime);
    }XSync(d,False);return result;
}

int main(int argc,char **argv)
{
    Display *d;void *lib;int to[2],from[2],status;pid_t pid;
    FILE *reader,*writer;char *line=NULL;size_t length=0;
    if(argc<2){fprintf(stderr,"usage: gui-suite-x11-bridge COMMAND ARGS... --external-input\n");return 2;}
    d=XOpenDisplay(NULL);if(!d){fprintf(stderr,"cannot open disposable test display\n");return 2;}
    lib=dlopen("libXtst.so.6",RTLD_NOW|RTLD_LOCAL);
    if(!lib){fprintf(stderr,"cannot load XTEST: %s\n",dlerror());return 2;}
    *(void **)(&fake_key)=dlsym(lib,"XTestFakeKeyEvent");
    *(void **)(&fake_button)=dlsym(lib,"XTestFakeButtonEvent");
    *(void **)(&fake_motion)=dlsym(lib,"XTestFakeMotionEvent");
    if(!fake_key||!fake_button||!fake_motion)return 2;
    if(pipe(to)||pipe(from))return 2;
    pid=fork();if(pid<0)return 2;
    if(!pid){
        dup2(to[0],STDIN_FILENO);dup2(from[1],STDOUT_FILENO);dup2(from[1],STDERR_FILENO);
        close(to[0]);close(to[1]);close(from[0]);close(from[1]);
        execvp(argv[1],argv+1);perror("execvp");_exit(127);
    }
    close(to[0]);close(from[1]);reader=fdopen(from[0],"r");writer=fdopen(to[1],"w");
    if(!reader||!writer){kill(pid,SIGTERM);return 2;}
    setvbuf(stdout,NULL,_IONBF,0);setvbuf(writer,NULL,_IONBF,0);
    while(getline(&line,&length,reader)>=0){
        unsigned int sequence;char kind[16];long a,b;
        fputs(line,stdout);
        if(sscanf(line,"GUI_INPUT %u %15s %ld %ld",&sequence,kind,&a,&b)==4)
            fputs(input(d,kind,a,b)?"OK\n":"FAIL\n",writer);
    }
    free(line);fclose(reader);fclose(writer);
    while(waitpid(pid,&status,0)<0)if(errno!=EINTR)return 2;
    XCloseDisplay(d);dlclose(lib);
    return WIFEXITED(status)?WEXITSTATUS(status):128+WTERMSIG(status);
}
