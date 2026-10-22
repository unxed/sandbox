{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/ttext.h, source/platform/ttext.cpp, include/tvision/scrncell.h
  See COPYRIGHT.magiblot. }
program t_text;

{$mode objfpc}
{$modeswitch advancedrecords}

uses
  TvColors, TvCell, TvUtf8, TvText;

{$I testlib.inc}

const
  Cjk = #$E4#$B8#$AD; { U+4E2D, two columns wide. }
  Acute = #$CC#$81; { U+0301, zero columns wide. }
  Joiner = #$E2#$80#$8D; { U+200D, zero columns wide. }
  C1Control = #$C2#$85; { U+0085, a control character of two bytes. }
  Euro = #$E2#$82#$AC; { U+20AC, one column wide. }
  Replacement = #$EF#$BF#$BD;
  Smiley = #$E2#$98#$BA; { U+263A. }

var
  A1, A2, Plain: TColorAttr;
  Calls: Integer = 0;

procedure Clear(var Cells: array of TScreenCell);
begin
  if Length(Cells) > 0 then
    FillChar(Cells[0], Length(Cells) * SizeOf(TScreenCell), 0);
end;

function Txt(const Cell: TScreenCell): string;
begin
  Result := Cell.Character.GetText;
end;

procedure Bump(var Attr: TColorAttr);
begin
  Inc(Calls);
  Attr := A2;
end;

function Mapped(C: Char): Cardinal;
begin
  if C = #1 then
    Result := $BA98E2
  else
    Result := Byte(C);
end;

procedure TestDrawChar;
var
  Cells: array[0..4] of TScreenCell;
  None: array of TScreenCell;
  I: Integer;
  Same: Boolean;
begin
  Clear(Cells);
  TTextCells.DrawChar(Cells, 'x');
  Same := True;
  for I := 0 to 4 do
    if (Txt(Cells[I]) <> 'x') or (Cells[I].Attribute <> Plain) then
      Same := False;
  Check(Same, 'a character fills the span and keeps the attributes');

  TTextCells.DrawChar(Cells, 'y', A1);
  Same := True;
  for I := 0 to 4 do
    if (Txt(Cells[I]) <> 'y') or (Cells[I].Attribute <> A1) or Cells[I].Character.IsWide then
      Same := False;
  Check(Same, 'a character with an attribute fills the span');

  Clear(Cells);
  Cells[1].Character.InitWithMultiByteChar(Cjk, True);
  Cells[2].Character.InitAsWideCharTrail;
  TTextCells.DrawChar(Cells, 'z');
  Check(not Cells[1].Character.IsWide and not Cells[2].Character.IsWideCharTrail, 'the flags are replaced');

  Calls := 0;
  Clear(Cells);
  TTextCells.DrawCharEx(Cells, 'q', @Bump);
  Check(Calls = 5, 'the callback is called for each cell');
  Check((Txt(Cells[0]) = 'q') and (Txt(Cells[4]) = 'q') and (Cells[3].Attribute = A2), 'the callback sets the attribute');

  SetLength(None, 0);
  TTextCells.DrawChar(None, 'a');
  TTextCells.DrawChar(None, 'a', A1);
  Check(True, 'an empty span is accepted');
end;

procedure TestDrawStrAscii;
var
  Cells: array[0..7] of TScreenCell;
  Small: array[0..2] of TScreenCell;
  N: SizeInt;
begin
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 'abc');
  Check(N = 3, 'ascii: the count of cells');
  Check((Txt(Cells[0]) = 'a') and (Txt(Cells[1]) = 'b') and (Txt(Cells[2]) = 'c'), 'ascii: the texts');
  Check((Txt(Cells[3]) = #0) and (Cells[0].Attribute = Plain), 'ascii: the rest and the attributes are untouched');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 'abc', A1);
  Check(N = 3, 'ascii with an attribute: the count of cells');
  Check((Cells[0].Attribute = A1) and (Cells[2].Attribute = A1) and (Cells[3].Attribute = Plain),
    'ascii with an attribute: the attributes');

  Clear(Small);
  N := TTextCells.DrawStr(Small, 'abcdef');
  Check((N = 3) and (Txt(Small[2]) = 'c'), 'a text longer than the span is cut');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 2, 'xy', 0);
  Check(N = 2, 'indent: the count of cells');
  Check((Txt(Cells[0]) = #0) and (Txt(Cells[1]) = #0) and (Txt(Cells[2]) = 'x') and (Txt(Cells[3]) = 'y'),
    'indent: the texts');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 7, 'xy', 0);
  Check((N = 1) and (Txt(Cells[7]) = 'x'), 'indent near the end');
  N := TTextCells.DrawStr(Cells, 8, 'xy', 0);
  Check(N = 0, 'indent at the end');
  N := TTextCells.DrawStr(Cells, 20, 'xy', 0);
  Check(N = 0, 'indent beyond the end');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 0, 'abcdef', 2);
  Check((N = 4) and (Txt(Cells[0]) = 'c') and (Txt(Cells[3]) = 'f'), 'text indent');
  N := TTextCells.DrawStr(Cells, 0, 'ab', 5);
  Check(N = 0, 'text indent beyond the text');
  N := TTextCells.DrawStr(Cells, 0, '', 0);
  Check(N = 0, 'an empty text');
  N := TTextCells.DrawStr(Cells, 1, 'abcd', 1, A2);
  Check((N = 3) and (Txt(Cells[1]) = 'b') and (Cells[3].Attribute = A2) and (Cells[4].Attribute = Plain),
    'indent, text indent and attribute');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, Euro + 'a');
  Check((N = 2) and (Txt(Cells[0]) = Euro) and not Cells[0].Character.IsWide, 'a character of width one');
end;

procedure TestControl;
var
  Cells: array[0..7] of TScreenCell;
  Saved: TPackedUtf8Func;
  N: SizeInt;
begin
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, #1'A'#$7F#$FF#0);
  Check(N = 5, 'control characters take one cell each');
  Check((Txt(Cells[0]) = #1) and (Txt(Cells[1]) = 'A') and (Txt(Cells[2]) = #$7F) and (Txt(Cells[3]) = #$FF) and
    (Txt(Cells[4]) = #0), 'control characters are kept by default');

  Saved := CodePageToPackedUtf8;
  CodePageToPackedUtf8 := @Mapped;
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, #1'A'#2);
  CodePageToPackedUtf8 := Saved;
  Check(N = 3, 'converted control characters take one cell each');
  Check((Txt(Cells[0]) = Smiley) and (Txt(Cells[1]) = 'A') and (Txt(Cells[2]) = #2), 'control characters are converted');
  Check(not Cells[0].Character.IsWide, 'a converted character is not wide');

  { A combining character can be appended to a converted control character. }
  CodePageToPackedUtf8 := @Mapped;
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, #1 + Acute);
  CodePageToPackedUtf8 := Saved;
  Check((N = 1) and (Txt(Cells[0]) = Smiley + Acute), 'a combining character after a control character');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, C1Control + 'a');
  Check((N = 2) and (Txt(Cells[0]) = Replacement) and (Txt(Cells[1]) = 'a'), 'a control character of two bytes');
end;

procedure TestWide;
var
  Cells: array[0..5] of TScreenCell;
  Small: array[0..2] of TScreenCell;
  One: array[0..0] of TScreenCell;
  Two: array[0..1] of TScreenCell;
  N: SizeInt;
begin
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 'a' + Cjk + 'b');
  Check(N = 4, 'wide: the count of cells');
  Check(Txt(Cells[0]) = 'a', 'wide: the character before');
  Check((Txt(Cells[1]) = Cjk) and Cells[1].Character.IsWide and not Cells[1].Character.IsWideCharTrail,
    'wide: the head');
  Check(Cells[2].Character.IsWideCharTrail and not Cells[2].Character.IsWide, 'wide: the trail');
  Check(Txt(Cells[3]) = 'b', 'wide: the character after');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 'a' + Cjk + 'b', A1);
  Check((N = 4) and (Cells[0].Attribute = A1) and (Cells[1].Attribute = A1) and (Cells[2].Attribute = A1) and
    (Cells[3].Attribute = A1) and (Cells[4].Attribute = Plain), 'wide: the attribute covers the trail');

  Clear(Small);
  N := TTextCells.DrawStr(Small, 'ab' + Cjk);
  Check(N = 3, 'a wide character that does not fit: the count of cells');
  Check((Txt(Small[2]) = Cjk) and Small[2].Character.IsWide and not Small[2].Character.IsWideCharTrail,
    'a wide character that does not fit is drawn without a trail');

  Clear(One);
  N := TTextCells.DrawStr(One, Cjk);
  Check((N = 1) and (Txt(One[0]) = Cjk), 'a wide character in a span of one cell');

  Clear(Two);
  N := TTextCells.DrawStr(Two, Cjk + Cjk);
  Check(N = 2, 'a wide character fills two cells and the next is not drawn');
  Check(Two[1].Character.IsWideCharTrail, 'the trail of the wide character at the start');

  { Text indent in the middle of a wide character: a whitespace takes its place. }
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 0, 'a' + Cjk + 'b', 2);
  Check((N = 2) and (Txt(Cells[0]) = ' ') and (Txt(Cells[1]) = 'b'), 'text indent inside a wide character');
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 0, 'a' + Cjk + 'b', 2, A1);
  Check((Cells[0].Attribute = A1) and (Cells[1].Attribute = A1) and (Cells[2].Attribute = Plain),
    'the whitespace takes the attribute');
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 0, 'a' + Cjk + 'b', 1);
  Check((N = 3) and (Txt(Cells[0]) = Cjk) and Cells[1].Character.IsWideCharTrail and (Txt(Cells[2]) = 'b'),
    'text indent before a wide character');
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 0, 'a' + Cjk + 'b', 3);
  Check((N = 1) and (Txt(Cells[0]) = 'b'), 'text indent after a wide character');
  Clear(Small);
  N := TTextCells.DrawStr(Small, 2, 'a' + Cjk + 'b', 2);
  Check((N = 1) and (Txt(Small[2]) = ' '), 'the whitespace needs a cell');
  Clear(Small);
  N := TTextCells.DrawStr(Small, 3, 'a' + Cjk + 'b', 2);
  Check(N = 0, 'no whitespace when the indent is at the end');
end;

procedure TestCombining;
var
  Cells: array[0..5] of TScreenCell;
  N: SizeInt;
begin
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 'e' + Acute + 'x');
  Check(N = 2, 'combining: the count of cells');
  Check(Txt(Cells[0]) = 'e' + Acute, 'combining: appended to the previous cell');
  Check(Txt(Cells[1]) = 'x', 'combining: the next cell');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 'e' + Acute + Acute);
  Check((N = 1) and (Txt(Cells[0]) = 'e' + Acute + Acute), 'combining: two in a row');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, Acute + 'a');
  Check((N = 1) and (Txt(Cells[0]) = 'a'), 'combining: nothing to append to at the start');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, Cjk + Acute);
  Check(N = 2, 'combining after a wide character: the count of cells');
  Check((Txt(Cells[0]) = Cjk + Acute) and Cells[0].Character.IsWide, 'combining after a wide character: the head');
  Check(Cells[1].Character.IsWideCharTrail, 'combining after a wide character: the trail stays');

  Clear(Cells);
  TTextCells.DrawChar(Cells, 'z', A1);
  N := TTextCells.DrawStr(Cells, 1, Acute + 'b', 0, A2);
  Check(N = 1, 'combining at the indent: the count of cells');
  Check(Txt(Cells[0]) = 'z' + Acute, 'combining at the indent: appended before the indent');
  Check((Cells[0].Attribute = A1) and (Cells[1].Attribute = A2), 'combining at the indent: attributes');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 'a' + Joiner + 'b');
  Check((N = 2) and (Txt(Cells[0]) = 'a') and (Txt(Cells[1]) = 'b'), 'a zero width joiner is not drawn');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 'e' + Acute, A1);
  Check((N = 1) and (Cells[0].Attribute = A1) and (Cells[1].Attribute = Plain), 'combining: the attribute');
end;

procedure TestDrawOne;
var
  Cells: array[0..3] of TScreenCell;
  One: array[0..0] of TScreenCell;
  I, J: SizeInt;
  R: Boolean;
begin
  Clear(Cells);
  I := 0;
  J := 0;
  R := TTextCells.DrawOne(Cells, I, 'ab', J);
  Check(R and (I = 1) and (J = 1) and (Txt(Cells[0]) = 'a'), 'one: the first character');
  R := TTextCells.DrawOne(Cells, I, 'ab', J);
  Check(R and (I = 2) and (J = 2) and (Txt(Cells[1]) = 'b'), 'one: the second character');
  R := TTextCells.DrawOne(Cells, I, 'ab', J);
  Check((not R) and (I = 2) and (J = 2), 'one: the end of the text');

  Clear(One);
  I := 0;
  J := 0;
  R := TTextCells.DrawOne(One, I, 'ab', J);
  Check(R and (I = 1) and (J = 1), 'one: the last cell');
  R := TTextCells.DrawOne(One, I, 'ab', J);
  Check((not R) and (I = 1) and (J = 1), 'one: the end of the span');

  Clear(Cells);
  I := 0;
  J := 0;
  R := TTextCells.DrawOne(Cells, I, Cjk + 'x', J, A1);
  Check(R and (I = 2) and (J = 3), 'one: a wide character moves both indices');
  Check((Cells[0].Attribute = A1) and (Cells[1].Attribute = A1) and (Cells[2].Attribute = Plain),
    'one: the attribute of a wide character');
  R := TTextCells.DrawOne(Cells, I, Cjk + 'x', J, A2);
  Check(R and (I = 3) and (J = 4) and (Txt(Cells[2]) = 'x') and (Cells[2].Attribute = A2), 'one: the next character');

  Clear(Cells);
  I := 0;
  J := 0;
  TTextCells.DrawOne(Cells, I, 'e', J, A1);
  J := 0;
  R := TTextCells.DrawOne(Cells, I, Acute, J, A2);
  Check(R and (I = 1) and (J = 2), 'one: a combining character does not move the cell index');
  J := 0;
  R := TTextCells.DrawOne(Cells, I, Acute, J, A2);
  Check(R and (I = 1) and (J = 2) and (Txt(Cells[0]) = 'e' + Acute + Acute), 'one: appended twice');
  Check((Cells[0].Attribute = A1) and (Cells[1].Attribute = Plain), 'one: the attribute is not set');

  Clear(Cells);
  I := 0;
  J := 0;
  R := TTextCells.DrawOne(Cells, I, '', J);
  Check((not R) and (I = 0) and (J = 0), 'one: an empty text');
end;

procedure TestDrawStrEx;
var
  Cells: array[0..5] of TScreenCell;
  N: SizeInt;
begin
  Calls := 0;
  Clear(Cells);
  N := TTextCells.DrawStrEx(Cells, 0, 'a' + Cjk, 0, @Bump);
  Check((N = 3) and (Calls = 3), 'ex: one call for each cell, the trail included');
  Check((Cells[0].Attribute = A2) and (Cells[2].Attribute = A2) and (Cells[3].Attribute = Plain), 'ex: the attributes');

  Calls := 0;
  Clear(Cells);
  N := TTextCells.DrawStrEx(Cells, 0, 'e' + Acute, 0, @Bump);
  Check((N = 1) and (Calls = 1), 'ex: no call for a combining character');

  Calls := 0;
  Clear(Cells);
  N := TTextCells.DrawStrEx(Cells, 0, 'a' + Cjk + 'b', 2, @Bump);
  Check((N = 2) and (Calls = 2) and (Txt(Cells[0]) = ' '), 'ex: a call for the whitespace');
end;

procedure TestUtf32;
var
  Cells: array[0..5] of TScreenCell;
  Small: array[0..1] of TScreenCell;
  N: SizeInt;
  I, J: SizeInt;
  R: Boolean;
begin
  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 0, [$61, $4E2D, $62], 0);
  Check(N = 4, 'utf32: the count of cells');
  Check((Txt(Cells[0]) = 'a') and (Txt(Cells[1]) = Cjk) and Cells[1].Character.IsWide and
    Cells[2].Character.IsWideCharTrail and (Txt(Cells[3]) = 'b'), 'utf32: the cells');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 1, [$61, $4E2D], 0, A1);
  Check((N = 3) and (Cells[0].Attribute = Plain) and (Cells[1].Attribute = A1) and (Cells[3].Attribute = A1),
    'utf32 with an attribute and an indent');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 0, [$65, $301, $78], 0);
  Check((N = 2) and (Txt(Cells[0]) = 'e' + Acute) and (Txt(Cells[1]) = 'x'), 'utf32: combining');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 0, [$61, $200D, $62], 0);
  Check((N = 2) and (Txt(Cells[0]) = 'a') and (Txt(Cells[1]) = 'b'), 'utf32: zero width joiner');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 0, [$41, $0A, $85, $20AC], 0);
  Check(N = 4, 'utf32: control characters take one cell each');
  Check((Txt(Cells[1]) = Replacement) and (Txt(Cells[2]) = Replacement) and (Txt(Cells[3]) = Euro),
    'utf32: control characters are replaced');

  Clear(Cells);
  N := TTextCells.DrawStr(Cells, 0, [$61, $4E2D, $62], 2);
  Check((N = 2) and (Txt(Cells[0]) = ' ') and (Txt(Cells[1]) = 'b'), 'utf32: text indent inside a wide character');

  Clear(Small);
  N := TTextCells.DrawStr(Small, 0, [$62, $4E2D], 0);
  Check((N = 2) and (Txt(Small[1]) = Cjk) and not Small[1].Character.IsWideCharTrail, 'utf32: a wide character that does not fit');

  Calls := 0;
  Clear(Cells);
  N := TTextCells.DrawStrEx(Cells, 0, [$61, $4E2D, $301], 0, @Bump);
  Check((N = 3) and (Calls = 3) and (Txt(Cells[1]) = Cjk + Acute), 'utf32: ex');

  Clear(Cells);
  I := 0;
  J := 0;
  R := TTextCells.DrawOne(Cells, I, [$4E2D, $301], J);
  Check(R and (I = 2) and (J = 1), 'utf32 one: a wide character');
  R := TTextCells.DrawOne(Cells, I, [$4E2D, $301], J, A1);
  Check(R and (I = 2) and (J = 2) and (Txt(Cells[0]) = Cjk + Acute), 'utf32 one: a combining character');
  R := TTextCells.DrawOne(Cells, I, [$4E2D, $301], J, A1);
  Check((not R) and (J = 2), 'utf32 one: the end of the text');
end;

begin
  A1 := TColorAttr.Create(Integer($1F));
  A2 := TColorAttr.Create(Integer($2E));
  FillChar(Plain, SizeOf(Plain), 0);
  TestDrawChar;
  TestDrawStrAscii;
  TestControl;
  TestWide;
  TestCombining;
  TestDrawOne;
  TestDrawStrEx;
  TestUtf32;
  Done;
end.
