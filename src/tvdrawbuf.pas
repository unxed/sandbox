{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/drawbuf.h, source/tvision/drivers.cpp
  See COPYRIGHT.magiblot.

  Only the branch of both files for the flat memory model is translated: the buffer is a pointer to cells with a
  capacity, and the members that move text go through TTextCells of TvText. The members of drivers.cpp are
  all of TDrawBuffer; the assembler branch for DOS in that file is left out. The C++ type uchar is a Byte,
  ushort is a Word and a TStringView is a string. The pointer and length of MoveBuf are a Pointer and a Word, and
  the indices into a string are zero-based, as in TvText.

  TScreen has no unit. ScreenWidth and ScreenHeight stand for TScreen::screenWidth and TScreen::screenHeight and
  are zero until a program sets them. }
unit TvDrawBuf;

{$mode objfpc}
{$modeswitch advancedrecords}
{$POINTERMATH ON}
{$R-}
{$Q-}

interface

uses
  TvColors, TvCell;

type
  PScreenCell = ^TScreenCell;

  { The high-level interface to the screen manager: a row of cells that a view fills before it is written. }
  TDrawBuffer = class
  protected
    Data: PScreenCell;
    Capacity: SizeUInt;
  public
    { Allocates the buffer. Its capacity is the largest of the screen dimensions and 80, plus 8 columns for views
      that exceed the screen. All cells are zero. }
    constructor Create;
    destructor Destroy; override;
    { Puts Count copies of C with the attribute Attr, starting at Indent. A zero C keeps the characters, and a
      zero Attr keeps the attributes. Nothing is written beyond Capacity. }
    procedure MoveChar(Indent: Word; C: Char; Attr: TColorAttr; Count: Word);
    { Moves Str starting at its column StrIndent, with Attr as the attribute of every cell (a zero Attr keeps the
      attributes). At most MaxStrWidth columns are written. Returns the width of the moved text. }
    function MoveStr(Indent: Word; const Str: string; Attr: TColorAttr; MaxStrWidth: Word = High(Word);
      StrIndent: Word = 0): Word;
    { As MoveStr, with the low attribute of Attrs at first and a tilde in Str switching between the low and the
      high attribute. Tildes are not moved. }
    function MoveCStr(Indent: Word; const Str: string; const Attrs: TAttrPair; MaxStrWidth: Word = High(Word);
      StrIndent: Word = 0): Word;
    { Moves Count bytes at Source as MoveStr moves a string. }
    procedure MoveBuf(Indent: Word; Source: Pointer; Attr: TColorAttr; Count: Word);
    { Both routines do nothing when Indent is not below Capacity. }
    procedure PutAttribute(Indent: Word; Attr: TColorAttr);
    procedure PutChar(Indent: Word; C: Byte);
  end;

var
  ScreenWidth: Integer;
  ScreenHeight: Integer;

implementation

uses
  Math, TvUtf8, TvText;

type
  TCellArray = array[0..$FFFFF] of TScreenCell;
  PCellArray = ^TCellArray;

{ Moves the text of Str into Dest, switching between the two attributes at each tilde.
  Pre: Indent < Length(Dest), Length(Str) > 0. }
function CStrInto(var Dest: array of TScreenCell; Indent: SizeInt; const Str: string; const Attrs: TAttrPair;
  StrIndent: Word): SizeInt;
var
  I, J, W: SizeInt;
  Toggle: Integer;
  CurAttr: TColorAttr;
  Cell: TScreenCell;
begin
  I := Indent;
  J := 0;
  W := 0;
  Toggle := 1;
  CurAttr := Attrs.Attrs[0];
  while J < Length(Str) do
    if Str[J + 1] = '~' then
    begin
      CurAttr := Attrs.Attrs[Toggle];
      Toggle := 1 - Toggle;
      Inc(J);
    end
    else if StrIndent <= W then
    begin
      if not TTextCells.DrawOne(Dest, I, Str, J, CurAttr) then
        Break;
    end
    else
    begin
      if not TText.Next(Str, J, W) then
        Break;
      if (StrIndent < W) and (I < Length(Dest)) then
      begin
        { StrIndent is in the middle of a double-width character. }
        Cell := TScreenCell.Create(TScreenCharacter.Create(' '), CurAttr);
        Dest[I] := Cell;
        Inc(I);
      end;
    end;
  Result := I - Indent;
end;

constructor TDrawBuffer.Create;
begin
  { The screen's dimensions are arbitrary, so the buffer is allocated dynamically. The largest dimension is taken,
    since a buffer can also draw vertical views. Some room is left for views that exceed the screen size. }
  Capacity := 8 + SizeUInt(Max(Max(ScreenWidth, ScreenHeight), 80));
  GetMem(Data, Capacity * SizeOf(TScreenCell));
  FillChar(Data^, Capacity * SizeOf(TScreenCell), 0);
end;

destructor TDrawBuffer.Destroy;
begin
  FreeMem(Data);
  inherited Destroy;
end;

procedure TDrawBuffer.MoveChar(Indent: Word; C: Char; Attr: TColorAttr; Count: Word);
var
  Dest: PScreenCell;
  Cell: TScreenCell;
begin
  if (Count = 0) or (Indent >= Capacity) then
    Exit;
  if SizeUInt(Indent) + Count >= Capacity then
    Count := Word(Capacity - Indent);
  Dest := @Data[Indent];
  if Attr <> 0 then
  begin
    if C <> #0 then
    begin
      Cell := TScreenCell.Create(TScreenCharacter.Create(C), Attr);
      while Count > 0 do
      begin
        Dest^ := Cell;
        Inc(Dest);
        Dec(Count);
      end;
    end
    else
      while Count > 0 do
      begin
        Dest^.Attribute := Attr;
        Inc(Dest);
        Dec(Count);
      end;
  end
  else
    while Count > 0 do
    begin
      Dest^.Character.InitWithChar(C);
      Inc(Dest);
      Dec(Count);
    end;
end;

function TDrawBuffer.MoveStr(Indent: Word; const Str: string; Attr: TColorAttr; MaxStrWidth: Word;
  StrIndent: Word): Word;
begin
  if (Indent >= Capacity) or (Length(Str) = 0) or (MaxStrWidth = 0) then
  begin
    Result := 0;
    Exit;
  end;
  if (SizeUInt(Indent) + MaxStrWidth < Indent) or (SizeUInt(Indent) + MaxStrWidth >= Capacity) then
    MaxStrWidth := Word(Capacity - Indent);
  if Attr <> 0 then
    Result := Word(TTextCells.DrawStr(Slice(PCellArray(Data)^, SizeInt(Indent) + MaxStrWidth), Indent, Str, StrIndent, Attr))
  else
    Result := Word(TTextCells.DrawStr(Slice(PCellArray(Data)^, SizeInt(Indent) + MaxStrWidth), Indent, Str, StrIndent));
end;

function TDrawBuffer.MoveCStr(Indent: Word; const Str: string; const Attrs: TAttrPair; MaxStrWidth: Word;
  StrIndent: Word): Word;
begin
  if (Indent >= Capacity) or (Length(Str) = 0) or (MaxStrWidth = 0) then
  begin
    Result := 0;
    Exit;
  end;
  if (SizeUInt(Indent) + MaxStrWidth < Indent) or (SizeUInt(Indent) + MaxStrWidth >= Capacity) then
    MaxStrWidth := Word(Capacity - Indent);
  Result := Word(CStrInto(Slice(PCellArray(Data)^, SizeInt(Indent) + MaxStrWidth), Indent, Str, Attrs, StrIndent));
end;

procedure TDrawBuffer.MoveBuf(Indent: Word; Source: Pointer; Attr: TColorAttr; Count: Word);
var
  Str: string;
begin
  SetString(Str, PChar(Source), Count);
  MoveStr(Indent, Str, Attr, High(Word), 0);
end;

procedure TDrawBuffer.PutAttribute(Indent: Word; Attr: TColorAttr);
begin
  if Indent < Capacity then
    Data[Indent].Attribute := Attr;
end;

procedure TDrawBuffer.PutChar(Indent: Word; C: Byte);
begin
  if Indent < Capacity then
    Data[Indent].Character.InitWithChar(Chr(C));
end;

end.
