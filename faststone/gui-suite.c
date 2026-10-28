/* Public-API black-box FastStone GUI tests. One disposable Wine prefix and
 * application copy per invocation. No application-code inspection/modification.
 */
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <commctrl.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { int w,h; BYTE *p; } Frame;
static DWORD pid, deadline=120000;
static HANDLE process;
static FILE *logfile;
static int checks, failures, external;
static unsigned serial;
static char output[MAX_PATH];
static HWND result, fullscreen_window;
static long largest;

static void quoted(FILE *f,const char *s)
{
    const unsigned char *p=(const unsigned char *)s;fputc('"',f);
    for(;*p;p++) {
        if(*p=='"'||*p=='\\') { fputc('\\',f);fputc(*p,f); }
        else if(*p<32)fprintf(f,"\\u%04x",*p);
        else fputc(*p,f);
    }
    fputc('"',f);
}

static void check(const char *name,int pass,long actual,long expected)
{
    checks++;if(!pass)failures++;
    fprintf(logfile,"{\"event\":\"assert\",\"name\":");quoted(logfile,name);
    fprintf(logfile,",\"pass\":%s,\"actual\":%ld,\"expected\":%ld}\n",pass?"true":"false",actual,expected);
    fflush(logfile);printf("%s %s actual=%ld expected=%ld\n",pass?"PASS":"FAIL",name,actual,expected);fflush(stdout);
}

static void skip(const char *name,const char *reason)
{
    fprintf(logfile,"{\"event\":\"skip\",\"name\":");quoted(logfile,name);
    fprintf(logfile,",\"reason\":");quoted(logfile,reason);fprintf(logfile,"}\n");fflush(logfile);
}

static int ours(HWND w) { DWORD p=0;GetWindowThreadProcessId(w,&p);return p==pid; }
static int alive(void) { DWORD code;return GetExitCodeProcess(process,&code)&&code==STILL_ACTIVE; }

static BOOL CALLBACK biggest(HWND w,LPARAM unused)
{
    RECT r;long area;(void)unused;
    if(!ours(w)||!IsWindowVisible(w))return TRUE;
    GetWindowRect(w,&r);area=(r.right-r.left)*(r.bottom-r.top);
    if(area>largest){largest=area;result=w;}return TRUE;
}
static HWND main_window(void) { largest=0;result=NULL;EnumWindows(biggest,0);return result; }
static int fullscreen(void)
{
    HWND w=main_window();RECT r;LONG s;if(!w)return 0;
    GetWindowRect(w,&r);s=GetWindowLongA(w,GWL_STYLE);
    return r.left<=1&&r.top<=1&&r.right>=GetSystemMetrics(SM_CXSCREEN)-1&&
           r.bottom>=GetSystemMetrics(SM_CYSCREEN)-1&&!(s&WS_CAPTION);
}

static int bridge(const char *kind,long a,long b)
{
    char reply[32];printf("GUI_INPUT %u %s %ld %ld\n",++serial,kind,a,b);fflush(stdout);
    return fgets(reply,sizeof(reply),stdin)&&!strncmp(reply,"OK",2);
}
static void x11_snapshot(const char *name)
{
    static long counter;long id=++counter;int ok=external?bridge("SNAP",id,0):0;
    fprintf(logfile,"{\"event\":\"x11-snapshot\",\"name\":\"%s\",\"id\":%ld,\"ok\":%d}\n",name,id,ok);
}
static void key_state(WORD vk,int down)
{
    INPUT in;UINT sent;
    if(external){check("external key input",bridge("KEY",vk,down),vk,down);return;}
    memset(&in,0,sizeof(in));in.type=INPUT_KEYBOARD;in.ki.wVk=vk;in.ki.dwFlags=down?0:KEYEVENTF_KEYUP;
    sent=SendInput(1,&in,sizeof(in));check("SendInput keyboard",sent==1,sent,1);
}
static void key(WORD vk){key_state(vk,1);key_state(vk,0);}
static void chord(WORD mod,WORD vk){key_state(mod,1);key(vk);key_state(mod,0);}
static void move(int x,int y)
{
    INPUT in;UINT sent;
    if(external){POINT pt={-1,-1};int ok=bridge("MOVE",x,y);check("external pointer input",ok,x,y);
        {int w;for(w=0;w<40;w++){Sleep(50);GetCursorPos(&pt);if(pt.x==x&&pt.y==y)break;}}
        /* Informational: under TCG load the readback can lag, and it must not abort a plan. */
        if(pt.x!=x||pt.y!=y)fprintf(logfile,"{\"event\":\"cursor-readback-mismatch\",\"want\":[%d,%d],\"got\":[%ld,%ld]}\n",x,y,pt.x,pt.y);
        return;}
    memset(&in,0,sizeof(in));in.type=INPUT_MOUSE;
    in.mi.dx=x*65535/(GetSystemMetrics(SM_CXSCREEN)-1);in.mi.dy=y*65535/(GetSystemMetrics(SM_CYSCREEN)-1);
    in.mi.dwFlags=MOUSEEVENTF_MOVE|MOUSEEVENTF_ABSOLUTE;
    sent=SendInput(1,&in,sizeof(in));check("SendInput pointer",sent==1,sent,1);
}
static void mouse(DWORD flags,LONG data)
{
    INPUT in;UINT sent;
    if(external){check("external mouse input",bridge("MOUSE",flags,data),flags,data);return;}
    memset(&in,0,sizeof(in));in.type=INPUT_MOUSE;in.mi.dwFlags=flags;in.mi.mouseData=data;
    sent=SendInput(1,&in,sizeof(in));check("SendInput mouse",sent==1,sent,1);
}
static void click(void){mouse(MOUSEEVENTF_LEFTDOWN,0);mouse(MOUSEEVENTF_LEFTUP,0);}
static void center(void){move(GetSystemMetrics(SM_CXSCREEN)/2,GetSystemMetrics(SM_CYSCREEN)/2);Sleep(700);}

static Frame capture(void)
{
    Frame f={0,0,NULL};BITMAPINFO bi;void *bits=NULL;HBITMAP bm,old;
    HDC dc=GetDC(NULL),mem=CreateCompatibleDC(dc);
    f.w=GetSystemMetrics(SM_CXSCREEN);f.h=GetSystemMetrics(SM_CYSCREEN);
    memset(&bi,0,sizeof(bi));bi.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth=f.w;bi.bmiHeader.biHeight=-f.h;bi.bmiHeader.biPlanes=1;bi.bmiHeader.biBitCount=32;
    bm=CreateDIBSection(dc,&bi,DIB_RGB_COLORS,&bits,NULL,0);
    if(bm){old=SelectObject(mem,bm);BitBlt(mem,0,0,f.w,f.h,dc,0,0,SRCCOPY);
        f.p=malloc((size_t)f.w*f.h*4);if(f.p)memcpy(f.p,bits,(size_t)f.w*f.h*4);
        SelectObject(mem,old);DeleteObject(bm);}
    DeleteDC(mem);ReleaseDC(NULL,dc);return f;
}
static void release(Frame *f){free(f->p);f->p=NULL;}
static long difference(const Frame *a,const Frame *b,RECT r)
{
    int x,y;long n=0;if(!a->p||!b->p||a->w!=b->w||a->h!=b->h)return -1;
    r.left=max(0,r.left);r.top=max(0,r.top);r.right=min(a->w,r.right);r.bottom=min(a->h,r.bottom);
    for(y=r.top;y<r.bottom;y++)for(x=r.left;x<r.right;x++){
        const BYTE *p=a->p+4*((size_t)y*a->w+x),*q=b->p+4*((size_t)y*b->w+x);
        if(abs(p[0]-q[0])+abs(p[1]-q[1])+abs(p[2]-q[2])>30)n++;}
    return n;
}
static long colorful(const Frame *f,RECT r)
{
    int x,y;long n=0;if(!f->p)return 0;
    r.left=max(0,r.left);r.top=max(0,r.top);r.right=min(f->w,r.right);r.bottom=min(f->h,r.bottom);
    for(y=r.top;y<r.bottom;y++)for(x=r.left;x<r.right;x++){
        const BYTE *p=f->p+4*((size_t)y*f->w+x);
        int lo=min(p[0],min(p[1],p[2])),hi=max(p[0],max(p[1],p[2]));
        if(hi-lo>60&&hi>120&&lo<160)n++;}return n;
}
static int fixture_color_bins(const Frame *f,RECT r)
{
    long bins[8]={0},area;int x,y,n=0,i;
    if(!f->p)return 0;
    r.left=max(0,r.left);r.top=max(0,r.top);r.right=min(f->w,r.right);r.bottom=min(f->h,r.bottom);
    area=(r.right-r.left)*(r.bottom-r.top);
    for(y=r.top;y<r.bottom;y++)for(x=r.left;x<r.right;x++){
        const BYTE *p=f->p+4*((size_t)y*f->w+x);
        int lo=min(p[0],min(p[1],p[2])),hi=max(p[0],max(p[1],p[2]));
        if(hi-lo>60&&hi>120&&lo<160){int bin=(p[2]>120?4:0)|(p[1]>120?2:0)|(p[0]>120?1:0);bins[bin]++;}}
    for(i=1;i<7;i++)if(bins[i]>max(5,area/200))n++;
    return n;
}
static void save(const char *name,const Frame *f)
{
    char path[MAX_PATH],safe[80];FILE *out;BITMAPFILEHEADER bf;BITMAPINFOHEADER bi;size_t i;
    if(!f->p){check("capture pixels",0,0,1);return;}
    for(i=0;name[i]&&i<sizeof(safe)-1;i++)safe[i]=isalnum((unsigned char)name[i])||name[i]=='-'||name[i]=='_'?name[i]:'_';
    safe[i]=0;
    snprintf(path,sizeof(path),"%s\\%s.bmp",output,safe);out=fopen(path,"wb");
    if(!out){check("save screenshot",0,0,1);return;}
    memset(&bf,0,sizeof(bf));memset(&bi,0,sizeof(bi));bf.bfType=0x4d42;
    bf.bfOffBits=sizeof(bf)+sizeof(bi);bf.bfSize=bf.bfOffBits+f->w*f->h*4;
    bi.biSize=sizeof(bi);bi.biWidth=f->w;bi.biHeight=-f->h;bi.biPlanes=1;bi.biBitCount=32;
    fwrite(&bf,sizeof(bf),1,out);fwrite(&bi,sizeof(bi),1,out);fwrite(f->p,4,(size_t)f->w*f->h,out);fclose(out);
}

static BOOL CALLBACK dump(HWND w,LPARAM child)
{
    char cls[128],title[512];RECT r;DWORD thread;GUITHREADINFO gi;
    if(!ours(w)||!IsWindowVisible(w))return TRUE;
    GetClassNameA(w,cls,sizeof(cls));GetWindowTextA(w,title,sizeof(title));GetWindowRect(w,&r);
    thread=GetWindowThreadProcessId(w,NULL);memset(&gi,0,sizeof(gi));gi.cbSize=sizeof(gi);GetGUIThreadInfo(thread,&gi);
    fprintf(logfile,"{\"event\":\"window\",\"hwnd\":\"%p\",\"parent\":\"%p\",\"owner\":\"%p\",\"foreground\":\"%p\",\"active\":\"%p\",\"focus\":\"%p\",\"class\":",
            w,GetParent(w),GetWindow(w,GW_OWNER),GetForegroundWindow(),gi.hwndActive,gi.hwndFocus);
    quoted(logfile,cls);fprintf(logfile,",\"title\":");quoted(logfile,title);
    fprintf(logfile,",\"rect\":[%ld,%ld,%ld,%ld],\"style\":%lu}\n",r.left,r.top,r.right,r.bottom,(unsigned long)GetWindowLongA(w,GWL_STYLE));
    if(!child)EnumChildWindows(w,dump,1);
    return TRUE;
}
static void snapshot(const char *name)
{
    Frame f=capture();fprintf(logfile,"{\"event\":\"snapshot\",\"name\":");quoted(logfile,name);fprintf(logfile,"}\n");
    EnumWindows(dump,0);fflush(logfile);save(name,&f);release(&f);
}
static LRESULT msg(HWND w,UINT id,WPARAM wp,LPARAM lp)
{
    DWORD_PTR r=0;if(!SendMessageTimeoutA(w,id,wp,lp,SMTO_ABORTIFHUNG,3000,&r)){
        check("window responds",0,GetLastError(),0);return -1;}return (LRESULT)r;
}

static const char *wanted;
static int contains(const char *s,const char *needle)
{
    size_t i,j,n=strlen(needle);for(i=0;s[i];i++){
        for(j=0;j<n&&s[i+j]&&tolower((unsigned char)s[i+j])==tolower((unsigned char)needle[j]);j++);
        if(j==n)return 1;}return !n;
}
static BOOL CALLBACK title_window(HWND w,LPARAM children)
{
    char title[512];if(!ours(w)||!IsWindowVisible(w))return TRUE;
    GetWindowTextA(w,title,sizeof(title));if(contains(title,wanted))result=w;
    if(children)EnumChildWindows(w,title_window,0);
    return TRUE;
}
static HWND locate(const char *title,int children)
{wanted=title;result=NULL;EnumWindows(title_window,children);return result;}

static int within(HWND child,HWND parent)
{return child==parent||IsChild(parent,child);}
static int above(HWND front,HWND back)
{
    HWND w;front=GetAncestor(front,GA_ROOT);back=GetAncestor(back,GA_ROOT);
    if(front==back)return 1;
    for(w=GetTopWindow(NULL);w;w=GetWindow(w,GW_HWNDNEXT)){
        if(w==front)return 1;
        if(w==back)return 0;}return 0;
}
static void assert_front(HWND dialog,HWND parent)
{
    HWND fg,owner;GUITHREADINFO gi;DWORD thread,start=GetTickCount();int linked=0,got;
    if(!dialog){check("expected dialog exists",0,0,1);return;}
    while(IsWindowVisible(dialog)&&!within(GetForegroundWindow(),dialog)&&GetTickCount()-start<min(deadline/4,10000))Sleep(100);
    fg=GetForegroundWindow();
    check("dialog visible",IsWindowVisible(dialog),IsWindowVisible(dialog),1);
    check("dialog is foreground input target",within(fg,dialog),within(fg,dialog),1);
    thread=GetWindowThreadProcessId(dialog,NULL);memset(&gi,0,sizeof(gi));gi.cbSize=sizeof(gi);
    got=GetGUIThreadInfo(thread,&gi);check("read target GUI thread state",got,got,1);
    if(got){
        check("dialog is thread active window",within(gi.hwndActive,dialog),within(gi.hwndActive,dialog),1);
        check("keyboard focus belongs to dialog",gi.hwndFocus&&within(gi.hwndFocus,dialog),gi.hwndFocus&&within(gi.hwndFocus,dialog),1);}
    if(parent){check("dialog is above expected parent",above(dialog,parent),above(dialog,parent),1);
        for(owner=dialog;owner;owner=GetWindow(owner,GW_OWNER))if(owner==parent){linked=1;break;}
        fprintf(logfile,"{\"event\":\"owner-chain\",\"dialog\":\"%p\",\"expected_parent\":\"%p\",\"linked\":%s}\n",dialog,parent,linked?"true":"false");}
    if(fullscreen_window&&dialog!=fullscreen_window)
        check("dialog is above fullscreen image",above(dialog,fullscreen_window),above(dialog,fullscreen_window),1);
}
static HWND expect_dialog(const char *name,HWND parent)
{
    DWORD start=GetTickCount();HWND w=NULL;
    while(GetTickCount()-start<deadline/2&&alive()){
        w=locate(name,0);if(w&&w!=parent)break;Sleep(100);}
    if(w==parent)w=NULL;
    check(name,w!=NULL,w!=NULL,1);if(w)assert_front(w,parent);snapshot(name);return w;
}
typedef struct {char wanted[256];HWND exact,partial;int exact_count,partial_count;} Controls;
static void normalized_caption(char *out,size_t size,const char *in)
{
    size_t i=0;int space=0;
    for(;*in&&i+1<size;in++){
        unsigned char c=(unsigned char)*in;
        if(c=='&')continue;
        if(c=='\t')break;
        if(isspace(c)){space=i!=0;continue;}
        if(space&&i+1<size)out[i++]=' ';
        space=0;out[i++]=(char)tolower(c);
    }
    while(i&&(out[i-1]=='.'||out[i-1]==' '))i--;
    out[i]=0;
}
static BOOL CALLBACK matching_control(HWND w,LPARAM context)
{
    Controls *c=(Controls *)context;char title[512],normal[512];RECT r;
    if(!ours(w)||!IsWindowVisible(w)||!IsWindowEnabled(w))return TRUE;
    GetWindowRect(w,&r);if(r.right<=r.left||r.bottom<=r.top)return TRUE;
    GetWindowTextA(w,title,sizeof(title));normalized_caption(normal,sizeof(normal),title);
    if(!normal[0])return TRUE;
    if(!strcmp(normal,c->wanted)){c->exact=w;c->exact_count++;}
    else if(contains(normal,c->wanted)){c->partial=w;c->partial_count++;}
    return TRUE;
}
static BOOL CALLBACK matching_top(HWND w,LPARAM context)
{EnumChildWindows(w,matching_control,context);return TRUE;}
static int click_control(const char *text,HWND scope)
{
    Controls c;HWND w=NULL;RECT r;char cls[128];memset(&c,0,sizeof(c));normalized_caption(c.wanted,sizeof(c.wanted),text);
    if(scope)EnumChildWindows(scope,matching_control,(LPARAM)&c);else EnumWindows(matching_top,(LPARAM)&c);
    if(c.exact_count==1)w=c.exact;else if(c.exact_count==0&&c.partial_count==1)w=c.partial;
    check("click locator is unique",w!=NULL,c.exact_count?c.exact_count:c.partial_count,1);
    if(!w){snapshot("missing-or-ambiguous-click-target");return 0;}
    GetWindowRect(w,&r);GetClassNameA(w,cls,sizeof(cls));
    fprintf(logfile,"{\"event\":\"click-target\",\"hwnd\":\"%p\",\"class\":",w);quoted(logfile,cls);
    fprintf(logfile,",\"label\":");quoted(logfile,text);fprintf(logfile,",\"rect\":[%ld,%ld,%ld,%ld]}\n",r.left,r.top,r.right,r.bottom);
    move((r.left+r.right)/2,(r.top+r.bottom)/2);click();Sleep(600);return 1;
}
static BOOL CALLBACK find_processing(HWND w,LPARAM lp)
{
    char t[128];
    if(!ours(w)||!IsWindowVisible(w))return TRUE;
    GetWindowTextA(w,t,sizeof(t));
    if(strstr(t,"Processing")){*(HWND *)lp=w;return FALSE;}
    return TRUE;
}
/* FastStone 5.6 shows a modal "Processing - Updating Database File" dialog on first
   use of a folder (CI run 40674997715 screenshot); no panel can open while it is up.
   Wait for the application to close it; never dismiss it with synthetic input. */
static void wait_no_processing_dialog(void)
{
    DWORD start=GetTickCount();HWND w=NULL;int seen=0;
    for(;;){
        w=NULL;EnumWindows(find_processing,(LPARAM)&w);
        if(!w){break;}
        seen=1;
        if(GetTickCount()-start>600000){fprintf(logfile,"{\"event\":\"processing-dialog-timeout\"}\n");break;}
        Sleep(500);
    }
    if(seen)fprintf(logfile,"{\"event\":\"processing-dialog-closed\",\"ms\":%lu}\n",(unsigned long)(GetTickCount()-start));
}
static void edge_once(const char *side)
{
    int sw=GetSystemMetrics(SM_CXSCREEN),sh=GetSystemMetrics(SM_CYSCREEN);
    center();
    if(!strcmp(side,"left"))move(0,sh/2);
    else if(!strcmp(side,"right"))move(sw-1,sh/2);
    else if(!strcmp(side,"top"))move(sw/2,0);
    else if(!strcmp(side,"bottom"))move(sw/2,sh-1);
    else check("known screen edge",0,0,1);
    Sleep(300);
    /* Many small motion events inside the edge zone: one approach did not open the
       8.5 panel while repeated moves did (run 40674997715). */
    {
        int k;
        for(k=0;k<16;k++){
            int d=(k&1)?0:6;
            if(!strcmp(side,"left"))move(d,sh/2+(k&2?1:0));
            else if(!strcmp(side,"right"))move(sw-1-d,sh/2+(k&2?1:0));
            else if(!strcmp(side,"top"))move(sw/2+(k&2?1:0),d);
            else if(!strcmp(side,"bottom"))move(sw/2+(k&2?1:0),sh-1-d);
            Sleep(50);
        }
    }
    Sleep(1500);
}
/* Approach an edge like a user would, retrying while nothing opened: the first
   approach after startup can be ignored while the application is still busy. */
static void edge(const char *side)
{
    int sw=GetSystemMetrics(SM_CXSCREEN),sh=GetSystemMetrics(SM_CYSCREEN),attempt;
    RECT zone={0,0,sw,sh};
    if(!strcmp(side,"top"))zone.bottom=sh/3;
    else if(!strcmp(side,"right"))zone.left=sw*2/3;
    else if(!strcmp(side,"bottom"))zone.top=sh*2/3;
    else if(!strcmp(side,"left"))zone.right=sw/3;
    wait_no_processing_dialog();
    for(attempt=1;attempt<=6;attempt++){
        Frame a,b;long n;
        center();a=capture();edge_once(side);b=capture();n=difference(&a,&b,zone);
        release(&a);release(&b);
        fprintf(logfile,"{\"event\":\"edge-attempt\",\"side\":\"%s\",\"attempt\":%d,\"changed_pixels\":%ld}\n",side,attempt,n);
        if(n>500)return;
        wait_no_processing_dialog();
    }
}
static int setup_fullscreen(void)
{
    HWND w=main_window();DWORD start;
    if(!w)return 0;
    SetForegroundWindow(w);center();if(!fullscreen()){key('F');Sleep(700);}
    start=GetTickCount();while(GetTickCount()-start<deadline&&alive()){
        if(fullscreen()){fullscreen_window=main_window();return 1;}Sleep(100);}return 0;
}
/* Diagnostic: if XTEST motion did not reveal the panel, ask which window Wine
   believes is under the pointer and whether message-driven logic reacts to
   posted WM_MOUSEMOVE. Separates "Wine did not deliver motion to the window"
   from "the application does not react to edge approach at all". */
static void diagnose_edge(const char *side,const Frame *before,RECT zone)
{
    int sw=GetSystemMetrics(SM_CXSCREEN),sh=GetSystemMetrics(SM_CYSCREEN),x=sw/2,y=sh/2,k;
    POINT pt;HWND under;char cls[128]="",title[128]="";DWORD upid=0;Frame d;long n;
    if(!strcmp(side,"left")){x=0;}else if(!strcmp(side,"right")){x=sw-1;}else if(!strcmp(side,"top")){y=0;}else if(!strcmp(side,"bottom")){y=sh-1;}
    pt.x=x;pt.y=y;under=WindowFromPoint(pt);
    if(under){GetClassNameA(under,cls,sizeof(cls));GetWindowTextA(under,title,sizeof(title));GetWindowThreadProcessId(under,&upid);}
    fprintf(logfile,"{\"event\":\"edge-diagnostic\",\"side\":\"%s\",\"under\":\"%p\",\"our_process\":%d,\"class\":",side,under,(int)(upid==pid));
    quoted(logfile,cls);fprintf(logfile,",\"title\":");quoted(logfile,title);fprintf(logfile,"}\n");
    if(!under)return;
    for(k=0;k<6;k++){POINT c=pt;ScreenToClient(under,&c);if(k<5){c.x+=(x==0?5-k:0);c.y+=(y==0?5-k:0);}
        PostMessageA(under,WM_MOUSEMOVE,0,MAKELPARAM(c.x,c.y));Sleep(80);}
    Sleep(1500);d=capture();n=difference(before,&d,zone);
    check("diagnostic: posted WM_MOUSEMOVE reveals panel",n>500,n,500);release(&d);
}
static void edges(void)
{
    const char *names[]={"top","right","bottom","left"};int i,sw=GetSystemMetrics(SM_CXSCREEN),sh=GetSystemMetrics(SM_CYSCREEN);
    for(i=0;i<4;i++){
        Frame a,b,c;RECT r={0,0,sw,sh};long n;
        center();a=capture();edge(names[i]);b=capture();
        if(i==0)r.bottom=sh/3;
        if(i==1)r.left=sw*2/3;
        if(i==2)r.top=sh*2/3;
        if(i==3)r.right=sw/3;
        n=difference(&a,&b,r);check(names[i],n>500,n,500);snapshot(names[i]);
        if(n<=500)diagnose_edge(names[i],&a,r);
        center();c=capture();n=difference(&b,&c,r);check("edge panel hides",n>500,n,500);
        check("edge retains fullscreen",fullscreen(),fullscreen(),1);release(&a);release(&b);release(&c);}
    move(sw-1,sh-1);Sleep(600);snapshot("bottom-right-corner");
    skip("Windows Taskbar corner","No desktop shell runs on isolated Xvfb.");center();
}

static BOOL CALLBACK find_strip(HWND w,LPARAM unused)
{
    char cls[128];RECT r;long area;(void)unused;
    if(!ours(w)||!IsWindowVisible(w))return TRUE;
    GetClassNameA(w,cls,sizeof(cls));if(strcmp(cls,"SysListView32"))return TRUE;
    GetWindowRect(w,&r);area=(r.right-r.left)*(r.bottom-r.top);
    if(r.top<GetSystemMetrics(SM_CYSCREEN)/3&&r.bottom<GetSystemMetrics(SM_CYSCREEN)/2&&
       r.right-r.left>GetSystemMetrics(SM_CXSCREEN)/2&&area>largest){largest=area;result=w;}return TRUE;
}
static BOOL CALLBACK strip_top(HWND w,LPARAM unused){find_strip(w,unused);EnumChildWindows(w,find_strip,0);return TRUE;}
static HWND strip(void){largest=0;result=NULL;EnumWindows(strip_top,0);return result;}
static int item_rect(HWND w,int index,RECT *r)
{
    HANDLE p=OpenProcess(PROCESS_VM_OPERATION|PROCESS_VM_READ|PROCESS_VM_WRITE,FALSE,pid);void *remote;int ok=0;
    if(!p)return 0;
    remote=VirtualAllocEx(p,NULL,sizeof(*r),MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE);r->left=LVIR_BOUNDS;
    if(remote&&WriteProcessMemory(p,remote,r,sizeof(*r),NULL)&&msg(w,LVM_GETITEMRECT,index,(LPARAM)remote)>0)
        ok=ReadProcessMemory(p,remote,r,sizeof(*r),NULL);
    if(remote)VirtualFreeEx(p,remote,0,MEM_RELEASE);
    CloseHandle(p);return ok;
}
static void top(void)
{
    HWND lv;RECT r,client;POINT origin={0,0};Frame a,b;long before,after;int i,target=-1,visible=0;LRESULT count;
    edge("top");lv=strip();check("thumbnail strip exists",lv!=NULL,lv!=NULL,1);snapshot("top-open");if(!lv)return;
    count=msg(lv,LVM_GETITEMCOUNT,0,0);check("164 thumbnails",count>=164,(long)count,164);
    GetWindowRect(lv,&r);GetClientRect(lv,&client);ClientToScreen(lv,&origin);move((r.left+r.right)/2,(r.top+r.bottom)/2);a=capture();
    before=GetScrollPos(lv,SB_HORZ);for(i=0;i<4;i++)mouse(MOUSEEVENTF_WHEEL,-WHEEL_DELTA);Sleep(700);
    after=GetScrollPos(lv,SB_HORZ);check("wheel advances horizontal strip",after>before,after,before+1);
    msg(lv,LVM_SCROLL,GetSystemMetrics(SM_CXSCREEN)*3,0);Sleep(1000);b=capture();
    before=colorful(&a,r);after=colorful(&b,r);check("scrolled thumbnails stay painted",after>500&&after*2>=before,after,before/2);
    for(i=0;i<(int)count;i++){RECT ir;if(item_rect(lv,i,&ir)&&ir.left>=0&&ir.right<=client.right&&ir.top>=0&&ir.bottom<=client.bottom){
        RECT screen=ir;char name[96];int bins;
        OffsetRect(&screen,origin.x,origin.y);bins=fixture_color_bins(&b,screen);visible++;
        snprintf(name,sizeof(name),"visible thumbnail %d retains multiple fixture colors",i);
        check(name,bins>=3,bins,3);
    }}
    check("at least one fully visible thumbnail tested",visible>0,visible,1);
    snapshot("top-scrolled");release(&a);release(&b);
    for(i=0;i<(int)count;i++){RECT ir;if(item_rect(lv,i,&ir)&&ir.left>=0&&ir.right<=client.right&&ir.top>=0&&ir.bottom<=client.bottom){
        target=i;move(origin.x+(ir.left+ir.right)/2,origin.y+(ir.top+ir.bottom)/2);click();break;}}
    check("visible scrolled item reachable",target>=0,target,0);if(target>=0){Sleep(500);
        after=(long)msg(lv,LVM_GETNEXTITEM,(WPARAM)-1,LVNI_SELECTED);check("scrolled item hit testing",after==target,after,target);snapshot("top-selected");}center();
}
static void changed(const char *name,WORD vk,WORD mod)
{
    Frame a=capture(),b;RECT r={60,60,GetSystemMetrics(SM_CXSCREEN)-60,GetSystemMetrics(SM_CYSCREEN)-60};long n;
    if(mod)chord(mod,vk);else key(vk);Sleep(650);b=capture();n=difference(&a,&b,r);
    check(name,n>500,n,500);snapshot(name);release(&a);release(&b);
}
static void navigation(void)
{key(VK_HOME);Sleep(300);changed("next-image",VK_SPACE,0);changed("previous-image",VK_BACK,0);
 changed("last-image",VK_END,0);changed("first-image",VK_HOME,0);check("navigation stays fullscreen",fullscreen(),fullscreen(),1);}
typedef struct {HWND w[16];LRESULT selected[16];int count;} Selections;
static BOOL CALLBACK collect_selection(HWND w,LPARAM context)
{
    Selections *s=(Selections *)context;char cls[128];DWORD_PTR count=0,selected=0;
    if(!ours(w)||s->count>=16)return TRUE;
    GetClassNameA(w,cls,sizeof(cls));if(strcmp(cls,"SysListView32"))return TRUE;
    if(!SendMessageTimeoutA(w,LVM_GETITEMCOUNT,0,0,SMTO_ABORTIFHUNG,2000,&count)||count<164)return TRUE;
    if(!SendMessageTimeoutA(w,LVM_GETNEXTITEM,(WPARAM)-1,LVNI_SELECTED,SMTO_ABORTIFHUNG,2000,&selected))return TRUE;
    s->w[s->count]=w;s->selected[s->count++]=(LRESULT)selected;return TRUE;
}
static BOOL CALLBACK collect_top(HWND w,LPARAM context)
{collect_selection(w,context);EnumChildWindows(w,collect_selection,context);return TRUE;}
static Selections selection(void)
{Selections s;memset(&s,0,sizeof(s));EnumWindows(collect_top,(LPARAM)&s);return s;}
static void same_image(const Selections *before)
{
    Selections after=selection();int i,j,matched=0;
    for(i=0;i<before->count;i++)for(j=0;j<after.count;j++)if(before->w[i]==after.w[j]){
        check("zoom preserves selected image",before->selected[i]==after.selected[j],(long)after.selected[j],(long)before->selected[i]);matched++;}
    if(!matched)skip("zoom image identity","This version exposes no common image ListView; inspect rendering separately.");
}
static void zoom(void)
{
    RECT r={100,100,GetSystemMetrics(SM_CXSCREEN)-100,GetSystemMetrics(SM_CYSCREEN)-100};
    Frame a,b;Selections s;long n;
    changed("actual-size",'A',0);changed("best-fit",'B',0);
    center();a=capture();s=selection();key_state(VK_CONTROL,1);mouse(MOUSEEVENTF_WHEEL,WHEEL_DELTA);key_state(VK_CONTROL,0);
    Sleep(500);b=capture();n=difference(&a,&b,r);check("Ctrl-wheel zooms",n>500,n,500);same_image(&s);save("ctrl-wheel",&b);release(&a);release(&b);
    key('B');center();a=capture();s=selection();edge("bottom");mouse(MOUSEEVENTF_WHEEL,WHEEL_DELTA);Sleep(500);center();b=capture();
    n=difference(&a,&b,r);check("bottom toolbar wheel zooms image",n>500,n,500);same_image(&s);save("bottom-wheel",&b);release(&a);release(&b);
}
static void pan_select(void)
{
    int sw=GetSystemMetrics(SM_CXSCREEN),sh=GetSystemMetrics(SM_CYSCREEN);
    RECT r={60,60,sw-60,sh-60};Frame a,b;Selections s;long n;
    key('A');center();a=capture();s=selection();mouse(MOUSEEVENTF_LEFTDOWN,0);move(sw/2+sw/6,sh/2+sh/6);Sleep(300);mouse(MOUSEEVENTF_LEFTUP,0);
    Sleep(400);b=capture();n=difference(&a,&b,r);check("drag pans oversized image",n>500,n,500);same_image(&s);save("pan-drag",&b);release(&a);release(&b);
    key('B');center();a=capture();s=selection();key_state(VK_CONTROL,1);move(sw/3,sh/3);mouse(MOUSEEVENTF_LEFTDOWN,0);
    move(sw*2/3,sh*2/3);Sleep(300);mouse(MOUSEEVENTF_LEFTUP,0);key_state(VK_CONTROL,0);Sleep(500);center();b=capture();
    n=difference(&a,&b,r);check("Ctrl-drag selects and zooms",n>500,n,500);same_image(&s);save("ctrl-drag-zoom",&b);release(&a);release(&b);
}
static void shift_zoom(void)
{
    RECT r={60,60,GetSystemMetrics(SM_CXSCREEN)-60,GetSystemMetrics(SM_CYSCREEN)-60};
    Frame a,b,c;Selections s;long n;key('B');center();a=capture();s=selection();
    key_state(VK_SHIFT,1);click();key_state(VK_SHIFT,0);Sleep(500);b=capture();
    n=difference(&a,&b,r);check("Shift-LMB zooms in",n>500,n,500);same_image(&s);save("shift-left-zoom",&b);
    key_state(VK_SHIFT,1);mouse(MOUSEEVENTF_RIGHTDOWN,0);mouse(MOUSEEVENTF_RIGHTUP,0);key_state(VK_SHIFT,0);Sleep(500);c=capture();
    n=difference(&b,&c,r);check("Shift-RMB zooms out",n>500,n,500);same_image(&s);check("Shift-RMB retains fullscreen",fullscreen(),fullscreen(),1);
    save("shift-right-zoom",&c);release(&a);release(&b);release(&c);
}
static void magnifier(int right)
{
    Frame a,b,c;RECT r={100,100,GetSystemMetrics(SM_CXSCREEN)-100,GetSystemMetrics(SM_CYSCREEN)-100};long n;
    key('B');center();a=capture();mouse(right?MOUSEEVENTF_RIGHTDOWN:MOUSEEVENTF_LEFTDOWN,0);Sleep(1200);b=capture();
    check("held button retains fullscreen",fullscreen(),fullscreen(),1);n=difference(&a,&b,r);check("held magnification",n>500,n,500);
    save(right?"right-held":"left-held",&b);mouse(right?MOUSEEVENTF_RIGHTUP:MOUSEEVENTF_LEFTUP,0);Sleep(400);c=capture();
    save(right?"right-released":"left-released",&c);release(&a);release(&b);release(&c);
}
static void transforms(void)
{
    const WORD keys[]={'L','R','H','V'};const char *names[]={"rotate-left","rotate-right","flip-horizontal","flip-vertical"};
    RECT r={60,60,GetSystemMetrics(SM_CXSCREEN)-60,GetSystemMetrics(SM_CYSCREEN)-60};int i;
    for(i=0;i<4;i++){Frame a,b,c,d;long n;key('B');center();a=capture();key(keys[i]);Sleep(700);b=capture();
        n=difference(&a,&b,r);check(names[i],n>500,n,500);save(names[i],&b);chord(VK_CONTROL,'Z');Sleep(700);c=capture();
        n=difference(&a,&c,r);check("undo restores image",n>=0&&n<1000,n,1000);chord(VK_CONTROL,'Y');Sleep(700);d=capture();
        n=difference(&b,&d,r);check("redo restores edit",n>=0&&n<1000,n,1000);chord(VK_CONTROL,'Z');Sleep(400);
        release(&a);release(&b);release(&c);release(&d);}
}
static void smoke_dialog(const char *title,WORD vk,WORD mod)
{
    HWND parent=main_window(),dialog;edge("left");snapshot("left-before-command");center();
    if(mod)chord(mod,vk);else key(vk);dialog=expect_dialog(title,parent);
    if(dialog){key(VK_ESCAPE);Sleep(700);assert_front(parent,fullscreen_window);}check("application lives after dialog",alive(),alive(),1);
}

/* Plans are TSV, recorded from observed controls/screenshots; no invisible
 * hotkey fallback is permitted for click steps. Missing locators fail fast.
 * edge SIDE | click-text TEXT | click-at X Y | expect TITLE | edit MARKER |
 * close | capture NAME. expect/close maintain a parent stack for nested UI.
 */
static BOOL CALLBACK edit_control(HWND w,LPARAM unused)
{
    char cls[128];(void)unused;if(!IsWindowVisible(w))return TRUE;GetClassNameA(w,cls,sizeof(cls));
    if(contains(cls,"edit")){result=w;return FALSE;}return TRUE;
}
static int edit_marker(HWND dialog,const char *marker)
{
    HWND edit;RECT r;char text[512];size_t i;GUITHREADINFO gi;DWORD t;
    result=NULL;EnumChildWindows(dialog,edit_control,0);edit=result;
    check("nested editable input exists",edit!=NULL,edit!=NULL,1);if(!edit)return 0;
    GetWindowRect(edit,&r);move((r.left+r.right)/2,(r.top+r.bottom)/2);click();Sleep(200);
    t=GetWindowThreadProcessId(dialog,NULL);memset(&gi,0,sizeof(gi));gi.cbSize=sizeof(gi);GetGUIThreadInfo(t,&gi);
    check("clicked edit owns keyboard focus",within(gi.hwndFocus,edit),gi.hwndFocus==edit,1);chord(VK_CONTROL,'A');
    for(i=0;marker[i];i++){unsigned char c=(unsigned char)marker[i];
        if(c>='a'&&c<='z')key((WORD)toupper(c));else if(c>='0'&&c<='9')key(c);else if(c==' ')key(VK_SPACE);
        else {check("marker uses supported keys",0,c,0);return 0;}}
    Sleep(200);GetWindowTextA(edit,text,sizeof(text));check("typing reaches expected nested edit",strstr(text,marker)!=NULL,strstr(text,marker)!=NULL,1);
    return strstr(text,marker)!=NULL;
}
static void plan(const char *path)
{
    FILE *f=fopen(path,"rb");char line[1024],*action,*arg,*arg2;HWND stack[24];int depth=0,line_no=0;
    Frame remembered={0,0,NULL};RECT remembered_region={0,0,0,0};HWND remembered_window=NULL;char remembered_name[80]="";
    check("E2E plan opens",f!=NULL,f!=NULL,1);if(!f)return;stack[0]=fullscreen_window;
    while(fgets(line,sizeof(line),f)&&alive()){
        int prior=failures;line_no++;line[strcspn(line,"\r\n")]=0;if(!line[0]||line[0]=='#')continue;
        action=strtok(line,"\t");arg=strtok(NULL,"\t");arg2=strtok(NULL,"\t");
        fprintf(logfile,"{\"event\":\"plan-step\",\"line\":%d,\"action\":",line_no);quoted(logfile,action);fprintf(logfile,"}\n");
        if(!strcmp(action,"edge")&&arg)edge(arg);
        else if(!strcmp(action,"click-text")&&arg)click_control(arg,depth?stack[depth]:NULL);
        else if(!strcmp(action,"click-at")&&arg&&arg2){int cx=atoi(arg),cy=atoi(arg2),k;
            /* Owner-drawn toolbar items track hover from several motion events before a press
               (the press after one jump was ignored and the panel closed, run 40687736869). */
            for(k=6;k>=0;k-=2){move(cx-k,cy-(k/2));Sleep(60);}
            Sleep(400);
            {char nm[64];sprintf(nm,"hover-%d-%d",cx,cy);snapshot(nm);x11_snapshot(nm);}
            click();Sleep(700);
            {char nm[64];sprintf(nm,"after-click-%d-%d",cx,cy);snapshot(nm);x11_snapshot(nm);}}
        else if(!strcmp(action,"expect")&&arg){HWND w=expect_dialog(arg,stack[depth]);
            if(w&&depth<23)stack[++depth]=w;else if(depth>=23)check("plan nesting bound",0,depth,23);}
        else if(!strcmp(action,"edit")&&arg)edit_marker(stack[depth],arg);
        else if(!strcmp(action,"active"))assert_front(stack[depth],depth?stack[depth-1]:NULL);
        else if(!strcmp(action,"close")){if(depth){HWND old=stack[depth--];key(VK_ESCAPE);Sleep(700);
                check("nested dialog closed or hidden",!IsWindowVisible(old),IsWindowVisible(old),0);assert_front(stack[depth],depth?stack[depth-1]:NULL);}
            else check("close has expected parent",0,depth,1);}
        else if(!strcmp(action,"return")){if(depth){HWND old=stack[depth];DWORD begin=GetTickCount();
                while(IsWindowVisible(old)&&GetTickCount()-begin<deadline/2)Sleep(100);
                check("clicked action closed nested dialog",!IsWindowVisible(old),IsWindowVisible(old),0);
                if(!IsWindowVisible(old)){depth--;assert_front(stack[depth],depth?stack[depth-1]:NULL);}}
            else check("return has expected parent",0,depth,1);}
        else if(!strcmp(action,"remember")&&arg){release(&remembered);remembered=capture();remembered_window=stack[depth];
            GetWindowRect(remembered_window,&remembered_region);InflateRect(&remembered_region,-40,-40);
            snprintf(remembered_name,sizeof(remembered_name),"%s",arg);snapshot(arg);}
        else if(!strcmp(action,"changed")&&arg){Frame now=capture();long n=difference(&remembered,&now,remembered_region);
            check("render comparison returns to same logical window",remembered_window==stack[depth],remembered_window==stack[depth],1);
            check("render comparison has matching baseline",!strcmp(remembered_name,arg),!strcmp(remembered_name,arg),1);
            check("accepted operation changes parent rendering",n>50,n,50);snapshot(arg);release(&now);}
        else if(!strcmp(action,"capture")&&arg)snapshot(arg);
        else check("valid E2E plan step",0,line_no,0);
        if(failures>prior){snapshot("e2e-first-failure");break;}
    }
    release(&remembered);fclose(f);
}

int main(int argc,char **argv)
{
    const char *app=NULL,*image=NULL,*scenario=NULL,*plan_path=NULL;char cmd[32768],path[MAX_PATH],dir[MAX_PATH],*slash;
    STARTUPINFOA si;PROCESS_INFORMATION pi;DWORD start;int i,code;
    setvbuf(stdout,NULL,_IONBF,0);
    for(i=1;i<argc;i++){
        if(!strcmp(argv[i],"--app")&&i+1<argc)app=argv[++i];
        else if(!strcmp(argv[i],"--image")&&i+1<argc)image=argv[++i];
        else if(!strcmp(argv[i],"--out")&&i+1<argc)snprintf(output,sizeof(output),"%s",argv[++i]);
        else if(!strcmp(argv[i],"--scenario")&&i+1<argc)scenario=argv[++i];
        else if(!strcmp(argv[i],"--plan")&&i+1<argc)plan_path=argv[++i];
        else if(!strcmp(argv[i],"--timeout-ms")&&i+1<argc)deadline=strtoul(argv[++i],NULL,0);
        else if(!strcmp(argv[i],"--external-input"))external=1;
        else {fprintf(stderr,"Unknown argument: %s\n",argv[i]);return 2;}}
    if(!app||!image||!output[0]||(!scenario&&!plan_path)){
        fprintf(stderr,"gui-suite --app EXE --image FILE --out DIR --scenario edges|top|navigation|zoom|pan-select|shift-zoom|magnifier|right-hold|transforms|crop|resize|draw|copy|move|slideshow|comment|histogram|save-as|settings|properties [--plan TSV] [--external-input]\n");return 2;}
    CreateDirectoryA(output,NULL);snprintf(path,sizeof(path),"%s\\assertions.jsonl",output);logfile=fopen(path,"wb");if(!logfile)return 2;
    fprintf(logfile,"{\"event\":\"start\",\"scenario\":");quoted(logfile,scenario?scenario:"plan");fprintf(logfile,",\"app\":");quoted(logfile,app);fprintf(logfile,"}\n");
    snprintf(cmd,sizeof(cmd),"\"%s\" \"%s\"",app,image);snprintf(dir,sizeof(dir),"%s",app);slash=strrchr(dir,'\\');if(slash)*slash=0;
    memset(&si,0,sizeof(si));memset(&pi,0,sizeof(pi));si.cb=sizeof(si);
    if(!CreateProcessA(app,cmd,NULL,NULL,FALSE,0,NULL,slash?dir:NULL,&si,&pi)){check("launch",0,GetLastError(),0);fclose(logfile);return 1;}
    pid=pi.dwProcessId;process=pi.hProcess;CloseHandle(pi.hThread);start=GetTickCount();
    while(GetTickCount()-start<deadline&&!main_window()&&alive())Sleep(100);
    Sleep(1500);snapshot("startup");check("main window exists",main_window()!=NULL,main_window()!=NULL,1);
    if(!setup_fullscreen()){check("enter fullscreen",0,0,1);goto done;}
    check("enter fullscreen",1,1,1);snapshot("fullscreen");
    if(plan_path)plan(plan_path);
    else if(!strcmp(scenario,"edges")||!strcmp(scenario,"inspect"))edges();
    else if(!strcmp(scenario,"top"))top();else if(!strcmp(scenario,"navigation"))navigation();
    else if(!strcmp(scenario,"zoom"))zoom();else if(!strcmp(scenario,"pan-select"))pan_select();else if(!strcmp(scenario,"shift-zoom"))shift_zoom();
    else if(!strcmp(scenario,"magnifier"))magnifier(0);else if(!strcmp(scenario,"right-hold"))magnifier(1);
    else if(!strcmp(scenario,"transforms"))transforms();
    else if(!strcmp(scenario,"crop"))smoke_dialog("Crop",'X',0);
    else if(!strcmp(scenario,"resize"))smoke_dialog("Resize",'R',VK_CONTROL);
    else if(!strcmp(scenario,"draw"))smoke_dialog("Draw",'D',0);
    else if(!strcmp(scenario,"copy"))smoke_dialog("Copy",'C',0);else if(!strcmp(scenario,"move"))smoke_dialog("Move",'M',0);
    else if(!strcmp(scenario,"slideshow"))smoke_dialog("Slide",'S',0);else if(!strcmp(scenario,"comment"))smoke_dialog("Comment",'T',0);
    else if(!strcmp(scenario,"histogram"))smoke_dialog("Histogram",'H',VK_CONTROL);
    else if(!strcmp(scenario,"save-as"))smoke_dialog("Save",'S',VK_CONTROL);
    else if(!strcmp(scenario,"settings"))smoke_dialog("Settings",VK_F12,0);
    else if(!strcmp(scenario,"properties"))smoke_dialog("Properties",'I',0);else check("known scenario",0,0,1);
done:
    snapshot("final");if(main_window()){DWORD_PTR r;check("application remains responsive",SendMessageTimeoutA(main_window(),WM_NULL,0,0,SMTO_ABORTIFHUNG,30000,&r)!=0,alive(),1);}
    else check("application remains alive",0,alive(),1);
    fprintf(logfile,"{\"event\":\"summary\",\"checks\":%d,\"failures\":%d}\n",checks,failures);fclose(logfile);code=failures?1:0;
    if(alive())TerminateProcess(process,0);
    CloseHandle(process);return code;
}
