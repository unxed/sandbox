{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/scrncell.h
  See COPYRIGHT.magiblot.

  Only the branch of scrncell.h for compilers other than Borland C++ is translated. The text of a TScreenCharacter
  is a string, the indices of a text are zero-based inside the record and the string returned by GetText is
  one-based. The maximum size of a character is the length of TUtf8Bytes of TvUtf8. A zero-initialized
  TScreenCharacter or TScreenCell is valid and represents the text of an empty screen cell, and the comparison of two
  TScreenCell values compares all their bytes. }
unit TvCell;

{$mode objfpc}
{$modeswitch advancedrecords}
{$R-}
{$Q-}

interface

uses
  TvColors;

type
  { Represents text in a screen cell: a single byte of ASCII or extended ASCII text, up to 15 bytes of UTF-8 text
    (one or two columns wide in total), or a special value that marks the cell as a wide char trail. }
  TScreenCharacter = packed record
  private
    FText: array[0..14] of Char;
    { The low four bits hold the length of the text minus one, the high four bits hold the flags. }
    FBits: Byte;
    function GetLengthMinusOne: Integer;
    procedure SetLengthMinusOne(Value: Integer);
    function GetFlags: Integer;
    procedure SetFlags(Value: Integer);
  public
    constructor Create(C: Char);
    procedure InitWithChar(C: Char);
    { Mbc is a multibyte-encoded character cast to a Cardinal. }
    procedure InitWithMultiByteChar(Mbc: Cardinal; Wide: Boolean = False); overload;
    procedure InitWithMultiByteChar(const Mbc: string; Wide: Boolean = False); overload;
    procedure InitAsWideCharTrail;
    function IsWide: Boolean;
    function IsWideCharTrail: Boolean;
    procedure AppendZeroWidthChar(const Mbc: string);
    { Must not be called on a wide char trail. }
    function GetText: string;
  end;

  { Stores the text and the color attributes of a screen cell. }
  TScreenCell = packed record
    Character: TScreenCharacter;
    Attribute: TColorAttr;
    constructor Create(const Ch: TScreenCharacter; Attr: TColorAttr); overload;
    constructor Create(Bios: Word); overload;
    class operator =(const One, Two: TScreenCell): Boolean;
    class operator <>(const One, Two: TScreenCell): Boolean;
  end;

implementation

uses
  TvUtf8;

const
  fWide = $1;
  fTrail = $2;
  fOverflow = $4;

  MaxCharSize = High(TUtf8Bytes) + 1;

{ TScreenCharacter }

function TScreenCharacter.GetLengthMinusOne: Integer;
begin
  Result := FBits and $0F;
end;

procedure TScreenCharacter.SetLengthMinusOne(Value: Integer);
begin
  FBits := (FBits and $F0) or (Value and $0F);
end;

function TScreenCharacter.GetFlags: Integer;
begin
  Result := FBits shr 4;
end;

procedure TScreenCharacter.SetFlags(Value: Integer);
begin
  FBits := (FBits and $0F) or ((Value and $0F) shl 4);
end;

constructor TScreenCharacter.Create(C: Char);
begin
  FillChar(Self, SizeOf(Self), 0);
  FText[0] := C;
end;

procedure TScreenCharacter.InitWithChar(C: Char);
begin
  FillChar(Self, SizeOf(Self), 0);
  FText[0] := C;
end;

procedure TScreenCharacter.InitWithMultiByteChar(Mbc: Cardinal; Wide: Boolean);
begin
  FillChar(Self, SizeOf(Self), 0);
{$IFNDEF ENDIAN_BIG}
  FText[0] := Chr(Byte(Mbc));
  FText[1] := Chr(Byte(Mbc shr 8));
  FText[2] := Chr(Byte(Mbc shr 16));
  FText[3] := Chr(Byte(Mbc shr 24));
  SetLengthMinusOne(Ord(Mbc > $000000FF) + Ord(Mbc > $0000FFFF) + Ord(Mbc > $00FFFFFF));
{$ELSE}
  FText[0] := Chr(Byte(Mbc shr 24));
  FText[1] := Chr(Byte(Mbc shr 16));
  FText[2] := Chr(Byte(Mbc shr 8));
  FText[3] := Chr(Byte(Mbc));
  SetLengthMinusOne(Ord((Mbc and $00FFFFFF) <> 0) + Ord((Mbc and $0000FFFF) <> 0) + Ord((Mbc and $000000FF) <> 0));
{$ENDIF}
  SetFlags(Ord(Wide) * fWide);
end;

procedure TScreenCharacter.InitWithMultiByteChar(const Mbc: string; Wide: Boolean);
var
  I: Integer;
begin
  FillChar(Self, SizeOf(Self), 0);
  if (Length(Mbc) > 0) and (Length(Mbc) <= MaxCharSize) then
  begin
    SetFlags(GetFlags or (Ord(Wide) * fWide));
    SetLengthMinusOne(Length(Mbc) - 1);
    for I := 0 to Length(Mbc) - 1 do
      FText[I] := Mbc[I + 1];
  end;
end;

procedure TScreenCharacter.InitAsWideCharTrail;
begin
  FillChar(Self, SizeOf(Self), 0);
  SetFlags(fTrail);
end;

function TScreenCharacter.IsWide: Boolean;
begin
  Result := (GetFlags and fWide) <> 0;
end;

function TScreenCharacter.IsWideCharTrail: Boolean;
begin
  Result := (GetFlags and fTrail) <> 0;
end;

procedure TScreenCharacter.AppendZeroWidthChar(const Mbc: string);
var
  Sz, I: Integer;
begin
  if (GetFlags and fOverflow) <> 0 then
    Exit;
  Sz := GetLengthMinusOne + 1;
  if Length(Mbc) <= SizeOf(FText) - Sz then
  begin
    if FText[0] = #0 then
      FText[0] := ' ';
    if (Length(Mbc) >= 1) and (Length(Mbc) <= MaxCharSize) then
      for I := 0 to Length(Mbc) - 1 do
        FText[Sz + I] := Mbc[I + 1];
    SetLengthMinusOne(GetLengthMinusOne + Length(Mbc));
  end
  else
    SetFlags(GetFlags or fOverflow);
end;

function TScreenCharacter.GetText: string;
begin
  SetString(Result, PChar(@FText[0]), GetLengthMinusOne + 1);
end;

{ TScreenCell }

constructor TScreenCell.Create(const Ch: TScreenCharacter; Attr: TColorAttr);
begin
  Character := Ch;
  Attribute := Attr;
end;

constructor TScreenCell.Create(Bios: Word);
begin
  Character := TScreenCharacter.Create(Chr(Byte(Bios)));
  Attribute := TColorAttr.Create(Integer(Bios shr 8));
end;

class operator TScreenCell.=(const One, Two: TScreenCell): Boolean;
begin
  Result := CompareByte(One, Two, SizeOf(TScreenCell)) = 0;
end;

class operator TScreenCell.<>(const One, Two: TScreenCell): Boolean;
begin
  Result := not (One = Two);
end;

end.
