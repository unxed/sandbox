/* Differential test of HX DKRNL32 code page conversions (WC2MB.ASM,
   GETCPINF.ASM, assembled by JWasm and linked in) against kernel32 of the
   Windows runner (taken with GetProcAddress).  windows.h is not included on
   purpose: the calls below must bind to the linked DKRNL32 objects, not to
   the kernel32 imports.  Exit code 0 = all checks passed. */

#include <stdio.h>
#include <string.h>

#define WINAPI __stdcall
#define IMP __declspec(dllimport)

typedef unsigned short WCH;

/* DKRNL32, linked objects */
int WINAPI MultiByteToWideChar(unsigned cp, unsigned long fl, const char *s,
                               int n, WCH *d, int nd);
int WINAPI WideCharToMultiByte(unsigned cp, unsigned long fl, const WCH *s,
                               int n, char *d, int nd, const char *defc,
                               int *useddef);
int WINAPI GetCPInfo(unsigned cp, void *info);

/* kernel32 */
IMP void *WINAPI GetModuleHandleA(const char *name);
IMP void *WINAPI GetProcAddress(void *mod, const char *name);
IMP unsigned long WINAPI GetLastError(void);
IMP void WINAPI SetLastError(unsigned long err);

typedef int(WINAPI *MB2WC)(unsigned, unsigned long, const char *, int, WCH *,
                           int);
typedef int(WINAPI *WC2MB)(unsigned, unsigned long, const WCH *, int, char *,
                           int, const char *, int *);
typedef int(WINAPI *CPINFO)(unsigned, void *);

static MB2WC ref_mb;
static WC2MB ref_wc;
static CPINFO ref_cpi;
static int checks, fails;

#define CP_UTF8 65001
#define MB_ERR_INVALID_CHARS 0x08
#define WC_ERR_INVALID_CHARS 0x80

static void hexb(const char *p, int n)
{
    int i;
    for (i = 0; i < n; i++)
        printf(" %02X", (unsigned char)p[i]);
}

static void hexw(const WCH *p, int n)
{
    int i;
    for (i = 0; i < n; i++)
        printf(" %04X", p[i]);
}

static void mb(const char *name, const char *src, int n, unsigned long fl,
               int nd)
{
    WCH a[64], b[64];
    int ra, rb, ok;
    unsigned long ea = 0, eb = 0;

    memset(a, 0xCC, sizeof a);
    memset(b, 0xCC, sizeof b);
    SetLastError(0);
    ra = MultiByteToWideChar(CP_UTF8, fl, src, n, nd ? a : NULL, nd);
    if (!ra)
        ea = GetLastError();
    SetLastError(0);
    rb = ref_mb(CP_UTF8, fl, src, n, nd ? b : NULL, nd);
    if (!rb)
        eb = GetLastError();
    ok = ra == rb && (ra ? (!nd || !memcmp(a, b, ra * 2)) : ea == eb);
    checks++;
    if (!ok) {
        fails++;
        printf("FAIL mb %s n=%d fl=%lX nd=%d: hx=%d err=%lu", name, n, fl, nd,
               ra, ea);
        if (ra && nd)
            hexw(a, ra);
        printf(" | win=%d err=%lu", rb, eb);
        if (rb && nd)
            hexw(b, rb);
        printf("\n");
    }
}

static void wc(const char *name, const WCH *src, int n, unsigned long fl,
               int nd)
{
    char a[64], b[64];
    int ra, rb, ok;
    unsigned long ea = 0, eb = 0;

    memset(a, 0xCC, sizeof a);
    memset(b, 0xCC, sizeof b);
    SetLastError(0);
    ra = WideCharToMultiByte(CP_UTF8, fl, src, n, nd ? a : NULL, nd, NULL,
                             NULL);
    if (!ra)
        ea = GetLastError();
    SetLastError(0);
    rb = ref_wc(CP_UTF8, fl, src, n, nd ? b : NULL, nd, NULL, NULL);
    if (!rb)
        eb = GetLastError();
    ok = ra == rb && (ra ? (!nd || !memcmp(a, b, ra)) : ea == eb);
    checks++;
    if (!ok) {
        fails++;
        printf("FAIL wc %s n=%d fl=%lX nd=%d: hx=%d err=%lu", name, n, fl, nd,
               ra, ea);
        if (ra && nd)
            hexb(a, ra);
        printf(" | win=%d err=%lu", rb, eb);
        if (rb && nd)
            hexb(b, rb);
        printf("\n");
    }
}

static void expect(const char *what, int cond)
{
    checks++;
    if (!cond) {
        fails++;
        printf("FAIL %s\n", what);
    }
}

struct mbv {
    const char *name, *s;
    int n;
};
#define M(name, lit) {name, lit, sizeof(lit) - 1}

static const struct mbv mbvec[] = {
    M("empty", ""),
    M("ascii", "hello"),
    M("cyrillic", "\xD0\x9F\xD1\x80\xD0\xB8\xD0\xB2\xD0\xB5\xD1\x82"),
    M("cjk", "\xE6\x97\xA5\xE6\x9C\xAC\xE8\xAA\x9E"),
    M("emoji", "\xF0\x9F\x98\x80"),
    M("mixed", "a\xD0\x96\xE6\x97\xA5\xF0\x9F\x98\x80z"),
    M("U+0080", "\xC2\x80"),
    M("U+07FF", "\xDF\xBF"),
    M("U+0800", "\xE0\xA0\x80"),
    M("U+D7FF", "\xED\x9F\xBF"),
    M("U+E000", "\xEE\x80\x80"),
    M("U+FFFD", "\xEF\xBF\xBD"),
    M("U+FFFF", "\xEF\xBF\xBF"),
    M("U+10000", "\xF0\x90\x80\x80"),
    M("U+10FFFF", "\xF4\x8F\xBF\xBF"),
    M("nul inside", "a\0b"),
    M("bad 80", "\x80"),
    M("bad BF", "\xBF"),
    M("overlong C0 80", "\xC0\x80"),
    M("overlong C1 BF", "\xC1\xBF"),
    M("overlong E0 80 80", "\xE0\x80\x80"),
    M("overlong E0 9F BF", "\xE0\x9F\xBF"),
    M("surrogate ED A0 80", "\xED\xA0\x80"),
    M("surrogate ED BF BF", "\xED\xBF\xBF"),
    M("overlong F0 8F", "\xF0\x8F\xBF\xBF"),
    M("too big F4 90", "\xF4\x90\x80\x80"),
    M("F5", "\xF5\x80\x80\x80"),
    M("FE", "\xFE"),
    M("FF", "\xFF"),
    M("cut C3", "\xC3"),
    M("cut E3 81", "\xE3\x81"),
    M("cut E3 81 A", "\xE3\x81" "A"),
    M("cut F0 9F 98 A", "\xF0\x9F\x98" "A"),
    M("cut then ok", "\xE3\x81\xE3\x81\x82"),
    M("extra cont", "\xF0\x9F\x98\x80\x80"),
    M("bad between", "a\x80" "b\xC3\xA9"),
    M("C3 C3 A9", "\xC3\xC3\xA9"),
};

struct wcv {
    const char *name;
    WCH s[8];
    int n;
};

static const struct wcv wcvec[] = {
    {"empty", {0}, 0},
    {"ascii", {'h', 'e', 'l', 'l', 'o'}, 5},
    {"cyrillic", {0x41F, 0x440, 0x438, 0x432, 0x435, 0x442}, 6},
    {"cjk", {0x65E5, 0x672C, 0x8A9E}, 3},
    {"emoji", {0xD83D, 0xDE00}, 2},
    {"U+10FFFF", {0xDBFF, 0xDFFF}, 2},
    {"bounds", {0x7F, 0x80, 0x7FF, 0x800, 0xD7FF, 0xE000, 0xFFFD, 0xFFFF}, 8},
    {"nul inside", {'a', 0, 'b'}, 3},
    {"lone high", {0xD800}, 1},
    {"high then A", {0xD800, 'A'}, 2},
    {"lone low", {0xDC00}, 1},
    {"low high", {0xDC00, 0xD800}, 2},
    {"high high low", {0xD83D, 0xD83D, 0xDE00}, 3},
    {"A then high", {'A', 0xDBFF}, 2},
};

static const int sizes[] = {64, 0, 1, 2, 3};

int main(void)
{
    void *k32 = GetModuleHandleA("kernel32.dll");
    unsigned i, j, f;
    static const unsigned long mbfl[] = {0, MB_ERR_INVALID_CHARS};
    static const unsigned long wcfl[] = {0, WC_ERR_INVALID_CHARS};

    ref_mb = (MB2WC)GetProcAddress(k32, "MultiByteToWideChar");
    ref_wc = (WC2MB)GetProcAddress(k32, "WideCharToMultiByte");
    ref_cpi = (CPINFO)GetProcAddress(k32, "GetCPInfo");
    if (!ref_mb || !ref_wc || !ref_cpi) {
        printf("no kernel32 reference\n");
        return 2;
    }

    for (i = 0; i < sizeof mbvec / sizeof mbvec[0]; i++)
        for (f = 0; f < 2; f++)
            for (j = 0; j < sizeof sizes / sizeof sizes[0]; j++) {
                mb(mbvec[i].name, mbvec[i].s, mbvec[i].n, mbfl[f],
                       sizes[j]);
                mb(mbvec[i].name, mbvec[i].s, -1, mbfl[f], sizes[j]);
            }

    for (i = 0; i < sizeof wcvec / sizeof wcvec[0]; i++)
        for (f = 0; f < 2; f++)
            for (j = 0; j < sizeof sizes / sizeof sizes[0]; j++) {
                WCH z[9];
                wc(wcvec[i].name, wcvec[i].s, wcvec[i].n, wcfl[f],
                       sizes[j]);
                memcpy(z, wcvec[i].s, sizeof wcvec[i].s);
                z[wcvec[i].n] = 0;
                wc(wcvec[i].name, z, -1, wcfl[f], sizes[j]);
            }

    /* GetCPInfo: whole CPINFO (18 bytes) as Windows has it */
    {
        static const unsigned cps[] = {CP_UTF8, 437, 850, 866, 1252};
        for (i = 0; i < sizeof cps / sizeof cps[0]; i++) {
            unsigned char a[18], b[18];
            char what[64];
            memset(a, 0xCC, sizeof a);
            memset(b, 0xCC, sizeof b);
            GetCPInfo(cps[i], a);
            ref_cpi(cps[i], b);
            sprintf(what, "GetCPInfo(%u) same as Windows", cps[i]);
            expect(what, !memcmp(a, b, sizeof a));
        }
    }

    /* other code pages: unchanged behaviour, bytes 1:1 to 0000h-00FFh */
    {
        WCH w[8];
        char c[8];
        static const WCH ws[] = {0x41, 0xE9, 0x410};
        int r;

        r = MultiByteToWideChar(1, 0, "A\xE9\x80", 3, w, 8);
        expect("CP_OEMCP mb: 3 chars, zero-extended",
               r == 3 && w[0] == 0x41 && w[1] == 0xE9 && w[2] == 0x80);
        r = MultiByteToWideChar(0, 0, "A\xE9", -1, w, 8);
        expect("CP_ACP mb -1: 3 chars with the 0",
               r == 3 && w[0] == 0x41 && w[1] == 0xE9 && w[2] == 0);
        r = MultiByteToWideChar(0, 0, "A\xE9", -1, NULL, 0);
        expect("CP_ACP mb size query", r == 3);
        r = WideCharToMultiByte(1, 0, ws, 3, c, 8, NULL, NULL);
        expect("CP_OEMCP wc: 3 bytes, low byte",
               r == 3 && c[0] == 0x41 && (unsigned char)c[1] == 0xE9 &&
                   c[2] == 0x10);
        r = WideCharToMultiByte(0, 0, ws, 3, NULL, 0, NULL, NULL);
        expect("CP_ACP wc size query", r == 3);
    }

    printf("%d checks, %d failed\n", checks, fails);
    return fails ? 1 : 0;
}
