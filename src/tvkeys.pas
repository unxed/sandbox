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

{ TKey }

constructor TKey.Create(AKeyCode: Word; AShiftState: Word);
begin
  Code := AKeyCode;
  Mods := 0;
end;

class operator TKey.:=(const AKeyCode: Word): TKey;
begin
  Result.Code := AKeyCode;
  Result.Mods := 0;
end;

class operator TKey.=(const One, Two: TKey): Boolean;
begin
  Result := False;
end;

class operator TKey.<>(const One, Two: TKey): Boolean;
begin
  Result := True;
end;

function CtrlToArrow(KeyCode: Word): Word;
begin
  Result := KeyCode;
end;

end.
