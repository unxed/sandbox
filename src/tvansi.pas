{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/internal/ansiwrit.h, source/platform/ansiwrit.cpp
  See COPYRIGHT.magiblot.

  The writer produces bytes into a buffer and has no operating system calls. Flush returns the bytes of the buffer
  and empties it, where the C++ writes them to the console, and the destructor of the writer does not write
  anything. The detection of the capabilities of a display (TermCap::getDisplayCapabilities) is not part of the
  unit, because it reads the environment, the console and the display adapter. The conversions of a TermColor and
  of a result of a color conversion to and from a 32-bit integer are not part of it either; the records compare
  field by field. The decimal numbers of the sequences are written by the unit itself.

  The enumerators of the color types are tctDefault, tctIndexed, tctRGB and tctNoColor, because NoColor is also an
  enumerator of the color levels of a terminal. The text of a cell is a string of bytes. }
unit TvAnsi;

{$mode objfpc}
{$modeswitch advancedrecords}
{$H+}
{$R-}
{$Q-}

interface

uses
  TvGeom, TvColors;

const
  { Terminal quirk flags. }
  qfBoldIsBright = $0001;
  qfBlinkIsBright = $0002;
  qfNoItalic = $0004;
  qfNoUnderline = $0008;

type
  { The kinds of a color that is printed to the screen with ANSI escape sequences. }
  TTermColorType = (tctDefault, tctIndexed, tctRGB, tctNoColor);

  { A color that is printed to the screen with ANSI escape sequences. Idx is meaningful for an indexed color and
    Bgr (blue first) for an RGB color; the other fields are zero. A zero-initialized value is the default color. }
  TTermColor = record
    Kind: TTermColorType;
    Idx: Byte;
    Bgr: array[0..2] of Byte;
    constructor Create(AIdx: Byte; AKind: TTermColorType); overload;
    constructor Create(C: TColorRGB; AKind: TTermColorType); overload;
    constructor Create(AKind: TTermColorType); overload;
    class operator =(const One, Two: TTermColor): Boolean;
    class operator <>(const One, Two: TTermColor): Boolean;
  end;

  TTermAttr = record
    Fg, Bg: TTermColor;
    Style: Word;
  end;

  { The number of colors of a terminal. }
  TTermCapColors = (NoColor, Indexed8, Indexed16, Indexed256, Direct, TermCapColorCount);

  TTermCap = record
    Colors: TTermCapColors;
    Quirks: Word;
  end;

  { The bytes that are waiting to be written to the terminal. }
  TAnsiBuffer = record
  private
    FData: string;
    FLen: SizeInt;
  public
    function Size: SizeInt;
    procedure Clear;
    procedure Reserve(ExtraCapacity: SizeInt);
    procedure Push(const S: string);
    procedure PushChar(C: Char);
    { Appends the decimal digits of an unsigned number. }
    procedure PushDecimal(Value: Cardinal);
    function EndsWith(C: Char): Boolean;
    procedure ReplaceLast(C: Char);
    procedure DropLast(Count: SizeInt);
    function Bytes: string;
  end;

  { Allows printing characters and color attributes directly to the screen using ANSI escape codes. }
  TAnsiScreenWriter = class
  private
    FTermCap: TTermCap;
    FBuf: TAnsiBuffer;
    FCaretPos: TPoint;
    FLastAttr: TTermAttr;
    procedure BufWriteCSI1(A: Integer; F: Char);
    procedure BufWriteCSI2(A, B: Integer; F: Char);
  public
    constructor Create(ATermCap: TTermCap);
    procedure Reset;
    procedure ClearScreen;
    procedure WriteCell(Pos: TPoint; const Text: string; Attr: TColorAttr; DoubleWidth: Boolean);
    procedure SetCaretPosition(Pos: TPoint);
    { Returns the bytes written since the last call and empties the buffer. }
    function Flush: string;
  end;

implementation

const
  { The control sequence introducer. }
  CSI = #27'[';

type
  { The result of a color conversion: the color and the style flags that stand in for what the terminal lacks. }
  TColorConvResult = record
    Color: TTermColor;
    ExtraStyle: Word;
    constructor Create(const AColor: TTermColor; AExtraStyle: Word = 0);
  end;

{ TTermColor }

constructor TTermColor.Create(AIdx: Byte; AKind: TTermColorType);
begin
  FillChar(Self, SizeOf(Self), 0);
  Idx := AIdx;
  Kind := AKind;
end;

constructor TTermColor.Create(C: TColorRGB; AKind: TTermColorType);
begin
  FillChar(Self, SizeOf(Self), 0);
  Bgr[0] := C.GetBlue;
  Bgr[1] := C.GetGreen;
  Bgr[2] := C.GetRed;
  Kind := AKind;
end;

constructor TTermColor.Create(AKind: TTermColorType);
begin
  FillChar(Self, SizeOf(Self), 0);
  Kind := AKind;
end;

class operator TTermColor.=(const One, Two: TTermColor): Boolean;
begin
  Result := (One.Kind = Two.Kind) and (One.Idx = Two.Idx) and (One.Bgr[0] = Two.Bgr[0]) and
    (One.Bgr[1] = Two.Bgr[1]) and (One.Bgr[2] = Two.Bgr[2]);
end;

class operator TTermColor.<>(const One, Two: TTermColor): Boolean;
begin
  Result := not (One = Two);
end;

{ TColorConvResult }

constructor TColorConvResult.Create(const AColor: TTermColor; AExtraStyle: Word);
begin
  Color := AColor;
  ExtraStyle := AExtraStyle;
end;

{ TAnsiBuffer }

function TAnsiBuffer.Size: SizeInt;
begin
  Result := FLen;
end;

procedure TAnsiBuffer.Clear;
begin
  FLen := 0;
end;

procedure TAnsiBuffer.Reserve(ExtraCapacity: SizeInt);
var
  Capacity, Wanted: SizeInt;
begin
  Capacity := Length(FData);
  if FLen + ExtraCapacity > Capacity then
  begin
    Wanted := 2 * Capacity;
    if Wanted < 4096 then
      Wanted := 4096;
    if Wanted < Capacity + ExtraCapacity then
      Wanted := Capacity + ExtraCapacity;
    SetLength(FData, Wanted);
  end;
end;

procedure TAnsiBuffer.Push(const S: string);
begin
  if S = '' then
    Exit;
  Reserve(Length(S));
  Move(S[1], FData[FLen + 1], Length(S));
  Inc(FLen, Length(S));
end;

procedure TAnsiBuffer.PushChar(C: Char);
begin
  Reserve(1);
  Inc(FLen);
  FData[FLen] := C;
end;

procedure TAnsiBuffer.PushDecimal(Value: Cardinal);
var
  Digits: array[0..9] of Char;
  Count: Integer;
begin
  Count := 0;
  repeat
    Digits[Count] := Chr(Ord('0') + Value mod 10);
    Inc(Count);
    Value := Value div 10;
  until Value = 0;
  while Count > 0 do
  begin
    Dec(Count);
    PushChar(Digits[Count]);
  end;
end;

function TAnsiBuffer.EndsWith(C: Char): Boolean;
begin
  Result := (FLen > 0) and (FData[FLen] = C);
end;

procedure TAnsiBuffer.ReplaceLast(C: Char);
begin
  FData[FLen] := C;
end;

procedure TAnsiBuffer.DropLast(Count: SizeInt);
begin
  Dec(FLen, Count);
end;

function TAnsiBuffer.Bytes: string;
begin
  Result := Copy(FData, 1, FLen);
end;

{ Color conversion }

function ConvertNoColor(Color: TColor; const Cap: TTermCap; IsFg: Boolean): TColorConvResult;
var
  Bios: Byte;
begin
  Result := TColorConvResult.Create(TTermColor.Create(tctNoColor));
  { Mimic the mono palettes with styles. }
  if Color.IsBIOS then
  begin
    Bios := Color.AsBIOS;
    if IsFg then
    begin
      if (Bios and $8) <> 0 then
        Result.ExtraStyle := Result.ExtraStyle or slBold
      else if Bios = $1 then
        Result.ExtraStyle := Result.ExtraStyle or slUnderline;
    end
    else if (Bios and $7) = $7 then
      Result.ExtraStyle := Result.ExtraStyle or slReverse;
  end;
end;

function ConvertIndexed16(Color: TColor; const Cap: TTermCap; IsFg: Boolean): TColorConvResult;
var
  Idx: Byte;
begin
  if Color.IsBIOS then
  begin
    Idx := TColorConversion.BIOStoXTerm16(Color.AsBIOS);
    Result := TColorConvResult.Create(TTermColor.Create(Idx, tctIndexed));
  end
  else if Color.IsXTerm then
  begin
    Idx := Color.AsXTerm;
    if Idx >= 16 then
      Idx := TColorConversion.XTerm256toXTerm16(TColorXTerm.Create(Idx));
    Result := TColorConvResult.Create(TTermColor.Create(Idx, tctIndexed));
  end
  else if Color.IsRGB then
  begin
    Idx := TColorConversion.RGBtoXTerm16(Color.AsRGB);
    Result := TColorConvResult.Create(TTermColor.Create(Idx, tctIndexed));
  end
  else
    Result := TColorConvResult.Create(TTermColor.Create(tctDefault));
end;

function ConvertIndexed8(Color: TColor; const Cap: TTermCap; IsFg: Boolean): TColorConvResult;
begin
  Result := ConvertIndexed16(Color, Cap, IsFg);
  if (Result.Color.Kind = tctIndexed) and (Result.Color.Idx >= 8) then
  begin
    Result.Color.Idx := Result.Color.Idx - 8;
    if IsFg then
    begin
      if (Cap.Quirks and qfBoldIsBright) <> 0 then
        Result.ExtraStyle := Result.ExtraStyle or slBold;
    end
    else if (Cap.Quirks and qfBlinkIsBright) <> 0 then
      Result.ExtraStyle := Result.ExtraStyle or slBlink;
  end;
end;

function ConvertIndexed256(Color: TColor; const Cap: TTermCap; IsFg: Boolean): TColorConvResult;
var
  Idx: Byte;
begin
  if Color.IsXTerm then
  begin
    Idx := Color.AsXTerm;
    Result := TColorConvResult.Create(TTermColor.Create(Idx, tctIndexed));
  end
  else if Color.IsRGB then
  begin
    Idx := TColorConversion.RGBtoXTerm256(Color.AsRGB);
    Result := TColorConvResult.Create(TTermColor.Create(Idx, tctIndexed));
  end
  else
    Result := ConvertIndexed16(Color, Cap, IsFg);
end;

function ConvertDirect(Color: TColor; const Cap: TTermCap; IsFg: Boolean): TColorConvResult;
begin
  if Color.IsRGB then
    Result := TColorConvResult.Create(TTermColor.Create(Color.AsRGB, tctRGB))
  else
    Result := ConvertIndexed256(Color, Cap, IsFg);
end;

procedure ConvertColor(C: TColor; out ResultColor: TTermColor; var ResultStyle: Word; const Cap: TTermCap;
  IsFg: Boolean);
var
  Cnv: TColorConvResult;
begin
  case Cap.Colors of
    Indexed8:
      Cnv := ConvertIndexed8(C, Cap, IsFg);
    Indexed16:
      Cnv := ConvertIndexed16(C, Cap, IsFg);
    Indexed256:
      Cnv := ConvertIndexed256(C, Cap, IsFg);
    Direct:
      Cnv := ConvertDirect(C, Cap, IsFg);
  else
    Cnv := ConvertNoColor(C, Cap, IsFg);
  end;
  ResultColor := Cnv.Color;
  ResultStyle := ResultStyle or Cnv.ExtraStyle;
end;

{ Writing of the attributes }

procedure WriteFlag(var Buf: TAnsiBuffer; const Attr, LastAttr: TTermAttr; Mask: Word; const OnStr, OffStr: string);
begin
  if (Attr.Style and Mask) <> (LastAttr.Style and Mask) then
  begin
    if (Attr.Style and Mask) <> 0 then
      Buf.Push(OnStr)
    else
      Buf.Push(OffStr);
    Buf.PushChar(';');
  end;
end;

{ Closes the SGR sequence that is being written and opens another one. }
procedure SplitSGR(var Buf: TAnsiBuffer);
begin
  if Buf.EndsWith(';') then
  begin
    Buf.ReplaceLast('m');
    Buf.Push(CSI);
  end;
end;

procedure WriteColor(var Buf: TAnsiBuffer; const Color: TTermColor; IsFg: Boolean);
var
  I: Integer;
begin
  { RGB and XTerm256 colors get a separate SGR sequence because some terminal emulators may otherwise have
    trouble processing them. }
  case Color.Kind of
    tctDefault:
      if IsFg then
        Buf.Push('39;')
      else
        Buf.Push('49;');
    tctIndexed:
      if Color.Idx >= 16 then
      begin
        SplitSGR(Buf);
        if IsFg then
          Buf.Push('38;5;')
        else
          Buf.Push('48;5;');
        Buf.PushDecimal(Color.Idx);
        Buf.PushChar(';');
        SplitSGR(Buf);
      end
      else
      begin
        if Color.Idx >= 8 then
        begin
          if IsFg then
            Buf.PushDecimal(Color.Idx - 8 + 90)
          else
            Buf.PushDecimal(Color.Idx - 8 + 100);
        end
        else if IsFg then
          Buf.PushDecimal(Color.Idx + 30)
        else
          Buf.PushDecimal(Color.Idx + 40);
        Buf.PushChar(';');
      end;
    tctRGB:
      begin
        SplitSGR(Buf);
        if IsFg then
          Buf.Push('38;2;')
        else
          Buf.Push('48;2;');
        for I := 2 downto 0 do
        begin
          Buf.PushDecimal(Color.Bgr[I]);
          Buf.PushChar(';');
        end;
        SplitSGR(Buf);
      end;
    tctNoColor:
      ;
  end;
end;

procedure WriteAttributes(var Buf: TAnsiBuffer; const Attr, LastAttr: TTermAttr);
begin
  Buf.Push(CSI);

  WriteFlag(Buf, Attr, LastAttr, slBold, '1', '22');
  WriteFlag(Buf, Attr, LastAttr, slItalic, '3', '23');
  WriteFlag(Buf, Attr, LastAttr, slUnderline, '4', '24');
  WriteFlag(Buf, Attr, LastAttr, slBlink, '5', '25');
  WriteFlag(Buf, Attr, LastAttr, slReverse, '7', '27');
  WriteFlag(Buf, Attr, LastAttr, slStrike, '9', '29');

  if Attr.Fg <> LastAttr.Fg then
    WriteColor(Buf, Attr.Fg, True);
  if Attr.Bg <> LastAttr.Bg then
    WriteColor(Buf, Attr.Bg, False);

  { Nothing changed: the sequence is taken back. }
  if Buf.EndsWith(';') then
    Buf.ReplaceLast('m')
  else
    Buf.DropLast(Length(CSI));
end;

procedure ConvertAttributes(const C: TColorAttr; var LastAttr: TTermAttr; const Cap: TTermCap;
  var Buf: TAnsiBuffer);
var
  Attr: TTermAttr;
begin
  FillChar(Attr, SizeOf(Attr), 0);
  Attr.Style := C.GetStyle;

  ConvertColor(C.GetForeground, Attr.Fg, Attr.Style, Cap, True);
  ConvertColor(C.GetBackground, Attr.Bg, Attr.Style, Cap, False);

  if (Cap.Quirks and qfNoItalic) <> 0 then
    Attr.Style := Attr.Style and not Word(slItalic);
  if (Cap.Quirks and qfNoUnderline) <> 0 then
    Attr.Style := Attr.Style and not Word(slUnderline);

  WriteAttributes(Buf, Attr, LastAttr);

  LastAttr := Attr;
end;

{ TAnsiScreenWriter }

constructor TAnsiScreenWriter.Create(ATermCap: TTermCap);
begin
  inherited Create;
  FTermCap := ATermCap;
  FCaretPos.X := -1;
  FCaretPos.Y := -1;
  FillChar(FLastAttr, SizeOf(FLastAttr), 0);
end;

procedure TAnsiScreenWriter.BufWriteCSI1(A: Integer; F: Char);
begin
  { CSI a F }
  FBuf.Push(CSI);
  FBuf.PushDecimal(Cardinal(A));
  FBuf.PushChar(F);
end;

procedure TAnsiScreenWriter.BufWriteCSI2(A, B: Integer; F: Char);
begin
  { CSI a ; b F }
  FBuf.Push(CSI);
  FBuf.PushDecimal(Cardinal(A));
  FBuf.PushChar(';');
  FBuf.PushDecimal(Cardinal(B));
  FBuf.PushChar(F);
end;

procedure TAnsiScreenWriter.Reset;
begin
  FBuf.Push(CSI + '0m');
  FCaretPos.X := -1;
  FCaretPos.Y := -1;
  FillChar(FLastAttr, SizeOf(FLastAttr), 0);
end;

procedure TAnsiScreenWriter.ClearScreen;
begin
  FBuf.Push(CSI + '0m' + CSI + '2J');
  FillChar(FLastAttr, SizeOf(FLastAttr), 0);
end;

procedure TAnsiScreenWriter.WriteCell(Pos: TPoint; const Text: string; Attr: TColorAttr; DoubleWidth: Boolean);
begin
  { Move caret. When the movement is only horizontal, we can use a shorter sequence. }
  if Pos.Y <> FCaretPos.Y then
    BufWriteCSI2(Pos.Y + 1, Pos.X + 1, 'H')
  else if Pos.X <> FCaretPos.X then
    BufWriteCSI1(Pos.X + 1, 'G');

  ConvertAttributes(Attr, FLastAttr, FTermCap, FBuf);
  FBuf.Push(Text);

  FCaretPos.X := Pos.X + 1 + Ord(DoubleWidth);
  FCaretPos.Y := Pos.Y;
end;

procedure TAnsiScreenWriter.SetCaretPosition(Pos: TPoint);
begin
  BufWriteCSI2(Pos.Y + 1, Pos.X + 1, 'H');
  FCaretPos := Pos;
end;

function TAnsiScreenWriter.Flush: string;
begin
  Result := FBuf.Bytes;
  FBuf.Clear;
end;

end.
