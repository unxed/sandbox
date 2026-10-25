// Замер: цена вызова Go-DLL из нативного (не-Go) потока против нативных вызовов Windows.
// Сборка: gcc -O2 bench.c -o bench.exe (gobench.dll грузится через LoadLibrary).
#include <windows.h>
#include <stdio.h>

typedef int (__cdecl *nop_t)(int);
static nop_t go_nop;
static double ns_per_tick;
static volatile LONG sink;
#define N 1000000

static double now(void) {
    LARGE_INTEGER c;
    QueryPerformanceCounter(&c);
    return (double)c.QuadPart * ns_per_tick;
}

#define BENCH(name, expr) do { \
    for (int w = 0; w < 1000; w++) { expr; } \
    double t0 = now(); \
    for (int i = 0; i < N; i++) { expr; } \
    double t1 = now(); \
    printf("  %-40s %8.1f ns/call\n", name, (t1 - t0) / N); \
} while (0)

static void run_suite(const char *where) {
    HANDLE ev = CreateEventW(NULL, FALSE, FALSE, NULL);
    POINT p;
    int x = 0;
    printf("[%s]\n", where);
    BENCH("empty loop (floor)", sink++);
    BENCH("GetCurrentThreadId (user-mode, TEB)", sink += (LONG)GetCurrentThreadId());
    BENCH("SetEvent (NtSetEvent, real syscall)", SetEvent(ev));
    BENCH("GetCursorPos (win32k syscall)", GetCursorPos(&p));
    BENCH("Go DLL export Nop (foreign thread)", x = go_nop(x));
    sink += x;
    CloseHandle(ev);
}

static DWORD WINAPI thr(LPVOID a) {
    (void)a;
    run_suite("CreateThread thread (foreign to Go)");
    return 0;
}

static DWORD WINAPI once(LPVOID a) {
    (void)a;
    go_nop(1);
    return 0;
}

int main(void) {
    LARGE_INTEGER f;
    QueryPerformanceFrequency(&f);
    ns_per_tick = 1e9 / (double)f.QuadPart;

    HMODULE h = LoadLibraryA("gobench.dll");
    if (!h) { printf("LoadLibrary failed: %lu\n", GetLastError()); return 1; }
    go_nop = (nop_t)GetProcAddress(h, "Nop");
    if (!go_nop) { printf("GetProcAddress failed: %lu\n", GetLastError()); return 1; }

    go_nop(0); // первый вызов: инициализация Go-рантайма
    run_suite("main thread");

    HANDLE t = CreateThread(NULL, 0, thr, NULL, 0, NULL);
    WaitForSingleObject(t, INFINITE);
    CloseHandle(t);

    // свежий поток + первый вызов в Go (attach), против свежего потока без вызова
    const int M = 2000;
    double t0 = now();
    for (int i = 0; i < M; i++) {
        HANDLE h2 = CreateThread(NULL, 0, once, NULL, 0, NULL);
        WaitForSingleObject(h2, INFINITE);
        CloseHandle(h2);
    }
    double t1 = now();
    printf("[thread lifecycle]\n  fresh thread + first Go call %14.0f ns/thread\n", (t1 - t0) / M);
    return 0;
}
