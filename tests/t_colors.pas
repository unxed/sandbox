{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/colors.h, source/platform/colors.cpp
  See COPYRIGHT.magiblot. }
program t_colors;

{$mode objfpc}
{$modeswitch advancedrecords}

uses
  TvColors;

{$I testlib.inc}

function RgbValue(const C: TColorRGB): Cardinal;
begin
  Result := C;
end;

function BiosValue(const C: TColorBIOS): Byte;
begin
  Result := C;
end;

function XTermValue(const C: TColorXTerm): Byte;
begin
  Result := C;
end;

function AttrValue(const A: TColorAttr): Byte;
begin
  Result := A;
end;

function PairValue(const P: TAttrPair): Word;
begin
  Result := P;
end;

function Rgb(R, G, B: Byte): TColorRGB;
begin
  Result := TColorRGB.Create(R, G, B);
end;

function XTerm(Idx: Byte): TColorXTerm;
begin
  Result := TColorXTerm.Create(Idx);
end;

function Bios(Irgb: Byte): TColorBIOS;
begin
  Result := TColorBIOS.Create(Irgb);
end;

function To16(R, G, B: Byte): Byte;
begin
  Result := XTermValue(TColorConversion.RGBtoXTerm16(Rgb(R, G, B)));
end;

function To256(R, G, B: Byte): Byte;
begin
  Result := XTermValue(TColorConversion.RGBtoXTerm256(Rgb(R, G, B)));
end;

function Down16(Idx: Byte): Byte;
begin
  Result := XTermValue(TColorConversion.XTerm256toXTerm16(XTerm(Idx)));
end;

function Up(Idx: Byte): Cardinal;
begin
  Result := RgbValue(TColorConversion.XTerm256toRGB(XTerm(Idx)));
end;

var
  F1, G1: TColor;

procedure Split(const At: TColorAttr);
begin
  F1 := At.GetForeground;
  G1 := At.GetBackground;
end;

function Quant(const Col: TColor; IsFg: Boolean): Byte;
begin
  Result := Col.ToBIOS(IsFg);
end;

const
  Swapped: array[0..15] of Byte = (0, 4, 2, 6, 1, 5, 3, 7, 8, 12, 10, 14, 9, 13, 11, 15);

var
  R: TColorRGB;
  B: TColorBIOS;
  X: TColorXTerm;
  Def: TColorDefault;
  C, C2, CDef: TColor;
  A, A2, A3, AZero: TColorAttr;
  P, P2: TAttrPair;
  I: Integer;
  Ok: Boolean;

begin
  { TColorRGB }
  R := TColorRGB.Create(127, 0, 187);
  Check(RgbValue(R) = $7F00BB, 'rgb from components');
  Check((R.GetRed = 127) and (R.GetGreen = 0) and (R.GetBlue = 187), 'rgb getters');
  R := TColorRGB.Create($7F00BB);
  Check((R.GetRed = $7F) and (R.GetGreen = $00) and (R.GetBlue = $BB), 'rgb from integer');
  R := TColorRGB.Create($AABBCCDD);
  Check(RgbValue(R) = $BBCCDD, 'rgb drops the unused bits');
  Check((R.GetRed = $BB) and (R.GetGreen = $CC) and (R.GetBlue = $DD), 'rgb components of a wide integer');
  R.SetRed($11);
  Check(RgbValue(R) = $11CCDD, 'rgb SetRed');
  R.SetGreen($22);
  Check(RgbValue(R) = $1122DD, 'rgb SetGreen');
  R.SetBlue($33);
  Check(RgbValue(R) = $112233, 'rgb SetBlue');
  FillChar(R, SizeOf(R), 0);
  Check(RgbValue(R) = 0, 'rgb zero is black');

  { TColorBIOS }
  B := TColorBIOS.Create($AB);
  Check(BiosValue(B) = $B, 'bios drops the unused bits');
  Check(B.GetBlue and B.GetGreen and (not B.GetRed) and B.GetIntensity, 'bios flags of 1011');
  B := TColorBIOS.Create(0);
  Check(BiosValue(B) = 0, 'bios black');
  B.SetBlue(True);
  Check(BiosValue(B) = 1, 'bios SetBlue');
  B.SetGreen(True);
  Check(BiosValue(B) = 3, 'bios SetGreen');
  B.SetRed(True);
  Check(BiosValue(B) = 7, 'bios SetRed');
  B.SetIntensity(True);
  Check(BiosValue(B) = 15, 'bios SetIntensity');
  B.SetGreen(False);
  Check(BiosValue(B) = 13, 'bios clear green');
  B.SetBlue(False);
  Check(BiosValue(B) = 12, 'bios clear blue');
  B.SetRed(False);
  Check(BiosValue(B) = 8, 'bios clear red');
  B.SetIntensity(False);
  Check(BiosValue(B) = 0, 'bios clear intensity');
  Check(BiosValue(TColorBIOS.Create($C)) = $C, 'bios light red');

  { TColorXTerm }
  X := TColorXTerm.Create($FE);
  Check(XTermValue(X) = $FE, 'xterm index');
  Check(XTermValue(TColorXTerm.Create(0)) = 0, 'xterm index 0');

  { conversions between BIOS and the 16 colors of XTerm }
  Ok := True;
  for I := 0 to 15 do
    if XTermValue(TColorConversion.BIOStoXTerm16(Bios(I))) <> Swapped[I] then
      Ok := False;
  Check(Ok, 'BIOStoXTerm16 swaps red and blue');
  Ok := True;
  for I := 0 to 15 do
    if BiosValue(TColorConversion.XTerm16toBIOS(XTerm(I))) <> Swapped[I] then
      Ok := False;
  Check(Ok, 'XTerm16toBIOS swaps red and blue');
  Ok := True;
  for I := 0 to 15 do
    if BiosValue(TColorConversion.XTerm16toBIOS(TColorConversion.BIOStoXTerm16(Bios(I)))) <> I then
      Ok := False;
  Check(Ok, 'BIOS to XTerm16 and back');

  { XTerm256 to XTerm16 }
  Ok := True;
  for I := 0 to 15 do
    if Down16(I) <> I then
      Ok := False;
  Check(Ok, 'XTerm256toXTerm16 keeps indices 0-15');
  Check(Down16(16) = 0, 'XTerm256toXTerm16 16 black');
  Check(Down16(231) = 15, 'XTerm256toXTerm16 231 white');
  Check(Down16(196) = 9, 'XTerm256toXTerm16 196 red');
  Check(Down16(46) = 10, 'XTerm256toXTerm16 46 green');
  Check(Down16(226) = 11, 'XTerm256toXTerm16 226 yellow');
  Check(Down16(21) = 12, 'XTerm256toXTerm16 21 blue');
  Check(Down16(201) = 13, 'XTerm256toXTerm16 201 magenta');
  Check(Down16(51) = 14, 'XTerm256toXTerm16 51 cyan');
  Check(Down16(232) = 0, 'XTerm256toXTerm16 232 dark gray ramp');
  Check(Down16(244) = 8, 'XTerm256toXTerm16 244 gray ramp');
  Check(Down16(250) = 7, 'XTerm256toXTerm16 250 light gray ramp');
  Check(Down16(255) = 15, 'XTerm256toXTerm16 255 white ramp');

  { XTerm256 to RGB }
  Check(Up(16) = $000000, 'XTerm256toRGB 16');
  Check(Up(231) = $FFFFFF, 'XTerm256toRGB 231');
  Check(Up(196) = $FF0000, 'XTerm256toRGB 196');
  Check(Up(21) = $0000FF, 'XTerm256toRGB 21');
  Check(Up(67) = $5F87AF, 'XTerm256toRGB 67');
  Check(Up(232) = $080808, 'XTerm256toRGB 232');
  Check(Up(244) = $808080, 'XTerm256toRGB 244');
  Check(Up(255) = $EEEEEE, 'XTerm256toRGB 255');
  Check(Up(5) = 0, 'XTerm256toRGB has no color for indices 0-15');

  { RGB to XTerm16 }
  Check(To16(0, 0, 0) = 0, 'RGBtoXTerm16 black');
  Check(To16(255, 255, 255) = 15, 'RGBtoXTerm16 white');
  Check(To16(255, 0, 0) = 9, 'RGBtoXTerm16 bright red');
  Check(To16(0, 255, 0) = 10, 'RGBtoXTerm16 bright green');
  Check(To16(255, 255, 0) = 11, 'RGBtoXTerm16 bright yellow');
  Check(To16(0, 0, 255) = 12, 'RGBtoXTerm16 bright blue');
  Check(To16(255, 0, 255) = 13, 'RGBtoXTerm16 bright magenta');
  Check(To16(0, 255, 255) = 14, 'RGBtoXTerm16 bright cyan');
  Check(To16(128, 0, 0) = 1, 'RGBtoXTerm16 dark red');
  Check(To16(0, 0, 128) = 4, 'RGBtoXTerm16 dark blue');
  Check(To16(128, 128, 128) = 8, 'RGBtoXTerm16 gray');
  Check(To16(192, 192, 192) = 7, 'RGBtoXTerm16 light gray');
  Check(To16(100, 100, 100) = 8, 'RGBtoXTerm16 darker gray');
  Check(To16(30, 30, 30) = 0, 'RGBtoXTerm16 near black');
  Check(To16(130, 128, 128) = 8, 'RGBtoXTerm16 low chroma is gray');
  Check(To16(12, 0, 0) = 1, 'RGBtoXTerm16 chroma 12 is a color');
  Check(To16(11, 0, 0) = 0, 'RGBtoXTerm16 chroma 11 is gray');
  Check(To16(255, 250, 250) = 15, 'RGBtoXTerm16 bright low chroma');
  Check(To16(255, 200, 200) = 9, 'RGBtoXTerm16 light red stays bright red');
  Check(To16(255, 240, 240) = 15, 'RGBtoXTerm16 very light red is white');
  Check(RgbValue(TColorConversion.XTerm256toRGB(XTerm(196))) = $FF0000, 'XTerm256toRGB result is an RGB color');
  Check(XTermValue(TColorConversion.RGBtoXTerm16(Rgb(255, 0, 0))) = 9, 'RGBtoXTerm16 takes a TColorRGB');

  { RGB to XTerm256 }
  Check(To256(255, 0, 0) = 196, 'RGBtoXTerm256 red');
  Check(To256(0, 0, 0) = 16, 'RGBtoXTerm256 black');
  Check(To256(255, 255, 255) = 231, 'RGBtoXTerm256 white');
  Check(To256(95, 135, 175) = 67, 'RGBtoXTerm256 exact cube color');
  Check(To256(128, 128, 128) = 244, 'RGBtoXTerm256 gray');
  Check(To256(8, 8, 8) = 232, 'RGBtoXTerm256 first ramp gray');
  Check(To256(2, 2, 2) = 16, 'RGBtoXTerm256 almost black');
  Check(To256(250, 250, 250) = 231, 'RGBtoXTerm256 almost white');
  Check(To256(242, 242, 242) = 255, 'RGBtoXTerm256 last ramp gray');
  Check(To256(238, 238, 238) = 255, 'RGBtoXTerm256 exact last ramp gray');
  Check(To256(60, 0, 0) = 52, 'RGBtoXTerm256 dark red is raised');
  Check(To256(55, 0, 0) = 52, 'RGBtoXTerm256 55 is raised to the first step');
  Check(To256(54, 0, 0) = 234, 'RGBtoXTerm256 dark color rounded to black uses the ramp');
  Check(To256(20, 10, 5) = 232, 'RGBtoXTerm256 dark mixed color uses the ramp');
  Check(To256(100, 100, 110) = 242, 'RGBtoXTerm256 low chroma uses the ramp');

  { TColor }
  FillChar(CDef, SizeOf(CDef), 0);
  Check(CDef.IsDefault and not CDef.IsBIOS and not CDef.IsRGB and not CDef.IsXTerm, 'zero color is the default');
  C := TColor.Create(Def);
  Check(C.IsDefault, 'color from TColorDefault');
  Check(C = CDef, 'default colors are equal');
  C := TColor.Create(#15);
  Check(C.IsBIOS and not C.IsDefault and not C.IsRGB and not C.IsXTerm, 'color from char is BIOS');
  Check(BiosValue(C.AsBIOS) = 15, 'color BIOS value');
  C := TColor.Create(#$AF);
  Check(BiosValue(C.AsBIOS) = $F, 'color from char keeps the low four bits');
  C := TColor.Create($7F00BB);
  Check(C.IsRGB and not C.IsDefault and not C.IsBIOS and not C.IsXTerm, 'color from integer is RGB');
  Check(RgbValue(C.AsRGB) = $7F00BB, 'color RGB value');
  C := TColor.Create(-1);
  Check(RgbValue(C.AsRGB) = $FFFFFF, 'color from integer drops the unused bits');
  C := TColor.Create(Rgb(1, 2, 3));
  Check(C.IsRGB and (RgbValue(C.AsRGB) = $010203), 'color from TColorRGB');
  C := TColor.Create(Bios(5));
  Check(C.IsBIOS and (BiosValue(C.AsBIOS) = 5), 'color from TColorBIOS');
  C := TColor.Create(XTerm(200));
  Check(C.IsXTerm and not C.IsBIOS and not C.IsRGB and not C.IsDefault, 'color from TColorXTerm');
  Check(XTermValue(C.AsXTerm) = 200, 'color XTerm value');
  C := TColor.Create(#7);
  C2 := TColor.Create(Bios(7));
  Check(C = C2, 'equal BIOS colors');
  Check(not (C <> C2), 'equal BIOS colors are not different');
  Check(C <> TColor.Create($000007), 'BIOS and RGB colors differ');
  Check(C <> TColor.Create(XTerm(7)), 'BIOS and XTerm colors differ');
  Check(CDef <> TColor.Create(#0), 'default and BIOS 0 differ');

  { TColor.ToBIOS }
  Check(BiosValue(CDef.ToBIOS(True)) = 7, 'default foreground quantizes to 7');
  Check(BiosValue(CDef.ToBIOS(False)) = 0, 'default background quantizes to 0');
  Check(Quant(TColor.Create(#9), True) = 9, 'BIOS color keeps its value as foreground');
  Check(Quant(TColor.Create(#9), False) = 9, 'BIOS color keeps its value as background');
  Check(Quant(TColor.Create($FF0000), True) = 12, 'RGB red quantizes to light red');
  Check(Quant(TColor.Create($0000FF), True) = 9, 'RGB blue quantizes to light blue');
  Check(Quant(TColor.Create($000000), False) = 0, 'RGB black quantizes to 0');
  Check(Quant(TColor.Create($FFFFFF), False) = 15, 'RGB white quantizes to 15');
  Check(Quant(TColor.Create($808080), True) = 8, 'RGB gray quantizes to 8');
  Check(Quant(TColor.Create(XTerm(4)), True) = 1, 'XTerm 4 is BIOS 1');
  Check(Quant(TColor.Create(XTerm(196)), True) = 12, 'XTerm 196 quantizes to light red');
  Check(Quant(TColor.Create(XTerm(21)), False) = 9, 'XTerm 21 quantizes to light blue');
  Check(Quant(TColor.Create(XTerm(232)), False) = 0, 'XTerm 232 quantizes to 0');
  Check(Quant(TColor.Create(XTerm(255)), True) = 15, 'XTerm 255 quantizes to 15');

  { style masks }
  Check((slBold = $001) and (slItalic = $002) and (slUnderline = $004) and (slBlink = $008), 'style masks');
  Check((slReverse = $010) and (slStrike = $020) and (slWindowShadow = $200), 'style masks, second group');

  { TColorAttr }
  FillChar(AZero, SizeOf(AZero), 0);
  Split(AZero);
  Check(F1.IsDefault and G1.IsDefault and (AZero.GetStyle = 0),
    'zero attribute has default colors and no style');
  Check(AttrValue(AZero) = $5F, 'zero attribute is not a BIOS attribute');
  Check(AZero.ToBIOS = $07, 'zero attribute quantizes to white on black');
  A := TColorAttr.Create($3D);
  Split(A);
  Check(F1.IsBIOS and (BiosValue(F1.AsBIOS) = $D), 'attribute from BIOS, foreground');
  Split(A);
  Check(G1.IsBIOS and (BiosValue(G1.AsBIOS) = $3), 'attribute from BIOS, background');
  Check(A.GetStyle = 0, 'attribute from BIOS, style');
  Check(AttrValue(A) = $3D, 'attribute to BIOS byte');
  Check(A.ToBIOS = $3D, 'attribute ToBIOS');
  Check(A = $3D, 'attribute equals the BIOS integer');
  Check(not (A <> $3D), 'attribute is not different from the BIOS integer');
  Check(A <> $3E, 'attribute differs from another BIOS integer');
  Check(A = TColorAttr.Create($3D), 'equal attributes');
  Check(A <> TColorAttr.Create($3E), 'different attributes');
  A2 := TColorAttr.Create(0);
  Check(A2 = 0, 'attribute 0 equals 0');
  Check(AttrValue(A2) = 0, 'attribute 0 to BIOS byte');
  Check(A2 <> AZero, 'BIOS attribute 0 differs from the zero attribute');
  Check(TColorAttr.Create($1FF3D) = $3D, 'BIOS integer comparison keeps the low byte');

  A := TColorAttr.Create(TColor.Create(#7), TColor.Create($7F00BB), slBold or slItalic);
  Split(A);
  Check(F1.IsBIOS and (BiosValue(F1.AsBIOS) = 7), 'attribute foreground');
  Split(A);
  Check(G1.IsRGB and (RgbValue(G1.AsRGB) = $7F00BB), 'attribute background');
  Check(A.GetStyle = (slBold or slItalic), 'attribute style');
  Check(AttrValue(A) = $5F, 'attribute that is not BIOS gives 5F');
  Check(A.ToBIOS = $57, 'attribute ToBIOS ignores the style and quantizes');
  A2 := TColorAttr.Create(TColor.Create(#7), TColor.Create(#1), slBold);
  Check(AttrValue(A2) = $5F, 'BIOS colors with a style give 5F');
  A2 := TColorAttr.Create(TColor.Create(#7), TColor.Create(#1));
  Check(AttrValue(A2) = $17, 'attribute without style argument');
  Check(A2.GetStyle = 0, 'style defaults to 0');

  A2 := A;
  A2.SetStyle(slUnderline);
  Check(A2.GetStyle = slUnderline, 'SetStyle');
  Split(A2);
  Check(RgbValue(G1.AsRGB) = $7F00BB, 'SetStyle keeps the background');
  Split(A2);
  Check(BiosValue(F1.AsBIOS) = 7, 'SetStyle keeps the foreground');
  A2.SetStyle($FFFF);
  Check(A2.GetStyle = $3FF, 'style has ten bits');
  Split(A2);
  Check(RgbValue(G1.AsRGB) = $7F00BB, 'wide style keeps the background');
  A2.SetForeground(TColor.Create($123456));
  Split(A2);
  Check(F1.IsRGB and (RgbValue(F1.AsRGB) = $123456), 'SetForeground');
  Split(A2);
  Check(RgbValue(G1.AsRGB) = $7F00BB, 'SetForeground keeps the background');
  Check(A2.GetStyle = $3FF, 'SetForeground keeps the style');
  A2.SetBackground(TColor.Create(XTerm(99)));
  Split(A2);
  Check(G1.IsXTerm and (XTermValue(G1.AsXTerm) = 99), 'SetBackground');
  Split(A2);
  Check(RgbValue(F1.AsRGB) = $123456, 'SetBackground keeps the foreground');
  Check(A2.GetStyle = $3FF, 'SetBackground keeps the style');
  A2.SetForeground(CDef);
  Split(A2);
  Check(F1.IsDefault and G1.IsXTerm, 'SetForeground to the default color');

  { TColorAttr.Reversed }
  A2 := A.Reversed;
  Split(A2);
  Check(F1.IsRGB and (RgbValue(F1.AsRGB) = $7F00BB), 'Reversed swaps, foreground');
  Split(A2);
  Check(G1.IsBIOS and (BiosValue(G1.AsBIOS) = 7), 'Reversed swaps, background');
  Check(A2.GetStyle = (slBold or slItalic), 'Reversed keeps the style');
  A3 := A2.Reversed;
  Check(A3 = A, 'Reversed twice');
  A2 := TColorAttr.Create(CDef, TColor.Create(#15));
  A3 := A2.Reversed;
  Check(A3.GetForeground = A2.GetForeground, 'Reversed with a default color keeps the foreground');
  Check(A3.GetBackground = A2.GetBackground, 'Reversed with a default color keeps the background');
  Check(A3.GetStyle = slReverse, 'Reversed with a default color sets slReverse');
  A3 := A3.Reversed;
  Check(A3 = A2, 'Reversed with a default color toggles slReverse');
  A3 := TColorAttr.Create(TColor.Create(#15), CDef, slBold);
  A3 := A3.Reversed;
  Check(A3.GetStyle = (slBold or slReverse), 'Reversed with a default background');
  A3 := AZero.Reversed;
  Check(A3.GetStyle = slReverse, 'Reversed zero attribute');

  { TAttrPair }
  P := TAttrPair.Create($1F2E);
  Check(AttrValue(P.Attrs[0]) = $2E, 'pair from BIOS, low');
  Check(AttrValue(P.Attrs[1]) = $1F, 'pair from BIOS, high');
  Check(PairValue(P) = $1F2E, 'pair to BIOS word');
  P2 := TAttrPair.Create(TColorAttr.Create($12), TColorAttr.Create($34));
  Check(PairValue(P2) = $3412, 'pair from two attributes');
  Check(P2.Attrs[0] = $12, 'pair low attribute');
  Check(P2.Attrs[1] = $34, 'pair high attribute');
  P2.Attrs[1] := TColorAttr.Create($56);
  Check(PairValue(P2) = $5612, 'pair set attribute');
  P2 := TAttrPair.Create(A, A2);
  Check((P2.Attrs[0] = A) and (P2.Attrs[1] = A2), 'pair keeps attributes that are not BIOS');
  P2 := P.ShiftRight(8);
  Check(P2.Attrs[0] = P.Attrs[1], 'pair shifted by 8 holds the high attribute');
  Check(P2.Attrs[1] = 0, 'pair shifted by 8 has the BIOS attribute 0 as high');
  Check(PairValue(P2) = $001F, 'pair shifted by 8 as a word');
  Check(PairValue(P.ShiftRight(4)) = $01F2, 'pair shifted by 4');
  Check(PairValue(P.ShiftRight(0)) = $1F2E, 'pair shifted by 0');
  P2 := TAttrPair.ShiftedLeft(TColorAttr.Create($2E), 8);
  Check((P2.Attrs[0] = 0) and (P2.Attrs[1] = $2E), 'attribute shifted by 8 is the high attribute');
  Check(PairValue(P2) = $2E00, 'attribute shifted by 8 as a word');
  Check(PairValue(TAttrPair.ShiftedLeft(TColorAttr.Create($2E), 4)) = $02E0, 'attribute shifted by 4');
  P2 := TAttrPair.Create(0);
  P2.OrAssign(A);
  Check(P2.Attrs[0] = A, 'or into the BIOS attribute 0 sets the attribute');
  P2 := TAttrPair.Create($0F);
  P2.OrAssign(TColorAttr.Create($30));
  Check(PairValue(P2) = $003F, 'or of two BIOS attributes');
  P2 := TAttrPair.Create($0F);
  P2.OrAssign(A);
  Check(AttrValue(P2.Attrs[0]) = (($0F) or $5F), 'or with an attribute that is not BIOS');
  P2 := TAttrPair.Create($1100);
  P2 := P2.OrAssign(TColorAttr.Create($05));
  Check(PairValue(P2) = $1105, 'OrAssign result keeps the high attribute');

  Done;
end.
