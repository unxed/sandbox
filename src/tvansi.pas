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

{ TTermColor }

constructor TTermColor.Create(AIdx: Byte; AKind: TTermColorType);
begin
end;

constructor TTermColor.Create(C: TColorRGB; AKind: TTermColorType);
begin
end;

constructor TTermColor.Create(AKind: TTermColorType);
begin
end;

class operator TTermColor.=(const One, Two: TTermColor): Boolean;
begin
  Result := False;
end;

class operator TTermColor.<>(const One, Two: TTermColor): Boolean;
begin
  Result := True;
end;

{ TAnsiBuffer }

function TAnsiBuffer.Size: SizeInt;
begin
  Result := 0;
end;

procedure TAnsiBuffer.Clear;
begin
end;

procedure TAnsiBuffer.Reserve(ExtraCapacity: SizeInt);
begin
end;

procedure TAnsiBuffer.Push(const S: string);
begin
end;

procedure TAnsiBuffer.PushChar(C: Char);
begin
end;

procedure TAnsiBuffer.PushDecimal(Value: Cardinal);
begin
end;

function TAnsiBuffer.EndsWith(C: Char): Boolean;
begin
  Result := False;
end;

procedure TAnsiBuffer.ReplaceLast(C: Char);
begin
end;

procedure TAnsiBuffer.DropLast(Count: SizeInt);
begin
end;

function TAnsiBuffer.Bytes: string;
begin
  Result := '';
end;

{ TAnsiScreenWriter }

constructor TAnsiScreenWriter.Create(ATermCap: TTermCap);
begin
end;

procedure TAnsiScreenWriter.BufWriteCSI1(A: Integer; F: Char);
begin
end;

procedure TAnsiScreenWriter.BufWriteCSI2(A, B: Integer; F: Char);
begin
end;

procedure TAnsiScreenWriter.Reset;
begin
end;

procedure TAnsiScreenWriter.ClearScreen;
begin
end;

procedure TAnsiScreenWriter.WriteCell(Pos: TPoint; const Text: string; Attr: TColorAttr; DoubleWidth: Boolean);
begin
end;

procedure TAnsiScreenWriter.SetCaretPosition(Pos: TPoint);
begin
end;

function TAnsiScreenWriter.Flush: string;
begin
  Result := '';
end;

end.
