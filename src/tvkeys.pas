{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/tkeys.h, source/tvision/tkey.cpp,
  source/tvision/drivers2.cpp (ctrlToArrow)
  See COPYRIGHT.magiblot. }
unit TvKeys;

{$mode objfpc}
{$modeswitch advancedrecords}

interface

const
  { Control keys }
  kbCtrlA = $0001;
  kbCtrlB = $0002;
  kbCtrlC = $0003;
  kbCtrlD = $0004;
  kbCtrlE = $0005;
  kbCtrlF = $0006;
  kbCtrlG = $0007;
  kbCtrlH = $0008;
  kbCtrlI = $0009;
  kbCtrlJ = $000A;
  kbCtrlK = $000B;
  kbCtrlL = $000C;
  kbCtrlM = $000D;
  kbCtrlN = $000E;
  kbCtrlO = $000F;
  kbCtrlP = $0010;
  kbCtrlQ = $0011;
  kbCtrlR = $0012;
  kbCtrlS = $0013;
  kbCtrlT = $0014;
  kbCtrlU = $0015;
  kbCtrlV = $0016;
  kbCtrlW = $0017;
  kbCtrlX = $0018;
  kbCtrlY = $0019;
  kbCtrlZ = $001A;

  { Extended key codes }
  kbEsc = $011B;
  kbAltSpace = $0200;
  kbCtrlIns = $0400;
  kbShiftIns = $0500;
  kbCtrlDel = $0600;
  kbShiftDel = $0700;
  kbBack = $0E08;
  kbCtrlBack = $0E7F;
  kbShiftTab = $0F00;
  kbTab = $0F09;
  kbAltQ = $1000;
  kbAltW = $1100;
  kbAltE = $1200;
  kbAltR = $1300;
  kbAltT = $1400;
  kbAltY = $1500;
  kbAltU = $1600;
  kbAltI = $1700;
  kbAltO = $1800;
  kbAltP = $1900;
  kbCtrlEnter = $1C0A;
  kbEnter = $1C0D;
  kbAltA = $1E00;
  kbAltS = $1F00;
  kbAltD = $2000;
  kbAltF = $2100;
  kbAltG = $2200;
  kbAltH = $2300;
  kbAltJ = $2400;
  kbAltK = $2500;
  kbAltL = $2600;
  kbAltZ = $2C00;
  kbAltX = $2D00;
  kbAltC = $2E00;
  kbAltV = $2F00;
  kbAltB = $3000;
  kbAltN = $3100;
  kbAltM = $3200;
  kbF1 = $3B00;
  kbF2 = $3C00;
  kbF3 = $3D00;
  kbF4 = $3E00;
  kbF5 = $3F00;
  kbF6 = $4000;
  kbF7 = $4100;
  kbF8 = $4200;
  kbF9 = $4300;
  kbF10 = $4400;
  kbHome = $4700;
  kbUp = $4800;
  kbPgUp = $4900;
  kbGrayMinus = $4A2D;
  kbLeft = $4B00;
  kbRight = $4D00;
  kbGrayPlus = $4E2B;
  kbEnd = $4F00;
  kbDown = $5000;
  kbPgDn = $5100;
  kbIns = $5200;
  kbDel = $5300;
  kbShiftF1 = $5400;
  kbShiftF2 = $5500;
  kbShiftF3 = $5600;
  kbShiftF4 = $5700;
  kbShiftF5 = $5800;
  kbShiftF6 = $5900;
  kbShiftF7 = $5A00;
  kbShiftF8 = $5B00;
  kbShiftF9 = $5C00;
  kbShiftF10 = $5D00;
  kbCtrlF1 = $5E00;
  kbCtrlF2 = $5F00;
  kbCtrlF3 = $6000;
  kbCtrlF4 = $6100;
  kbCtrlF5 = $6200;
  kbCtrlF6 = $6300;
  kbCtrlF7 = $6400;
  kbCtrlF8 = $6500;
  kbCtrlF9 = $6600;
  kbCtrlF10 = $6700;
  kbAltF1 = $6800;
  kbAltF2 = $6900;
  kbAltF3 = $6A00;
  kbAltF4 = $6B00;
  kbAltF5 = $6C00;
  kbAltF6 = $6D00;
  kbAltF7 = $6E00;
  kbAltF8 = $6F00;
  kbAltF9 = $7000;
  kbAltF10 = $7100;
  kbCtrlPrtSc = $7200;
  kbCtrlLeft = $7300;
  kbCtrlRight = $7400;
  kbCtrlEnd = $7500;
  kbCtrlPgDn = $7600;
  kbCtrlHome = $7700;
  kbAlt1 = $7800;
  kbAlt2 = $7900;
  kbAlt3 = $7A00;
  kbAlt4 = $7B00;
  kbAlt5 = $7C00;
  kbAlt6 = $7D00;
  kbAlt7 = $7E00;
  kbAlt8 = $7F00;
  kbAlt9 = $8000;
  kbAlt0 = $8100;
  kbAltMinus = $8200;
  kbAltEqual = $8300;
  kbCtrlPgUp = $8400;
  kbNoKey = $0000;

  { Additional extended key codes }
  kbAltEsc = $0100;
  kbAltBack = $0E00;
  kbF11 = $8500;
  kbF12 = $8600;
  kbShiftF11 = $8700;
  kbShiftF12 = $8800;
  kbCtrlF11 = $8900;
  kbCtrlF12 = $8A00;
  kbAltF11 = $8B00;
  kbAltF12 = $8C00;
  kbCtrlUp = $8D00;
  kbCtrlDown = $9100;
  kbCtrlTab = $9400;
  kbAltHome = $9700;
  kbAltUp = $9800;
  kbAltPgUp = $9900;
  kbAltLeft = $9B00;
  kbAltRight = $9D00;
  kbAltEnd = $9F00;
  kbAltDown = $A000;
  kbAltPgDn = $A100;
  kbAltIns = $A200;
  kbAltDel = $A300;
  kbAltTab = $A500;
  kbAltEnter = $A600;

  { Keyboard state and shift masks }
  kbLeftShift = $0001;
  kbRightShift = $0002;
  kbShift = kbLeftShift or kbRightShift;
  kbLeftCtrl = $0004;
  kbRightCtrl = $0004;
  kbCtrlShift = kbLeftCtrl or kbRightCtrl;
  kbLeftAlt = $0008;
  kbRightAlt = $0008;
  kbAltShift = kbLeftAlt or kbRightAlt;
  kbScrollState = 1 shl 4;
  kbNumState = 1 shl 5;
  kbCapsState = 1 shl 6;
  kbInsState = 1 shl 7;
  kbPaste = 1 shl 8;

type
  { A key combination: a key code and a mask of Shift, Ctrl and Alt.
    Different spellings of the same combination give equal values. }
  TKey = record
    Code: Word;
    Mods: Word;
    constructor Create(AKeyCode: Word; AShiftState: Word = 0);
    class operator :=(const AKeyCode: Word): TKey;
    class operator =(const One, Two: TKey): Boolean;
    class operator <>(const One, Two: TKey): Boolean;
  end;

{ Maps the Wordstar control keys to the corresponding arrow and editing keys;
  any other key code is returned unchanged. }
function CtrlToArrow(KeyCode: Word): Word;

implementation

type
  TKeyCodeLookupEntry = record
    NormalKeyCode: Word;
    ShiftState: Byte;
  end;

const
  CtrlKeyLookup: array[0..$1A] of TKeyCodeLookupEntry = (
  (NormalKeyCode: 0; ShiftState: 0), { $0000 }
  (NormalKeyCode: Ord('A'); ShiftState: kbCtrlShift), { $0001 }
  (NormalKeyCode: Ord('B'); ShiftState: kbCtrlShift), { $0002 }
  (NormalKeyCode: Ord('C'); ShiftState: kbCtrlShift), { $0003 }
  (NormalKeyCode: Ord('D'); ShiftState: kbCtrlShift), { $0004 }
  (NormalKeyCode: Ord('E'); ShiftState: kbCtrlShift), { $0005 }
  (NormalKeyCode: Ord('F'); ShiftState: kbCtrlShift), { $0006 }
  (NormalKeyCode: Ord('G'); ShiftState: kbCtrlShift), { $0007 }
  (NormalKeyCode: Ord('H'); ShiftState: kbCtrlShift), { $0008 }
  (NormalKeyCode: Ord('I'); ShiftState: kbCtrlShift), { $0009 }
  (NormalKeyCode: Ord('J'); ShiftState: kbCtrlShift), { $000A }
  (NormalKeyCode: Ord('K'); ShiftState: kbCtrlShift), { $000B }
  (NormalKeyCode: Ord('L'); ShiftState: kbCtrlShift), { $000C }
  (NormalKeyCode: Ord('M'); ShiftState: kbCtrlShift), { $000D }
  (NormalKeyCode: Ord('N'); ShiftState: kbCtrlShift), { $000E }
  (NormalKeyCode: Ord('O'); ShiftState: kbCtrlShift), { $000F }
  (NormalKeyCode: Ord('P'); ShiftState: kbCtrlShift), { $0010 }
  (NormalKeyCode: Ord('Q'); ShiftState: kbCtrlShift), { $0011 }
  (NormalKeyCode: Ord('R'); ShiftState: kbCtrlShift), { $0012 }
  (NormalKeyCode: Ord('S'); ShiftState: kbCtrlShift), { $0013 }
  (NormalKeyCode: Ord('T'); ShiftState: kbCtrlShift), { $0014 }
  (NormalKeyCode: Ord('U'); ShiftState: kbCtrlShift), { $0015 }
  (NormalKeyCode: Ord('V'); ShiftState: kbCtrlShift), { $0016 }
  (NormalKeyCode: Ord('W'); ShiftState: kbCtrlShift), { $0017 }
  (NormalKeyCode: Ord('X'); ShiftState: kbCtrlShift), { $0018 }
  (NormalKeyCode: Ord('Y'); ShiftState: kbCtrlShift), { $0019 }
  (NormalKeyCode: Ord('Z'); ShiftState: kbCtrlShift) { $001A }
  );

  ExtKeyLookupSize = $A7;

  ExtKeyLookup: array[0..ExtKeyLookupSize - 1] of TKeyCodeLookupEntry = (
  (NormalKeyCode: 0; ShiftState: 0), { $0000 }
  (NormalKeyCode: kbEsc; ShiftState: kbAltShift), { $0100 }
  (NormalKeyCode: Ord(' '); ShiftState: kbAltShift), { $0200 }
  (NormalKeyCode: 0; ShiftState: 0), { $0300 }
  (NormalKeyCode: kbIns; ShiftState: kbCtrlShift), { $0400 }
  (NormalKeyCode: kbIns; ShiftState: kbShift), { $0500 }
  (NormalKeyCode: kbDel; ShiftState: kbCtrlShift), { $0600 }
  (NormalKeyCode: kbDel; ShiftState: kbShift), { $0700 }
  (NormalKeyCode: 0; ShiftState: 0), { $0800 }
  (NormalKeyCode: 0; ShiftState: 0), { $0900 }
  (NormalKeyCode: 0; ShiftState: 0), { $0A00 }
  (NormalKeyCode: 0; ShiftState: 0), { $0B00 }
  (NormalKeyCode: 0; ShiftState: 0), { $0C00 }
  (NormalKeyCode: 0; ShiftState: 0), { $0D00 }
  (NormalKeyCode: kbBack; ShiftState: kbAltShift), { $0E00 }
  (NormalKeyCode: kbTab; ShiftState: kbShift), { $0F00 }
  (NormalKeyCode: Ord('Q'); ShiftState: kbAltShift), { $1000 }
  (NormalKeyCode: Ord('W'); ShiftState: kbAltShift), { $1100 }
  (NormalKeyCode: Ord('E'); ShiftState: kbAltShift), { $1200 }
  (NormalKeyCode: Ord('R'); ShiftState: kbAltShift), { $1300 }
  (NormalKeyCode: Ord('T'); ShiftState: kbAltShift), { $1400 }
  (NormalKeyCode: Ord('Y'); ShiftState: kbAltShift), { $1500 }
  (NormalKeyCode: Ord('U'); ShiftState: kbAltShift), { $1600 }
  (NormalKeyCode: Ord('I'); ShiftState: kbAltShift), { $1700 }
  (NormalKeyCode: Ord('O'); ShiftState: kbAltShift), { $1800 }
  (NormalKeyCode: Ord('P'); ShiftState: kbAltShift), { $1900 }
  (NormalKeyCode: 0; ShiftState: 0), { $1A00 }
  (NormalKeyCode: 0; ShiftState: 0), { $1B00 }
  (NormalKeyCode: 0; ShiftState: 0), { $1C00 }
  (NormalKeyCode: 0; ShiftState: 0), { $1D00 }
  (NormalKeyCode: Ord('A'); ShiftState: kbAltShift), { $1E00 }
  (NormalKeyCode: Ord('S'); ShiftState: kbAltShift), { $1F00 }
  (NormalKeyCode: Ord('D'); ShiftState: kbAltShift), { $2000 }
  (NormalKeyCode: Ord('F'); ShiftState: kbAltShift), { $2100 }
  (NormalKeyCode: Ord('G'); ShiftState: kbAltShift), { $2200 }
  (NormalKeyCode: Ord('H'); ShiftState: kbAltShift), { $2300 }
  (NormalKeyCode: Ord('J'); ShiftState: kbAltShift), { $2400 }
  (NormalKeyCode: Ord('K'); ShiftState: kbAltShift), { $2500 }
  (NormalKeyCode: Ord('L'); ShiftState: kbAltShift), { $2600 }
  (NormalKeyCode: 0; ShiftState: 0), { $2700 }
  (NormalKeyCode: 0; ShiftState: 0), { $2800 }
  (NormalKeyCode: 0; ShiftState: 0), { $2900 }
  (NormalKeyCode: 0; ShiftState: 0), { $2A00 }
  (NormalKeyCode: 0; ShiftState: 0), { $2B00 }
  (NormalKeyCode: Ord('Z'); ShiftState: kbAltShift), { $2C00 }
  (NormalKeyCode: Ord('X'); ShiftState: kbAltShift), { $2D00 }
  (NormalKeyCode: Ord('C'); ShiftState: kbAltShift), { $2E00 }
  (NormalKeyCode: Ord('V'); ShiftState: kbAltShift), { $2F00 }
  (NormalKeyCode: Ord('B'); ShiftState: kbAltShift), { $3000 }
  (NormalKeyCode: Ord('N'); ShiftState: kbAltShift), { $3100 }
  (NormalKeyCode: Ord('M'); ShiftState: kbAltShift), { $3200 }
  (NormalKeyCode: 0; ShiftState: 0), { $3300 }
  (NormalKeyCode: 0; ShiftState: 0), { $3400 }
  (NormalKeyCode: Ord('/'); ShiftState: kbCtrlShift), { $3500 }
  (NormalKeyCode: 0; ShiftState: 0), { $3600 }
  (NormalKeyCode: Ord('*'); ShiftState: kbCtrlShift), { $3700 }
  (NormalKeyCode: 0; ShiftState: 0), { $3800 }
  (NormalKeyCode: 0; ShiftState: 0), { $3900 }
  (NormalKeyCode: 0; ShiftState: 0), { $3A00 }
  (NormalKeyCode: kbF1; ShiftState: 0), { $3B00 }
  (NormalKeyCode: kbF2; ShiftState: 0), { $3C00 }
  (NormalKeyCode: kbF3; ShiftState: 0), { $3D00 }
  (NormalKeyCode: kbF4; ShiftState: 0), { $3E00 }
  (NormalKeyCode: kbF5; ShiftState: 0), { $3F00 }
  (NormalKeyCode: kbF6; ShiftState: 0), { $4000 }
  (NormalKeyCode: kbF7; ShiftState: 0), { $4100 }
  (NormalKeyCode: kbF8; ShiftState: 0), { $4200 }
  (NormalKeyCode: kbF9; ShiftState: 0), { $4300 }
  (NormalKeyCode: kbF10; ShiftState: 0), { $4400 }
  (NormalKeyCode: 0; ShiftState: 0), { $4500 }
  (NormalKeyCode: 0; ShiftState: 0), { $4600 }
  (NormalKeyCode: kbHome; ShiftState: 0), { $4700 }
  (NormalKeyCode: kbUp; ShiftState: 0), { $4800 }
  (NormalKeyCode: kbPgUp; ShiftState: 0), { $4900 }
  (NormalKeyCode: Ord('-'); ShiftState: kbCtrlShift), { $4A00 }
  (NormalKeyCode: kbLeft; ShiftState: 0), { $4B00 }
  (NormalKeyCode: 0; ShiftState: 0), { $4C00 }
  (NormalKeyCode: kbRight; ShiftState: 0), { $4D00 }
  (NormalKeyCode: Ord('+'); ShiftState: kbCtrlShift), { $4E00 }
  (NormalKeyCode: kbEnd; ShiftState: 0), { $4F00 }
  (NormalKeyCode: kbDown; ShiftState: 0), { $5000 }
  (NormalKeyCode: kbPgDn; ShiftState: 0), { $5100 }
  (NormalKeyCode: kbIns; ShiftState: 0), { $5200 }
  (NormalKeyCode: kbDel; ShiftState: 0), { $5300 }
  (NormalKeyCode: kbF1; ShiftState: kbShift), { $5400 }
  (NormalKeyCode: kbF2; ShiftState: kbShift), { $5500 }
  (NormalKeyCode: kbF3; ShiftState: kbShift), { $5600 }
  (NormalKeyCode: kbF4; ShiftState: kbShift), { $5700 }
  (NormalKeyCode: kbF5; ShiftState: kbShift), { $5800 }
  (NormalKeyCode: kbF6; ShiftState: kbShift), { $5900 }
  (NormalKeyCode: kbF7; ShiftState: kbShift), { $5A00 }
  (NormalKeyCode: kbF8; ShiftState: kbShift), { $5B00 }
  (NormalKeyCode: kbF9; ShiftState: kbShift), { $5C00 }
  (NormalKeyCode: kbF10; ShiftState: kbShift), { $5D00 }
  (NormalKeyCode: kbF1; ShiftState: kbCtrlShift), { $5E00 }
  (NormalKeyCode: kbF2; ShiftState: kbCtrlShift), { $5F00 }
  (NormalKeyCode: kbF3; ShiftState: kbCtrlShift), { $6000 }
  (NormalKeyCode: kbF4; ShiftState: kbCtrlShift), { $6100 }
  (NormalKeyCode: kbF5; ShiftState: kbCtrlShift), { $6200 }
  (NormalKeyCode: kbF6; ShiftState: kbCtrlShift), { $6300 }
  (NormalKeyCode: kbF7; ShiftState: kbCtrlShift), { $6400 }
  (NormalKeyCode: kbF8; ShiftState: kbCtrlShift), { $6500 }
  (NormalKeyCode: kbF9; ShiftState: kbCtrlShift), { $6600 }
  (NormalKeyCode: kbF10; ShiftState: kbCtrlShift), { $6700 }
  (NormalKeyCode: kbF1; ShiftState: kbAltShift), { $6800 }
  (NormalKeyCode: kbF2; ShiftState: kbAltShift), { $6900 }
  (NormalKeyCode: kbF3; ShiftState: kbAltShift), { $6A00 }
  (NormalKeyCode: kbF4; ShiftState: kbAltShift), { $6B00 }
  (NormalKeyCode: kbF5; ShiftState: kbAltShift), { $6C00 }
  (NormalKeyCode: kbF6; ShiftState: kbAltShift), { $6D00 }
  (NormalKeyCode: kbF7; ShiftState: kbAltShift), { $6E00 }
  (NormalKeyCode: kbF8; ShiftState: kbAltShift), { $6F00 }
  (NormalKeyCode: kbF9; ShiftState: kbAltShift), { $7000 }
  (NormalKeyCode: kbF10; ShiftState: kbAltShift), { $7100 }
  (NormalKeyCode: kbCtrlPrtSc; ShiftState: kbCtrlShift), { $7200 }
  (NormalKeyCode: kbLeft; ShiftState: kbCtrlShift), { $7300 }
  (NormalKeyCode: kbRight; ShiftState: kbCtrlShift), { $7400 }
  (NormalKeyCode: kbEnd; ShiftState: kbCtrlShift), { $7500 }
  (NormalKeyCode: kbPgDn; ShiftState: kbCtrlShift), { $7600 }
  (NormalKeyCode: kbHome; ShiftState: kbCtrlShift), { $7700 }
  (NormalKeyCode: Ord('1'); ShiftState: kbAltShift), { $7800 }
  (NormalKeyCode: Ord('2'); ShiftState: kbAltShift), { $7900 }
  (NormalKeyCode: Ord('3'); ShiftState: kbAltShift), { $7A00 }
  (NormalKeyCode: Ord('4'); ShiftState: kbAltShift), { $7B00 }
  (NormalKeyCode: Ord('5'); ShiftState: kbAltShift), { $7C00 }
  (NormalKeyCode: Ord('6'); ShiftState: kbAltShift), { $7D00 }
  (NormalKeyCode: Ord('7'); ShiftState: kbAltShift), { $7E00 }
  (NormalKeyCode: Ord('8'); ShiftState: kbAltShift), { $7F00 }
  (NormalKeyCode: Ord('9'); ShiftState: kbAltShift), { $8000 }
  (NormalKeyCode: Ord('0'); ShiftState: kbAltShift), { $8100 }
  (NormalKeyCode: Ord('-'); ShiftState: kbAltShift), { $8200 }
  (NormalKeyCode: Ord('='); ShiftState: kbAltShift), { $8300 }
  (NormalKeyCode: kbPgUp; ShiftState: kbCtrlShift), { $8400 }
  (NormalKeyCode: kbF11; ShiftState: 0), { $8500 }
  (NormalKeyCode: kbF12; ShiftState: 0), { $8600 }
  (NormalKeyCode: kbF11; ShiftState: kbShift), { $8700 }
  (NormalKeyCode: kbF12; ShiftState: kbShift), { $8800 }
  (NormalKeyCode: kbF11; ShiftState: kbCtrlShift), { $8900 }
  (NormalKeyCode: kbF12; ShiftState: kbCtrlShift), { $8A00 }
  (NormalKeyCode: kbF11; ShiftState: kbAltShift), { $8B00 }
  (NormalKeyCode: kbF12; ShiftState: kbAltShift), { $8C00 }
  (NormalKeyCode: kbUp; ShiftState: kbCtrlShift), { $8D00 }
  (NormalKeyCode: 0; ShiftState: 0), { $8E00 }
  (NormalKeyCode: 0; ShiftState: 0), { $8F00 }
  (NormalKeyCode: 0; ShiftState: 0), { $9000 }
  (NormalKeyCode: kbDown; ShiftState: kbCtrlShift), { $9100 }
  (NormalKeyCode: 0; ShiftState: 0), { $9200 }
  (NormalKeyCode: 0; ShiftState: 0), { $9300 }
  (NormalKeyCode: kbTab; ShiftState: kbCtrlShift), { $9400 }
  (NormalKeyCode: 0; ShiftState: 0), { $9500 }
  (NormalKeyCode: 0; ShiftState: 0), { $9600 }
  (NormalKeyCode: kbHome; ShiftState: kbAltShift), { $9700 }
  (NormalKeyCode: kbUp; ShiftState: kbAltShift), { $9800 }
  (NormalKeyCode: kbPgUp; ShiftState: kbAltShift), { $9900 }
  (NormalKeyCode: 0; ShiftState: 0), { $9A00 }
  (NormalKeyCode: kbLeft; ShiftState: kbAltShift), { $9B00 }
  (NormalKeyCode: 0; ShiftState: 0), { $9C00 }
  (NormalKeyCode: kbRight; ShiftState: kbAltShift), { $9D00 }
  (NormalKeyCode: 0; ShiftState: 0), { $9E00 }
  (NormalKeyCode: kbEnd; ShiftState: kbAltShift), { $9F00 }
  (NormalKeyCode: kbDown; ShiftState: kbAltShift), { $A000 }
  (NormalKeyCode: kbPgDn; ShiftState: kbAltShift), { $A100 }
  (NormalKeyCode: kbIns; ShiftState: kbAltShift), { $A200 }
  (NormalKeyCode: kbDel; ShiftState: kbAltShift), { $A300 }
  (NormalKeyCode: 0; ShiftState: 0), { $A400 }
  (NormalKeyCode: kbTab; ShiftState: kbAltShift), { $A500 }
  (NormalKeyCode: kbEnter; ShiftState: kbAltShift) { $A600 }
  );

  KbCtrlBackEntry: TKeyCodeLookupEntry =
    (NormalKeyCode: kbBack; ShiftState: kbCtrlShift);
  KbCtrlEnterEntry: TKeyCodeLookupEntry =
    (NormalKeyCode: kbEnter; ShiftState: kbCtrlShift);

  { Scan codes 16..50 of the letter keys, 0 where the key is not a letter }
  ScanKeys = 'QWERTYUIOP'#0#0#0#0'ASDFGHJKL'#0#0#0#0#0'ZXCVBNM';

function IsRawCtrlKey(ScanCode, CharCode: Byte): Boolean;
begin
  Result := False;
  if (ScanCode >= 16) and (ScanCode < 16 + 35) then
    Result := Ord(ScanKeys[ScanCode - 16 + 1]) = Integer(CharCode) - 1 + Ord('A');
end;

function IsPrintableCharacter(CharCode: Byte): Boolean;
begin
  Result := (CharCode >= Ord(' ')) and (CharCode <> $7F) and (CharCode <> $FF);
end;

function IsKeypadCharacter(ScanCode: Byte): Boolean;
begin
  Result := (ScanCode = $35) or (ScanCode = $37) or
    (ScanCode = $4A) or (ScanCode = $4E);
end;

{ TKey }

constructor TKey.Create(AKeyCode: Word; AShiftState: Word);
var
  LCode, LMods: Word;
  ScanCode, CharCode: Byte;
  Entry: TKeyCodeLookupEntry;
  HasEntry: Boolean;
begin
  LCode := AKeyCode;
  LMods := 0;
  if (AShiftState and kbShift) <> 0 then
    LMods := LMods or kbShift;
  if (AShiftState and kbCtrlShift) <> 0 then
    LMods := LMods or kbCtrlShift;
  if (AShiftState and kbAltShift) <> 0 then
    LMods := LMods or kbAltShift;
  ScanCode := AKeyCode shr 8;
  CharCode := AKeyCode and $FF;

  HasEntry := False;
  Entry.NormalKeyCode := 0;
  Entry.ShiftState := 0;
  if (AKeyCode <= kbCtrlZ) or IsRawCtrlKey(ScanCode, CharCode) then
  begin
    Entry := CtrlKeyLookup[CharCode];
    HasEntry := True;
  end
  else if CharCode = 0 then
  begin
    if ScanCode < ExtKeyLookupSize then
    begin
      Entry := ExtKeyLookup[ScanCode];
      HasEntry := True;
    end;
  end
  else if IsPrintableCharacter(CharCode) then
  begin
    if (CharCode >= Ord('a')) and (CharCode <= Ord('z')) then
      LCode := CharCode - Ord('a') + Ord('A')
    else if not IsKeypadCharacter(ScanCode) then
      LCode := LCode and $FF;
  end
  else
    case AKeyCode of
      kbCtrlBack:
        begin
          Entry := KbCtrlBackEntry;
          HasEntry := True;
        end;
      kbCtrlEnter:
        begin
          Entry := KbCtrlEnterEntry;
          HasEntry := True;
        end;
    end;

  if HasEntry then
  begin
    LMods := LMods or Entry.ShiftState;
    if Entry.NormalKeyCode <> 0 then
      LCode := Entry.NormalKeyCode;
  end;

  Code := LCode;
  if LCode <> kbNoKey then
    Mods := LMods
  else
    Mods := 0;
end;

class operator TKey.:=(const AKeyCode: Word): TKey;
begin
  Result := TKey.Create(AKeyCode);
end;

class operator TKey.=(const One, Two: TKey): Boolean;
begin
  Result := (LongWord(One.Code) or (LongWord(One.Mods) shl 16)) =
    (LongWord(Two.Code) or (LongWord(Two.Mods) shl 16));
end;

class operator TKey.<>(const One, Two: TKey): Boolean;
begin
  Result := not (One = Two);
end;

const
  { Pairs of a Wordstar control character and the key it stands for }
  WordstarKeys: array[0..21] of Word = (
    kbCtrlS, kbLeft,
    kbCtrlD, kbRight,
    kbCtrlE, kbUp,
    kbCtrlX, kbDown,
    kbCtrlA, kbHome,
    kbCtrlF, kbEnd,
    kbCtrlG, kbDel,
    kbCtrlV, kbIns,
    kbCtrlR, kbPgUp,
    kbCtrlC, kbPgDn,
    kbCtrlH, kbBack
  );

function CtrlToArrow(KeyCode: Word): Word;
var
  I: Integer;
begin
  Result := KeyCode;
  I := 0;
  while I < Length(WordstarKeys) do
  begin
    if WordstarKeys[I] = (KeyCode and $00FF) then
    begin
      Result := WordstarKeys[I + 1];
      Break;
    end;
    Inc(I, 2);
  end;
end;

end.
