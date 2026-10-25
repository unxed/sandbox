/*
 * Minimal visible Win32 GUI probe for the FastStone Wine workbench.
 *
 * It deliberately tests only the shared prerequisite for every later viewer
 * scenario: a top-level window and a child STATIC control can be created and
 * remain mapped long enough for the guest-side X11 snapshot helper to record
 * them.  It does not use, inspect, or modify FastStone binaries.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int hold_seconds = 20;

static int parse_args(int argc, char **argv)
{
    int i;
    for (i = 1; i < argc; ++i)
    {
        if (!strcmp(argv[i], "--hold-seconds") && i + 1 < argc)
        {
            char *end = NULL;
            long value = strtol(argv[++i], &end, 10);
            if (!end || *end || value < 1 || value > 300) return 0;
            hold_seconds = (int)value;
        }
        else return 0;
    }
    return 1;
}

int main(int argc, char **argv)
{
    WNDCLASSW cls;
    HWND parent, child;
    MSG message;
    DWORD started;

    if (!parse_args(argc, argv))
    {
        fprintf(stderr, "usage: gui-bootstrap-probe [--hold-seconds 1..300]\n");
        return 2;
    }
    memset(&cls, 0, sizeof(cls));
    cls.hInstance = GetModuleHandleW(NULL);
    cls.hCursor = LoadCursorW(NULL, IDC_ARROW);
    cls.lpfnWndProc = DefWindowProcW;
    cls.lpszClassName = L"FastStoneWineGuiBootstrapProbe";
    if (!RegisterClassW(&cls))
    {
        fprintf(stderr, "FAIL register parent class last_error=%lu\n", GetLastError());
        return 3;
    }
    parent = CreateWindowExW(0, cls.lpszClassName, L"Wine GUI bootstrap probe",
                             WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                             80, 60, 640, 240, NULL, NULL, cls.hInstance, NULL);
    if (!parent)
    {
        fprintf(stderr, "FAIL create parent last_error=%lu\n", GetLastError());
        return 3;
    }
    child = CreateWindowExW(0, L"STATIC", L"Wine GUI bootstrap static",
                            WS_CHILD | WS_VISIBLE | SS_CENTER,
                            40, 80, 560, 48, parent, NULL, cls.hInstance, NULL);
    if (!child)
    {
        fprintf(stderr, "FAIL create static last_error=%lu\n", GetLastError());
        DestroyWindow(parent);
        return 3;
    }
    ShowWindow(parent, SW_SHOWNORMAL);
    UpdateWindow(parent);
    fprintf(stderr, "GUI_BOOTSTRAP_READY parent=0x%p static=0x%p hold_seconds=%d\n",
            (void *)parent, (void *)child, hold_seconds);
    fflush(stderr);

    started = GetTickCount();
    while ((DWORD)(GetTickCount() - started) < (DWORD)hold_seconds * 1000U)
    {
        while (PeekMessageW(&message, NULL, 0, 0, PM_REMOVE))
        {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
        Sleep(20);
    }
    DestroyWindow(parent);
    return 0;
}
