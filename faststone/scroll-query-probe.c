#define WIN32_LEAN_AND_MEAN
#include "scroll-query-probe.h"
#include <stdio.h>
#include <string.h>

static HANDLE probe_mapping;
static ScrollProbeResult *probe_result;
static HHOOK wheel_hook_handle;
static HHOOK wheel_return_hook_handle;

static void resolve_proc_module(uintptr_t address,HMODULE *module,char *path,DWORD path_size,
                                uintptr_t *base,uintptr_t *rva,DWORD *memory_type,DWORD *error)
{
    MEMORY_BASIC_INFORMATION info;
    DWORD size;
    *module=NULL;*path=0;*base=0;*rva=0;*memory_type=0;
    SetLastError(ERROR_SUCCESS);
    if(address&&GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|
        GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,(LPCSTR)address,module)){
        *base=(uintptr_t)*module;
    }else{
        *error=GetLastError();
        if(address&&VirtualQuery((LPCVOID)address,&info,sizeof(info))==sizeof(info)){
            *memory_type=info.Type;
            if(info.Type==MEM_IMAGE){
                *module=(HMODULE)info.AllocationBase;
                *base=(uintptr_t)info.AllocationBase;
            }
        }
    }
    if(*module){
        size=GetModuleFileNameA(*module,path,path_size);
        if(size==0&&!*error)*error=GetLastError();
        if(address>=*base)*rva=address-*base;
    }
}

static void record_window_proc(HWND hwnd,ScrollProbeResult *result)
{
    LONG_PTR window_proc=GetWindowLongPtrA(hwnd,GWLP_WNDPROC);
    LONG_PTR class_proc=GetClassLongPtrA(hwnd,GCLP_WNDPROC);
    HMODULE window_module=NULL,class_module=NULL;
    ScrollProbeWindowProc *entry;
    LONG slot=InterlockedIncrement(&result->window_proc_count)-1;
    if(slot<0||slot>=9)return;
    entry=&result->window_procs[slot];
    memset(entry,0,sizeof(*entry));
    entry->hwnd=hwnd;
    entry->window_proc=(uintptr_t)window_proc;
    entry->class_proc=(uintptr_t)class_proc;
    GetClassNameA(hwnd,entry->class_name,sizeof(entry->class_name));
    resolve_proc_module((uintptr_t)window_proc,&window_module,entry->window_module,
        sizeof(entry->window_module),&entry->window_module_base,&entry->window_proc_rva,
        &entry->window_module_type,&entry->window_module_error);
    resolve_proc_module((uintptr_t)class_proc,&class_module,entry->class_module,
        sizeof(entry->class_module),&entry->class_module_base,&entry->class_proc_rva,
        &entry->class_module_type,&entry->class_module_error);
}

static void record_window_proc_chain(HWND target,ScrollProbeResult *result)
{
    HWND hwnd=target,parent;
    LONG depth=0;
    result->window_proc_count=0;
    record_window_proc(hwnd,result);
    for(parent=GetParent(target);parent&&depth<8;parent=GetParent(parent),depth++)
        record_window_proc(parent,result);
}

static void record_wheel_message(HWND hwnd,UINT message,WPARAM wparam,LPARAM lparam,
                                 LONG phase,LRESULT result)
{
    LONG slot=InterlockedIncrement(&probe_result->wheel_count)-1;
    ScrollProbeWheelMessage *event;
    HWND target=probe_result->hwnd,parent;
    LONG depth=0;
    if(slot>=SCROLL_PROBE_MAX_WHEEL_MESSAGES)return;
    event=&probe_result->wheel_messages[slot];
    event->hwnd=hwnd;
    event->message=message;
    event->wParam=wparam;
    event->lParam=lparam;
    event->hook_phase=phase;
    event->result=result;
    event->relation_depth=-1;
    event->class_name[0]='\0';
    for(parent=target;parent&&depth<16;parent=GetParent(parent),depth++){
        if(parent==hwnd){event->relation_depth=depth;break;}
    }
    if(event->relation_depth==-1&&IsChild(target,hwnd))event->relation_depth=-2;
    GetClassNameA(hwnd,event->class_name,sizeof(event->class_name));
}

static LRESULT CALLBACK wheel_hook(int code,WPARAM wparam,LPARAM lparam)
{
    if(code>=0&&probe_result){
        const CWPSTRUCT *call=(const CWPSTRUCT *)lparam;
        if(call->message==WM_MOUSEWHEEL||call->message==WM_MOUSEHWHEEL){
            record_wheel_message(call->hwnd,call->message,call->wParam,call->lParam,0,0);
        }
    }
    return CallNextHookEx(wheel_hook_handle,code,wparam,lparam);
}

static LRESULT CALLBACK wheel_return_hook(int code,WPARAM wparam,LPARAM lparam)
{
    if(code>=0&&probe_result){
        const CWPRETSTRUCT *call=(const CWPRETSTRUCT *)lparam;
        if(call->message==WM_MOUSEWHEEL||call->message==WM_MOUSEHWHEEL)
            record_wheel_message(call->hwnd,call->message,call->wParam,call->lParam,1,call->lResult);
    }
    return CallNextHookEx(wheel_return_hook_handle,code,wparam,lparam);
}

/* Executed by a remote thread inside the disposable FastStone process. This
   makes the public scrollbar queries same-process and records delivered wheel
   messages without changing FSViewer. */
__declspec(dllexport) DWORD WINAPI run_probe(void)
{
    char name[96];
    ScrollProbeResult *result;
    DWORD pid=GetCurrentProcessId();

    snprintf(name,sizeof(name),SCROLL_PROBE_MAPPING_PREFIX "%lu",(unsigned long)pid);
    if(!probe_result){
        probe_mapping=OpenFileMappingA(FILE_MAP_ALL_ACCESS,FALSE,name);
        if(!probe_mapping)return GetLastError();
        probe_result=(ScrollProbeResult *)MapViewOfFile(probe_mapping,FILE_MAP_ALL_ACCESS,0,0,sizeof(*probe_result));
        if(!probe_result){DWORD error=GetLastError();CloseHandle(probe_mapping);probe_mapping=NULL;return error;}
    }
    result=probe_result;
    record_window_proc_chain(result->hwnd,result);

    if(!wheel_hook_handle){
        DWORD thread_id=GetWindowThreadProcessId(result->hwnd,NULL);
        HMODULE module=GetModuleHandleA("scroll-query-probe.dll");
        if(thread_id&&module){
            wheel_hook_handle=SetWindowsHookExA(WH_CALLWNDPROC,wheel_hook,module,thread_id);
            if(!wheel_hook_handle)result->hook_error=GetLastError();
        }else result->hook_error=GetLastError();
    }
    if(!wheel_return_hook_handle){
        DWORD thread_id=GetWindowThreadProcessId(result->hwnd,NULL);
        HMODULE module=GetModuleHandleA("scroll-query-probe.dll");
        if(thread_id&&module){
            wheel_return_hook_handle=SetWindowsHookExA(WH_CALLWNDPROCRET,wheel_return_hook,module,thread_id);
            if(!wheel_return_hook_handle)result->return_hook_error=GetLastError();
        }else result->return_hook_error=GetLastError();
    }

    result->done=0;
    memset(&result->info,0,sizeof(result->info));
    result->info.cbSize=sizeof(result->info);
    result->info.fMask=SIF_ALL;
    SetLastError(ERROR_SUCCESS);
    result->info_ok=GetScrollInfo(result->hwnd,SB_HORZ,&result->info);
    result->info_error=GetLastError();

    memset(&result->bar,0,sizeof(result->bar));
    result->bar.cbSize=sizeof(result->bar);
    SetLastError(ERROR_SUCCESS);
    result->bar_ok=GetScrollBarInfo(result->hwnd,OBJID_HSCROLL,&result->bar);
    result->bar_error=GetLastError();
    InterlockedExchange(&result->done,1);
    return 0;
}
