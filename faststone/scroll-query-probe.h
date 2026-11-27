#ifndef FASTSTONE_SCROLL_QUERY_PROBE_H
#define FASTSTONE_SCROLL_QUERY_PROBE_H

#include <windows.h>
#include <commctrl.h>

#define SCROLL_PROBE_MAPPING_PREFIX "Local\\LunobotScrollProbe-"
#define SCROLL_PROBE_MAX_WHEEL_MESSAGES 64

typedef struct {
    HWND hwnd;
    UINT message;
    WPARAM wParam;
    LPARAM lParam;
    LONG relation_depth;
    char class_name[64];
} ScrollProbeWheelMessage;

typedef struct {
    HWND hwnd;
    volatile LONG done;
    volatile LONG wheel_count;
    DWORD hook_error;
    BOOL direct_probe;
    LONG direct_before;
    LONG direct_after;
    LRESULT direct_result;
    ScrollProbeWheelMessage wheel_messages[SCROLL_PROBE_MAX_WHEEL_MESSAGES];
    BOOL info_ok;
    DWORD info_error;
    SCROLLINFO info;
    BOOL bar_ok;
    DWORD bar_error;
    SCROLLBARINFO bar;
} ScrollProbeResult;

#endif
