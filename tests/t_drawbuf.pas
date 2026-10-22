{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/drawbuf.h, source/tvision/drivers.cpp
  See COPYRIGHT.magiblot. }
program t_drawbuf;

{$mode objfpc}
{$modeswitch advancedrecords}

uses
  TvColors, TvCell, TvDrawBuf;

{$I testlib.inc}

const
  { U+4E2D takes two columns. }
  Wide = #$E4#$B8#$AD;

type
  { Gives the tests access to the cells and the capacity of a TDrawBuffer. }
  TTestBuffer = class(TDrawBuffer)
  public
    function CellAt(I: SizeInt): TScreenCell;
    procedure SetCellAt(I: SizeInt; const Cell: TScreenCell);
    function Cap: SizeUInt;
    { Fills all cells with an 'A' on the BIOS attribute $1F. }
    procedure FillAll;
  end;

function TTestBuffer.CellAt(I: SizeInt): TScreenCell;
begin
  Result := Data[I];
end;

procedure TTestBuffer.SetCellAt(I: SizeInt; const Cell: TScreenCell);
begin
  Data[I] := Cell;
end;

function TTestBuffer.Cap: SizeUInt;
begin
  Result := Capacity;
end;

procedure TTestBuffer.FillAll;
var
  I: SizeInt;
begin
  for I := 0 to Capacity - 1 do
    Data[I] := TScreenCell.Create(Word($1F41));
end;

function AttrOf(Bios: Integer): TColorAttr;
begin
  Result := TColorAttr.Create(Bios);
end;

function NewBuffer: TTestBuffer;
begin
  Result := TTestBuffer.Create;
  Result.FillAll;
end;

function TextAt(B: TTestBuffer; I: SizeInt): string;
begin
  Result := B.CellAt(I).Character.GetText;
end;

function AttrAt(B: TTestBuffer; I: SizeInt): TColorAttr;
begin
  Result := B.CellAt(I).Attribute;
end;

{ True when the cell is still the one that FillAll made. }
function Unchanged(B: TTestBuffer; I: SizeInt): Boolean;
begin
  Result := B.CellAt(I) = TScreenCell.Create(Word($1F41));
end;

procedure TestCapacity;
var
  B: TTestBuffer;
begin
  B := TTestBuffer.Create;
  Check(B.Cap = 88, 'capacity without a screen size');
  B.Free;
  ScreenWidth := 200;
  ScreenHeight := 50;
  B := TTestBuffer.Create;
  Check(B.Cap = 208, 'capacity from the width');
  B.Free;
  ScreenWidth := 10;
  ScreenHeight := 300;
  B := TTestBuffer.Create;
  Check(B.Cap = 308, 'capacity from the height');
  B.Free;
  ScreenWidth := 0;
  ScreenHeight := 0;
end;

procedure TestZeroed;
var
  B: TTestBuffer;
  Cell: TScreenCell;
  I: SizeInt;
  All: Boolean;
begin
  B := TTestBuffer.Create;
  FillChar(Cell, SizeOf(Cell), 0);
  All := True;
  for I := 0 to SizeInt(B.Cap) - 1 do
    All := All and (B.CellAt(I) = Cell);
  Check(All, 'a new buffer is zero');
  B.Free;
end;

procedure TestMoveChar;
var
  B: TTestBuffer;
  I: SizeInt;
  Rest: Boolean;
begin
  B := NewBuffer;
  B.MoveChar(2, 'x', AttrOf($2E), 4);
  Check((TextAt(B, 2) = 'x') and (TextAt(B, 5) = 'x'), 'characters are moved');
  Check((AttrAt(B, 2) = AttrOf($2E)) and (AttrAt(B, 5) = AttrOf($2E)), 'attributes are moved');
  Check(Unchanged(B, 1) and Unchanged(B, 6), 'cells around are kept');
  B.MoveChar(10, #0, AttrOf($4E), 3);
  Check((TextAt(B, 10) = 'A') and (AttrAt(B, 10) = AttrOf($4E)) and (AttrAt(B, 12) = AttrOf($4E)),
    'a zero character keeps the characters');
  Check(Unchanged(B, 13), 'a zero character stops at the count');
  B.MoveChar(20, 'y', AttrOf(0), 2);
  Check((TextAt(B, 20) = 'y') and (TextAt(B, 21) = 'y') and (AttrAt(B, 20) = AttrOf($1F)),
    'a zero attribute keeps the attributes');
  B.MoveChar(30, 'z', AttrOf($70), 0);
  Check(Unchanged(B, 30), 'a zero count moves nothing');
  B.Free;
end;

procedure TestMoveCharClip;
var
  B: TTestBuffer;
  Last: SizeInt;
begin
  B := NewBuffer;
  Last := B.Cap - 1;
  B.MoveChar(Word(Last - 1), 'x', AttrOf($2E), 10);
  Check((TextAt(B, Last - 1) = 'x') and (TextAt(B, Last) = 'x'), 'a move is cut at the capacity');
  Check(Unchanged(B, Last - 2), 'the cell before a clipped move is kept');
  B.FillAll;
  B.MoveChar(Word(B.Cap), 'x', AttrOf($2E), 2);
  B.MoveChar(65535, 'x', AttrOf($2E), 2);
  Check(Unchanged(B, Last) and Unchanged(B, 0), 'nothing is moved at or beyond the capacity');
  B.MoveChar(Word(Last), 'q', AttrOf($2E), 65535);
  Check(TextAt(B, Last) = 'q', 'a count of 65535 is cut');
  B.Free;
end;

procedure TestMoveStr;
var
  B: TTestBuffer;
  N: Word;
begin
  B := NewBuffer;
  N := B.MoveStr(3, 'Hello', AttrOf($2E));
  Check(N = 5, 'width of the moved string');
  Check((TextAt(B, 3) = 'H') and (TextAt(B, 7) = 'o'), 'string characters');
  Check((AttrAt(B, 3) = AttrOf($2E)) and (AttrAt(B, 7) = AttrOf($2E)), 'string attributes');
  Check(Unchanged(B, 2) and Unchanged(B, 8), 'cells around a string are kept');
  N := B.MoveStr(10, 'abc', AttrOf(0));
  Check((N = 3) and (TextAt(B, 10) = 'a') and (TextAt(B, 12) = 'c') and (AttrAt(B, 11) = AttrOf($1F)),
    'a zero attribute keeps the attributes');
  N := B.MoveStr(20, 'Hello', AttrOf($2E), 3);
  Check((N = 3) and (TextAt(B, 22) = 'l') and Unchanged(B, 23), 'a string is cut at the maximum width');
  N := B.MoveStr(30, 'Hello', AttrOf($2E), 65535, 2);
  Check((N = 3) and (TextAt(B, 30) = 'l') and (TextAt(B, 32) = 'o') and Unchanged(B, 33), 'a string starts at its indent');
  N := B.MoveStr(40, '', AttrOf($2E));
  Check((N = 0) and Unchanged(B, 40), 'an empty string');
  N := B.MoveStr(40, 'abc', AttrOf($2E), 0);
  Check((N = 0) and Unchanged(B, 40), 'a maximum width of zero');
  N := B.MoveStr(Word(B.Cap), 'abc', AttrOf($2E));
  Check(N = 0, 'an indent at the capacity');
  N := B.MoveStr(Word(B.Cap - 3), 'Hello', AttrOf($2E));
  Check((N = 3) and (TextAt(B, B.Cap - 1) = 'l'), 'a string is cut at the capacity');
  B.Free;
end;

procedure TestMoveStrWide;
var
  B: TTestBuffer;
  N: Word;
begin
  B := NewBuffer;
  N := B.MoveStr(0, Wide + 'a', AttrOf($2E));
  Check(N = 3, 'width of a wide character and a letter');
  Check(B.CellAt(0).Character.IsWide and (TextAt(B, 0) = Wide), 'wide character');
  Check(B.CellAt(1).Character.IsWideCharTrail, 'trail of a wide character');
  Check(TextAt(B, 2) = 'a', 'letter after a wide character');
  Check((AttrAt(B, 0) = AttrOf($2E)) and (AttrAt(B, 1) = AttrOf($2E)), 'attribute of a wide character');
  B.FillAll;
  N := B.MoveStr(5, Wide + 'a', AttrOf($2E), 65535, 1);
  Check((N = 2) and (TextAt(B, 5) = ' ') and (TextAt(B, 6) = 'a'), 'a string starts in the middle of a wide character');
  B.Free;
end;

procedure TestMoveCStr;
var
  B: TTestBuffer;
  N: Word;
  Pair: TAttrPair;
begin
  Pair := TAttrPair.Create(AttrOf($1F), AttrOf($4E));
  B := NewBuffer;
  N := B.MoveCStr(1, '~H~ello', Pair);
  Check(N = 5, 'width of the moved string with tildes');
  Check((TextAt(B, 1) = 'H') and (TextAt(B, 5) = 'o'), 'characters without tildes');
  Check(AttrAt(B, 1) = AttrOf($4E), 'the first tilde selects the high attribute');
  Check((AttrAt(B, 2) = AttrOf($1F)) and (AttrAt(B, 5) = AttrOf($1F)), 'the second tilde selects the low attribute');
  Check(Unchanged(B, 0) and Unchanged(B, 6), 'cells around are kept');
  N := B.MoveCStr(10, 'x~y~z', Pair);
  Check((N = 3) and (AttrAt(B, 10) = AttrOf($1F)) and (AttrAt(B, 11) = AttrOf($4E)) and (AttrAt(B, 12) = AttrOf($1F)),
    'the low attribute is used first');
  N := B.MoveCStr(20, 'ab~c~d', Pair, 65535, 2);
  Check((N = 2) and (TextAt(B, 20) = 'c') and (AttrAt(B, 20) = AttrOf($4E)) and (TextAt(B, 21) = 'd') and
    (AttrAt(B, 21) = AttrOf($1F)), 'tildes are counted in the skipped part');
  N := B.MoveCStr(30, 'abcd', Pair, 2);
  Check((N = 2) and (TextAt(B, 31) = 'b') and Unchanged(B, 32), 'a string is cut at the maximum width');
  N := B.MoveCStr(40, '~~', Pair);
  Check((N = 0) and Unchanged(B, 40), 'a string of tildes');
  N := B.MoveCStr(40, '', Pair);
  Check(N = 0, 'an empty string');
  N := B.MoveCStr(Word(B.Cap), 'abc', Pair);
  Check(N = 0, 'an indent at the capacity');
  N := B.MoveCStr(Word(B.Cap - 2), 'abcd', Pair);
  Check((N = 2) and (TextAt(B, B.Cap - 1) = 'b'), 'a string is cut at the capacity');
  N := B.MoveCStr(50, Wide + 'a', Pair, 65535, 1);
  Check((N = 2) and (TextAt(B, 50) = ' ') and (TextAt(B, 51) = 'a'), 'a string starts in the middle of a wide character');
  B.Free;
end;

procedure TestMoveBuf;
var
  B: TTestBuffer;
  Bytes: array[0..3] of Char;
begin
  Bytes[0] := 'H';
  Bytes[1] := 'i';
  Bytes[2] := '!';
  Bytes[3] := '?';
  B := NewBuffer;
  B.MoveBuf(4, @Bytes[0], AttrOf($2E), 3);
  Check((TextAt(B, 4) = 'H') and (TextAt(B, 6) = '!'), 'bytes are moved');
  Check((AttrAt(B, 4) = AttrOf($2E)) and Unchanged(B, 7), 'bytes stop at the count');
  B.MoveBuf(10, @Bytes[0], AttrOf(0), 2);
  Check((TextAt(B, 11) = 'i') and (AttrAt(B, 10) = AttrOf($1F)) and Unchanged(B, 12), 'a zero attribute keeps the attributes');
  B.Free;
end;

procedure TestPutChar;
var
  B: TTestBuffer;
begin
  B := NewBuffer;
  B.PutChar(3, Ord('Z'));
  Check(TextAt(B, 3) = 'Z', 'character is stored');
  Check(AttrAt(B, 3) = AttrOf($1F), 'attribute is kept by PutChar');
  Check(Unchanged(B, 2) and Unchanged(B, 4), 'neighbours are kept by PutChar');
  B.PutChar(0, 200);
  Check(TextAt(B, 0) = #200, 'extended character');
  B.PutChar(9, 0);
  Check(TextAt(B, 9) = #0, 'a null byte is stored with length one');
  B.PutChar(Word(B.Cap), Ord('Q'));
  B.PutChar(65535, Ord('Q'));
  Check(Unchanged(B, SizeInt(B.Cap) - 1), 'nothing is written at or beyond the capacity');
  B.PutChar(Word(B.Cap - 1), Ord('Q'));
  Check(TextAt(B, B.Cap - 1) = 'Q', 'the last cell is written');
  B.Free;
end;

procedure TestPutAttribute;
var
  B: TTestBuffer;
begin
  B := NewBuffer;
  B.PutAttribute(5, AttrOf($4E));
  Check(AttrAt(B, 5) = AttrOf($4E), 'attribute is stored');
  Check(TextAt(B, 5) = 'A', 'character is kept by PutAttribute');
  Check(Unchanged(B, 4) and Unchanged(B, 6), 'neighbours are kept by PutAttribute');
  B.PutAttribute(Word(B.Cap), AttrOf($70));
  B.PutAttribute(65535, AttrOf($70));
  Check(Unchanged(B, SizeInt(B.Cap) - 1), 'no attribute is written at or beyond the capacity');
  B.Free;
end;

procedure TestPutWide;
var
  B: TTestBuffer;
  Ch: TScreenCharacter;
begin
  B := NewBuffer;
  Ch.InitWithMultiByteChar(Wide, True);
  B.SetCellAt(2, TScreenCell.Create(Ch, AttrOf($1F)));
  Ch.InitAsWideCharTrail;
  B.SetCellAt(3, TScreenCell.Create(Ch, AttrOf($1F)));
  B.PutAttribute(2, AttrOf($2E));
  Check(B.CellAt(2).Character.IsWide and (TextAt(B, 2) = Wide), 'attribute leaves a wide character');
  Check(AttrAt(B, 2) = AttrOf($2E), 'attribute of a wide cell');
  B.PutAttribute(3, AttrOf($2E));
  Check(B.CellAt(3).Character.IsWideCharTrail, 'attribute leaves a trail');
  B.PutChar(2, Ord('w'));
  Check(not B.CellAt(2).Character.IsWide and (TextAt(B, 2) = 'w'), 'a byte replaces a wide character');
  Check(AttrAt(B, 2) = AttrOf($2E), 'attribute after replacing a wide character');
  B.PutChar(3, Ord('v'));
  Check(not B.CellAt(3).Character.IsWideCharTrail and (TextAt(B, 3) = 'v'), 'a byte replaces a trail');
  B.Free;
end;

begin
  TestCapacity;
  TestZeroed;
  TestMoveChar;
  TestMoveCharClip;
  TestMoveStr;
  TestMoveStrWide;
  TestMoveCStr;
  TestMoveBuf;
  TestPutChar;
  TestPutAttribute;
  TestPutWide;
  Done;
end.
