#define WIN32_LEAN_AND_MEAN
#include "scroll-query-probe.h"
#include <stdio.h>
#include <string.h>

/* Executed by a remote thread inside the disposable FastStone process. This
   makes the public scrollbar queries same-process without changing FSViewer. */
__declspec(dllexport) DWORD WINAPI run_probe(void)
{
    char name[96];
    HANDLE mapping;
    ScrollProbeResult *result;
    DWORD pid=GetCurrentProcessId();

    snprintf(name,sizeof(name),SCROLL_PROBE_MAPPING_PREFIX "%lu",(unsigned long)pid);
    mapping=OpenFileMappingA(FILE_MAP_ALL_ACCESS,FALSE,name);
    if(!mapping)return GetLastError();
    result=(ScrollProbeResult *)MapViewOfFile(mapping,FILE_MAP_ALL_ACCESS,0,0,sizeof(*result));
    if(!result){DWORD error=GetLastError();CloseHandle(mapping);return error;}

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
    UnmapViewOfFile(result);
    CloseHandle(mapping);
    return 0;
}
