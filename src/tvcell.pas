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

function TScreenCharacter.GetLengthMinusOne: Integer;
begin
  Result := 0;
end;

procedure TScreenCharacter.SetLengthMinusOne(Value: Integer);
begin
end;

function TScreenCharacter.GetFlags: Integer;
begin
  Result := 0;
end;

procedure TScreenCharacter.SetFlags(Value: Integer);
begin
end;

constructor TScreenCharacter.Create(C: Char);
begin
end;

procedure TScreenCharacter.InitWithChar(C: Char);
begin
end;

procedure TScreenCharacter.InitWithMultiByteChar(Mbc: Cardinal; Wide: Boolean);
begin
end;

procedure TScreenCharacter.InitWithMultiByteChar(const Mbc: string; Wide: Boolean);
begin
end;

procedure TScreenCharacter.InitAsWideCharTrail;
begin
end;

function TScreenCharacter.IsWide: Boolean;
begin
  Result := False;
end;

function TScreenCharacter.IsWideCharTrail: Boolean;
begin
  Result := False;
end;

procedure TScreenCharacter.AppendZeroWidthChar(const Mbc: string);
begin
end;

function TScreenCharacter.GetText: string;
begin
  Result := '';
end;

constructor TScreenCell.Create(const Ch: TScreenCharacter; Attr: TColorAttr);
begin
end;

constructor TScreenCell.Create(Bios: Word);
begin
end;

class operator TScreenCell.=(const One, Two: TScreenCell): Boolean;
begin
  Result := False;
end;

class operator TScreenCell.<>(const One, Two: TScreenCell): Boolean;
begin
  Result := False;
end;

end.
