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

const
  { Types of a TColor. }
  ctDefault = $0;
  ctBIOS = $1;
  ctRGB = $2;
  ctXTerm = $3;

  { Masks of the fields of a TColorAttr. }
  fgMask = $7FFFFFF;
  bgMask = $7FFFFFF;
  styleMask = $3FF;

  { The attribute that stands for "not a BIOS attribute". }
  InvalidBiosAttr = $5F;

  HuePrecision = 32;
  HueMax = 6 * HuePrecision;

type
  THCL = record
    H: Byte; { [0..HueMax) }
    C: Byte; { [0..255] }
    L: Byte; { [0..255] }
  end;

var
  XTerm256toXTerm16LUT: array[0..255] of Byte;
  XTerm256toRGBLUT: array[0..255] of Cardinal;

procedure Extremes(R, G, B: Byte; out Lo, Hi: Byte);
begin
  Lo := R;
  Hi := R;
  if G < Lo then
    Lo := G;
  if G > Hi then
    Hi := G;
  if B < Lo then
    Lo := B;
  if B > Hi then
    Hi := B;
end;

{ TColorRGB }

constructor TColorRGB.Create(R, G, B: Byte);
begin
  FBlue := B;
  FGreen := G;
  FRed := R;
end;

constructor TColorRGB.Create(Rgb: Cardinal);
begin
  FBlue := Byte(Rgb);
  FGreen := Byte(Rgb shr 8);
  FRed := Byte(Rgb shr 16);
end;

function TColorRGB.GetRed: Byte;
begin
  Result := FRed;
end;

procedure TColorRGB.SetRed(R: Byte);
begin
  FRed := R;
end;

function TColorRGB.GetGreen: Byte;
begin
  Result := FGreen;
end;

procedure TColorRGB.SetGreen(G: Byte);
begin
  FGreen := G;
end;

function TColorRGB.GetBlue: Byte;
begin
  Result := FBlue;
end;

procedure TColorRGB.SetBlue(B: Byte);
begin
  FBlue := B;
end;

class operator TColorRGB.:=(const C: TColorRGB): Cardinal;
begin
  Result := (Cardinal(C.FRed) shl 16) or (Cardinal(C.FGreen) shl 8) or C.FBlue;
end;

{ TColorBIOS }

constructor TColorBIOS.Create(Irgb: Byte);
begin
  FBits := Irgb and $F;
end;

function TColorBIOS.GetRed: Boolean;
begin
  Result := (FBits and $4) <> 0;
end;

procedure TColorBIOS.SetRed(R: Boolean);
begin
  if R then
    FBits := FBits or $4
  else
    FBits := FBits and not $4;
end;

function TColorBIOS.GetGreen: Boolean;
begin
  Result := (FBits and $2) <> 0;
end;

procedure TColorBIOS.SetGreen(G: Boolean);
begin
  if G then
    FBits := FBits or $2
  else
    FBits := FBits and not $2;
end;

function TColorBIOS.GetBlue: Boolean;
begin
  Result := (FBits and $1) <> 0;
end;

procedure TColorBIOS.SetBlue(B: Boolean);
begin
  if B then
    FBits := FBits or $1
  else
    FBits := FBits and not $1;
end;

function TColorBIOS.GetIntensity: Boolean;
begin
  Result := (FBits and $8) <> 0;
end;

procedure TColorBIOS.SetIntensity(I: Boolean);
begin
  if I then
    FBits := FBits or $8
  else
    FBits := FBits and not $8;
end;

class operator TColorBIOS.:=(const C: TColorBIOS): Byte;
begin
  Result := C.FBits;
end;

{ TColorXTerm }

constructor TColorXTerm.Create(Idx: Byte);
begin
  FIdx := Idx;
end;

class operator TColorXTerm.:=(const C: TColorXTerm): Byte;
begin
  Result := C.FIdx;
end;

{ Conversion from RGB to the 16 colors of XTerm. The color is taken to hue, chroma and lightness; the chroma
  decides between a color and a gray, the lightness picks the level, and the hue picks the color. }

function RGBtoHCL(R, G, B: Byte): THCL;
var
  Xmin, Xmax: Byte;
  Hue: Integer;
begin
  Extremes(R, G, B, Xmin, Xmax);
  Result.L := (Xmax + Xmin) div 2;
  Result.C := Xmax - Xmin;
  Hue := 0;
  if Result.C <> 0 then
  begin
    if Xmax = R then
      Hue := (HuePrecision * (Integer(G) - Integer(B))) div Result.C
    else if Xmax = G then
      Hue := (HuePrecision * (Integer(B) - Integer(R))) div Result.C + 2 * HuePrecision
    else if Xmax = B then
      Hue := (HuePrecision * (Integer(R) - Integer(G))) div Result.C + 4 * HuePrecision;
    if Hue < 0 then
      Hue := Hue + HueMax
    else if Hue >= HueMax then
      Hue := Hue - HueMax;
  end;
  Result.H := Byte(Hue);
end;

function ToByteScale(D: Double): Byte;
begin
  Result := Trunc(D * 255);
end;

function RGBtoXTerm16Impl(R, G, B: Byte): Byte;
var
  Col: THCL;
  Sector: Integer;
  Hues: array[0..5] of Byte;
begin
  Col := RGBtoHCL(R, G, B);
  if Col.C >= 12 then
  begin
    { A color: Chroma is at least 12. }
    Hues[0] := 1;
    Hues[1] := 3;
    Hues[2] := 2;
    Hues[3] := 6;
    Hues[4] := 4;
    Hues[5] := 5;
    if Col.H < HueMax - HuePrecision div 2 then
      Sector := (Col.H + HuePrecision div 2) div HuePrecision
    else
      Sector := (Col.H - (HueMax - HuePrecision div 2)) div HuePrecision;
    if Col.L < ToByteScale(0.5) then
      Result := Hues[Sector]
    else if Col.L < ToByteScale(0.925) then
      Result := Hues[Sector] + 8 { Bright: 9, 11, 10, 14, 12, 13. }
    else
      Result := 15;
  end
  else
  begin
    if Col.L < ToByteScale(0.25) then
      Result := 0
    else if Col.L < ToByteScale(0.625) then
      Result := 8
    else if Col.L < ToByteScale(0.875) then
      Result := 7
    else
      Result := 15;
  end;
end;

{ The channel values of the 6x6x6 cube are 0, 95, 135, 175, 215 and 255. }
function CubeLevel(Step: Integer): Byte;
begin
  if Step = 0 then
    Result := 0
  else
    Result := 55 + Step * 40;
end;

{ The gray ramp has 24 steps, 8 to 238 by 10. }
function RampLevel(Step: Integer): Byte;
begin
  Result := Step * 10 + 8;
end;

procedure InitLookupTables;
var
  I, J, K, Idx: Integer;
  R, G, B, L: Byte;
begin
  FillChar(XTerm256toRGBLUT, SizeOf(XTerm256toRGBLUT), 0);
  for I := 0 to 15 do
    XTerm256toXTerm16LUT[I] := I;
  for I := 0 to 5 do
    for J := 0 to 5 do
      for K := 0 to 5 do
      begin
        R := CubeLevel(I);
        G := CubeLevel(J);
        B := CubeLevel(K);
        Idx := 16 + (I * 6 + J) * 6 + K;
        XTerm256toXTerm16LUT[Idx] := RGBtoXTerm16Impl(R, G, B);
        XTerm256toRGBLUT[Idx] := (Cardinal(R) shl 16) or (Cardinal(G) shl 8) or B;
      end;
  for I := 0 to 23 do
  begin
    L := RampLevel(I);
    XTerm256toXTerm16LUT[232 + I] := RGBtoXTerm16Impl(L, L, L);
    XTerm256toRGBLUT[232 + I] := (Cardinal(L) shl 16) or (Cardinal(L) shl 8) or L;
  end;
end;

{ TColorConversion }

class function TColorConversion.BIOStoXTerm16(C: TColorBIOS): TColorXTerm;
var
  Swapped: Boolean;
  V: Byte;
begin
  { The red and blue bits trade places. }
  Swapped := C.GetBlue;
  C.SetBlue(C.GetRed);
  C.SetRed(Swapped);
  V := C;
  Result := TColorXTerm.Create(V);
end;

class function TColorConversion.XTerm16toBIOS(Idx: TColorXTerm): TColorBIOS;
var
  V: Byte;
begin
  V := Idx;
  V := BIOStoXTerm16(TColorBIOS.Create(V));
  Result := TColorBIOS.Create(V);
end;

class function TColorConversion.XTerm256toXTerm16(Idx: TColorXTerm): TColorXTerm;
var
  V: Byte;
begin
  V := Idx;
  Result := TColorXTerm.Create(XTerm256toXTerm16LUT[V]);
end;

class function TColorConversion.XTerm256toRGB(Idx: TColorXTerm): TColorRGB;
var
  V: Byte;
begin
  V := Idx;
  Result := TColorRGB.Create(XTerm256toRGBLUT[V]);
end;

class function TColorConversion.RGBtoXTerm16(C: TColorRGB): TColorXTerm;
begin
  Result := TColorXTerm.Create(RGBtoXTerm16Impl(C.GetRed, C.GetGreen, C.GetBlue));
end;

{ A channel to a step of the 6x6x6 cube. Dark colors are underrepresented in the cube, so the values below 75
  are raised by 20 before the division. }
function CubeStep(Value: Byte): Byte;
begin
  if Value < 75 then
    Value := Value + 20;
  if Value < 35 then
    Value := 35;
  Result := (Value - 35) div 40;
end;

{ A lightness to a step of the gray ramp, or to the black or the white of the cube at both ends. }
function GrayIndex(L: Byte): Byte;
begin
  if L < 3 then
    Result := 16
  else if L >= 243 then
    Result := 231
  else
    Result := 232 + (L - 3) div 10;
end;

class function TColorConversion.RGBtoXTerm256(C: TColorRGB): TColorXTerm;
var
  Idx, Xmin, Xmax, Chroma, Light: Byte;
  Cube, Back: Cardinal;
begin
  Idx := 16 + (CubeStep(C.GetRed) * 6 + CubeStep(C.GetGreen)) * 6 + CubeStep(C.GetBlue);
  Cube := C;
  Back := XTerm256toRGB(TColorXTerm.Create(Idx));
  if Cube <> Back then
  begin
    Extremes(C.GetRed, C.GetGreen, C.GetBlue, Xmin, Xmax);
    Chroma := Xmax - Xmin;
    { Low chroma, or a color that the cube would round to black, goes to the grays. }
    if (Chroma < 12) or (Idx = 16) then
    begin
      Light := (Xmax + Xmin) div 2;
      Idx := GrayIndex(Light);
    end;
  end;
  Result := TColorXTerm.Create(Idx);
end;

{ TColor }

function TColor.ColorType: Byte;
begin
  Result := Byte(FData shr 24);
end;

constructor TColor.Create(Bios: Char);
begin
  FData := Cardinal(Ord(Bios) and $F) or (ctBIOS shl 24);
end;

constructor TColor.Create(Rgb: Integer);
begin
  FData := Cardinal(Rgb and $FFFFFF) or (ctRGB shl 24);
end;

constructor TColor.Create(Bios: TColorBIOS);
var
  V: Byte;
begin
  V := Bios;
  FData := Cardinal(V and $F) or (ctBIOS shl 24);
end;

constructor TColor.Create(Rgb: TColorRGB);
var
  V: Cardinal;
begin
  V := Rgb;
  FData := (V and $FFFFFF) or (ctRGB shl 24);
end;

constructor TColor.Create(XTerm: TColorXTerm);
var
  V: Byte;
begin
  V := XTerm;
  FData := V or (ctXTerm shl 24);
end;

constructor TColor.Create(Def: TColorDefault);
begin
  FData := ctDefault;
end;

function TColor.IsDefault: Boolean;
begin
  Result := ColorType = ctDefault;
end;

function TColor.IsBIOS: Boolean;
begin
  Result := ColorType = ctBIOS;
end;

function TColor.IsRGB: Boolean;
begin
  Result := ColorType = ctRGB;
end;

function TColor.IsXTerm: Boolean;
begin
  Result := ColorType = ctXTerm;
end;

function TColor.AsBIOS: TColorBIOS;
begin
  Result := TColorBIOS.Create(Byte(FData));
end;

function TColor.AsRGB: TColorRGB;
begin
  Result := TColorRGB.Create(FData);
end;

function TColor.AsXTerm: TColorXTerm;
begin
  Result := TColorXTerm.Create(Byte(FData));
end;

function TColor.ToBIOS(IsForeground: Boolean): TColorBIOS;
var
  Idx: Byte;
begin
  case ColorType of
    ctBIOS:
      Result := AsBIOS;
    ctRGB:
      Result := TColorConversion.XTerm16toBIOS(TColorConversion.RGBtoXTerm16(AsRGB));
    ctXTerm:
      begin
        Idx := AsXTerm;
        if Idx >= 16 then
          Idx := TColorConversion.XTerm256toXTerm16(TColorXTerm.Create(Idx));
        Result := TColorConversion.XTerm16toBIOS(TColorXTerm.Create(Idx));
      end;
  else
    if IsForeground then
      Result := TColorBIOS.Create(7)
    else
      Result := TColorBIOS.Create(0);
  end;
end;

class operator TColor.=(const One, Two: TColor): Boolean;
begin
  Result := One.FData = Two.FData;
end;

class operator TColor.<>(const One, Two: TColor): Boolean;
begin
  Result := One.FData <> Two.FData;
end;

{ TColorAttr }

constructor TColorAttr.Create(Bios: Integer);
var
  Fg, Bg: TColor;
begin
  Fg := TColor.Create(Char(Byte(Bios)));
  Bg := TColor.Create(Char(Byte(Bios shr 4)));
  FData := QWord(Fg.FData and fgMask) or (QWord(Bg.FData and bgMask) shl 27);
end;

constructor TColorAttr.Create(Fg, Bg: TColor; Style: Word);
begin
  FData := QWord(Fg.FData and fgMask) or (QWord(Bg.FData and bgMask) shl 27) or (QWord(Style) shl 54);
end;

function TColorAttr.GetForeground: TColor;
begin
  Result.FData := Cardinal(FData and fgMask);
end;

procedure TColorAttr.SetForeground(Fg: TColor);
begin
  FData := (FData and not QWord(fgMask)) or QWord(Fg.FData and fgMask);
end;

function TColorAttr.GetBackground: TColor;
begin
  Result.FData := Cardinal((FData shr 27) and bgMask);
end;

procedure TColorAttr.SetBackground(Bg: TColor);
begin
  FData := (FData and not (QWord(bgMask) shl 27)) or (QWord(Bg.FData and bgMask) shl 27);
end;

function TColorAttr.GetStyle: Word;
begin
  Result := Word(FData shr 54);
end;

procedure TColorAttr.SetStyle(AStyle: Word);
begin
  FData := (FData and not (QWord(styleMask) shl 54)) or (QWord(AStyle) shl 54);
end;

function TColorAttr.Reversed: TColorAttr;
var
  Fg, Bg: TColor;
begin
  Fg := GetForeground;
  Bg := GetBackground;
  { The slReverse style may look different in different terminal emulators, so the colors trade places unless
    one of them is the default color. }
  if Fg.IsDefault or Bg.IsDefault then
    Result := TColorAttr.Create(Fg, Bg, GetStyle xor slReverse)
  else
    Result := TColorAttr.Create(Bg, Fg, GetStyle);
end;

function TColorAttr.ToBIOS: Byte;
var
  Fg, Bg: TColor;
  Low, High: Byte;
begin
  Fg := GetForeground;
  Bg := GetBackground;
  Low := Fg.ToBIOS(True);
  High := Bg.ToBIOS(False);
  Result := Low or (Integer(High) shl 4);
end;

class operator TColorAttr.:=(const A: TColorAttr): Byte;
var
  Fg, Bg: TColor;
  Low, High: Byte;
begin
  { Unless the value is a BIOS attribute, the result is a fixed one that is not 0, so that a comparison
    against 0 in old code keeps working. }
  Fg := A.GetForeground;
  Bg := A.GetBackground;
  if Fg.IsBIOS and Bg.IsBIOS and (A.GetStyle = 0) then
  begin
    Low := Fg.AsBIOS;
    High := Bg.AsBIOS;
    Result := Low or (Integer(High) shl 4);
  end
  else
    Result := InvalidBiosAttr;
end;

class operator TColorAttr.=(const One, Two: TColorAttr): Boolean;
begin
  Result := One.FData = Two.FData;
end;

class operator TColorAttr.<>(const One, Two: TColorAttr): Boolean;
begin
  Result := One.FData <> Two.FData;
end;

class operator TColorAttr.=(const One: TColorAttr; Bios: Integer): Boolean;
var
  Other: TColorAttr;
begin
  Other := TColorAttr.Create(Bios and $FF);
  Result := One.FData = Other.FData;
end;

class operator TColorAttr.<>(const One: TColorAttr; Bios: Integer): Boolean;
var
  Other: TColorAttr;
begin
  Other := TColorAttr.Create(Bios and $FF);
  Result := One.FData <> Other.FData;
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
  FAttrs[0] := Low;
  FAttrs[1] := High;
end;

constructor TAttrPair.Create(Bios: Integer);
begin
  FAttrs[0] := TColorAttr.Create(Bios and $FF);
  FAttrs[1] := TColorAttr.Create((Bios shr 8) and $FF);
end;

class operator TAttrPair.:=(const P: TAttrPair): Word;
var
  Low, High: Byte;
begin
  Low := P.FAttrs[0];
  High := P.FAttrs[1];
  Result := Low or (Integer(High) shl 8);
end;

function TAttrPair.ShiftRight(Shift: Integer): TAttrPair;
var
  Both: Word;
begin
  { Old code may take the high attribute with a shift by 8. }
  if Shift = 8 then
    Result := TAttrPair.Create(FAttrs[1], TColorAttr.Create(0))
  else
  begin
    Both := Self;
    Result := TAttrPair.Create(Integer(Both) shr Shift);
  end;
end;

function TAttrPair.OrAssign(const Attr: TColorAttr): TAttrPair;
var
  Low, Extra: Byte;
  Zero: TColorAttr;
begin
  Zero := TColorAttr.Create(0);
  { Old code may set the low attribute with an or, when that attribute is the BIOS attribute 0. In any other
    case this is an or of the two BIOS attributes. }
  if FAttrs[0] = Zero then
    FAttrs[0] := Attr
  else
  begin
    Low := FAttrs[0];
    Extra := Attr;
    FAttrs[0] := TColorAttr.Create(Low or Extra);
  end;
  Result := Self;
end;

class function TAttrPair.ShiftedLeft(const Attr: TColorAttr; Shift: Integer): TAttrPair;
var
  Low: Byte;
begin
  { Old code may build a pair with a shift by 8. }
  if Shift = 8 then
    Result := TAttrPair.Create(TColorAttr.Create(0), Attr)
  else
  begin
    Low := Attr;
    Result := TAttrPair.Create(Integer(Low) shl Shift);
  end;
end;

initialization
  InitLookupTables;

end.
