{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/util.h, source/tvision/drivers2.cpp (cstrlen, strwidth),
  source/tvision/tvtext2.cpp (getAltChar, getAltCharStr, getAltCode, getCtrlChar, getCtrlCharStr, getCtrlCode),
  source/tvision/newstr.cpp, source/tvision/fmtstr.cpp
  See COPYRIGHT.magiblot.

  The functions of util.h whose bodies are in these files. ctrlToArrow is in TvKeys. The other declarations of
  util.h have no body among the sources or need a type that has no unit, and are not translated.

  A TStringView is a string. A TStringView that returns a character of a table (getAltCharStr, getCtrlCharStr) is
  a string of one character, and an empty TStringView is an empty string. The C++ char is a Char, uchar is a Byte
  and ushort is a Word. The functions with a name that starts with a lower case letter in the C++ take a capital
  first letter, as in docs/API-NAMES.md (Cstrlen, Strwidth).

  newStr returns a block that was allocated for the characters and the terminating zero; it is released with
  FreeMem. The variadic list of formatStr is an array of const, and its format is a Free Pascal Format string; a
  C++ format specifier that Format does not accept (for example a length modifier such as l) counts as a failure
  of the formatting. }
unit TvUtil;

{$mode objfpc}
{$modeswitch advancedrecords}
{$R-}
{$Q-}

interface

uses
  TvEvents;

{ The smaller and the larger of two values. }
function Min(A, B: Integer): Integer; overload;
function Min(A, B: Int64): Int64; overload;
function Max(A, B: Integer): Integer; overload;
function Max(A, B: Int64): Int64; overload;

{ Returns the character of the Alt key code KeyCode: a letter or a digit, or the space-bar character for
  kbAltSpace; #0 when the code has no character. }
function GetAltChar(KeyCode: Word): Char;

{ Returns the text of an Alt+Key event, or the character of its Alt key code; empty when it has none. }
function GetAltCharStr(const KeyDown: TKeyDownEvent): string;

{ Returns the Alt key code of the character C (letters are taken in upper case); 0 when it has none. }
function GetAltCode(C: Char): Word;

{ Returns the letter of the Ctrl key code KeyCode: the control character 1 to 26 as the letter A to Z; #0 when the
  code has none. }
function GetCtrlChar(KeyCode: Word): Char;

{ Returns the text of a Ctrl+Key event (without Alt), or the letter of its control character; empty when it has
  none. }
function GetCtrlCharStr(const KeyDown: TKeyDownEvent): string;

{ Returns the Alt key code of the character Ch combined with the Ctrl code of its letter. }
function GetCtrlCode(Ch: Byte): Word;

{ Returns the displayed length of Text, ignoring the '~' characters. It is used for command strings, which use '~'
  to toggle between display attributes. }
function Cstrlen(const Text: string): Integer;

{ Returns the displayed length of Text. }
function Strwidth(const Text: string): Integer;

{ Returns a copy of the Size bytes at S in a block of Size + 1 bytes, with a terminating zero; nil when S is nil.
  The variant with a string always returns a block. }
function NewStr(S: PAnsiChar; Size: SizeInt): PAnsiChar; overload;
function NewStr(const S: string): PAnsiChar; overload;

{ Returns AFormat with its specifiers replaced by Args. When the formatting fails, returns AFormat. }
function FormatStr(const AFormat: string; const Args: array of const): string;
function VFormatStr(const AFormat: string; const Args: array of const): string;

implementation

function Min(A, B: Integer): Integer;
begin
  Result := 0;
end;

function Min(A, B: Int64): Int64;
begin
  Result := 0;
end;

function Max(A, B: Integer): Integer;
begin
  Result := 0;
end;

function Max(A, B: Int64): Int64;
begin
  Result := 0;
end;

function GetAltChar(KeyCode: Word): Char;
begin
  Result := #0;
end;

function GetAltCharStr(const KeyDown: TKeyDownEvent): string;
begin
  Result := '';
end;

function GetAltCode(C: Char): Word;
begin
  Result := 0;
end;

function GetCtrlChar(KeyCode: Word): Char;
begin
  Result := #0;
end;

function GetCtrlCharStr(const KeyDown: TKeyDownEvent): string;
begin
  Result := '';
end;

function GetCtrlCode(Ch: Byte): Word;
begin
  Result := 0;
end;

function Cstrlen(const Text: string): Integer;
begin
  Result := 0;
end;

function Strwidth(const Text: string): Integer;
begin
  Result := 0;
end;

function NewStr(S: PAnsiChar; Size: SizeInt): PAnsiChar;
begin
  Result := nil;
end;

function NewStr(const S: string): PAnsiChar;
begin
  Result := nil;
end;

function FormatStr(const AFormat: string; const Args: array of const): string;
begin
  Result := '';
end;

function VFormatStr(const AFormat: string; const Args: array of const): string;
begin
  Result := '';
end;

end.
