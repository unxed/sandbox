/* Public-API regression probe for Wine bug 48872.
 * Compile without a v6 manifest to test comctl32 v5, as used by FastStone.
 * Run the same executable with builtin comctl32 and app-local native cc580.
 * --measure-only records observations without enabling the proposed regression
 * expectation. --view / --font permit independent parallel test shards.
 * No application executable or private DLL implementation is inspected.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commctrl.h>
#include <shlwapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum text_case { EMPTY, NULL_TEXT, CALLBACK_EMPTY, CALLBACK_NULL, SPACE, NORMAL, MULTILINE };
static const char *case_names[] = {"empty", "null", "callback-empty", "callback-null", "space", "normal", "multiline"};
static const char *view_names[] = {"icon", "report", "smallicon", "list"};
static enum text_case current_case;
static unsigned callbacks, failures, records;
static BOOL measure_only;
static BOOL require_native_cc580, class_reported;
static const COLORREF background_color = RGB(235, 243, 251);

static LRESULT CALLBACK parent_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp)
{
    if (msg == WM_NOTIFY)
    {
        NMHDR *hdr = (NMHDR *)lp;
        if (hdr->code == LVN_GETDISPINFOA)
        {
            NMLVDISPINFOA *di = (NMLVDISPINFOA *)lp;
            if (di->item.mask & LVIF_TEXT)
            {
                callbacks++;
                if (current_case == CALLBACK_NULL) di->item.pszText = NULL;
                else if (di->item.pszText && di->item.cchTextMax) di->item.pszText[0] = 0;
            }
        }
        else if (hdr->code == LVN_GETDISPINFOW)
        {
            NMLVDISPINFOW *di = (NMLVDISPINFOW *)lp;
            if (di->item.mask & LVIF_TEXT)
            {
                callbacks++;
                if (current_case == CALLBACK_NULL) di->item.pszText = NULL;
                else if (di->item.pszText && di->item.cchTextMax) di->item.pszText[0] = 0;
            }
        }
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

static void check(BOOL condition, const char *what, DWORD view, BOOL unicode, BOOL large, BOOL images, BOOL focused)
{
    if (!condition)
    {
        fprintf(stderr, "FAIL %s view=%s api=%c font=%s images=%d text=%s focus=%d\n", what,
                view_names[view], unicode ? 'W' : 'A', large ? "large" : "default", images, case_names[current_case], focused);
        failures++;
    }
}

static void rect_json(const RECT *r)
{
    printf("[%ld,%ld,%ld,%ld]", r->left, r->top, r->right, r->bottom);
}

static unsigned count_label_highlight(HWND lv, const RECT *label)
{
    RECT client, sample;
    BITMAPINFO bi;
    HDC dc, mem;
    HBITMAP bmp, old;
    DWORD *pixels, highlight;
    COLORREF color = GetSysColor(COLOR_HIGHLIGHT);
    unsigned count = 0;
    int width, height, i;
    GetClientRect(lv, &client);
    if (!IntersectRect(&sample, &client, label)) return 0;
    width = sample.right - sample.left; height = sample.bottom - sample.top;
    memset(&bi, 0, sizeof(bi));
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = width; bi.bmiHeader.biHeight = -height;
    bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32;
    RedrawWindow(lv, NULL, NULL, RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW);
    dc = GetDC(lv); mem = CreateCompatibleDC(dc);
    bmp = CreateDIBSection(dc, &bi, DIB_RGB_COLORS, (void **)&pixels, NULL, 0);
    if (bmp)
    {
        old = SelectObject(mem, bmp);
        BitBlt(mem, 0, 0, width, height, dc, sample.left, sample.top, SRCCOPY);
        GdiFlush();
        highlight = ((DWORD)GetRValue(color) << 16) | ((DWORD)GetGValue(color) << 8) | GetBValue(color);
        for (i = 0; i < width * height; i++) if ((pixels[i] & 0xffffff) == highlight) count++;
        SelectObject(mem, old); DeleteObject(bmp);
    }
    DeleteDC(mem); ReleaseDC(lv, dc);
    return count;
}

static void measure(HWND lv, DWORD view, BOOL unicode, BOOL large, BOOL images, BOOL focused, HFONT font)
{
    RECT label = {0}, icon = {0}, bounds = {0}, selection = {0}, space = {0};
    TEXTMETRICW tm;
    HDC dc;
    HFONT old;
    BOOL got_label, got_icon, got_bounds, got_selection;
    unsigned highlight_pixels;
    LVHITTESTINFO hit;
    int hit_item;
    /* Settle layout before recording rectangles and sampling their pixels. */
    RedrawWindow(lv, NULL, NULL, RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW);
    dc = GetDC(lv); old = SelectObject(dc, font);
    GetTextMetricsW(dc, &tm);
    DrawTextW(dc, L" ", 1, &space, DT_CALCRECT | DT_SINGLELINE | DT_NOPREFIX);
    SelectObject(dc, old); ReleaseDC(lv, dc);
    got_label = ListView_GetItemRect(lv, 0, &label, LVIR_LABEL);
    got_icon = ListView_GetItemRect(lv, 0, &icon, LVIR_ICON);
    got_bounds = ListView_GetItemRect(lv, 0, &bounds, LVIR_BOUNDS);
    got_selection = ListView_GetItemRect(lv, 0, &selection, LVIR_SELECTBOUNDS);
    highlight_pixels = count_label_highlight(lv, &label);
    memset(&hit, 0, sizeof(hit));
    hit.pt.x = label.left + (label.right - label.left) / 2;
    hit.pt.y = label.top + (label.bottom - label.top) / 2;
    hit_item = ListView_HitTest(lv, &hit);
    check(got_label && got_icon && got_bounds && got_selection, "rectangle API success", view, unicode, large, images, focused);
    check(label.right >= label.left && label.bottom >= label.top, "nonnegative label extent", view, unicode, large, images, focused);
    /* Enable these proposed expectations only after measuring native cc580. */
    if (!measure_only && view == LVS_ICON && current_case <= CALLBACK_EMPTY)
    {
        check(label.right > label.left, "empty icon label has width", view, unicode, large, images, focused);
        check(label.bottom - label.top >= tm.tmHeight, "empty icon label accommodates font height", view, unicode, large, images, focused);
        if (focused) check(!highlight_pixels, "empty icon label is not painted as a selection", view, unicode, large, images, focused);
    }
    printf("{\"view\":\"%s\",\"api\":\"%c\",\"font\":\"%s\",\"images\":%d,\"text\":\"%s\",\"focus\":%d,\"label\":",
           view_names[view], unicode ? 'W' : 'A', large ? "large" : "default", images, case_names[current_case], focused);
    rect_json(&label); printf(",\"icon\":"); rect_json(&icon);
    printf(",\"bounds\":"); rect_json(&bounds); printf(",\"selection\":"); rect_json(&selection);
    printf(",\"font_height\":%ld,\"space_size\":[%ld,%ld],\"callbacks\":%u,\"highlight_pixels\":%u,\"hit_item\":%d,\"hit_flags\":%u,\"has_focus\":%d}\n", tm.tmHeight,
           space.right - space.left, space.bottom - space.top, callbacks, highlight_pixels, hit_item, hit.flags, GetFocus() == lv);
    records++;
}

static HIMAGELIST make_images(int size)
{
    HIMAGELIST images = ImageList_Create(size, size, ILC_COLOR32, 1, 1);
    HBITMAP bmp = CreateBitmap(size, size, 1, 1, NULL);
    if (images && bmp) ImageList_Add(images, bmp, NULL);
    if (bmp) DeleteObject(bmp);
    return images;
}

static void run_case(HWND parent, DWORD view, BOOL unicode, BOOL large, BOOL images)
{
    HWND lv;
    LVITEMA a;
    LVITEMW w;
    LVCOLUMNA col;
    HIMAGELIST normal = NULL, small_images = NULL;
    HFONT font = large ? CreateFontW(-24, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                                    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                                    DEFAULT_QUALITY, DEFAULT_PITCH, L"Arial") : GetStockObject(DEFAULT_GUI_FONT);
    int inserted;
    DWORD style = WS_CHILD | WS_VISIBLE | view | LVS_SHAREIMAGELISTS;
    callbacks = 0;
    lv = unicode ? CreateWindowExW(0, WC_LISTVIEWW, L"", style, 0, 0, 480, 220, parent, (HMENU)1, GetModuleHandleW(NULL), NULL) :
                   CreateWindowExA(0, WC_LISTVIEWA, "", style, 0, 0, 480, 220, parent, (HMENU)1, GetModuleHandleA(NULL), NULL);
    if (!lv)
    {
        check(FALSE, "create control", view, unicode, large, images, FALSE);
        if (large) DeleteObject(font);
        return;
    }
    if (!class_reported)
    {
        HMODULE class_module = (HMODULE)GetClassLongPtrA(lv, GCLP_HMODULE), proc_module = NULL;
        ULONG_PTR proc = (ULONG_PTR)GetClassLongPtrA(lv, GCLP_WNDPROC);
        char class_path[MAX_PATH] = "", proc_path[MAX_PATH] = "";
        GetModuleFileNameA(class_module, class_path, sizeof(class_path));
        GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                          (LPCSTR)proc, &proc_module);
        if (proc_module) GetModuleFileNameA(proc_module, proc_path, sizeof(proc_path));
        fprintf(stderr, "listview_class_module=%s listview_proc_module=%s\n", class_path, proc_path);
        if (require_native_cc580)
            check(class_module == GetModuleHandleA("comctl32.dll"), "listview class belongs to measured native module",
                  view, unicode, large, images, FALSE);
        class_reported = TRUE;
    }
    SendMessageW(lv, WM_SETFONT, (WPARAM)font, FALSE);
    ListView_SetBkColor(lv, background_color);
    ListView_SetTextBkColor(lv, background_color);
    ListView_SetUnicodeFormat(lv, unicode);
    memset(&col, 0, sizeof(col)); col.mask = LVCF_WIDTH; col.cx = 320;
    ListView_InsertColumn(lv, 0, &col);
    if (images)
    {
        normal = make_images(32); small_images = make_images(16);
        ListView_SetImageList(lv, normal, LVSIL_NORMAL);
        ListView_SetImageList(lv, small_images, LVSIL_SMALL);
    }
    memset(&a, 0, sizeof(a)); memset(&w, 0, sizeof(w));
    a.mask = w.mask = LVIF_TEXT | LVIF_IMAGE;
    a.iImage = w.iImage = 0;
    switch (current_case)
    {
    case EMPTY: a.pszText = ""; w.pszText = L""; break;
    case NULL_TEXT: a.pszText = NULL; w.pszText = NULL; break;
    case CALLBACK_EMPTY: case CALLBACK_NULL: a.pszText = LPSTR_TEXTCALLBACKA; w.pszText = LPSTR_TEXTCALLBACKW; break;
    case SPACE: a.pszText = " "; w.pszText = L" "; break;
    case NORMAL: a.pszText = "Photo.jpg"; w.pszText = L"Photo.jpg"; break;
    case MULTILINE: a.pszText = "a reasonably long filename with multiple words.jpg";
                    w.pszText = L"a reasonably long filename with multiple words.jpg"; break;
    }
    inserted = unicode ? (int)SendMessageW(lv, LVM_INSERTITEMW, 0, (LPARAM)&w) :
                         (int)SendMessageA(lv, LVM_INSERTITEMA, 0, (LPARAM)&a);
    check(inserted == 0, "insert item", view, unicode, large, images, FALSE);
    if (view == LVS_ICON || view == LVS_SMALLICON) ListView_SetItemPosition(lv, 0, 30, 20);
    SetFocus(parent);
    measure(lv, view, unicode, large, images, FALSE, font);
    ListView_SetItemState(lv, 0, LVIS_FOCUSED | LVIS_SELECTED, LVIS_FOCUSED | LVIS_SELECTED);
    SetFocus(lv);
    measure(lv, view, unicode, large, images, TRUE, font);
    DestroyWindow(lv);
    if (normal) ImageList_Destroy(normal);
    if (small_images) ImageList_Destroy(small_images);
    if (large) DeleteObject(font);
}

int main(int argc, char **argv)
{
    WNDCLASSW cls;
    INITCOMMONCONTROLSEX init = {sizeof(init), ICC_LISTVIEW_CLASSES};
    DLLVERSIONINFO ver;
    HRESULT (CALLBACK *get_version)(DLLVERSIONINFO *);
    HWND parent;
    HMODULE comctl;
    char module_path[MAX_PATH];
    int only_view = -1, only_font = -1, i, view, unicode, large, images, c;
    for (i = 1; i < argc; i++)
    {
        if (!strcmp(argv[i], "--measure-only")) measure_only = TRUE;
        else if (!strcmp(argv[i], "--require-native-cc580")) require_native_cc580 = TRUE;
        else if (!strcmp(argv[i], "--view") && i + 1 < argc)
        {
            ++i;
            for (view = 0; view < 4; view++) if (!strcmp(argv[i], view_names[view])) only_view = view;
            if (only_view < 0) { fprintf(stderr, "unknown view\n"); return 2; }
        }
        else if (!strcmp(argv[i], "--font") && i + 1 < argc)
        {
            ++i;
            if (!strcmp(argv[i], "default")) only_font = 0;
            else if (!strcmp(argv[i], "large")) only_font = 1;
            else return 2;
        }
        else { fprintf(stderr, "usage: label-regression [--measure-only] [--require-native-cc580] [--view icon|smallicon|report|list] [--font default|large]\n"); return 2; }
    }
    setvbuf(stdout, NULL, _IONBF, 0);
    if (!InitCommonControlsEx(&init)) return 3;
    memset(&ver, 0, sizeof(ver)); ver.cbSize = sizeof(ver);
    comctl = GetModuleHandleA("comctl32.dll");
    module_path[0] = 0;
    GetModuleFileNameA(comctl, module_path, sizeof(module_path));
    fprintf(stderr, "comctl32_module=%s\n", module_path);
    get_version = (void *)GetProcAddress(comctl, "DllGetVersion");
    if (get_version && SUCCEEDED(get_version(&ver)))
        fprintf(stderr, "comctl32=%lu.%lu.%lu\n", ver.dwMajorVersion, ver.dwMinorVersion, ver.dwBuildNumber);
    if (require_native_cc580 && (ver.dwMajorVersion != 5 || ver.dwMinorVersion != 80))
    {
        fprintf(stderr, "FAIL requested native cc580, but loaded %lu.%lu.%lu; refusing reference measurement\n",
                ver.dwMajorVersion, ver.dwMinorVersion, ver.dwBuildNumber);
        return 3;
    }
    memset(&cls, 0, sizeof(cls));
    cls.lpfnWndProc = parent_proc; cls.hInstance = GetModuleHandleW(NULL); cls.lpszClassName = L"LabelRegressionParent";
    if (!RegisterClassW(&cls)) return 3;
    parent = CreateWindowExW(0, cls.lpszClassName, L"Label regression", WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                             0, 0, 640, 480, NULL, NULL, cls.hInstance, NULL);
    if (!parent) return 3;
    SetActiveWindow(parent); SetForegroundWindow(parent);
    for (view = 0; view < 4; view++)
        if (only_view < 0 || view == only_view)
            for (large = 0; large < 2; large++)
                if (only_font < 0 || large == only_font)
                    for (unicode = 0; unicode < 2; unicode++)
                        for (images = 0; images < 2; images++)
                            for (c = EMPTY; c <= MULTILINE; c++)
                            {
                                current_case = (enum text_case)c;
                                run_case(parent, view, unicode, large, images);
                            }
    DestroyWindow(parent);
    fprintf(stderr, "RESULT records=%u failures=%u mode=%s\n", records, failures, measure_only ? "measure-only" : "regression");
    return failures ? 1 : 0;
}
