{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/colors.h, source/platform/colors.cpp
  See COPYRIGHT.magiblot.

  A zero-initialized TColorRGB, TColorBIOS, TColorXTerm, TColor, TColorAttr or TAttrPair has the value that the
  default constructor of the C++ class gives: black for the three color types, the terminal default color for
  TColor and for both colors of TColorAttr. A TAttrPair that is zero-initialized has both attributes set to
  the default colors, while TAttrPair.Create(0) holds the BIOS attribute 0 twice.

  The constructors of TColor that take a char and an int in the C++ take a Char and an Integer. The method
  type() of TColor is ColorType. The conversion of a TAttrPair to a TColorAttr is Attrs[0], and the shift of a
  TColorAttr to the left that gives a TAttrPair is TAttrPair.ShiftedLeft. }
unit TvColors;

{$mode objfpc}
{$modeswitch advancedrecords}
{$R-}
{$Q-}

interface

const
  { TColorAttr style masks }
  slBold = $001;
  slItalic = $002;
  slUnderline = $004;
  slBlink = $008;
  slReverse = $010; { Prefer using Reversed instead. }
  slStrike = $020;

  { Private masks (used internally by TV) }
  slWindowShadow = $200;

type
  { A 24-bit RGB color; the Cardinal conversion is $00RRGGBB. }
  TColorRGB = record
  private
    FBlue: Byte;
    FGreen: Byte;
    FRed: Byte;
  public
    constructor Create(R, G, B: Byte); overload;
    constructor Create(Rgb: Cardinal); overload;
    function GetRed: Byte;
    procedure SetRed(R: Byte);
    function GetGreen: Byte;
    procedure SetGreen(G: Byte);
    function GetBlue: Byte;
    procedure SetBlue(B: Byte);
    class operator :=(const C: TColorRGB): Cardinal;
  end;

  { The 4-bit color encoding of Turbo Vision on DOS; the Byte conversion keeps the low four bits. }
  TColorBIOS = record
  private
    FBits: Byte;
  public
    constructor Create(Irgb: Byte);
    function GetRed: Boolean;
    procedure SetRed(R: Boolean);
    function GetGreen: Boolean;
    procedure SetGreen(G: Boolean);
    function GetBlue: Boolean;
    procedure SetBlue(B: Boolean);
    function GetIntensity: Boolean;
    procedure SetIntensity(I: Boolean);
    class operator :=(const C: TColorBIOS): Byte;
  end;

  { An index into the 256-color palette of the xterm-256color terminal type. }
  TColorXTerm = record
  private
    FIdx: Byte;
  public
    constructor Create(Idx: Byte);
    class operator :=(const C: TColorXTerm): Byte;
  end;

  { The terminal default color. }
  TColorDefault = record
  end;

  { Conversions between color types. }
  TColorConversion = class
  public
    class function BIOStoXTerm16(C: TColorBIOS): TColorXTerm; static;
    class function XTerm16toBIOS(Idx: TColorXTerm): TColorBIOS; static; { XTerm indices 0-15 }
    class function XTerm256toXTerm16(Idx: TColorXTerm): TColorXTerm; static; { XTerm indices 16-255 to 0-15 }
    class function XTerm256toRGB(Idx: TColorXTerm): TColorRGB; static; { XTerm indices 16-255 }
    class function RGBtoXTerm16(C: TColorRGB): TColorXTerm; static; { XTerm indices 0-15 }
    class function RGBtoXTerm256(C: TColorRGB): TColorXTerm; static; { XTerm indices 16-255 }
  end;

  { A color in any of the supported color types. A zero-initialized value is the default color. }
  TColor = record
  private
    { Bit 0: color (24 bits). Bit 24: type (8 bits, of which only 2 are used). }
    FData: Cardinal;
    function ColorType: Byte;
  public
    constructor Create(Bios: Char); overload;
    constructor Create(Rgb: Integer); overload;
    constructor Create(Bios: TColorBIOS); overload;
    constructor Create(Rgb: TColorRGB); overload;
    constructor Create(XTerm: TColorXTerm); overload;
    constructor Create(Def: TColorDefault); overload;
    function IsDefault: Boolean;
    function IsBIOS: Boolean;
    function IsRGB: Boolean;
    function IsXTerm: Boolean;
    { They perform no conversion: check the color type first. }
    function AsBIOS: TColorBIOS;
    function AsRGB: TColorRGB;
    function AsXTerm: TColorXTerm;
    { Quantization to TColorBIOS. }
    function ToBIOS(IsForeground: Boolean): TColorBIOS;
    class operator =(const One, Two: TColor): Boolean;
    class operator <>(const One, Two: TColor): Boolean;
  end;

  { The colors and style used when writing text to the screen. A zero-initialized value has both colors set to
    the default color and no style. }
  TColorAttr = record
  private
    { Bit 0: foreground (27 bits). Bit 27: background (27 bits). Bit 54: style (10 bits). }
    FData: QWord;
  public
    constructor Create(Bios: Integer); overload;
    constructor Create(Fg, Bg: TColor; Style: Word = 0); overload;
    function GetForeground: TColor;
    procedure SetForeground(Fg: TColor);
    function GetBackground: TColor;
    procedure SetBackground(Bg: TColor);
    function GetStyle: Word;
    procedure SetStyle(AStyle: Word);
    function Reversed: TColorAttr;
    { Converts to a BIOS color attribute, using quantization if necessary. Style flags are ignored. }
    function ToBIOS: Byte;
    { The corresponding BIOS color attribute when both colors are BIOS colors and there is no style flag,
      otherwise the fixed attribute $5F. }
    class operator :=(const A: TColorAttr): Byte;
    class operator =(const One, Two: TColorAttr): Boolean;
    class operator <>(const One, Two: TColorAttr): Boolean;
    class operator =(const One: TColorAttr; Bios: Integer): Boolean;
    class operator <>(const One: TColorAttr; Bios: Integer): Boolean;
  end;

  { A pair of color attributes; Attrs[0] is the low one and Attrs[1] the high one. }
  TAttrPair = record
  private
    FAttrs: array[0..1] of TColorAttr;
    function GetAttr(I: Integer): TColorAttr;
    procedure SetAttr(I: Integer; const A: TColorAttr);
  public
    constructor Create(const Low, High: TColorAttr); overload;
    constructor Create(Bios: Integer); overload;
    property Attrs[I: Integer]: TColorAttr read GetAttr write SetAttr;
    { The pair of BIOS attributes; it is exact only when both attributes are BIOS attributes. }
    class operator :=(const P: TAttrPair): Word;
    function ShiftRight(Shift: Integer): TAttrPair;
    function OrAssign(const Attr: TColorAttr): TAttrPair;
    class function ShiftedLeft(const Attr: TColorAttr; Shift: Integer): TAttrPair; static;
  end;

implementation

{ TColorRGB }

constructor TColorRGB.Create(R, G, B: Byte);
begin
end;

constructor TColorRGB.Create(Rgb: Cardinal);
begin
end;

function TColorRGB.GetRed: Byte;
begin
  Result := 0;
end;

procedure TColorRGB.SetRed(R: Byte);
begin
end;

function TColorRGB.GetGreen: Byte;
begin
  Result := 0;
end;

procedure TColorRGB.SetGreen(G: Byte);
begin
end;

function TColorRGB.GetBlue: Byte;
begin
  Result := 0;
end;

procedure TColorRGB.SetBlue(B: Byte);
begin
end;

class operator TColorRGB.:=(const C: TColorRGB): Cardinal;
begin
  Result := 0;
end;

{ TColorBIOS }

constructor TColorBIOS.Create(Irgb: Byte);
begin
end;

function TColorBIOS.GetRed: Boolean;
begin
  Result := False;
end;

procedure TColorBIOS.SetRed(R: Boolean);
begin
end;

function TColorBIOS.GetGreen: Boolean;
begin
  Result := False;
end;

procedure TColorBIOS.SetGreen(G: Boolean);
begin
end;

function TColorBIOS.GetBlue: Boolean;
begin
  Result := False;
end;

procedure TColorBIOS.SetBlue(B: Boolean);
begin
end;

function TColorBIOS.GetIntensity: Boolean;
begin
  Result := False;
end;

procedure TColorBIOS.SetIntensity(I: Boolean);
begin
end;

class operator TColorBIOS.:=(const C: TColorBIOS): Byte;
begin
  Result := 0;
end;

{ TColorXTerm }

constructor TColorXTerm.Create(Idx: Byte);
begin
end;

class operator TColorXTerm.:=(const C: TColorXTerm): Byte;
begin
  Result := 0;
end;

{ TColorConversion }

class function TColorConversion.BIOStoXTerm16(C: TColorBIOS): TColorXTerm;
begin
  Result := TColorXTerm.Create(0);
end;

class function TColorConversion.XTerm16toBIOS(Idx: TColorXTerm): TColorBIOS;
begin
  Result := TColorBIOS.Create(0);
end;

class function TColorConversion.XTerm256toXTerm16(Idx: TColorXTerm): TColorXTerm;
begin
  Result := TColorXTerm.Create(0);
end;

class function TColorConversion.XTerm256toRGB(Idx: TColorXTerm): TColorRGB;
begin
  Result := TColorRGB.Create(0);
end;

class function TColorConversion.RGBtoXTerm16(C: TColorRGB): TColorXTerm;
begin
  Result := TColorXTerm.Create(0);
end;

class function TColorConversion.RGBtoXTerm256(C: TColorRGB): TColorXTerm;
begin
  Result := TColorXTerm.Create(0);
end;

{ TColor }

function TColor.ColorType: Byte;
begin
  Result := 0;
end;

constructor TColor.Create(Bios: Char);
begin
end;

constructor TColor.Create(Rgb: Integer);
begin
end;

constructor TColor.Create(Bios: TColorBIOS);
begin
end;

constructor TColor.Create(Rgb: TColorRGB);
begin
end;

constructor TColor.Create(XTerm: TColorXTerm);
begin
end;

constructor TColor.Create(Def: TColorDefault);
begin
end;

function TColor.IsDefault: Boolean;
begin
  Result := False;
end;

function TColor.IsBIOS: Boolean;
begin
  Result := False;
end;

function TColor.IsRGB: Boolean;
begin
  Result := False;
end;

function TColor.IsXTerm: Boolean;
begin
  Result := False;
end;

function TColor.AsBIOS: TColorBIOS;
begin
  Result := TColorBIOS.Create(0);
end;

function TColor.AsRGB: TColorRGB;
begin
  Result := TColorRGB.Create(0);
end;

function TColor.AsXTerm: TColorXTerm;
begin
  Result := TColorXTerm.Create(0);
end;

function TColor.ToBIOS(IsForeground: Boolean): TColorBIOS;
begin
  Result := TColorBIOS.Create(0);
end;

class operator TColor.=(const One, Two: TColor): Boolean;
begin
  Result := False;
end;

class operator TColor.<>(const One, Two: TColor): Boolean;
begin
  Result := False;
end;

{ TColorAttr }

constructor TColorAttr.Create(Bios: Integer);
begin
end;

constructor TColorAttr.Create(Fg, Bg: TColor; Style: Word);
begin
end;

function TColorAttr.GetForeground: TColor;
begin
  Result := TColor.Create(Char(0));
end;

procedure TColorAttr.SetForeground(Fg: TColor);
begin
end;

function TColorAttr.GetBackground: TColor;
begin
  Result := TColor.Create(Char(0));
end;

procedure TColorAttr.SetBackground(Bg: TColor);
begin
end;

function TColorAttr.GetStyle: Word;
begin
  Result := 0;
end;

procedure TColorAttr.SetStyle(AStyle: Word);
begin
end;

function TColorAttr.Reversed: TColorAttr;
begin
  Result := Self;
end;

function TColorAttr.ToBIOS: Byte;
begin
  Result := 0;
end;

class operator TColorAttr.:=(const A: TColorAttr): Byte;
begin
  Result := 0;
end;

class operator TColorAttr.=(const One, Two: TColorAttr): Boolean;
begin
  Result := False;
end;

class operator TColorAttr.<>(const One, Two: TColorAttr): Boolean;
begin
  Result := False;
end;

class operator TColorAttr.=(const One: TColorAttr; Bios: Integer): Boolean;
begin
  Result := False;
end;

class operator TColorAttr.<>(const One: TColorAttr; Bios: Integer): Boolean;
begin
  Result := False;
end;

{ TAttrPair }

function TAttrPair.GetAttr(I: Integer): TColorAttr;
begin
  Result := FAttrs[I];
end;

procedure TAttrPair.SetAttr(I: Integer; const A: TColorAttr);
begin
  FAttrs[I] := A;
end;

constructor TAttrPair.Create(const Low, High: TColorAttr);
begin
end;

constructor TAttrPair.Create(Bios: Integer);
begin
end;

class operator TAttrPair.:=(const P: TAttrPair): Word;
begin
  Result := 0;
end;

function TAttrPair.ShiftRight(Shift: Integer): TAttrPair;
begin
  Result := Self;
end;

function TAttrPair.OrAssign(const Attr: TColorAttr): TAttrPair;
begin
  Result := Self;
end;

class function TAttrPair.ShiftedLeft(const Attr: TColorAttr; Shift: Integer): TAttrPair;
begin
  Result := TAttrPair.Create(0);
end;

end.
