// Checks the byte examples of VTExts.md against the real far2l StackSerializer/base64 code.
// For each example: (1) build the wire string the way far2l's own code does (same Push order as in
// TTYBackend.cpp / TTYFar2lClipboardBackend.cpp / VTFar2lExtensios.cpp) and compare with the document;
// (2) decode the documented string with the Pop order of the receiving side and compare every value.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <map>
#include <string>
#include <vector>
#include <StackSerializer.h>
#include "WinCompat.h"
#include "FarTTY.h"

static int g_fail = 0, g_ok = 0;
#define CHECK(cond, name) do { if (!(cond)) { std::printf("FAIL [%s]: %s (line %d)\n", name, #cond, __LINE__); ++g_fail; } else { ++g_ok; } } while (0)

struct Ex { std::string name, kind, b64; };

static std::string strRaw(StackSerializer &s, size_t n) { std::string r(n, '\0'); if (n) s.Pop(&r[0], n); return r; }

int main(int argc, char **argv)
{
	std::ifstream f(argv[1]);
	std::map<std::string, Ex> ex;
	std::string line;
	while (std::getline(f, line)) {
		size_t a = line.find('\t'), b = line.find('\t', a + 1);
		if (a == std::string::npos || b == std::string::npos) continue;
		Ex e{line.substr(0, a), line.substr(a + 1, b - a - 1), line.substr(b + 1)};
		ex[e.name] = e;
	}
	auto get = [&](const char *n) -> Ex & {
		auto i = ex.find(n);
		if (i == ex.end()) { std::printf("FAIL [%s]: missing in document\n", n); ++g_fail; static Ex dummy; dummy = Ex{n, "", ""}; return dummy; }
		return i->second;
	};
	auto built = [&](const char *n, const char *kind, StackSerializer &s) {
		Ex &e = get(n);
		CHECK(e.kind == kind, n);
		CHECK(s.ToBase64() == e.b64, n);
		if (s.ToBase64() != e.b64) std::printf("   built %s\n   doc   %s\n", s.ToBase64().c_str(), e.b64.c_str());
	};

	{ // cursor height 50, id 0 (TTYOutput::ChangeCursorHeight)
		StackSerializer s; s.PushNum(UCHAR(50)); s.PushNum(FARTTY_INTERACT_SET_CURSOR_HEIGHT); s.PushNum((uint8_t)0);
		built("cursor-height", "request", s);
		StackSerializer d(get("cursor-height").b64); // server side: vtshell OnApplicationProtocolCommand + OnInteract
		CHECK(d.PopU8() == 0, "cursor-height"); CHECK(d.PopChar() == 'h', "cursor-height");
		UCHAR h; d.PopNum(h); CHECK(h == 50, "cursor-height"); CHECK(d.IsEmpty(), "cursor-height");
	}
	{ // maxsize request/reply
		StackSerializer s; s.PushNum(FARTTY_INTERACT_GET_WINDOW_MAXSIZE); s.PushNum((uint8_t)1);
		built("maxsize-request", "request", s);
		StackSerializer r; // VTFar2lExtensios::OnInteract_GetLargestWindowSize then id pushed by vtshell
		int16_t X = 200, Y = 50; r.PushNum(X); r.PushNum(Y); r.PushNum((uint8_t)1);
		built("maxsize-reply", "reply", r);
		StackSerializer d(get("maxsize-reply").b64); // client: OnFar2lReply then OnConsoleGetLargestWindowSize
		CHECK(d.PopU8() == 1, "maxsize-reply"); int16_t oy, ox; d.PopNum(oy); d.PopNum(ox);
		CHECK(oy == 50 && ox == 200, "maxsize-reply"); CHECK(d.IsEmpty(), "maxsize-reply");
	}
	{ // notification (TTYBackend::OnConsoleDisplayNotification)
		StackSerializer s; s.PushStr(std::string("OK")); s.PushStr(std::string("Done")); s.PushNum(FARTTY_INTERACT_DESKTOP_NOTIFICATION); s.PushNum((uint8_t)0);
		built("notification", "request", s);
		StackSerializer d(get("notification").b64);
		CHECK(d.PopU8() == 0, "notification"); CHECK(d.PopChar() == 'n', "notification");
		CHECK(d.PopStr() == "Done", "notification"); CHECK(d.PopStr() == "OK", "notification"); CHECK(d.IsEmpty(), "notification");
	}
	{ // F-key titles (TTYBackend::OnConsoleSetFKeyTitles), id 1
		const char *titles[12] = {"Help", "Menu"};
		StackSerializer s;
		for (int i = 11; i >= 0; --i) {
			unsigned char state = (titles[i] != NULL) ? 1 : 0;
			if (state != 0) s.PushStr(titles[i]);
			s.PushNum(state);
		}
		s.PushNum(FARTTY_INTERACT_SET_FKEY_TITLES); s.PushNum((uint8_t)1);
		built("fkeys", "request", s);
		StackSerializer d(get("fkeys").b64); // VTFar2lExtensios::OnInteract_SetFKeyTitles
		CHECK(d.PopU8() == 1, "fkeys"); CHECK(d.PopChar() == 'f', "fkeys");
		std::string t[12];
		for (unsigned i = 0; i < 12 && !d.IsEmpty(); ++i) { unsigned char st = 0; d.PopNum(st); if (st) d.PopStr(t[i]); }
		CHECK(t[0] == "Help" && t[1] == "Menu", "fkeys");
		for (int i = 2; i < 12; ++i) CHECK(t[i].empty(), "fkeys");
		CHECK(d.IsEmpty(), "fkeys");
		StackSerializer r; bool out = true; r.PushNum(out); r.PushNum((uint8_t)1);
		built("fkeys-reply", "reply", r);
	}
	const std::string passcode = "0123456789abcdef0123456789abcdef";
	{ // clipboard open (TTYFar2lClipboardBackend::OnClipboardOpen + Far2lInteract)
		StackSerializer s; s.PushStr(passcode); s.PushNum(FARTTY_INTERACT_CLIP_OPEN); s.PushNum(FARTTY_INTERACT_CLIPBOARD); s.PushNum((uint8_t)1);
		built("clip-open", "request", s);
		StackSerializer d(get("clip-open").b64);
		CHECK(d.PopU8() == 1, "clip-open"); CHECK(d.PopChar() == 'c', "clip-open"); CHECK(d.PopChar() == 'o', "clip-open");
		CHECK(d.PopStr() == passcode, "clip-open"); CHECK(d.IsEmpty(), "clip-open");
		// server reply (OnInteract_ClipboardOpen)
		StackSerializer r; char out = 1; r.PushNum(uint64_t(FARTTY_FEATCLIP_DATA_ID | FARTTY_FEATCLIP_CHUNKED_SET)); r.PushNum(out); r.PushNum((uint8_t)1);
		built("clip-open-reply", "reply", r);
		StackSerializer dr(get("clip-open-reply").b64);
		CHECK(dr.PopU8() == 1, "clip-open-reply"); CHECK(dr.PopChar() == 1, "clip-open-reply");
		uint64_t feats = 0; CHECK(!dr.IsEmpty(), "clip-open-reply"); dr.PopNum(feats); CHECK(feats == 3, "clip-open-reply"); CHECK(dr.IsEmpty(), "clip-open-reply");
	}
	{ // set data (SetDataThread::ThreadProc)
		const char *text = "hello"; const uint32_t len = 5; const UINT format = CF_TEXT;
		StackSerializer s; s.Push(text, len); s.PushNum(len); s.PushNum(format); s.PushNum(FARTTY_INTERACT_CLIP_SETDATA); s.PushNum(FARTTY_INTERACT_CLIPBOARD); s.PushNum((uint8_t)2);
		built("clip-setdata", "request", s);
		StackSerializer d(get("clip-setdata").b64); // OnInteract_ClipboardSetData
		CHECK(d.PopU8() == 2, "clip-setdata"); CHECK(d.PopChar() == 'c', "clip-setdata"); CHECK(d.PopChar() == 's', "clip-setdata");
		UINT fmt; uint32_t l; d.PopNum(fmt); d.PopNum(l); CHECK(fmt == 1 && l == 5, "clip-setdata"); CHECK(strRaw(d, l) == "hello", "clip-setdata"); CHECK(d.IsEmpty(), "clip-setdata");
		StackSerializer r; uint64_t id = 0x1122334455667788ull; char out = 1; r.PushNum(id); r.PushNum(out); r.PushNum((uint8_t)2);
		built("clip-setdata-reply", "reply", r);
		StackSerializer dr(get("clip-setdata-reply").b64); // OnSetDataThreadComplete
		CHECK(dr.PopU8() == 2, "clip-setdata-reply"); CHECK(dr.PopChar() == 1, "clip-setdata-reply"); uint64_t rid; dr.PopNum(rid); CHECK(rid == id, "clip-setdata-reply"); CHECK(dr.IsEmpty(), "clip-setdata-reply");
	}
	{ // get data
		StackSerializer s; s.PushNum(UINT(CF_TEXT)); s.PushNum(FARTTY_INTERACT_CLIP_GETDATA); s.PushNum(FARTTY_INTERACT_CLIPBOARD); s.PushNum((uint8_t)3);
		built("clip-getdata", "request", s);
		StackSerializer r; uint64_t id = 0x1122334455667788ull; r.PushNum(id); r.Push("hello", 5); r.PushNum(uint32_t(5)); r.PushNum((uint8_t)3); // OnInteract_ClipboardGetData
		built("clip-getdata-reply", "reply", r);
		StackSerializer dr(get("clip-getdata-reply").b64); // InnerClipboardGetData
		CHECK(dr.PopU8() == 3, "clip-getdata-reply"); uint32_t len = dr.PopU32(); CHECK(len == 5, "clip-getdata-reply");
		CHECK(strRaw(dr, len) == "hello", "clip-getdata-reply"); uint64_t rid; dr.PopNum(rid); CHECK(rid == id, "clip-getdata-reply"); CHECK(dr.IsEmpty(), "clip-getdata-reply");
	}
	{ // close, id 0
		StackSerializer s; s.PushNum(FARTTY_INTERACT_CLIP_CLOSE); s.PushNum(FARTTY_INTERACT_CLIPBOARD); s.PushNum((uint8_t)0);
		built("clip-close", "request", s);
	}
	{ // register format, id 4
		StackSerializer s; s.PushStr(std::string("FAR_VerticalBlock_Unicode")); s.PushNum(FARTTY_INTERACT_CLIP_REGISTER_FORMAT); s.PushNum(FARTTY_INTERACT_CLIPBOARD); s.PushNum((uint8_t)4);
		built("clip-register", "request", s);
		StackSerializer d(get("clip-register").b64);
		CHECK(d.PopU8() == 4, "clip-register"); CHECK(d.PopChar() == 'c', "clip-register"); CHECK(d.PopChar() == 'r', "clip-register");
		CHECK(d.PopStr() == "FAR_VerticalBlock_Unicode", "clip-register"); CHECK(d.IsEmpty(), "clip-register");
		StackSerializer r; UINT out = 0xC000; r.PushNum(out); r.PushNum((uint8_t)4);
		built("clip-register-reply", "reply", r);
		StackSerializer dr(get("clip-register-reply").b64); CHECK(dr.PopU8() == 4, "clip-register-reply"); CHECK(dr.PopU32() == 0xC000, "clip-register-reply"); CHECK(dr.IsEmpty(), "clip-register-reply");
	}
	{ // image caps, id 5
		StackSerializer s; s.PushNum(FARTTY_INTERACT_IMAGE_CAPS); s.PushNum(FARTTY_INTERACT_IMAGE); s.PushNum((uint8_t)5);
		built("image-caps", "request", s);
		StackSerializer r; uint64_t caps = 0xB03; int16_t X = 8, Y = 16; // VTFar2lExtensios::OnInteract_ImageCaps
		r.PushNum(caps); r.PushNum(X); r.PushNum(Y); r.PushNum((uint8_t)5);
		built("image-caps-reply", "reply", r);
		StackSerializer dr(get("image-caps-reply").b64); // TTYBackend::OnGetConsoleImageCaps
		CHECK(dr.PopU8() == 5, "image-caps-reply"); int16_t py, px; uint64_t pc; dr.PopNum(py); dr.PopNum(px); dr.PopNum(pc);
		CHECK(py == 16 && px == 8 && pc == 0xB03, "image-caps-reply"); CHECK(dr.IsEmpty(), "image-caps-reply");
	}
	{ // image set (TTYBackend::OnSetConsoleImage), id 6
		const unsigned char px[4] = {255, 0, 0, 255};
		SMALL_RECT area; area.Left = 2; area.Top = 3; area.Right = -1; area.Bottom = -1;
		DWORD width = 1, height = 1; DWORD64 flags = WP_IMG_RGBA;
		StackSerializer s; s.Push(px, 4); s.PushNum(height); s.PushNum(width); s.PushNum(area.Bottom); s.PushNum(area.Right); s.PushNum(area.Top); s.PushNum(area.Left);
		s.PushNum(flags); s.PushStr("img"); s.PushNum(FARTTY_INTERACT_IMAGE_SET); s.PushNum(FARTTY_INTERACT_IMAGE); s.PushNum((uint8_t)6);
		built("image-set", "request", s);
		StackSerializer d(get("image-set").b64); // VTFar2lExtensios::OnInteract_ImageSet
		CHECK(d.PopU8() == 6, "image-set"); CHECK(d.PopChar() == 'i', "image-set"); CHECK(d.PopChar() == 's', "image-set");
		DWORD64 fl{}; DWORD w{}, h{}; SMALL_RECT a{-1, -1, -1, -1};
		std::string id = d.PopStr(); d.PopNum(fl); d.PopNum(a.Left); d.PopNum(a.Top); d.PopNum(a.Right); d.PopNum(a.Bottom); d.PopNum(w); d.PopNum(h);
		CHECK(id == "img" && fl == 0 && a.Left == 2 && a.Top == 3 && a.Right == -1 && a.Bottom == -1 && w == 1 && h == 1, "image-set");
		CHECK(strRaw(d, 4) == std::string("\xff\x00\x00\xff", 4), "image-set"); CHECK(d.IsEmpty(), "image-set");
		StackSerializer r; uint8_t ok = 1; r.PushNum(ok); r.PushNum((uint8_t)6);
		built("image-set-reply", "reply", r);
	}
	{ // image transform (TTYBackend::OnTransformConsoleImage), id 7
		SMALL_RECT area{-1, -1, -1, -1}; uint16_t tf = WP_IMGTF_ROTATE90 | WP_IMGTF_MIRROR_H;
		StackSerializer s; s.PushNum(tf); s.PushNum(area.Bottom); s.PushNum(area.Right); s.PushNum(area.Top); s.PushNum(area.Left); s.PushStr("img");
		s.PushNum(FARTTY_INTERACT_IMAGE_TRANSFORM); s.PushNum(FARTTY_INTERACT_IMAGE); s.PushNum((uint8_t)7);
		built("image-transform", "request", s);
		StackSerializer d(get("image-transform").b64); // OnInteract_ImageTransform
		CHECK(d.PopU8() == 7, "image-transform"); CHECK(d.PopChar() == 'i', "image-transform"); CHECK(d.PopChar() == 't', "image-transform");
		SMALL_RECT a{-1, -1, -1, -1}; uint16_t t{}; std::string id = d.PopStr(); d.PopNum(a.Left); d.PopNum(a.Top); d.PopNum(a.Right); d.PopNum(a.Bottom); d.PopNum(t);
		CHECK(id == "img" && a.Left == -1 && a.Top == -1 && a.Right == -1 && a.Bottom == -1 && t == 5, "image-transform"); CHECK(d.IsEmpty(), "image-transform");
	}
	{ // choose features (TTYOutput ctor)
		StackSerializer s; s.PushNum(uint64_t(FARTTY_FEAT_COMPACT_INPUT)); s.PushNum(FARTTY_INTERACT_CHOOSE_EXTRA_FEATURES); s.PushNum((uint8_t)0);
		built("features", "request", s);
		StackSerializer d(get("features").b64);
		CHECK(d.PopU8() == 0, "features"); CHECK(d.PopChar() == 'x', "features"); uint64_t fe = 0; d.PopNum(fe); CHECK(fe == 1, "features"); CHECK(d.IsEmpty(), "features");
	}
	{ // key down (VTFar2lExtensios::OnInputKey, non-compact), decode = TTYBackend OnFar2lEvent + OnFar2lKey
		StackSerializer s; s.PushNum(uint16_t(1)); s.PushNum(uint16_t(0x41)); s.PushNum(uint16_t(0x1E)); s.PushNum(uint32_t(0)); s.PushNum(uint32_t(0x61)); s.PushNum(FARTTY_INPUT_KEYDOWN);
		built("key-down", "event", s);
		StackSerializer d(get("key-down").b64);
		CHECK(d.PopChar() == 'K', "key-down"); CHECK(d.PopU32() == 0x61, "key-down"); CHECK(d.PopU32() == 0, "key-down");
		CHECK(d.PopU16() == 0x1E, "key-down"); CHECK(d.PopU16() == 0x41, "key-down"); CHECK(d.PopU16() == 1, "key-down"); CHECK(d.IsEmpty(), "key-down");
	}
	{ // key down compact
		StackSerializer s; s.PushNum(uint8_t(0x41)); s.PushNum(uint16_t(0)); s.PushNum(uint16_t(0x61)); s.PushNum(FARTTY_INPUT_KEYDOWN_COMPACT);
		built("key-down-compact", "event", s);
		StackSerializer d(get("key-down-compact").b64); // OnFar2lKeyCompact
		CHECK(d.PopChar() == 'C', "key-down-compact"); CHECK(d.PopU16() == 0x61, "key-down-compact"); CHECK(d.PopU16() == 0, "key-down-compact"); CHECK(d.PopU8() == 0x41, "key-down-compact"); CHECK(d.IsEmpty(), "key-down-compact");
	}
	{ // mouse compact: button state 1 at column 10 row 5
		MOUSE_EVENT_RECORD me{}; me.dwMousePosition.X = 10; me.dwMousePosition.Y = 5; me.dwButtonState = FROM_LEFT_1ST_BUTTON_PRESSED;
		CHECK((me.dwButtonState & 0xff00ff00) == 0 && me.dwControlKeyState < 0x100 && me.dwEventFlags < 0x100, "mouse-compact");
		StackSerializer s; s.PushNum(me.dwMousePosition.X); s.PushNum(me.dwMousePosition.Y);
		const uint16_t enc = ((me.dwButtonState & 0xff) | ((me.dwButtonState >> 8) & 0xff00));
		s.PushNum(enc); s.PushNum(uint8_t(me.dwControlKeyState)); s.PushNum(uint8_t(me.dwEventFlags)); s.PushNum(FARTTY_INPUT_MOUSE_COMPACT);
		built("mouse-compact", "event", s);
		StackSerializer d(get("mouse-compact").b64); // OnFar2lMouse(compact)
		CHECK(d.PopChar() == 'm', "mouse-compact"); uint8_t fl = d.PopU8(); uint8_t ck = d.PopU8(); DWORD bs = d.PopU16();
		bs = (bs & 0xff) | ((bs & 0xff00) << 8); int16_t y, x; d.PopNum(y); d.PopNum(x);
		CHECK(fl == 0 && ck == 0 && bs == 1 && y == 5 && x == 10 && d.IsEmpty(), "mouse-compact");
	}
	{ // wheel down does not fit the compact form
		MOUSE_EVENT_RECORD me{}; me.dwMousePosition.X = 10; me.dwMousePosition.Y = 5; me.dwButtonState = 0xFFFF0000u; me.dwEventFlags = MOUSE_WHEELED;
		CHECK((me.dwButtonState & 0xff00ff00) != 0, "mouse-wheel-down");
		StackSerializer s; s.PushNum(me.dwMousePosition.X); s.PushNum(me.dwMousePosition.Y); s.PushNum(me.dwButtonState); s.PushNum(me.dwControlKeyState); s.PushNum(me.dwEventFlags); s.PushNum(FARTTY_INPUT_MOUSE);
		built("mouse-wheel-down", "event", s);
		StackSerializer d(get("mouse-wheel-down").b64);
		CHECK(d.PopChar() == 'M', "mouse-wheel-down"); DWORD fl, ck, bs; d.PopNum(fl); d.PopNum(ck); d.PopNum(bs); int16_t y, x; d.PopNum(y); d.PopNum(x);
		CHECK(fl == 4 && ck == 0 && bs == 0xFFFF0000u && y == 5 && x == 10 && d.IsEmpty(), "mouse-wheel-down");
	}
	{ // terminal size (VTFar2lExtensios::OnTerminalResized; decode = OnFar2lTerminalSize)
		StackSerializer s; s.PushNum(uint16_t(80)); s.PushNum(uint16_t(25)); s.PushNum(FARTTY_INPUT_TERMINAL_SIZE);
		built("terminal-size", "event", s);
		StackSerializer d(get("terminal-size").b64);
		CHECK(d.PopChar() == 'S', "terminal-size"); uint16_t h, w; d.PopNum(h); d.PopNum(w); CHECK(h == 25 && w == 80 && d.IsEmpty(), "terminal-size");
	}
	// every example of the document must have been exercised
	for (auto &kv : ex) { (void)kv; }
	std::printf("examples in document: %zu; checks passed: %d; failed: %d\n", ex.size(), g_ok, g_fail);
	return g_fail ? 1 : 0;
}
