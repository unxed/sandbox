{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/ttext.h, source/platform/ttext.cpp, include/tvision/scrncell.h
  See COPYRIGHT.magiblot.

  The members of the C++ class TText that write into screen cells (drawChar, drawStr, drawOne and what they need).
  The other members of TText are in TvUtf8. A Pascal class cannot be extended in another unit, so these members are
  class methods of TTextCells.

  Only the branch of ttext.h for compilers other than Borland C++ is translated. A TSpan<TScreenCell> is an open
  array of TScreenCell that is passed by reference, a TStringView is a string, a TSpan<const uint32_t> is an open
  array of Cardinal. Indices into a text are zero-based (the character at index J is Text[J + 1]); indices into
  Cells are zero-based. A function template parameter that transforms an attribute is a TTransformAttr.

  The conversion of control characters and of extended ASCII to a code page character goes through the variable
  CodePageToPackedUtf8, which returns the bytes of the UTF-8 sequence as a Cardinal with the first byte lowest, as
  InitWithMultiByteChar expects. Its default returns the byte itself. }
unit TvText;

{$mode objfpc}
{$modeswitch advancedrecords}
{$R-}
{$Q-}

interface

uses
  TvColors, TvCell;

type
  { The callback of the Ex variants: changes the color attribute of a cell. }
  TTransformAttr = procedure(var Attr: TColorAttr);

  { Converts a code page character to a packed UTF-8 character. }
  TPackedUtf8Func = function(C: Char): Cardinal;

  TTextCells = class
  public
    { Fills Cells with the character C.
      The variant with Attr also sets the color attribute to Attr. }
    class procedure DrawChar(var Cells: array of TScreenCell; C: Char); overload; static;
    class procedure DrawChar(var Cells: array of TScreenCell; C: Char; Attr: TColorAttr); overload; static;

    { Copies text from Text into Cells, starting at position Indent of Cells and at column TextIndent of Text.
      Returns the number of cells that were filled with text.
      The variants with Attr also set the color attribute to Attr.
      The variants without Indent and TextIndent use Indent = 0 and TextIndent = 0.
      When column TextIndent of Text is in the middle of a double-width character, a whitespace is copied in its
      place. }
    class function DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
      TextIndent: Integer): SizeInt; overload; static;
    class function DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
      TextIndent: Integer; Attr: TColorAttr): SizeInt; overload; static;
    class function DrawStr(var Cells: array of TScreenCell; const Text: string): SizeInt; overload; static;
    class function DrawStr(var Cells: array of TScreenCell; const Text: string;
      Attr: TColorAttr): SizeInt; overload; static;

    { Reads a single character from a multibyte-encoded string, and writes it into a screen cell.
      I is an index into Cells that is increased by the number of cells that have been updated. J is an index into
      Text that is increased by the number of bytes read from Text. Attr is the color attribute to set in the cell.
      Returns False when no character was read.
      A screen cell may contain one printable character (of width 1 or more) and several combining characters
      appended to it (of width 0). When a zero-width character is found in Text, it is combined with the previous
      cell, Cells[I - 1], if I > 0. In this case, I is not increased and the color attribute is not set. }
    class function DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: string;
      var J: SizeInt): Boolean; overload; static;
    class function DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: string; var J: SizeInt;
      Attr: TColorAttr): Boolean; overload; static;

    { Variants of the functions above which call Transform to change the color attribute of each cell (rather than
      setting it to a fixed value). }
    class procedure DrawCharEx(var Cells: array of TScreenCell; C: Char; Transform: TTransformAttr); static;
    class function DrawStrEx(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
      TextIndent: Integer; Transform: TTransformAttr): SizeInt; overload; static;

    { UTF-32 variants of some of the functions above. }
    class function DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
      TextIndent: Integer): SizeInt; overload; static;
    class function DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
      TextIndent: Integer; Attr: TColorAttr): SizeInt; overload; static;
    class function DrawStrEx(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
      TextIndent: Integer; Transform: TTransformAttr): SizeInt; overload; static;
    class function DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: array of Cardinal;
      var J: SizeInt): Boolean; overload; static;
    class function DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: array of Cardinal;
      var J: SizeInt; Attr: TColorAttr): Boolean; overload; static;
  end;

var
  CodePageToPackedUtf8: TPackedUtf8Func;

implementation

uses
  TvUtf8;

const
  { U+FFFD REPLACEMENT CHARACTER in UTF-8. }
  Replacement = #$EF#$BF#$BD;
  { U+200D ZERO WIDTH JOINER in UTF-8. }
  ZeroWidthJoiner = #$E2#$80#$8D;

type
  TLw = record
    Length, Width: SizeInt;
  end;

  TMbStat = record
    Length, Width: Integer;
  end;

  { How the color attribute of a cell is changed: left as it is, set to a value, or passed to a callback. }
  TAttrMode = (amKeep, amSet, amCall);

  TAttrAction = record
    Mode: TAttrMode;
    Attr: TColorAttr;
    Func: TTransformAttr;
  end;

function PlainPackedUtf8(C: Char): Cardinal;
begin
  Result := Byte(C);
end;

function KeepAttr: TAttrAction;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Mode := amKeep;
end;

function SetAttr(const Attr: TColorAttr): TAttrAction;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Mode := amSet;
  Result.Attr := Attr;
end;

function CallAttr(Transform: TTransformAttr): TAttrAction;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Mode := amCall;
  Result.Func := Transform;
end;

procedure ApplyAction(const Action: TAttrAction; var Attr: TColorAttr);
begin
  case Action.Mode of
    amSet:
      Attr := Action.Attr;
    amCall:
      if Assigned(Action.Func) then
        Action.Func(Attr);
  end;
end;

{ The length and the width of the character that starts at the zero-based position Start of Text, as
  TText.Next finds them, and the width of the code point when the character has several bytes.
  Pre: Start < Length(Text). }
function MbStat(const Text: string; Start: SizeInt): TMbStat;
var
  Index, W: SizeInt;
begin
  Index := Start;
  W := 0;
  TText.Next(Text, Index, W);
  Result.Length := Index - Start;
  Result.Width := 1;
  if Result.Length > 1 then
    Result.Width := CharWidth(Utf8To32(Copy(Text, Start + 1, Result.Length)));
end;

{ Zero-width joiners are not printed: terminal applications represent them differently, and they can combine
  different characters together, changing the width of a whole string. }
function IsZeroWidthJoiner(const Mbc: string): Boolean;
begin
  Result := Mbc = ZeroWidthJoiner;
end;

{ Appends a zero-width character to the cell before position I, skipping back over wide char trails.
  Pre: 0 < I <= Length(Cells). }
procedure AppendToPrevious(var Cells: array of TScreenCell; I: SizeInt; const Zwc: string);
var
  K: SizeInt;
begin
  K := I - 1;
  while Cells[K].Character.IsWideCharTrail and (K > 0) do
    Dec(K);
  Cells[K].Character.AppendZeroWidthChar(Zwc);
end;

function DrawOneImpl(var Cells: array of TScreenCell; I: SizeInt; const Text: string; J: SizeInt): TLw; overload;
var
  Mb: TMbStat;
  Mbc: string;
  Wide, DrawTrail: Boolean;
begin
  Result.Length := 0;
  Result.Width := 0;
  if J >= Length(Text) then
    Exit;
  Mb := MbStat(Text, J);
  if Mb.Length <= 1 then
  begin
    if I < Length(Cells) then
    begin
      { Control characters are converted here, since combining characters may be appended to them later. }
      if (Text[J + 1] < ' ') or (Text[J + 1] >= #$7F) then
        Cells[I].Character.InitWithMultiByteChar(CodePageToPackedUtf8(Text[J + 1]))
      else
        Cells[I].Character.InitWithChar(Text[J + 1]);
      Result.Length := 1;
      Result.Width := 1;
    end;
    Exit;
  end;
  Mbc := Copy(Text, J + 1, Mb.Length);
  if Mb.Width < 0 then
  begin
    if I < Length(Cells) then
    begin
      Cells[I].Character.InitWithMultiByteChar(Replacement);
      Result.Length := Mb.Length;
      Result.Width := 1;
    end;
  end
  else if Mb.Width = 0 then
  begin
    if (I > 0) and (I <= Length(Cells)) and not IsZeroWidthJoiner(Mbc) then
      AppendToPrevious(Cells, I, Mbc);
    Result.Length := Mb.Length;
  end
  else if I < Length(Cells) then
  begin
    Wide := Mb.Width > 1;
    Cells[I].Character.InitWithMultiByteChar(Mbc, Wide);
    DrawTrail := Wide and (I + 1 < Length(Cells));
    if DrawTrail then
      Cells[I + 1].Character.InitAsWideCharTrail;
    Result.Length := Mb.Length;
    Result.Width := 1 + Ord(DrawTrail);
  end;
end;

function DrawOneImpl(var Cells: array of TScreenCell; I: SizeInt; const TextU32: array of Cardinal;
  J: SizeInt): TLw; overload;
var
  U8: TUtf8Bytes;
  Mbc: string;
  Count, N: SizeInt;
  Width: Integer;
  Wide, DrawTrail: Boolean;
begin
  Result.Length := 0;
  Result.Width := 0;
  if J >= Length(TextU32) then
    Exit;
  FillChar(U8, SizeOf(U8), 0);
  Count := Utf32To8(TextU32[J], U8);
  SetLength(Mbc, Count);
  for N := 0 to Count - 1 do
    Mbc[N + 1] := Chr(U8[N]);
  Width := CharWidth(TextU32[J]);
  if Width < 0 then
  begin
    if I < Length(Cells) then
    begin
      Cells[I].Character.InitWithMultiByteChar(Replacement);
      Result.Length := 1;
      Result.Width := 1;
    end;
  end
  else if (TextU32[J] <> 0) and (Width = 0) then
  begin
    if (I > 0) and (I <= Length(Cells)) and not IsZeroWidthJoiner(Mbc) then
      AppendToPrevious(Cells, I, Mbc);
    Result.Length := 1;
  end
  else if I < Length(Cells) then
  begin
    Wide := Width > 1;
    Cells[I].Character.InitWithMultiByteChar(Mbc, Wide);
    DrawTrail := Wide and (I + 1 < Length(Cells));
    if DrawTrail then
      Cells[I + 1].Character.InitAsWideCharTrail;
    Result.Length := 1;
    Result.Width := 1 + Ord(DrawTrail);
  end;
end;

{ Draws the character at J and applies Action to the attributes of the cells that it fills. }
function DrawOneT(var Cells: array of TScreenCell; var I: SizeInt; const Text: string; var J: SizeInt;
  const Action: TAttrAction): Boolean; overload;
var
  R: TLw;
begin
  R := DrawOneImpl(Cells, I, Text, J);
  if R.Width > 0 then
    ApplyAction(Action, Cells[I].Attribute);
  if R.Width > 1 then
    ApplyAction(Action, Cells[I + 1].Attribute);
  Inc(I, R.Width);
  Inc(J, R.Length);
  Result := R.Length <> 0;
end;

function DrawOneT(var Cells: array of TScreenCell; var I: SizeInt; const Text: array of Cardinal; var J: SizeInt;
  const Action: TAttrAction): Boolean; overload;
var
  R: TLw;
begin
  R := DrawOneImpl(Cells, I, Text, J);
  if R.Width > 0 then
    ApplyAction(Action, Cells[I].Attribute);
  if R.Width > 1 then
    ApplyAction(Action, Cells[I + 1].Attribute);
  Inc(I, R.Width);
  Inc(J, R.Length);
  Result := R.Length <> 0;
end;

function DrawStrExT(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string; TextIndent: Integer;
  const Action: TAttrAction): SizeInt; overload;
var
  I, J, LeadWidth: SizeInt;
begin
  I := Indent;
  J := 0;
  if TextIndent > 0 then
  begin
    LeadWidth := 0;
    TText.Scroll(Text, TextIndent, True, J, LeadWidth);
    if (LeadWidth > TextIndent) and (I < Length(Cells)) then
    begin
      Cells[I].Character := TScreenCharacter.Create(' ');
      ApplyAction(Action, Cells[I].Attribute);
      Inc(I);
    end;
  end;
  while DrawOneT(Cells, I, Text, J, Action) do
    ;
  Result := I - Indent;
end;

function DrawStrExT(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
  TextIndent: Integer; const Action: TAttrAction): SizeInt; overload;
var
  I, J, LeadWidth: SizeInt;
begin
  I := Indent;
  J := 0;
  if TextIndent > 0 then
  begin
    LeadWidth := 0;
    TText.Scroll(Text, TextIndent, True, J, LeadWidth);
    if (LeadWidth > TextIndent) and (I < Length(Cells)) then
    begin
      Cells[I].Character := TScreenCharacter.Create(' ');
      ApplyAction(Action, Cells[I].Attribute);
      Inc(I);
    end;
  end;
  while DrawOneT(Cells, I, Text, J, Action) do
    ;
  Result := I - Indent;
end;

procedure FillCells(var Cells: array of TScreenCell; C: Char; const Action: TAttrAction);
var
  K: SizeInt;
begin
  for K := 0 to High(Cells) do
  begin
    Cells[K].Character := TScreenCharacter.Create(C);
    ApplyAction(Action, Cells[K].Attribute);
  end;
end;

{ TTextCells }

class procedure TTextCells.DrawChar(var Cells: array of TScreenCell; C: Char);
begin
  FillCells(Cells, C, KeepAttr);
end;

class procedure TTextCells.DrawChar(var Cells: array of TScreenCell; C: Char; Attr: TColorAttr);
var
  ACell: TScreenCell;
  K: SizeInt;
begin
  ACell := TScreenCell.Create(TScreenCharacter.Create(C), Attr);
  for K := 0 to High(Cells) do
    Cells[K] := ACell;
end;

class procedure TTextCells.DrawCharEx(var Cells: array of TScreenCell; C: Char; Transform: TTransformAttr);
begin
  FillCells(Cells, C, CallAttr(Transform));
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; const Text: string): SizeInt;
begin
  Result := DrawStr(Cells, 0, Text, 0);
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; const Text: string; Attr: TColorAttr): SizeInt;
begin
  Result := DrawStr(Cells, 0, Text, 0, Attr);
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
  TextIndent: Integer): SizeInt;
begin
  Result := DrawStrExT(Cells, Indent, Text, TextIndent, KeepAttr);
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
  TextIndent: Integer): SizeInt;
begin
  Result := DrawStrExT(Cells, Indent, Text, TextIndent, KeepAttr);
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
  TextIndent: Integer; Attr: TColorAttr): SizeInt;
begin
  Result := DrawStrExT(Cells, Indent, Text, TextIndent, SetAttr(Attr));
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
  TextIndent: Integer; Attr: TColorAttr): SizeInt;
begin
  Result := DrawStrExT(Cells, Indent, Text, TextIndent, SetAttr(Attr));
end;

class function TTextCells.DrawStrEx(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
  TextIndent: Integer; Transform: TTransformAttr): SizeInt;
begin
  Result := DrawStrExT(Cells, Indent, Text, TextIndent, CallAttr(Transform));
end;

class function TTextCells.DrawStrEx(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
  TextIndent: Integer; Transform: TTransformAttr): SizeInt;
begin
  Result := DrawStrExT(Cells, Indent, Text, TextIndent, CallAttr(Transform));
end;

class function TTextCells.DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: string;
  var J: SizeInt): Boolean;
begin
  Result := DrawOneT(Cells, I, Text, J, KeepAttr);
end;

class function TTextCells.DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: array of Cardinal;
  var J: SizeInt): Boolean;
begin
  Result := DrawOneT(Cells, I, Text, J, KeepAttr);
end;

class function TTextCells.DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: string;
  var J: SizeInt; Attr: TColorAttr): Boolean;
begin
  Result := DrawOneT(Cells, I, Text, J, SetAttr(Attr));
end;

class function TTextCells.DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: array of Cardinal;
  var J: SizeInt; Attr: TColorAttr): Boolean;
begin
  Result := DrawOneT(Cells, I, Text, J, SetAttr(Attr));
end;

initialization
  CodePageToPackedUtf8 := @PlainPackedUtf8;

end.
