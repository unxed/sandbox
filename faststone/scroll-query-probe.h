#ifndef FASTSTONE_SCROLL_QUERY_PROBE_H
#define FASTSTONE_SCROLL_QUERY_PROBE_H

#include <windows.h>
#include <commctrl.h>

#define SCROLL_PROBE_MAPPING_PREFIX "Local\\LunobotScrollProbe-"

typedef struct {
    HWND hwnd;
    volatile LONG done;
    BOOL info_ok;
    DWORD info_error;
    SCROLLINFO info;
    BOOL bar_ok;
    DWORD bar_error;
    SCROLLBARINFO bar;
} ScrollProbeResult;

#endif
