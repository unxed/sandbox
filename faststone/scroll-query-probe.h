#ifndef FASTSTONE_SCROLL_QUERY_PROBE_H
#define FASTSTONE_SCROLL_QUERY_PROBE_H

#include <windows.h>
#include <commctrl.h>
#include <stdint.h>

#define SCROLL_PROBE_MAPPING_PREFIX "Local\\LunobotScrollProbe-"
#define SCROLL_PROBE_MAX_WHEEL_MESSAGES 128

typedef struct {
    HWND hwnd;
    UINT message;
    WPARAM wParam;
    LPARAM lParam;
    LRESULT result;
    LONG hook_phase;
    LONG relation_depth;
    char class_name[64];
} ScrollProbeWheelMessage;

typedef struct {
    HWND hwnd;
    uintptr_t window_proc;
    uintptr_t class_proc;
    char class_name[64];
    char window_module[MAX_PATH];
    char class_module[MAX_PATH];
    uintptr_t window_module_base;
    uintptr_t window_proc_rva;
    uintptr_t class_module_base;
    uintptr_t class_proc_rva;
    DWORD window_module_type;
    DWORD class_module_type;
    DWORD window_module_error;
    DWORD class_module_error;
} ScrollProbeWindowProc;

typedef struct {
    HWND hwnd;
    volatile LONG done;
    volatile LONG wheel_count;
    DWORD return_hook_error;
    DWORD hook_error;
    ScrollProbeWheelMessage wheel_messages[SCROLL_PROBE_MAX_WHEEL_MESSAGES];
    volatile LONG window_proc_count;
    ScrollProbeWindowProc window_procs[9];
    BOOL info_ok;
    DWORD info_error;
    SCROLLINFO info;
    BOOL bar_ok;
    DWORD bar_error;
    SCROLLBARINFO bar;
} ScrollProbeResult;

#endif
