/*
 * Does Wine deliver XTEST pointer motion to Win32 windows as WM_MOUSEMOVE and
 * to a WH_MOUSE_LL hook?  FastStone edge panels did not open although
 * GetCursorPos followed the XTEST pointer; this isolates the delivery path
 * from application logic.  Runs under gui-suite-x11-bridge (GUI_INPUT protocol).
 * Output: NDJSON lines, "type":"case" with pass flags.  Exit 0 = probe ran.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>

static unsigned serial;
static volatile LONG move_count, ll_count;
static volatile LONG last_x = -1, last_y = -1, ll_x = -1, ll_y = -1;

static int bridge_move(long x, long y)
{
    char reply[32];
    printf("GUI_INPUT %u MOVE %ld %ld\n", ++serial, x, y);
    fflush(stdout);
    return fgets(reply, sizeof(reply), stdin) && !strncmp(reply, "OK", 2);
}

static LRESULT CALLBACK ll_proc(int code, WPARAM wp, LPARAM lp)
{
    if (code == HC_ACTION && wp == WM_MOUSEMOVE)
    {
        const MSLLHOOKSTRUCT *m = (const MSLLHOOKSTRUCT *)lp;
        InterlockedIncrement(&ll_count);
        ll_x = m->pt.x;
        ll_y = m->pt.y;
    }
    return CallNextHookEx(NULL, code, wp, lp);
}

static LRESULT CALLBACK wnd_proc(HWND w, UINT msg, WPARAM wp, LPARAM lp)
{
    if (msg == WM_MOUSEMOVE)
    {
        POINT pt;
        InterlockedIncrement(&move_count);
        pt.x = (short)LOWORD(lp);
        pt.y = (short)HIWORD(lp);
        ClientToScreen(w, &pt);
        last_x = pt.x;
        last_y = pt.y;
    }
    return DefWindowProcW(w, msg, wp, lp);
}

static void pump(DWORD ms)
{
    DWORD start = GetTickCount();
    MSG m;
    while (GetTickCount() - start < ms)
    {
        while (PeekMessageW(&m, NULL, 0, 0, PM_REMOVE)) { TranslateMessage(&m); DispatchMessageW(&m); }
        Sleep(10);
    }
}

static int move_expect(const char *name, long x, long y)
{
    int ok, got_msg, got_ll;
    LONG m0 = move_count, l0 = ll_count;
    ok = bridge_move(x, y);
    pump(700);
    got_msg = move_count > m0 && last_x == x && last_y == y;
    got_ll = ll_count > l0 && ll_x == x && ll_y == y;
    printf("{\"type\":\"case\",\"name\":\"%s\",\"x\":%ld,\"y\":%ld,\"bridge\":%d,"
           "\"wm_mousemove_at_target\":%d,\"ll_hook_at_target\":%d,\"wm_count\":%ld,\"ll_count\":%ld,"
           "\"last\":[%ld,%ld],\"ll_last\":[%ld,%ld]}\n",
           name, x, y, ok, got_msg, got_ll, (long)(move_count - m0), (long)(ll_count - l0),
           (long)last_x, (long)last_y, (long)ll_x, (long)ll_y);
    fflush(stdout);
    return ok;
}

static HWND make_window(const char *title, DWORD style, int x, int y, int w, int h, DWORD ex)
{
    WNDCLASSW cls;
    WCHAR wtitle[64];
    static ATOM atom;
    if (!atom)
    {
        memset(&cls, 0, sizeof(cls));
        cls.lpfnWndProc = wnd_proc;
        cls.hInstance = GetModuleHandleW(NULL);
        cls.lpszClassName = L"PointerDeliveryProbe";
        cls.hCursor = LoadCursorW(NULL, MAKEINTRESOURCEW(32512));
        cls.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
        atom = RegisterClassW(&cls);
    }
    MultiByteToWideChar(CP_UTF8, 0, title, -1, wtitle, 64);
    return CreateWindowExW(ex, L"PointerDeliveryProbe", wtitle, style, x, y, w, h, NULL, NULL,
                           GetModuleHandleW(NULL), NULL);
}

int main(void)
{
    HWND w;
    int sw, sh;
    HHOOK hook = SetWindowsHookExW(WH_MOUSE_LL, ll_proc, GetModuleHandleW(NULL), 0);
    sw = GetSystemMetrics(SM_CXSCREEN);
    sh = GetSystemMetrics(SM_CYSCREEN);
    printf("{\"type\":\"info\",\"ll_hook_installed\":%d,\"screen\":[%d,%d]}\n", hook != NULL, sw, sh);

    w = make_window("windowed", WS_POPUP | WS_VISIBLE, 100, 100, 400, 300, 0);
    pump(500);
    move_expect("windowed-inside-1", 150, 150);
    move_expect("windowed-inside-2", 300, 250);
    DestroyWindow(w);

    w = make_window("fullscreen", WS_POPUP | WS_VISIBLE, 0, 0, sw, sh, WS_EX_TOPMOST);
    SetForegroundWindow(w);
    pump(500);
    move_expect("fullscreen-center", sw / 2, sh / 2);
    move_expect("fullscreen-left-edge", 0, sh / 2);
    move_expect("fullscreen-right-edge", sw - 1, sh / 2);
    move_expect("fullscreen-top-edge", sw / 2, 0);
    move_expect("fullscreen-bottom-edge", sw / 2, sh - 1);

    {
        RECT r = { 0, 0, sw, sh };
        ClipCursor(&r);
        move_expect("fullscreen-clipped-center", sw / 2, sh / 2);
        move_expect("fullscreen-clipped-left-edge", 0, sh / 2);
        move_expect("fullscreen-clipped-top-edge", sw / 2, 0);
        ClipCursor(NULL);
    }
    DestroyWindow(w);
    if (hook) UnhookWindowsHookEx(hook);
    printf("POINTER_PROBE_DONE\n");
    return 0;
}
