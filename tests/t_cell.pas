{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/scrncell.h
  See COPYRIGHT.magiblot. }
program t_cell;

{$mode objfpc}
{$modeswitch advancedrecords}

uses
  TvColors, TvCell;

{$I testlib.inc}

function Zeroed: TScreenCharacter;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

procedure TestSizes;
begin
  Check(SizeOf(TScreenCharacter) = 16, 'size of a character');
  Check(SizeOf(TScreenCell) = 16 + SizeOf(TColorAttr), 'size of a cell');
end;

procedure TestZeroed;
var
  Ch: TScreenCharacter;
  Cell: TScreenCell;
begin
  Ch := Zeroed;
  Check(not Ch.IsWide, 'zeroed is not wide');
  Check(not Ch.IsWideCharTrail, 'zeroed is not a trail');
  Check(Ch.GetText = #0, 'zeroed holds one null byte');
  FillChar(Cell, SizeOf(Cell), 0);
  Check(Cell.Character.GetText = #0, 'zeroed cell text');
end;

procedure TestSingle;
var
  Ch: TScreenCharacter;
begin
  Ch := TScreenCharacter.Create('A');
  Check(Ch.GetText = 'A', 'constructor text');
  Check(not Ch.IsWide, 'constructor not wide');
  Check(not Ch.IsWideCharTrail, 'constructor not trail');
  Ch.InitWithChar(#200);
  Check(Ch.GetText = #200, 'init with an extended character');
  Ch.InitWithChar(#0);
  Check(Length(Ch.GetText) = 1, 'a null byte has length one');
  Check(Ch.GetText = #0, 'a null byte is kept');
end;

procedure TestMultiByteCardinal;
var
  Ch: TScreenCharacter;
begin
  { U+00E9 as the bytes C3 A9, packed with the first byte lowest. }
  Ch.InitWithMultiByteChar($A9C3);
  Check(Ch.GetText = #$C3#$A9, 'two bytes');
  Check(not Ch.IsWide, 'two bytes not wide by default');
  Ch.InitWithMultiByteChar($A9C3, True);
  Check(Ch.IsWide, 'two bytes wide');
  Check(not Ch.IsWideCharTrail, 'wide is not a trail');
  { U+4E2D as E4 B8 AD. }
  Ch.InitWithMultiByteChar($ADB8E4, True);
  Check(Ch.GetText = #$E4#$B8#$AD, 'three bytes');
  Check(Ch.IsWide, 'three bytes wide');
  { U+1F600 as F0 9F 98 80. }
  Ch.InitWithMultiByteChar($80989FF0, True);
  Check(Ch.GetText = #$F0#$9F#$98#$80, 'four bytes');
  Ch.InitWithMultiByteChar($41);
  Check(Ch.GetText = 'A', 'one byte');
  Ch.InitWithMultiByteChar(0);
  Check(Ch.GetText = #0, 'value zero is one null byte');
  Ch.InitWithMultiByteChar($100);
  Check(Length(Ch.GetText) = 2, 'a value above $FF has two bytes');
  Ch.InitWithMultiByteChar($10000);
  Check(Length(Ch.GetText) = 3, 'a value above $FFFF has three bytes');
  Ch.InitWithMultiByteChar($1000000);
  Check(Length(Ch.GetText) = 4, 'a value above $FFFFFF has four bytes');
end;

procedure TestMultiByteString;
var
  Ch: TScreenCharacter;
begin
  Ch.InitWithMultiByteChar(#$C3#$A9);
  Check(Ch.GetText = #$C3#$A9, 'string text');
  Check(not Ch.IsWide, 'string not wide');
  Ch.InitWithMultiByteChar(#$E4#$B8#$AD, True);
  Check(Ch.GetText = #$E4#$B8#$AD, 'wide string text');
  Check(Ch.IsWide, 'wide string is wide');
  Ch.InitWithMultiByteChar(#$F0#$9F#$98#$80, True);
  Check(Ch.GetText = #$F0#$9F#$98#$80, 'four byte string');
  Ch.InitWithMultiByteChar('x', True);
  Check(Ch.GetText = 'x', 'one byte string');
  Check(Ch.IsWide, 'one byte string can be marked wide');
  { An empty string and a string longer than a character give an empty cell. }
  Ch.InitWithMultiByteChar('', True);
  Check(Ch.GetText = #0, 'empty string gives the empty cell');
  Check(not Ch.IsWide, 'empty string is not wide');
  Ch.InitWithMultiByteChar('abcde', True);
  Check(Ch.GetText = #0, 'a string of five bytes gives the empty cell');
  Check(not Ch.IsWide, 'a string of five bytes is not wide');
end;

procedure TestTrail;
var
  Ch: TScreenCharacter;
begin
  Ch.InitWithMultiByteChar(#$E4#$B8#$AD, True);
  Ch.InitAsWideCharTrail;
  Check(Ch.IsWideCharTrail, 'trail');
  Check(not Ch.IsWide, 'trail is not wide');
  Ch.InitWithChar('a');
  Check(not Ch.IsWideCharTrail, 'init clears the trail');
end;

procedure TestAppend;
var
  Ch: TScreenCharacter;
  I: Integer;
begin
  Ch := TScreenCharacter.Create('e');
  Ch.AppendZeroWidthChar(#$CC#$81);
  Check(Ch.GetText = 'e'#$CC#$81, 'combining accent appended');
  Ch.AppendZeroWidthChar(#$CC#$82);
  Check(Ch.GetText = 'e'#$CC#$81#$CC#$82, 'a second one appended');
  Check(not Ch.IsWide, 'append keeps the width flag');

  Ch := Zeroed;
  Ch.AppendZeroWidthChar(#$CC#$81);
  Check(Ch.GetText = ' '#$CC#$81, 'a null first byte becomes a space');

  Ch.InitWithMultiByteChar(#$E4#$B8#$AD, True);
  Ch.AppendZeroWidthChar(#$CC#$81);
  Check(Ch.IsWide, 'append keeps wide');
  Check(Ch.GetText = #$E4#$B8#$AD#$CC#$81, 'wide with accent');

  { Fills the 15 bytes, then overflows and ignores later additions. }
  Ch := TScreenCharacter.Create('a');
  for I := 1 to 7 do
    Ch.AppendZeroWidthChar(#$CC#$81);
  Check(Length(Ch.GetText) = 15, 'fifteen bytes held');
  Ch.AppendZeroWidthChar(#$CC#$81);
  Check(Length(Ch.GetText) = 15, 'overflow leaves the text');
  Ch.AppendZeroWidthChar('');
  Check(Length(Ch.GetText) = 15, 'overflow stays after an empty append');

  { A refused append sets the overflow so that a smaller one is refused too. }
  Ch := TScreenCharacter.Create('a');
  for I := 1 to 6 do
    Ch.AppendZeroWidthChar(#$CC#$81);
  Check(Length(Ch.GetText) = 13, 'thirteen bytes held');
  Ch.AppendZeroWidthChar(#$CC#$81#$CC);
  Check(Length(Ch.GetText) = 13, 'three bytes do not fit');
  Ch.AppendZeroWidthChar(#$CC);
  Check(Length(Ch.GetText) = 13, 'one byte is refused after overflow');
  Ch.InitWithChar('a');
  Ch.AppendZeroWidthChar(#$CC);
  Check(Length(Ch.GetText) = 2, 'init clears the overflow');
end;

procedure TestCellCompare;
var
  A, B: TScreenCell;
  Ch: TScreenCharacter;
begin
  Ch := TScreenCharacter.Create('x');
  A := TScreenCell.Create(Ch, TColorAttr.Create(Integer($1F)));
  B := TScreenCell.Create(Ch, TColorAttr.Create(Integer($1F)));
  Check(A = B, 'equal cells');
  Check(not (A <> B), 'equal cells are not different');
  B := TScreenCell.Create(Ch, TColorAttr.Create(Integer($1E)));
  Check(A <> B, 'different attributes');
  Check(not (A = B), 'different attributes are not equal');
  B := TScreenCell.Create(TScreenCharacter.Create('y'), TColorAttr.Create(Integer($1F)));
  Check(A <> B, 'different characters');
  Ch.InitWithMultiByteChar(#$E4#$B8#$AD, True);
  A := TScreenCell.Create(Ch, TColorAttr.Create(Integer($1F)));
  Ch.InitWithMultiByteChar(#$E4#$B8#$AD, False);
  B := TScreenCell.Create(Ch, TColorAttr.Create(Integer($1F)));
  Check(A <> B, 'different width flags');
  Ch.InitAsWideCharTrail;
  B := TScreenCell.Create(Ch, TColorAttr.Create(Integer($1F)));
  Check(A <> B, 'a trail differs from a wide character');
end;

procedure TestBios;
var
  Cell: TScreenCell;
begin
  Cell := TScreenCell.Create(Word($1F41));
  Check(Cell.Character.GetText = 'A', 'bios character');
  Check(not Cell.Character.IsWide, 'bios character is not wide');
  Check(Cell.Attribute = TColorAttr.Create(Integer($1F)), 'bios attribute');
  Check(Cell.Attribute = $1F, 'bios attribute against an integer');
  Cell := TScreenCell.Create(Word($0720));
  Check(Cell.Character.GetText = ' ', 'bios space');
  Check(Cell.Attribute = $07, 'bios attribute 7');
  Cell := TScreenCell.Create(Word($70DB));
  Check(Cell.Character.GetText = #$DB, 'bios extended character');
  Check(Cell.Attribute = $70, 'bios attribute $70');
  Check(Cell = TScreenCell.Create(TScreenCharacter.Create(#$DB), TColorAttr.Create(Integer($70))), 'bios equals parts');
end;

begin
  TestSizes;
  TestZeroed;
  TestSingle;
  TestMultiByteCardinal;
  TestMultiByteString;
  TestTrail;
  TestAppend;
  TestCellCompare;
  TestBios;
  Done;
end.
