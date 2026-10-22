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

constructor TDrawBuffer.Create;
begin
end;

destructor TDrawBuffer.Destroy;
begin
  inherited Destroy;
end;

procedure TDrawBuffer.MoveChar(Indent: Word; C: Char; Attr: TColorAttr; Count: Word);
begin
end;

function TDrawBuffer.MoveStr(Indent: Word; const Str: string; Attr: TColorAttr; MaxStrWidth: Word;
  StrIndent: Word): Word;
begin
  Result := 0;
end;

function TDrawBuffer.MoveCStr(Indent: Word; const Str: string; const Attrs: TAttrPair; MaxStrWidth: Word;
  StrIndent: Word): Word;
begin
  Result := 0;
end;

procedure TDrawBuffer.MoveBuf(Indent: Word; Source: Pointer; Attr: TColorAttr; Count: Word);
begin
end;

procedure TDrawBuffer.PutAttribute(Indent: Word; Attr: TColorAttr);
begin
end;

procedure TDrawBuffer.PutChar(Indent: Word; C: Byte);
begin
end;

end.
