/* Black-box public ListView API tests for Wine #59251 / #59609.
 * Build i686/x86_64-w64-mingw32-gcc -O2 -Wall -Wextra this.c -o probe.exe
 *       -lcomctl32 -lgdi32 -luser32
 * Output: NDJSON. --measure keeps assertions but always returns exit status 0.
 * Fixture positions are checked: no scroll conclusions from a failed layout.
 * Native reference: --dll Z:\work\test-bin\native\comctl32.dll --expect-comctl 5.80
 * The DLL is loaded explicitly; the executable has no comctl32 import.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commctrl.h>
#include <shlwapi.h>
#include <stdio.h>
#include <string.h>

static unsigned checks, failures;
static BOOL measure_only;
static HIMAGELIST normal_images, small_images;
static unsigned expected_major,expected_minor;
static BOOL expect_version;
static HMODULE test_module;
static HIMAGELIST (WINAPI *pImageList_Create)(int,int,UINT,int,int);
static int (WINAPI *pImageList_Add)(HIMAGELIST,HBITMAP,HBITMAP);
static BOOL (WINAPI *pImageList_Destroy)(HIMAGELIST);

static void check(const char *test,const char *name,BOOL success)
{
    checks++;
    if (!success) failures++;
    printf("{\"type\":\"assert\",\"test\":\"%s\",\"name\":\"%s\",\"pass\":%s}\n",
           test,name,success?"true":"false");
    fflush(stdout);
}

static void pump(void)
{
    MSG msg;
    while (PeekMessageA(&msg,NULL,0,0,PM_REMOVE))
    {
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }
}

static HIMAGELIST make_images(int size)
{
    HIMAGELIST images=pImageList_Create(size,size,ILC_COLOR32|ILC_MASK,1,0);
    HDC dc=GetDC(NULL),mem=CreateCompatibleDC(dc);
    HBITMAP bmp=CreateCompatibleBitmap(dc,size,size),old=SelectObject(mem,bmp);
    RECT r={0,0,size,size};
    FillRect(mem,&r,(HBRUSH)GetStockObject(BLACK_BRUSH));
    pImageList_Add(images,bmp,NULL);
    SelectObject(mem,old); DeleteObject(bmp); DeleteDC(mem); ReleaseDC(NULL,dc);
    return images;
}

static HWND make_list(HWND parent,DWORD style,unsigned columns,unsigned rows,const char *test)
{
    HWND lv;
    LVITEMA item;
    unsigned i;
    BOOL positions_ok=TRUE;
    POINT first,last;
    HMODULE class_module;
    char module_path[MAX_PATH];
    DLLVERSIONINFO version;
    HRESULT (CALLBACK *class_getver)(DLLVERSIONINFO *);
    lv=CreateWindowExA(0,WC_LISTVIEWA,"",WS_CHILD|WS_VISIBLE|LVS_SHAREIMAGELISTS|style,
                       0,0,380,220,parent,NULL,test_module,NULL);
    check(test,"create",lv!=NULL);
    if (!lv) return NULL;
    /* GCLP_HMODULE is not an identity oracle: Wine's builtin comctl32 registers its
       classes with hInstance NULL (so the executable is reported). Identify the
       implementation by the module that contains the class window procedure. */
    {
        WNDCLASSEXW wc;HMODULE impl=NULL,reported=(HMODULE)GetClassLongPtrA(lv,GCLP_HMODULE);
        memset(&wc,0,sizeof(wc));wc.cbSize=sizeof(wc);
        if (GetClassInfoExW(reported,L"SysListView32",&wc) && wc.lpfnWndProc)
            GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                               (LPCWSTR)wc.lpfnWndProc,&impl);
        printf("{\"type\":\"class-identity\",\"test\":\"%s\",\"hmodule_reported\":\"%p\",\"wndproc_module\":\"%p\",\"selected\":\"%p\"}\n",
               test,(void *)reported,(void *)impl,(void *)test_module);
        class_module=impl?impl:reported;
    }
    check(test,"class-module-is-selected-module",class_module==test_module);
    GetModuleFileNameA(class_module,module_path,sizeof(module_path));
    fprintf(stderr,"ListView class module (%s): %s\n",test,module_path);
    memset(&version,0,sizeof(version)); version.cbSize=sizeof(version);
    class_getver=(void *)GetProcAddress(class_module,"DllGetVersion");
    if (class_getver) class_getver(&version);
    printf("{\"type\":\"class-module-version\",\"test\":\"%s\",\"version\":[%lu,%lu,%lu]}\n",
           test,version.dwMajorVersion,version.dwMinorVersion,version.dwBuildNumber);
    if (expect_version)
        check(test,"class-module-has-required-reference-version",
              version.dwMajorVersion==expected_major && version.dwMinorVersion==expected_minor);
    ListView_SetImageList(lv,normal_images,LVSIL_NORMAL);
    ListView_SetImageList(lv,small_images,LVSIL_SMALL);
    ListView_SetIconSpacing(lv,100,110);
    memset(&item,0,sizeof(item));
    item.mask=LVIF_TEXT|LVIF_IMAGE; item.pszText="tile"; item.iImage=0;
    for(i=0;i<columns*rows;i++)
    {
        item.iItem=i;
        if (ListView_InsertItem(lv,&item)!=(int)i) positions_ok=FALSE;
    }
    /* Finish initial metrics/paint before manual placement: Wine's first paint
     * arranges items even without LVS_AUTOARRANGE. Then resize once to update
     * scrollbar ranges, because moving an individual Wine icon does not. */
    UpdateWindow(lv); pump();
    for(i=0;i<columns*rows;i++)
        if (!SendMessageA(lv,LVM_SETITEMPOSITION,i,MAKELPARAM(20+(i%columns)*100,20+(i/columns)*110)))
            positions_ok=FALSE;
    SetWindowPos(lv,NULL,0,0,381,220,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);
    SetWindowPos(lv,NULL,0,0,380,220,SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE);
    UpdateWindow(lv); pump();
    first.x=first.y=last.x=last.y=-9999;
    if (!ListView_GetItemPosition(lv,0,&first) || !ListView_GetItemPosition(lv,columns*rows-1,&last))
        positions_ok=FALSE;
    positions_ok=positions_ok && last.x-first.x==(LONG)(columns-1)*100 && last.y-first.y==(LONG)(rows-1)*110;
    printf("{\"type\":\"layout\",\"test\":\"%s\",\"columns\":%u,\"rows\":%u,"
           "\"first_position\":[%ld,%ld],\"last_position\":[%ld,%ld]}\n",
           test,columns,rows,first.x,first.y,last.x,last.y);
    check(test,"manual-layout-verified",positions_ok);
    if (!positions_ok) { DestroyWindow(lv); return NULL; }
    return lv;
}

static void point_record(const char *test,const char *stage,HWND lv,int index,
                         POINT *position,POINT *origin,RECT *icon)
{
    BOOL p,o,r;
    position->x=position->y=origin->x=origin->y=-9999;
    SetRect(icon,-9999,-9999,-9999,-9999);
    p=ListView_GetItemPosition(lv,index,position);
    o=ListView_GetOrigin(lv,origin);
    r=ListView_GetItemRect(lv,index,icon,LVIR_ICON);
    printf("{\"type\":\"position\",\"test\":\"%s\",\"stage\":\"%s\",\"item\":%d,"
           "\"position_ok\":%d,\"origin_ok\":%d,\"rect_ok\":%d,"
           "\"position\":[%ld,%ld],\"origin\":[%ld,%ld],\"icon_rect\":[%ld,%ld,%ld,%ld],"
           "\"style\":%lu,\"scroll\":[%d,%d]}\n",
           test,stage,index,p,o,r,position->x,position->y,origin->x,origin->y,
           icon->left,icon->top,icon->right,icon->bottom,
           (unsigned long)GetWindowLongA(lv,GWL_STYLE),GetScrollPos(lv,SB_HORZ),GetScrollPos(lv,SB_VERT));
    check(test,"position-origin-icon-queries-succeed",p&&o&&r);
}

static void neighbors(HWND lv,int index,int results[4])
{
    static const UINT directions[]={LVNI_TOLEFT,LVNI_TORIGHT,LVNI_ABOVE,LVNI_BELOW};
    unsigned i;
    for(i=0;i<4;i++) results[i]=ListView_GetNextItem(lv,index,directions[i]);
}

static void test_coordinates(HWND parent,DWORD style,const char *test)
{
    HWND lv=make_list(parent,style,10,8,test);
    POINT before,after,origin_before,origin_after;
    RECT rect_before,rect_after;
    int adjacent_before[4],adjacent_after[4];
    LVFINDINFOA find;
    int find_public,find_client;
    BYTE keys[256],saved[256];
    UINT selected;
    const int index=34;
    if (!lv) return;
    point_record(test,"before",lv,index,&before,&origin_before,&rect_before);
    neighbors(lv,index,adjacent_before);
    check(test,"scroll-call",ListView_Scroll(lv,300,220)); pump();
    point_record(test,"scrolled",lv,index,&after,&origin_after,&rect_after);
    check(test,"both-axes-actually-scrolled",origin_after.x>origin_before.x && origin_after.y>origin_before.y);
    check(test,"public-position-stays-in-view-coordinates",before.x==after.x && before.y==after.y);
    check(test,"icon-rect-moves-in-client-coordinates",
          rect_before.left-rect_after.left==origin_after.x-origin_before.x &&
          rect_before.top-rect_after.top==origin_after.y-origin_before.y);
    neighbors(lv,index,adjacent_after);
    printf("{\"type\":\"neighbors\",\"test\":\"%s\",\"item\":%d,\"before\":[%d,%d,%d,%d],"
           "\"after\":[%d,%d,%d,%d]}\n",test,index,
           adjacent_before[0],adjacent_before[1],adjacent_before[2],adjacent_before[3],
           adjacent_after[0],adjacent_after[1],adjacent_after[2],adjacent_after[3]);
    check(test,"directional-neighbors-unchanged-by-scroll",!memcmp(adjacent_before,adjacent_after,sizeof(adjacent_before)));
    check(test,"right-neighbor-is-next-column",adjacent_after[1]==index+1);
    memset(&find,0,sizeof(find)); find.flags=LVFI_NEARESTXY;
    find.vkDirection=VK_RIGHT; find.pt=after;
    find_public=ListView_FindItem(lv,-1,&find);
    find.pt.x-=origin_after.x; find.pt.y-=origin_after.y;
    find_client=ListView_FindItem(lv,-1,&find);
    printf("{\"type\":\"finditem-coordinate-convention\",\"test\":\"%s\","
           "\"from_public_position\":%d,\"from_public_minus_origin\":%d}\n",test,find_public,find_client);
    /* Both private callers must continue to receive client coordinates. */
    ListView_SetItemState(lv,-1,0,LVIS_SELECTED|LVIS_FOCUSED);
    ListView_SetItemState(lv,index,LVIS_SELECTED|LVIS_FOCUSED,LVIS_SELECTED|LVIS_FOCUSED);
    ListView_SetSelectionMark(lv,index); SetFocus(lv);
    GetKeyboardState(saved); memcpy(keys,saved,sizeof(keys));
    keys[VK_SHIFT]=keys[VK_LSHIFT]=0x80;
    check(test,"set-shift-key-state",SetKeyboardState(keys));
    SendMessageA(lv,WM_KEYDOWN,VK_RIGHT,1);
    SetKeyboardState(saved); pump();
    selected=ListView_GetSelectedCount(lv);
    printf("{\"type\":\"selection\",\"test\":\"%s\",\"count\":%u,\"focused\":%d,"
           "\"anchor_selected\":%d,\"neighbor_selected\":%d}\n",test,selected,
           ListView_GetNextItem(lv,-1,LVNI_FOCUSED),
           !!ListView_GetItemState(lv,index,LVIS_SELECTED),!!ListView_GetItemState(lv,index+1,LVIS_SELECTED));
    check(test,"shift-right-focus",ListView_GetNextItem(lv,-1,LVNI_FOCUSED)==index+1);
    check(test,"shift-right-selects-anchor-and-neighbor-only",selected==2 &&
          ListView_GetItemState(lv,index,LVIS_SELECTED) && ListView_GetItemState(lv,index+1,LVIS_SELECTED));
    DestroyWindow(lv); pump();
}

static void reset_scroll(HWND lv)
{
    SendMessageA(lv,WM_HSCROLL,SB_LEFT,0);
    SendMessageA(lv,WM_VSCROLL,SB_TOP,0); pump();
}

static void wheel_record(const char *test,const char *stage,HWND lv,int delta)
{
    SendMessageA(lv,WM_MOUSEWHEEL,MAKEWPARAM(0,(WORD)delta),0); pump();
    printf("{\"type\":\"wheel\",\"test\":\"%s\",\"stage\":\"%s\",\"delta\":%d,"
           "\"style\":%lu,\"scroll\":[%d,%d]}\n",test,stage,delta,
           (unsigned long)GetWindowLongA(lv,GWL_STYLE),GetScrollPos(lv,SB_HORZ),GetScrollPos(lv,SB_VERT));
}

static void test_wheel(HWND parent,DWORD style,unsigned columns,unsigned rows,const char *test,BOOL horizontal)
{
    HWND lv=make_list(parent,style,columns,rows,test);
    int sb=horizontal?SB_HORZ:SB_VERT,other=horizontal?SB_VERT:SB_HORZ;
    int full,fractional,i;
    DWORD window_style;
    if (!lv) return;
    window_style=GetWindowLongA(lv,GWL_STYLE);
    printf("{\"type\":\"wheel-layout\",\"test\":\"%s\",\"horizontal\":%s,\"style\":%lu}\n",
           test,horizontal?"true":"false",(unsigned long)window_style);
    check(test,"intended-scrollbar-present",!!(window_style&(horizontal?WS_HSCROLL:WS_VSCROLL)));
    check(test,"other-scrollbar-absent",!(window_style&(horizontal?WS_VSCROLL:WS_HSCROLL)));
    reset_scroll(lv); wheel_record(test,"full-down",lv,-WHEEL_DELTA);
    full=GetScrollPos(lv,sb);
    check(test,"full-down-moves-correct-axis",full>0 && GetScrollPos(lv,other)==0);
    wheel_record(test,"full-up",lv,WHEEL_DELTA);
    check(test,"full-up-returns-to-start",GetScrollPos(lv,sb)==0);
    reset_scroll(lv);
    for(i=0;i<4;i++) wheel_record(test,"quarter-down",lv,-WHEEL_DELTA/4);
    fractional=GetScrollPos(lv,sb);
    /* Do not assume exact fractional semantics before a reliable native run. */
    printf("{\"type\":\"wheel-fraction-comparison\",\"test\":\"%s\",\"one_full\":%d,\"four_quarters\":%d}\n",
           test,full,fractional);
    wheel_record(test,"quarter-direction-change",lv,WHEEL_DELTA/4);
    wheel_record(test,"zero",lv,0);
    reset_scroll(lv); wheel_record(test,"double-down",lv,-2*WHEEL_DELTA);
    DestroyWindow(lv); pump();
}

static void test_wheel_both(HWND parent,DWORD style,const char *test)
{
    HWND lv=make_list(parent,style,10,8,test);
    DWORD window_style;
    if (!lv) return;
    window_style=GetWindowLongA(lv,GWL_STYLE);
    check(test,"both-scrollbars-present",(window_style&(WS_HSCROLL|WS_VSCROLL))==(WS_HSCROLL|WS_VSCROLL));
    reset_scroll(lv); wheel_record(test,"full-down",lv,-WHEEL_DELTA);
    check(test,"vertical-axis-keeps-priority",GetScrollPos(lv,SB_VERT)>0 && GetScrollPos(lv,SB_HORZ)==0);
    wheel_record(test,"full-up",lv,WHEEL_DELTA);
    check(test,"full-up-returns-to-start",GetScrollPos(lv,SB_VERT)==0 && GetScrollPos(lv,SB_HORZ)==0);
    DestroyWindow(lv); pump();
}

int main(int argc,char **argv)
{
    INITCOMMONCONTROLSEX init={sizeof(init),ICC_LISTVIEW_CLASSES};
    DLLVERSIONINFO v;
    HRESULT (CALLBACK *getver)(DLLVERSIONINFO *);
    HWND parent;
    UINT lines=0;
    char module[MAX_PATH];
    HMODULE dll;
    BOOL (WINAPI *pInitCommonControlsEx)(const INITCOMMONCONTROLSEX *);
    const char *selected_dll="comctl32.dll";
    int arg;
    for(arg=1;arg<argc;arg++)
    {
        if (!strcmp(argv[arg],"--measure")) measure_only=TRUE;
        else if (!strcmp(argv[arg],"--expect-comctl") && arg+1<argc)
        {
            if (sscanf(argv[++arg],"%u.%u",&expected_major,&expected_minor)!=2) return 2;
            expect_version=TRUE;
        }
        else if (!strcmp(argv[arg],"--dll") && arg+1<argc) selected_dll=argv[++arg];
        else return 2;
    }
    /* An explicit module and its function pointers prevent an implicit import
     * or GetModuleHandle basename collision from silently selecting builtin
     * controls in a native-reference run. Use this same module for the control
     * class lookup and verify GCLP_HMODULE in every fixture. */
    test_module=LoadLibraryA(selected_dll);
    if (!test_module) { fprintf(stderr,"LoadLibrary(%s) failed: %lu\n",selected_dll,GetLastError()); return 2; }
    pInitCommonControlsEx=(void *)GetProcAddress(test_module,"InitCommonControlsEx");
    pImageList_Create=(void *)GetProcAddress(test_module,"ImageList_Create");
    pImageList_Add=(void *)GetProcAddress(test_module,"ImageList_Add");
    pImageList_Destroy=(void *)GetProcAddress(test_module,"ImageList_Destroy");
    if (!pInitCommonControlsEx || !pImageList_Create || !pImageList_Add || !pImageList_Destroy) return 2;
    if (!pInitCommonControlsEx(&init)) return 2;
    dll=test_module;
    memset(&v,0,sizeof(v)); v.cbSize=sizeof(v);
    getver=(void *)GetProcAddress(dll,"DllGetVersion");
    if (getver) getver(&v);
    GetModuleFileNameA(dll,module,sizeof(module));
    fprintf(stderr,"comctl32 module: %s\n",module);
    SystemParametersInfoA(SPI_GETWHEELSCROLLLINES,0,&lines,0);
    printf("{\"type\":\"environment\",\"pointer_bits\":%u,\"comctl32\":[%lu,%lu,%lu],\"wheel_lines\":%u,\"measure_only\":%s}\n",
           (unsigned)(sizeof(void *)*8),v.dwMajorVersion,v.dwMinorVersion,v.dwBuildNumber,lines,measure_only?"true":"false");
    parent=CreateWindowExA(0,"STATIC","ListView API regression tests",WS_OVERLAPPEDWINDOW|WS_VISIBLE,
                           20,20,640,480,NULL,NULL,GetModuleHandleA(NULL),NULL);
    if (!parent) {
        fprintf(stderr,"CreateWindow(parent STATIC) failed: %lu\n",GetLastError());
        return 2;
    }
    normal_images=make_images(32); small_images=make_images(16);
    test_coordinates(parent,LVS_ICON,"icon-coordinates");
    test_coordinates(parent,LVS_SMALLICON,"small-icon-coordinates");
    test_wheel(parent,LVS_ICON,80,1,"icon-horizontal-wheel",TRUE);
    test_wheel(parent,LVS_ICON,1,80,"icon-vertical-wheel",FALSE);
    test_wheel(parent,LVS_SMALLICON,80,1,"small-icon-horizontal-wheel",TRUE);
    test_wheel(parent,LVS_SMALLICON,1,80,"small-icon-vertical-wheel",FALSE);
    test_wheel_both(parent,LVS_ICON,"icon-both-axis-wheel");
    test_wheel_both(parent,LVS_SMALLICON,"small-icon-both-axis-wheel");
    pImageList_Destroy(normal_images); pImageList_Destroy(small_images); DestroyWindow(parent);
    printf("{\"type\":\"summary\",\"checks\":%u,\"failures\":%u}\n",checks,failures);
    return measure_only?0:!!failures;
}
