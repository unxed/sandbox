{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/internal/ansiwrit.h, source/platform/ansiwrit.cpp
  See COPYRIGHT.magiblot. }
program t_ansi;

{$mode objfpc}
{$modeswitch advancedrecords}
{$H+}

uses
  TvGeom, TvColors, TvAnsi;

{$I testlib.inc}

const
  E = #27'[';
  Wide = #$E4#$B8#$AD;

function Bios(N: Byte): TColor;
begin
  Result := TColor.Create(TColorBIOS.Create(N));
end;

function XT(N: Byte): TColor;
begin
  Result := TColor.Create(TColorXTerm.Create(N));
end;

function Rgb(R, G, B: Byte): TColor;
begin
  Result := TColor.Create(TColorRGB.Create(R, G, B));
end;

function Def: TColor;
var
  D: TColorDefault;
begin
  Result := TColor.Create(D);
end;

function Attr(Fg, Bg: TColor; Style: Word = 0): TColorAttr;
begin
  Result := TColorAttr.Create(Fg, Bg, Style);
end;

function Pt(X, Y: Integer): TPoint;
begin
  Result.X := X;
  Result.Y := Y;
end;

function Cap(Colors: TTermCapColors; Quirks: Word = 0): TTermCap;
begin
  Result.Colors := Colors;
  Result.Quirks := Quirks;
end;

{ The bytes that a new writer produces for one cell. }
function One(const Cp: TTermCap; const A: TColorAttr; const Text: string = 'X'): string;
var
  W: TAnsiScreenWriter;
begin
  W := TAnsiScreenWriter.Create(Cp);
  try
    W.WriteCell(Pt(0, 0), Text, A, False);
    Result := W.Flush;
  finally
    W.Free;
  end;
end;

procedure TestTermColor;
var
  C, D: TTermColor;
begin
  C := TTermColor.Create(5, tctIndexed);
  D := TTermColor.Create(5, tctIndexed);
  Check(C.Kind = tctIndexed, 'indexed kind');
  Check(C.Idx = 5, 'indexed index');
  Check(C = D, 'equal colors');
  Check(not (C <> D), 'equal colors are not different');
  D := TTermColor.Create(6, tctIndexed);
  Check(C <> D, 'different indices');
  D := TTermColor.Create(5, tctRGB);
  Check(C <> D, 'different kinds');
  C := TTermColor.Create(TColorRGB.Create(1, 2, 3), tctRGB);
  Check((C.Bgr[0] = 3) and (C.Bgr[1] = 2) and (C.Bgr[2] = 1), 'rgb is stored blue first');
  Check(C.Idx = 0, 'rgb leaves the index at zero');
  D := TTermColor.Create(TColorRGB.Create(1, 2, 4), tctRGB);
  Check(C <> D, 'different rgb values');
  C := TTermColor.Create(tctDefault);
  FillChar(D, SizeOf(D), 0);
  Check(C = D, 'zeroed is the default color');
  C := TTermColor.Create(tctNoColor);
  Check(C <> D, 'no color is not the default');
end;

procedure TestBuffer;
var
  B: TAnsiBuffer;
  I: Integer;
begin
  FillChar(B, SizeOf(B), 0);
  Check(B.Size = 0, 'empty buffer');
  Check(B.Bytes = '', 'empty bytes');
  Check(not B.EndsWith(';'), 'empty buffer ends with nothing');
  B.PushDecimal(0);
  B.PushChar(',');
  B.PushDecimal(7);
  B.PushChar(',');
  B.PushDecimal(10);
  B.PushChar(',');
  B.PushDecimal(255);
  B.PushChar(',');
  B.PushDecimal(4294967295);
  Check(B.Bytes = '0,7,10,255,4294967295', 'decimal numbers');
  Check(B.Size = 21, 'size after numbers');
  B.Push('');
  Check(B.Size = 21, 'an empty string adds nothing');
  B.Push(';');
  Check(B.EndsWith(';'), 'ends with a semicolon');
  B.ReplaceLast('m');
  Check(B.EndsWith('m') and not B.EndsWith(';'), 'last byte replaced');
  B.DropLast(2);
  Check(B.Bytes = '0,7,10,255,429496729', 'last bytes dropped');
  B.Clear;
  Check((B.Size = 0) and (B.Bytes = ''), 'cleared');
  for I := 1 to 5000 do
    B.PushChar('z');
  Check(B.Size = 5000, 'size after growth');
  B.Push(Wide);
  Check(Length(B.Bytes) = 5003, 'bytes after growth');
  Check(Copy(B.Bytes, 4999, 5) = 'zz' + Wide, 'content after growth');
end;

procedure TestCursor;
var
  W: TAnsiScreenWriter;
begin
  W := TAnsiScreenWriter.Create(Cap(Direct));
  try
    W.SetCaretPosition(Pt(4, 2));
    Check(W.Flush = E + '3;5H', 'caret position is one-based, row first');
    Check(W.Flush = '', 'a flush empties the buffer');
    W.SetCaretPosition(Pt(0, 0));
    Check(W.Flush = E + '1;1H', 'caret at the origin');
    W.SetCaretPosition(Pt(99, 9));
    Check(W.Flush = E + '10;100H', 'caret with several digits');
    W.SetCaretPosition(Pt(0, 9999));
    Check(W.Flush = E + '10000;1H', 'caret far down');
    W.SetCaretPosition(Pt(-1, -1));
    Check(W.Flush = E + '0;0H', 'caret at an unknown position');
    W.SetCaretPosition(Pt(1, 1));
    W.SetCaretPosition(Pt(2, 3));
    Check(W.Flush = E + '2;2H' + E + '4;3H', 'two caret moves');
  finally
    W.Free;
  end;
end;

procedure TestResetClear;
var
  W: TAnsiScreenWriter;
begin
  W := TAnsiScreenWriter.Create(Cap(Indexed16));
  try
    W.Reset;
    Check(W.Flush = E + '0m', 'reset');
    W.ClearScreen;
    Check(W.Flush = E + '0m' + E + '2J', 'clear screen');
    W.Reset;
    W.ClearScreen;
    Check(W.Flush = E + '0m' + E + '0m' + E + '2J', 'reset and clear screen');
  finally
    W.Free;
  end;
end;

procedure TestCaretMoves;
var
  W: TAnsiScreenWriter;
  A: TColorAttr;
begin
  A := Attr(Def, Def);
  W := TAnsiScreenWriter.Create(Cap(Indexed16));
  try
    W.WriteCell(Pt(0, 0), 'A', A, False);
    Check(W.Flush = E + '1;1HA', 'first cell moves to the cell');
    W.WriteCell(Pt(1, 0), 'B', A, False);
    Check(W.Flush = 'B', 'the next cell needs no move');
    W.WriteCell(Pt(2, 0), 'C', A, False);
    W.WriteCell(Pt(3, 0), 'D', A, False);
    Check(W.Flush = 'CD', 'a run of cells');
    W.WriteCell(Pt(9, 0), 'E', A, False);
    Check(W.Flush = E + '10GE', 'a horizontal jump is a column move');
    W.WriteCell(Pt(3, 0), 'F', A, False);
    Check(W.Flush = E + '4GF', 'a jump back is a column move');
    W.WriteCell(Pt(4, 1), 'G', A, False);
    Check(W.Flush = E + '2;5HG', 'a change of row is a full move');
    W.WriteCell(Pt(0, 1), 'H', A, False);
    Check(W.Flush = E + '1GH', 'column move to the first column');
    W.WriteCell(Pt(1, 1), 'I', A, False);
    W.WriteCell(Pt(1, 2), 'J', A, False);
    Check(W.Flush = 'I' + E + '3;2HJ', 'a row move even in the same column');
    W.SetCaretPosition(Pt(7, 7));
    W.WriteCell(Pt(7, 7), 'K', A, False);
    Check(W.Flush = E + '8;8H' + 'K', 'a cell where the caret was placed needs no move');
    W.WriteCell(Pt(8, 7), 'L', A, False);
    Check(W.Flush = 'L', 'and the next one neither');
    W.Reset;
    W.WriteCell(Pt(9, 7), 'M', A, False);
    Check(W.Flush = E + '0m' + E + '8;10HM', 'after a reset the caret is unknown');
  finally
    W.Free;
  end;
end;

procedure TestWidth;
var
  W: TAnsiScreenWriter;
  A: TColorAttr;
begin
  A := Attr(Def, Def);
  W := TAnsiScreenWriter.Create(Cap(Direct));
  try
    W.WriteCell(Pt(0, 0), Wide, A, True);
    W.WriteCell(Pt(2, 0), 'a', A, False);
    Check(W.Flush = E + '1;1H' + Wide + 'a', 'a double-width cell advances two columns');
    W.WriteCell(Pt(3, 0), Wide, A, True);
    W.WriteCell(Pt(5, 0), Wide, A, True);
    Check(W.Flush = Wide + Wide, 'two wide cells in a row');
    W.WriteCell(Pt(8, 0), 'b', A, False);
    Check(W.Flush = E + '9Gb', 'the caret is after the wide cell');
    W.WriteCell(Pt(9, 0), Wide, A, True);
    W.WriteCell(Pt(10, 0), 'c', A, False);
    Check(W.Flush = Wide + E + '11Gc', 'a cell on the trail of a wide one is moved to');
    W.WriteCell(Pt(11, 0), 'd', A, False);
    W.WriteCell(Pt(12, 0), 'e', A, False);
    Check(W.Flush = 'de', 'single cells advance by one column');
  finally
    W.Free;
  end;
end;

procedure TestRepeat;
var
  W: TAnsiScreenWriter;
  A: TColorAttr;
  I: Integer;
  S: string;
begin
  A := Attr(Bios(4), Def);
  W := TAnsiScreenWriter.Create(Cap(Indexed16));
  try
    for I := 0 to 4 do
      W.WriteCell(Pt(I, 0), 'a', A, False);
    Check(W.Flush = E + '1;1H' + E + '31m' + 'aaaaa', 'the attribute is written once for a run');
    for I := 5 to 6 do
      W.WriteCell(Pt(I, 0), 'b', A, False);
    Check(W.Flush = 'bb', 'the state is kept after a flush');
    for I := 7 to 5006 do
      W.WriteCell(Pt(I, 0), 'x', A, False);
    S := W.Flush;
    Check(Length(S) = 5000, 'a long run');
    Check((S[1] = 'x') and (S[2500] = 'x') and (S[5000] = 'x'), 'a long run holds the characters');
    for I := 0 to 3 do
    begin
      W.WriteCell(Pt(5007 + I, 0), 'y', A, False);
      W.WriteCell(Pt(5007 + I, 1), 'z', A, False);
    end;
    S := W.Flush;
    Check(S = 'y' + E + '2;5008Hz' + E + '1;5009Hy' + E + '2;5009Hz' + E + '1;5010Hy' + E + '2;5010Hz' +
      E + '1;5011Hy' + E + '2;5011Hz', 'cells that alternate between rows');
  finally
    W.Free;
  end;
end;

procedure TestAttrState;
var
  W: TAnsiScreenWriter;
  Red, None: TColorAttr;
begin
  Red := Attr(Bios(4), Def);
  None := Attr(Def, Def);
  W := TAnsiScreenWriter.Create(Cap(Indexed16));
  try
    W.WriteCell(Pt(0, 0), 'a', Red, False);
    W.ClearScreen;
    W.WriteCell(Pt(1, 0), 'b', Red, False);
    Check(W.Flush = E + '1;1H' + E + '31m' + 'a' + E + '0m' + E + '2J' + E + '31m' + 'b',
      'a cleared screen writes the attribute again');
    W.Reset;
    W.WriteCell(Pt(2, 0), 'c', Red, False);
    Check(W.Flush = E + '0m' + E + '1;3H' + E + '31m' + 'c', 'a reset writes the attribute again');
    W.WriteCell(Pt(3, 0), 'd', None, False);
    Check(W.Flush = E + '39m' + 'd', 'back to the default foreground');
  finally
    W.Free;
  end;
end;

procedure TestSixteenColors;
begin
  Check(One(Cap(Indexed16), Attr(Bios(4), Def)) = E + '1;1H' + E + '31m' + 'X', 'bios red foreground');
  Check(One(Cap(Indexed16), Attr(Bios(1), Def)) = E + '1;1H' + E + '34m' + 'X', 'bios blue foreground');
  Check(One(Cap(Indexed16), Attr(Bios(0), Def)) = E + '1;1H' + E + '30m' + 'X', 'bios black foreground');
  Check(One(Cap(Indexed16), Attr(Bios(12), Def)) = E + '1;1H' + E + '91m' + 'X', 'bios bright red foreground');
  Check(One(Cap(Indexed16), Attr(Bios(15), Def)) = E + '1;1H' + E + '97m' + 'X', 'bios white foreground');
  Check(One(Cap(Indexed16), Attr(Def, Bios(1))) = E + '1;1H' + E + '44m' + 'X', 'bios blue background');
  Check(One(Cap(Indexed16), Attr(Def, Bios(9))) = E + '1;1H' + E + '104m' + 'X', 'bios bright blue background');
  Check(One(Cap(Indexed16), Attr(Def, Bios(6))) = E + '1;1H' + E + '43m' + 'X', 'bios brown background');
  Check(One(Cap(Indexed16), Attr(Bios(4), Bios(1))) = E + '1;1H' + E + '31;44m' + 'X', 'foreground and background');
  Check(One(Cap(Indexed16), Attr(Bios(14), Bios(11))) = E + '1;1H' + E + '93;106m' + 'X', 'bright pair');
  Check(One(Cap(Indexed16), Attr(Def, Def)) = E + '1;1H' + 'X', 'default colors write no sequence');
  Check(One(Cap(Indexed16), TColorAttr.Create(Integer($1F))) = E + '1;1H' + E + '97;44m' + 'X', 'bios attribute');
end;

procedure TestSixteenFromOthers;
begin
  Check(One(Cap(Indexed16), Attr(XT(9), Def)) = E + '1;1H' + E + '91m' + 'X', 'xterm 9');
  Check(One(Cap(Indexed16), Attr(XT(5), Def)) = E + '1;1H' + E + '35m' + 'X', 'xterm 5');
  Check(One(Cap(Indexed16), Attr(XT(16), Def)) = E + '1;1H' + E + '30m' + 'X', 'xterm 16, the black of the cube');
  Check(One(Cap(Indexed16), Attr(XT(231), Def)) = E + '1;1H' + E + '97m' + 'X', 'xterm 231, the white of the cube');
  Check(One(Cap(Indexed16), Attr(XT(196), Def)) = E + '1;1H' + E + '91m' + 'X', 'xterm 196, red');
  Check(One(Cap(Indexed16), Attr(XT(21), Def)) = E + '1;1H' + E + '94m' + 'X', 'xterm 21, blue');
  Check(One(Cap(Indexed16), Attr(Def, XT(196))) = E + '1;1H' + E + '101m' + 'X', 'xterm 196 background');
  Check(One(Cap(Indexed16), Attr(Rgb(255, 0, 0), Def)) = E + '1;1H' + E + '91m' + 'X', 'rgb red');
  Check(One(Cap(Indexed16), Attr(Rgb(0, 0, 0), Def)) = E + '1;1H' + E + '30m' + 'X', 'rgb black');
  Check(One(Cap(Indexed16), Attr(Rgb(255, 255, 255), Def)) = E + '1;1H' + E + '97m' + 'X', 'rgb white');
  Check(One(Cap(Indexed16), Attr(Def, Rgb(0, 0, 255))) = E + '1;1H' + E + '104m' + 'X', 'rgb blue background');
end;

procedure TestChanges;
var
  W: TAnsiScreenWriter;
begin
  W := TAnsiScreenWriter.Create(Cap(Indexed16));
  try
    W.WriteCell(Pt(0, 0), 'a', Attr(Bios(4), Bios(1)), False);
    W.WriteCell(Pt(1, 0), 'b', Attr(Bios(4), Bios(1)), False);
    W.WriteCell(Pt(2, 0), 'c', Attr(Bios(2), Bios(1)), False);
    W.WriteCell(Pt(3, 0), 'd', Attr(Bios(2), Bios(4)), False);
    W.WriteCell(Pt(4, 0), 'e', Attr(Def, Bios(4)), False);
    W.WriteCell(Pt(5, 0), 'f', Attr(Def, Def), False);
    W.WriteCell(Pt(6, 0), 'g', Attr(Bios(3), Bios(7)), False);
    Check(W.Flush = E + '1;1H' + E + '31;44m' + 'ab' + E + '32m' + 'c' + E + '41m' + 'd' + E + '39m' + 'e' +
      E + '49m' + 'f' + E + '36;47m' + 'g', 'only the changed colors are written');
  finally
    W.Free;
  end;
end;

procedure TestStyles;
const
  All = slBold or slItalic or slUnderline or slBlink or slReverse or slStrike;
var
  W: TAnsiScreenWriter;
begin
  Check(One(Cap(Indexed16), Attr(Def, Def, slBold)) = E + '1;1H' + E + '1m' + 'X', 'bold');
  Check(One(Cap(Indexed16), Attr(Def, Def, slItalic)) = E + '1;1H' + E + '3m' + 'X', 'italic');
  Check(One(Cap(Indexed16), Attr(Def, Def, slUnderline)) = E + '1;1H' + E + '4m' + 'X', 'underline');
  Check(One(Cap(Indexed16), Attr(Def, Def, slBlink)) = E + '1;1H' + E + '5m' + 'X', 'blink');
  Check(One(Cap(Indexed16), Attr(Def, Def, slReverse)) = E + '1;1H' + E + '7m' + 'X', 'reverse');
  Check(One(Cap(Indexed16), Attr(Def, Def, slStrike)) = E + '1;1H' + E + '9m' + 'X', 'strike');
  Check(One(Cap(Indexed16), Attr(Def, Def, All)) = E + '1;1H' + E + '1;3;4;5;7;9m' + 'X', 'all styles in order');
  Check(One(Cap(Indexed16), Attr(Bios(4), Def, slBold)) = E + '1;1H' + E + '1;31m' + 'X', 'style before color');
  W := TAnsiScreenWriter.Create(Cap(Indexed16));
  try
    W.WriteCell(Pt(0, 0), 'a', Attr(Def, Def, All), False);
    W.WriteCell(Pt(1, 0), 'b', Attr(Def, Def, All), False);
    W.WriteCell(Pt(2, 0), 'c', Attr(Def, Def, slBold or slStrike), False);
    W.WriteCell(Pt(3, 0), 'd', Attr(Def, Def, 0), False);
    Check(W.Flush = E + '1;1H' + E + '1;3;4;5;7;9m' + 'ab' + E + '23;24;25;27m' + 'c' + E + '22;29m' + 'd',
      'styles are switched on and off one by one');
  finally
    W.Free;
  end;
end;

procedure TestTwoFiftySix;
var
  W: TAnsiScreenWriter;
begin
  Check(One(Cap(Indexed256), Attr(XT(200), Def)) = E + '1;1H' + E + '38;5;200m' + 'X', 'xterm foreground');
  Check(One(Cap(Indexed256), Attr(Def, XT(34))) = E + '1;1H' + E + '48;5;34m' + 'X', 'xterm background');
  Check(One(Cap(Indexed256), Attr(XT(200), XT(34))) = E + '1;1H' + E + '38;5;200m' + E + '48;5;34m' + 'X',
    'xterm pair in separate sequences');
  Check(One(Cap(Indexed256), Attr(XT(200), Def, slBold)) = E + '1;1H' + E + '1m' + E + '38;5;200m' + 'X',
    'style apart from an xterm color');
  Check(One(Cap(Indexed256), Attr(XT(200), Bios(1))) = E + '1;1H' + E + '38;5;200m' + E + '44m' + 'X',
    'xterm foreground with a 16-color background');
  Check(One(Cap(Indexed256), Attr(Bios(4), XT(34))) = E + '1;1H' + E + '31m' + E + '48;5;34m' + 'X',
    '16-color foreground with an xterm background');
  Check(One(Cap(Indexed256), Attr(XT(5), Def)) = E + '1;1H' + E + '35m' + 'X', 'low xterm index');
  Check(One(Cap(Indexed256), Attr(XT(15), Def)) = E + '1;1H' + E + '97m' + 'X', 'xterm 15');
  Check(One(Cap(Indexed256), Attr(Bios(12), Def)) = E + '1;1H' + E + '91m' + 'X', 'bios color');
  Check(One(Cap(Indexed256), Attr(Rgb(255, 0, 0), Def)) = E + '1;1H' + E + '38;5;196m' + 'X', 'rgb red');
  Check(One(Cap(Indexed256), Attr(Rgb(0, 0, 0), Def)) = E + '1;1H' + E + '38;5;16m' + 'X', 'rgb black');
  Check(One(Cap(Indexed256), Attr(Rgb(255, 255, 255), Def)) = E + '1;1H' + E + '38;5;231m' + 'X', 'rgb white');
  Check(One(Cap(Indexed256), Attr(Rgb(128, 128, 128), Def)) = E + '1;1H' + E + '38;5;244m' + 'X', 'rgb gray');
  Check(One(Cap(Indexed256), Attr(Def, Def)) = E + '1;1H' + 'X', 'default colors');
  W := TAnsiScreenWriter.Create(Cap(Indexed256));
  try
    W.WriteCell(Pt(0, 0), 'a', Attr(XT(200), Def), False);
    W.WriteCell(Pt(1, 0), 'b', Attr(XT(200), Def), False);
    W.WriteCell(Pt(2, 0), 'c', Attr(XT(201), Def), False);
    W.WriteCell(Pt(3, 0), 'd', Attr(Def, Def), False);
    Check(W.Flush = E + '1;1H' + E + '38;5;200m' + 'ab' + E + '38;5;201m' + 'c' + E + '39m' + 'd',
      'an xterm color is written again only when it changes');
  finally
    W.Free;
  end;
end;

procedure TestDirect;
var
  W: TAnsiScreenWriter;
begin
  Check(One(Cap(Direct), Attr(Rgb(1, 2, 3), Def)) = E + '1;1H' + E + '38;2;1;2;3m' + 'X', 'rgb foreground');
  Check(One(Cap(Direct), Attr(Def, Rgb(255, 128, 0))) = E + '1;1H' + E + '48;2;255;128;0m' + 'X', 'rgb background');
  Check(One(Cap(Direct), Attr(Rgb(0, 0, 0), Def)) = E + '1;1H' + E + '38;2;0;0;0m' + 'X', 'rgb black');
  Check(One(Cap(Direct), Attr(Rgb(1, 2, 3), Rgb(255, 128, 0))) =
    E + '1;1H' + E + '38;2;1;2;3m' + E + '48;2;255;128;0m' + 'X', 'rgb pair in separate sequences');
  Check(One(Cap(Direct), Attr(Rgb(1, 2, 3), Def, slBold)) = E + '1;1H' + E + '1m' + E + '38;2;1;2;3m' + 'X',
    'style apart from an rgb color');
  Check(One(Cap(Direct), Attr(Bios(4), Rgb(9, 8, 7))) = E + '1;1H' + E + '31m' + E + '48;2;9;8;7m' + 'X',
    '16-color foreground with an rgb background');
  Check(One(Cap(Direct), Attr(XT(200), Def)) = E + '1;1H' + E + '38;5;200m' + 'X', 'xterm color');
  Check(One(Cap(Direct), Attr(Bios(9), Bios(2))) = E + '1;1H' + E + '94;42m' + 'X', 'bios colors');
  W := TAnsiScreenWriter.Create(Cap(Direct));
  try
    W.WriteCell(Pt(0, 0), 'a', Attr(Rgb(1, 2, 3), Def), False);
    W.WriteCell(Pt(1, 0), 'b', Attr(Rgb(1, 2, 3), Def), False);
    W.WriteCell(Pt(2, 0), 'c', Attr(Rgb(1, 2, 4), Def), False);
    W.WriteCell(Pt(3, 0), 'd', Attr(Def, Def), False);
    Check(W.Flush = E + '1;1H' + E + '38;2;1;2;3m' + 'ab' + E + '38;2;1;2;4m' + 'c' + E + '39m' + 'd',
      'an rgb color is written again only when it changes');
  finally
    W.Free;
  end;
end;

procedure TestEightColors;
const
  Bold = qfBoldIsBright;
  Blink = qfBlinkIsBright;
begin
  Check(One(Cap(Indexed8), Attr(Bios(12), Def)) = E + '1;1H' + E + '31m' + 'X', 'bright foreground without quirks');
  Check(One(Cap(Indexed8, Bold), Attr(Bios(12), Def)) = E + '1;1H' + E + '1;31m' + 'X', 'bright foreground is bold');
  Check(One(Cap(Indexed8, Blink), Attr(Bios(12), Def)) = E + '1;1H' + E + '31m' + 'X', 'blink does not brighten a foreground');
  Check(One(Cap(Indexed8), Attr(Def, Bios(9))) = E + '1;1H' + E + '44m' + 'X', 'bright background without quirks');
  Check(One(Cap(Indexed8, Blink), Attr(Def, Bios(9))) = E + '1;1H' + E + '5;44m' + 'X', 'bright background blinks');
  Check(One(Cap(Indexed8, Bold), Attr(Def, Bios(9))) = E + '1;1H' + E + '44m' + 'X', 'bold does not brighten a background');
  Check(One(Cap(Indexed8, Bold or Blink), Attr(Bios(12), Bios(9))) = E + '1;1H' + E + '1;5;31;44m' + 'X',
    'both quirks');
  Check(One(Cap(Indexed8, Bold or Blink), Attr(Bios(4), Bios(1))) = E + '1;1H' + E + '31;44m' + 'X',
    'dark colors take no quirk');
  Check(One(Cap(Indexed8, Bold), Attr(XT(196), Def)) = E + '1;1H' + E + '1;31m' + 'X', 'bright xterm color');
  Check(One(Cap(Indexed8, Bold), Attr(Rgb(255, 255, 255), Def)) = E + '1;1H' + E + '1;37m' + 'X', 'bright rgb color');
  Check(One(Cap(Indexed8, Bold), Attr(Bios(12), Def, slBold)) = E + '1;1H' + E + '1;31m' + 'X',
    'bold is written once');
end;

procedure TestNoColor;
begin
  Check(One(Cap(NoColor), Attr(Bios(12), Def)) = E + '1;1H' + E + '1m' + 'X', 'bright foreground is bold');
  Check(One(Cap(NoColor), Attr(Bios(8), Def)) = E + '1;1H' + E + '1m' + 'X', 'dark gray foreground is bold');
  Check(One(Cap(NoColor), Attr(Bios(1), Def)) = E + '1;1H' + E + '4m' + 'X', 'blue foreground is underlined');
  Check(One(Cap(NoColor), Attr(Bios(7), Def)) = E + '1;1H' + 'X', 'light gray foreground');
  Check(One(Cap(NoColor), Attr(Bios(0), Def)) = E + '1;1H' + 'X', 'black foreground');
  Check(One(Cap(NoColor), Attr(Def, Bios(7))) = E + '1;1H' + E + '7m' + 'X', 'light gray background is reverse');
  Check(One(Cap(NoColor), Attr(Def, Bios(15))) = E + '1;1H' + E + '7m' + 'X', 'white background is reverse');
  Check(One(Cap(NoColor), Attr(Def, Bios(1))) = E + '1;1H' + 'X', 'blue background');
  Check(One(Cap(NoColor), TColorAttr.Create(Integer($7C))) = E + '1;1H' + E + '1;7m' + 'X', 'bios attribute');
  Check(One(Cap(NoColor), Attr(Bios(1), Bios(7))) = E + '1;1H' + E + '4;7m' + 'X', 'underline and reverse');
  Check(One(Cap(NoColor), Attr(Bios(12), Def, slBold)) = E + '1;1H' + E + '1m' + 'X', 'bold from color and style');
  Check(One(Cap(NoColor), Attr(Def, Def, slStrike)) = E + '1;1H' + E + '9m' + 'X', 'styles still apply');
  Check(One(Cap(NoColor), Attr(Rgb(255, 0, 0), XT(200))) = E + '1;1H' + 'X', 'other colors write nothing');
  Check(One(Cap(NoColor), Attr(Def, Def)) = E + '1;1H' + 'X', 'default colors write nothing');
end;

procedure TestQuirks;
const
  NoIt = qfNoItalic;
  NoUl = qfNoUnderline;
begin
  Check(One(Cap(Indexed16, NoIt), Attr(Def, Def, slItalic)) = E + '1;1H' + 'X', 'italic removed');
  Check(One(Cap(Indexed16, NoIt), Attr(Def, Def, slItalic or slBold)) = E + '1;1H' + E + '1m' + 'X',
    'italic removed, bold kept');
  Check(One(Cap(Indexed16, NoIt), Attr(Def, Def, slUnderline)) = E + '1;1H' + E + '4m' + 'X',
    'underline kept without its quirk');
  Check(One(Cap(Indexed16, NoUl), Attr(Def, Def, slUnderline)) = E + '1;1H' + 'X', 'underline removed');
  Check(One(Cap(Indexed16, NoUl), Attr(Def, Def, slItalic)) = E + '1;1H' + E + '3m' + 'X',
    'italic kept without its quirk');
  Check(One(Cap(Indexed16, NoIt or NoUl), Attr(Def, Def, slItalic or slUnderline)) = E + '1;1H' + 'X',
    'both removed');
  Check(One(Cap(NoColor, NoUl), Attr(Bios(1), Def)) = E + '1;1H' + 'X', 'underline from a color is removed');
  Check(One(Cap(Indexed8, qfBoldIsBright or qfBlinkIsBright or NoIt or NoUl),
    Attr(Bios(12), Bios(9), slItalic or slUnderline)) = E + '1;1H' + E + '1;5;31;44m' + 'X',
    'quirks of the Linux console');
end;

begin
  TestTermColor;
  TestBuffer;
  TestCursor;
  TestResetClear;
  TestCaretMoves;
  TestWidth;
  TestRepeat;
  TestAttrState;
  TestSixteenColors;
  TestSixteenFromOthers;
  TestChanges;
  TestStyles;
  TestTwoFiftySix;
  TestDirect;
  TestEightColors;
  TestNoColor;
  TestQuirks;
  Done;
end.
