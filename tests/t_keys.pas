{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/tkeys.h, source/tvision/tkey.cpp,
  source/tvision/drivers2.cpp (ctrlToArrow)
  See COPYRIGHT.magiblot. }
program t_keys;

{$mode objfpc}
{$modeswitch advancedrecords}

uses
  TvKeys;

{$I testlib.inc}

function Key(ACode: Word; AMods: Word = 0): TKey;
begin
  Result := TKey.Create(ACode, AMods);
end;

function Same(const T: TKey; ACode, AMods: Word): Boolean;
begin
  Result := (T.Code = ACode) and (T.Mods = AMods);
end;

function Chr_(C: Char): Word;
begin
  Result := Ord(C);
end;

var
  T: TKey;
  Mask: Word;

begin
  { Key code constants }
  Check(kbCtrlA = $0001, 'kbCtrlA');
  Check(kbCtrlM = $000D, 'kbCtrlM');
  Check(kbCtrlZ = $001A, 'kbCtrlZ');
  Check(kbEsc = $011B, 'kbEsc');
  Check(kbEnter = $1C0D, 'kbEnter');
  Check(kbCtrlEnter = $1C0A, 'kbCtrlEnter');
  Check(kbBack = $0E08, 'kbBack');
  Check(kbCtrlBack = $0E7F, 'kbCtrlBack');
  Check(kbTab = $0F09, 'kbTab');
  Check(kbShiftTab = $0F00, 'kbShiftTab');
  Check(kbAltQ = $1000, 'kbAltQ');
  Check(kbAltM = $3200, 'kbAltM');
  Check(kbF1 = $3B00, 'kbF1');
  Check(kbF10 = $4400, 'kbF10');
  Check(kbHome = $4700, 'kbHome');
  Check(kbGrayMinus = $4A2D, 'kbGrayMinus');
  Check(kbGrayPlus = $4E2B, 'kbGrayPlus');
  Check(kbDel = $5300, 'kbDel');
  Check(kbShiftF1 = $5400, 'kbShiftF1');
  Check(kbCtrlF10 = $6700, 'kbCtrlF10');
  Check(kbAltF1 = $6800, 'kbAltF1');
  Check(kbCtrlPrtSc = $7200, 'kbCtrlPrtSc');
  Check(kbAlt1 = $7800, 'kbAlt1');
  Check(kbAltEqual = $8300, 'kbAltEqual');
  Check(kbCtrlPgUp = $8400, 'kbCtrlPgUp');
  Check(kbNoKey = $0000, 'kbNoKey');
  Check(kbAltEsc = $0100, 'kbAltEsc');
  Check(kbAltBack = $0E00, 'kbAltBack');
  Check(kbF11 = $8500, 'kbF11');
  Check(kbF12 = $8600, 'kbF12');
  Check(kbAltF12 = $8C00, 'kbAltF12');
  Check(kbCtrlUp = $8D00, 'kbCtrlUp');
  Check(kbCtrlDown = $9100, 'kbCtrlDown');
  Check(kbCtrlTab = $9400, 'kbCtrlTab');
  Check(kbAltTab = $A500, 'kbAltTab');
  Check(kbAltEnter = $A600, 'kbAltEnter');

  { Shift masks }
  Check(kbShift = (kbLeftShift or kbRightShift), 'kbShift');
  Check(kbCtrlShift = (kbLeftCtrl or kbRightCtrl), 'kbCtrlShift');
  Check(kbAltShift = (kbLeftAlt or kbRightAlt), 'kbAltShift');
  Check((kbShift and kbCtrlShift) = 0, 'shift and ctrl masks are disjoint');
  Check((kbShift and kbAltShift) = 0, 'shift and alt masks are disjoint');
  Check((kbCtrlShift and kbAltShift) = 0, 'ctrl and alt masks are disjoint');

  { Equality of equivalent spellings }
  Check(Key(kbCtrlA) = Key(Chr_('A'), kbCtrlShift), 'Ctrl+A spellings');
  Check(Key(kbCtrlTab, kbShift) = Key(kbTab, kbShift or kbCtrlShift),
    'Shift+Ctrl+Tab spellings');
  Check(Key(kbAltDel, kbCtrlShift) = Key(kbCtrlDel, kbAltShift),
    'Ctrl+Alt+Del spellings');
  Check(Key(kbShiftF5) = Key(kbF5, kbShift), 'Shift+F5 spellings');
  Check(Key(kbAltF3) = Key(kbF3, kbAltShift), 'Alt+F3 spellings');
  Check(Key(kbCtrlLeft) = Key(kbLeft, kbCtrlShift), 'Ctrl+Left spellings');
  Check(Key(kbAltQ) = Key(Chr_('Q'), kbAltShift), 'Alt+Q spellings');
  Check(Key(kbAltQ) = Key(Chr_('q'), kbAltShift), 'Alt+q spellings');
  Check(Key(kbCtrlBack) = Key(kbBack, kbCtrlShift), 'Ctrl+Backspace spellings');
  Check(Key(kbCtrlEnter) = Key(kbEnter, kbCtrlShift), 'Ctrl+Enter spellings');
  Check(Key(kbAltEsc) = Key(kbEsc, kbAltShift), 'Alt+Esc spellings');

  { Inequality }
  Check(Key(kbF1) <> Key(kbF1, kbShift), 'different modifiers differ');
  Check(Key(kbF1) <> Key(kbF2), 'different codes differ');
  Check(not (Key(kbF1) <> Key(kbF1)), 'equal values are not different');
  Check(not (Key(kbF1) = Key(kbF1, kbAltShift)), 'equality needs equal modifiers');
  Check(Key(kbGrayPlus) <> Key(Chr_('+')), 'keypad plus differs from plain plus');

  { Control keys }
  T := Key(kbCtrlA);
  Check(Same(T, Ord('A'), kbCtrlShift), 'Ctrl+A');
  T := Key(kbCtrlM);
  Check(Same(T, Ord('M'), kbCtrlShift), 'Ctrl+M');
  T := Key(kbCtrlZ);
  Check(Same(T, Ord('Z'), kbCtrlShift), 'Ctrl+Z');
  T := Key(kbCtrlZ, kbShift);
  Check(Same(T, Ord('Z'), kbShift or kbCtrlShift), 'Shift+Ctrl+Z');
  T := Key($001B);
  Check(Same(T, $001B, 0), 'the character ESC is not a control letter');

  { Raw control keys: scan code of a letter key with the control character }
  T := Key($1011);
  Check(Same(T, Ord('Q'), kbCtrlShift), 'raw Ctrl+Q');
  T := Key($1E01);
  Check(Same(T, Ord('A'), kbCtrlShift), 'raw Ctrl+A');
  T := Key($320D);
  Check(Same(T, Ord('M'), kbCtrlShift), 'raw Ctrl+M on the M key');
  T := Key($1E02);
  Check(Same(T, $1E02, 0), 'scan code and control character of different letters');
  T := Key($0F01);
  Check(Same(T, $0F01, 0), 'scan code outside the letter keys');

  { Plain characters }
  T := Key(Ord('A'));
  Check(Same(T, Ord('A'), 0), 'upper case letter');
  T := Key(Ord('a'));
  Check(Same(T, Ord('A'), 0), 'lower case letter is made upper case');
  T := Key(Ord('z'), kbAltShift);
  Check(Same(T, Ord('Z'), kbAltShift), 'lower case letter keeps the modifiers');
  T := Key($1E61);
  Check(Same(T, Ord('A'), 0), 'lower case letter drops the scan code');
  T := Key($1E41);
  Check(Same(T, Ord('A'), 0), 'upper case letter drops the scan code');
  T := Key($0C2D);
  Check(Same(T, Ord('-'), 0), 'minus on the main keyboard drops the scan code');
  T := Key(Ord(' '));
  Check(Same(T, Ord(' '), 0), 'space');
  T := Key($0080);
  Check(Same(T, $0080, 0), 'character 128');
  T := Key($1E80);
  Check(Same(T, $0080, 0), 'character 128 drops the scan code');

  { Characters that are not printable keep the whole key code }
  T := Key($1E7F);
  Check(Same(T, $1E7F, 0), 'DEL character keeps the scan code');
  T := Key($1EFF);
  Check(Same(T, $1EFF, 0), 'character 255 keeps the scan code');

  { Keypad characters keep the scan code }
  T := Key(kbGrayMinus);
  Check(Same(T, kbGrayMinus, 0), 'keypad minus');
  T := Key(kbGrayPlus);
  Check(Same(T, kbGrayPlus, 0), 'keypad plus');
  T := Key($352F);
  Check(Same(T, $352F, 0), 'keypad slash');
  T := Key($372A);
  Check(Same(T, $372A, 0), 'keypad asterisk');
  T := Key($4E2B, kbShift);
  Check(Same(T, $4E2B, kbShift), 'keypad plus with Shift');

  { Keys that stand for themselves }
  T := Key(kbEsc);
  Check(Same(T, kbEsc, 0), 'Esc');
  T := Key(kbEnter);
  Check(Same(T, kbEnter, 0), 'Enter');
  T := Key(kbBack);
  Check(Same(T, kbBack, 0), 'Backspace');
  T := Key(kbTab);
  Check(Same(T, kbTab, 0), 'Tab');
  T := Key(kbF1);
  Check(Same(T, kbF1, 0), 'F1');
  T := Key(kbF10);
  Check(Same(T, kbF10, 0), 'F10');
  T := Key(kbF11);
  Check(Same(T, kbF11, 0), 'F11');
  T := Key(kbF12);
  Check(Same(T, kbF12, 0), 'F12');
  T := Key(kbHome);
  Check(Same(T, kbHome, 0), 'Home');
  T := Key(kbPgDn);
  Check(Same(T, kbPgDn, 0), 'PgDn');
  T := Key(kbIns);
  Check(Same(T, kbIns, 0), 'Ins');
  T := Key(kbDel);
  Check(Same(T, kbDel, 0), 'Del');

  { Key codes with an implied modifier }
  T := Key(kbShiftF1);
  Check(Same(T, kbF1, kbShift), 'Shift+F1');
  T := Key(kbShiftF10);
  Check(Same(T, kbF10, kbShift), 'Shift+F10');
  T := Key(kbCtrlF1);
  Check(Same(T, kbF1, kbCtrlShift), 'Ctrl+F1');
  T := Key(kbCtrlF10);
  Check(Same(T, kbF10, kbCtrlShift), 'Ctrl+F10');
  T := Key(kbAltF1);
  Check(Same(T, kbF1, kbAltShift), 'Alt+F1');
  T := Key(kbAltF10);
  Check(Same(T, kbF10, kbAltShift), 'Alt+F10');
  T := Key(kbShiftF11);
  Check(Same(T, kbF11, kbShift), 'Shift+F11');
  T := Key(kbCtrlF12);
  Check(Same(T, kbF12, kbCtrlShift), 'Ctrl+F12');
  T := Key(kbAltF11);
  Check(Same(T, kbF11, kbAltShift), 'Alt+F11');
  T := Key(kbAltF12);
  Check(Same(T, kbF12, kbAltShift), 'Alt+F12');
  T := Key(kbShiftTab);
  Check(Same(T, kbTab, kbShift), 'Shift+Tab');
  T := Key(kbCtrlTab);
  Check(Same(T, kbTab, kbCtrlShift), 'Ctrl+Tab');
  T := Key(kbAltTab);
  Check(Same(T, kbTab, kbAltShift), 'Alt+Tab');
  T := Key(kbCtrlIns);
  Check(Same(T, kbIns, kbCtrlShift), 'Ctrl+Ins');
  T := Key(kbShiftIns);
  Check(Same(T, kbIns, kbShift), 'Shift+Ins');
  T := Key(kbAltIns);
  Check(Same(T, kbIns, kbAltShift), 'Alt+Ins');
  T := Key(kbCtrlDel);
  Check(Same(T, kbDel, kbCtrlShift), 'Ctrl+Del');
  T := Key(kbShiftDel);
  Check(Same(T, kbDel, kbShift), 'Shift+Del');
  T := Key(kbAltDel);
  Check(Same(T, kbDel, kbAltShift), 'Alt+Del');
  T := Key(kbAltSpace);
  Check(Same(T, Ord(' '), kbAltShift), 'Alt+Space');
  T := Key(kbAltEsc);
  Check(Same(T, kbEsc, kbAltShift), 'Alt+Esc');
  T := Key(kbAltBack);
  Check(Same(T, kbBack, kbAltShift), 'Alt+Backspace');
  T := Key(kbCtrlBack);
  Check(Same(T, kbBack, kbCtrlShift), 'Ctrl+Backspace');
  T := Key(kbCtrlEnter);
  Check(Same(T, kbEnter, kbCtrlShift), 'Ctrl+Enter');
  T := Key(kbAltEnter);
  Check(Same(T, kbEnter, kbAltShift), 'Alt+Enter');
  T := Key(kbCtrlPrtSc);
  Check(Same(T, kbCtrlPrtSc, kbCtrlShift), 'Ctrl+PrtSc');

  { Navigation keys with Ctrl and Alt }
  T := Key(kbCtrlLeft);
  Check(Same(T, kbLeft, kbCtrlShift), 'Ctrl+Left');
  T := Key(kbCtrlRight);
  Check(Same(T, kbRight, kbCtrlShift), 'Ctrl+Right');
  T := Key(kbCtrlUp);
  Check(Same(T, kbUp, kbCtrlShift), 'Ctrl+Up');
  T := Key(kbCtrlDown);
  Check(Same(T, kbDown, kbCtrlShift), 'Ctrl+Down');
  T := Key(kbCtrlHome);
  Check(Same(T, kbHome, kbCtrlShift), 'Ctrl+Home');
  T := Key(kbCtrlEnd);
  Check(Same(T, kbEnd, kbCtrlShift), 'Ctrl+End');
  T := Key(kbCtrlPgUp);
  Check(Same(T, kbPgUp, kbCtrlShift), 'Ctrl+PgUp');
  T := Key(kbCtrlPgDn);
  Check(Same(T, kbPgDn, kbCtrlShift), 'Ctrl+PgDn');
  T := Key(kbAltLeft);
  Check(Same(T, kbLeft, kbAltShift), 'Alt+Left');
  T := Key(kbAltRight);
  Check(Same(T, kbRight, kbAltShift), 'Alt+Right');
  T := Key(kbAltUp);
  Check(Same(T, kbUp, kbAltShift), 'Alt+Up');
  T := Key(kbAltDown);
  Check(Same(T, kbDown, kbAltShift), 'Alt+Down');
  T := Key(kbAltHome);
  Check(Same(T, kbHome, kbAltShift), 'Alt+Home');
  T := Key(kbAltEnd);
  Check(Same(T, kbEnd, kbAltShift), 'Alt+End');
  T := Key(kbAltPgUp);
  Check(Same(T, kbPgUp, kbAltShift), 'Alt+PgUp');
  T := Key(kbAltPgDn);
  Check(Same(T, kbPgDn, kbAltShift), 'Alt+PgDn');

  { Alt with letters and digits }
  T := Key(kbAltA);
  Check(Same(T, Ord('A'), kbAltShift), 'Alt+A');
  T := Key(kbAltZ);
  Check(Same(T, Ord('Z'), kbAltShift), 'Alt+Z');
  T := Key(kbAltP);
  Check(Same(T, Ord('P'), kbAltShift), 'Alt+P');
  T := Key(kbAltL);
  Check(Same(T, Ord('L'), kbAltShift), 'Alt+L');
  T := Key(kbAlt1);
  Check(Same(T, Ord('1'), kbAltShift), 'Alt+1');
  T := Key(kbAlt9);
  Check(Same(T, Ord('9'), kbAltShift), 'Alt+9');
  T := Key(kbAlt0);
  Check(Same(T, Ord('0'), kbAltShift), 'Alt+0');
  T := Key(kbAltMinus);
  Check(Same(T, Ord('-'), kbAltShift), 'Alt+Minus');
  T := Key(kbAltEqual);
  Check(Same(T, Ord('='), kbAltShift), 'Alt+Equal');

  { Scan codes of keypad keys with no character, and scan codes outside the table }
  T := Key($3500, kbAltShift);
  Check(Same(T, Ord('/'), kbCtrlShift or kbAltShift), 'scan code 35 without character');
  T := Key($3700);
  Check(Same(T, Ord('*'), kbCtrlShift), 'scan code 37 without character');
  T := Key($4A00);
  Check(Same(T, Ord('-'), kbCtrlShift), 'scan code 4A without character');
  T := Key($4E00);
  Check(Same(T, Ord('+'), kbCtrlShift), 'scan code 4E without character');
  T := Key($0300, kbAltShift);
  Check(Same(T, $0300, kbAltShift), 'scan code without a key keeps the code');
  T := Key($4C00, kbShift);
  Check(Same(T, $4C00, kbShift), 'scan code 4C keeps the code');
  T := Key($A400);
  Check(Same(T, $A400, 0), 'hole at the end of the table');
  T := Key($A700);
  Check(Same(T, $A700, 0), 'scan code just after the table');
  T := Key($FF00, kbCtrlShift);
  Check(Same(T, $FF00, kbCtrlShift), 'scan code far after the table');

  { Modifiers }
  T := Key(kbF1, kbShift);
  Check(Same(T, kbF1, kbShift), 'Shift mask');
  T := Key(kbF1, kbLeftShift);
  Check(Same(T, kbF1, kbShift), 'left Shift gives the Shift mask');
  T := Key(kbF1, kbRightShift);
  Check(Same(T, kbF1, kbShift), 'right Shift gives the Shift mask');
  T := Key(kbF1, kbLeftCtrl);
  Check(Same(T, kbF1, kbCtrlShift), 'left Ctrl gives the Ctrl mask');
  T := Key(kbF1, kbRightCtrl);
  Check(Same(T, kbF1, kbCtrlShift), 'right Ctrl gives the Ctrl mask');
  T := Key(kbF1, kbLeftAlt);
  Check(Same(T, kbF1, kbAltShift), 'left Alt gives the Alt mask');
  T := Key(kbF1, kbRightAlt);
  Check(Same(T, kbF1, kbAltShift), 'right Alt gives the Alt mask');
  T := Key(kbF1, kbShift or kbCtrlShift or kbAltShift);
  Check(Same(T, kbF1, kbShift or kbCtrlShift or kbAltShift), 'all three modifiers');
  T := Key(kbF1, $FFFF);
  Check(Same(T, kbF1, kbShift or kbCtrlShift or kbAltShift), 'other bits are dropped');
  Mask := kbScrollState or kbNumState or kbCapsState or kbInsState or kbPaste;
  T := Key(kbF1, Mask);
  Check(Same(T, kbF1, 0), 'state flags are not modifiers');
  T := Key(kbF1, Mask or kbAltShift);
  Check(Same(T, kbF1, kbAltShift), 'state flags beside a modifier');
  T := Key(kbAltF1, kbAltShift);
  Check(Same(T, kbF1, kbAltShift), 'a modifier implied by the code is not doubled');
  T := Key(kbAltF1, kbCtrlShift);
  Check(Same(T, kbF1, kbAltShift or kbCtrlShift), 'implied and given modifiers are joined');

  { No key }
  T := Key(kbNoKey);
  Check(Same(T, 0, 0), 'no key');
  T := Key(kbNoKey, kbShift or kbAltShift);
  Check(Same(T, 0, 0), 'no key drops the modifiers');

  { Implicit conversion from a key code }
  T := kbF3;
  Check(Same(T, kbF3, 0), 'conversion of a key code');
  T := Key(kbF3);
  Check(T = Key(kbF3, 0), 'default modifiers are zero');

  { CtrlToArrow }
  Check(CtrlToArrow(kbCtrlS) = kbLeft, 'Ctrl+S is Left');
  Check(CtrlToArrow(kbCtrlD) = kbRight, 'Ctrl+D is Right');
  Check(CtrlToArrow(kbCtrlE) = kbUp, 'Ctrl+E is Up');
  Check(CtrlToArrow(kbCtrlX) = kbDown, 'Ctrl+X is Down');
  Check(CtrlToArrow(kbCtrlA) = kbHome, 'Ctrl+A is Home');
  Check(CtrlToArrow(kbCtrlF) = kbEnd, 'Ctrl+F is End');
  Check(CtrlToArrow(kbCtrlG) = kbDel, 'Ctrl+G is Del');
  Check(CtrlToArrow(kbCtrlV) = kbIns, 'Ctrl+V is Ins');
  Check(CtrlToArrow(kbCtrlR) = kbPgUp, 'Ctrl+R is PgUp');
  Check(CtrlToArrow(kbCtrlC) = kbPgDn, 'Ctrl+C is PgDn');
  Check(CtrlToArrow(kbCtrlH) = kbBack, 'Ctrl+H is Backspace');
  Check(CtrlToArrow(kbCtrlB) = kbCtrlB, 'Ctrl+B is unchanged');
  Check(CtrlToArrow(kbCtrlZ) = kbCtrlZ, 'Ctrl+Z is unchanged');
  Check(CtrlToArrow(kbCtrlM) = kbCtrlM, 'Ctrl+M is unchanged');
  Check(CtrlToArrow(kbLeft) = kbLeft, 'Left is unchanged');
  Check(CtrlToArrow(kbF1) = kbF1, 'F1 is unchanged');
  Check(CtrlToArrow(kbNoKey) = kbNoKey, 'no key is unchanged');
  Check(CtrlToArrow(kbEnter) = kbEnter, 'Enter is unchanged');
  Check(CtrlToArrow(kbTab) = kbTab, 'Tab is unchanged');
  Check(CtrlToArrow(kbEsc) = kbEsc, 'Esc is unchanged');
  Check(CtrlToArrow($1E01) = kbHome, 'only the low byte counts');
  Check(CtrlToArrow($FF13) = kbLeft, 'only the low byte counts, Ctrl+S');
  Check(CtrlToArrow(kbBack) = kbBack, 'Backspace stays Backspace');
  Check(CtrlToArrow(Ord('S')) = Ord('S'), 'the letter S is unchanged');

  Done;
end.
