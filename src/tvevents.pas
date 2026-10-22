{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/system.h (the event structures and codes),
  include/tvision/internal/termio.h, source/platform/termio.cpp,
  source/platform/far2l.cpp, include/tvision/internal/win32con.h,
  source/platform/win32con.cpp (the input parts)
  The reader of the Windows console (ReadConsoleInput and the console input records) is not part of this unit.
  See COPYRIGHT.magiblot. }
unit TvEvents;

{$mode objfpc}
{$modeswitch advancedrecords}
{$R-}
{$Q-}

interface

uses
  TvGeom, TvKeys, TvUtf8;

const
  { Event codes }
  evMouseDown = $0001;
  evMouseUp = $0002;
  evMouseMove = $0004;
  evMouseAuto = $0008;
  evMouseWheel = $0020;
  evKeyDown = $0010;
  evCommand = $0100;
  evBroadcast = $0200;

  { Event masks }
  evNothing = $0000;
  evMouse = $002F;
  evKeyboard = $0010;
  evMessage = $FF00;

  { Mouse button state masks }
  mbLeftButton = $01;
  mbRightButton = $02;
  mbMiddleButton = $04;

  { Mouse wheel state masks }
  mwUp = $01;
  mwDown = $02;
  mwLeft = $04;
  mwRight = $08;

  { Mouse event flags }
  meMouseMoved = $01;
  meDoubleClick = $02;
  meTripleClick = $04;

  { The size of the text of a key event: the longest UTF-8 sequence. }
  maxCharSize = 4;

  { Flags of the mouse events of the console (dwEventFlags): the values of the document
    tools/audit/facts/windows-console-mouse-event-record-str.md }
  MOUSE_WHEELED = $0004;
  MOUSE_HWHEELED = $0008;

  { Virtual key codes: the names and values of the document
    tools/audit/facts/windows-virtual-key-codes.md }
  VK_BACK = $08;
  VK_TAB = $09;
  VK_RETURN = $0D;
  VK_MENU = $12;
  VK_ESCAPE = $1B;
  VK_SPACE = $20;
  VK_PRIOR = $21;
  VK_NEXT = $22;
  VK_END = $23;
  VK_HOME = $24;
  VK_LEFT = $25;
  VK_UP = $26;
  VK_RIGHT = $27;
  VK_DOWN = $28;
  VK_INSERT = $2D;
  VK_DELETE = $2E;
  VK_NUMPAD0 = $60;
  VK_NUMPAD1 = $61;
  VK_NUMPAD2 = $62;
  VK_NUMPAD3 = $63;
  VK_NUMPAD4 = $64;
  VK_NUMPAD5 = $65;
  VK_NUMPAD6 = $66;
  VK_NUMPAD7 = $67;
  VK_NUMPAD8 = $68;
  VK_NUMPAD9 = $69;
  VK_MULTIPLY = $6A;
  VK_ADD = $6B;
  VK_SEPARATOR = $6C;
  VK_SUBTRACT = $6D;
  VK_DECIMAL = $6E;
  VK_DIVIDE = $6F;
  VK_F1 = $70;
  VK_F2 = $71;
  VK_F3 = $72;
  VK_F4 = $73;
  VK_F5 = $74;
  VK_F6 = $75;
  VK_F7 = $76;
  VK_F8 = $77;
  VK_F9 = $78;
  VK_F10 = $79;
  VK_F11 = $7A;
  VK_F12 = $7B;

type
  TMouseEventType = record
    Where: TPoint;
    EventFlags: Word; { Replacement for doubleClick. }
    ControlKeyState: Word;
    Buttons: Byte;
    Wheel: Byte;
  end;

  { The two bytes of a key code, as they lie in memory on a little-endian machine. }
  TCharScanType = record
    CharCode: Byte;
    ScanCode: Byte;
  end;

  { CharScan and KeyCode share their two bytes. Text is not zero-terminated. }
  TKeyDownEvent = record
    { Returns the first TextLength bytes of Text. }
    function GetText: string;
    function ToKey: TKey;
    case Byte of
      0: (KeyCode: Word;
          ControlKeyState: Word;
          Text: TUtf8Bytes;
          TextLength: Byte);
      1: (CharScan: TCharScanType);
  end;

  { The members after Command share their storage. }
  TMessageEvent = record
    Command: Word;
    case Integer of
      1: (InfoPtr: Pointer);
      2: (InfoLong: Int32);
      3: (InfoWord: UInt16);
      4: (InfoInt: Int16);
      5: (InfoByte: UInt8);
      6: (InfoChar: Char);
  end;

  { Mouse, KeyDown and Message share their storage. }
  TEvent = record
    What: Word;
    case Byte of
      0: (Mouse: TMouseEventType);
      1: (KeyDown: TKeyDownEvent);
      2: (Message: TMessageEvent);
  end;

  TParseResult = (Rejected, Accepted, Ignored);

  { A procedure that receives text: a write to the terminal, or a pasted text. }
  TTextProc = procedure(const Text: string);

  TFar2lState = record
    Enabled: Boolean;
  end;

  TInputState = record
    Buttons: Byte;
    Far2l: TFar2lState;
    HasFullOsc52: Boolean;
    BracketedPaste: Boolean;
    GotDsrResponse: Boolean;
    PutPaste: TTextProc;
  end;
  PInputState = ^TInputState;

  { A source of input bytes; Get returns -1 when there is none. }
  TInputGetter = class
  public
    function Get: Integer; virtual; abstract;
    procedure Unget(Key: Integer); virtual; abstract;
  end;

  { Remembers the keys read, so that they can be ungotten. }
  TGetChBuf = record
  private
    Size: Cardinal;
    Keys: array[0..30] of Integer;
  public
    In_: TInputGetter;
    constructor Create(AIn: TInputGetter);
    function GetUnbuffered: Integer;
    function Get(KeepErr: Boolean = False): Integer;
    function Last(I: SizeInt = 0): Integer;
    procedure Unget;
    procedure Reject;
    { Read a decimal number. The last key read, a non-digit or -1, is left in Last. }
    function GetNum(var Value: Cardinal): Boolean;
    function GetInt(var Value: Integer): Boolean;
    function ReadStr(const Str: string): Boolean;
  end;

const
  CSIMaxLength = 6;

type
  { The data of a CSI escape sequence. For "ESC [ 123 :: 456 ; 789 u": Length is 5, Terminator is 'u',
    GetValue(0) is 123, GetSeparator(0) is ':', GetValue(1) is the default, GetSeparator(1) is ':',
    GetValue(2) is 456, GetSeparator(2) is ';', GetValue(3) is 789. }
  TCSIData = record
    Length: Cardinal;
    Values: array[0..CSIMaxLength - 1] of Cardinal;
    Separators: array[0..CSIMaxLength - 1] of Char;
    Terminator: Char;
    function ReadFrom(var Buf: TGetChBuf): Boolean;
    function GetValue(I: Cardinal; ADefault: Cardinal = 1): Cardinal;
    function GetSeparator(I: Cardinal): Char;
  end;

  TBase64Func = function(const S: string): string;
  TCpFunc = function(const Text: string): Byte;

var
  { Conversions between bytes and Base64 text. They must be set before the far2l and OSC 52 input
    and the clipboard are used; while unset, the input is ignored and the clipboard reports failure. }
  Base64Decode: TBase64Func = nil;
  Base64Encode: TBase64Func = nil;

  { Conversions of the text of a key to its character in the current code page; 0 when it has none.
    While unset, only a single ASCII character converts. }
  CpFromUtf8: TCpFunc = nil;
  CpPrintableFromUtf8: TCpFunc = nil;

  { The sequences that turn the far2l terminal extensions on and off. }
  Far2lEnableSeq: string = '';
  Far2lDisableSeq: string = '';

  { Conversion of the scan codes 0..88 of the Windows console to key codes, without a modifier and
    with Shift, Ctrl and Alt. A zero entry means no conversion. }
  NormalCvt, ShiftCvt, CtrlCvt, AltCvt: array[0..88] of Word;

{ Conversion of the fields of Windows console input events, as the win32 input mode and the far2l extension
  deliver them: the virtual key code, the scan code, the character (a whole code point), the state of the
  control keys, the position, the state of the buttons and the event flags. }

{ Returns False when the key gives no event. }
function GetWin32Key(VirtualKey, ScanCode: Word; UnicodeChar, ControlKeyState: Cardinal; var Ev: TEvent;
  var State: TInputState): Boolean;
procedure GetWin32Mouse(X, Y: SmallInt; ButtonState, ControlKeyState, EventFlags: Cardinal; var Ev: TEvent;
  var State: TInputState);
procedure RegenerateMissingScanCodeFromVirtualKeyCode(VirtualKey: Word; var ScanCode: Word;
  var UnicodeChar: Cardinal; ControlKeyState: Cardinal);

{ Terminal input and its control sequences. The procedures that switch features on and off pass the
  sequence to Writer. }

procedure MouseOn(Writer: TTextProc);
procedure MouseOff(Writer: TTextProc);

{ The sequence of KeyModsOn for a TERM that is set (HasTerm) and has the value Term. }
function KeyModsOnSequence(HasTerm: Boolean; const Term: string): string;
procedure KeyModsOn(Writer: TTextProc);
procedure KeyModsOff(Writer: TTextProc);

procedure NormalizeKey(var KeyDown: TKeyDownEvent);

function SetClipboardText(Writer: TTextProc; const Text: string; var State: TInputState): Boolean;
function RequestClipboardText(Writer: TTextProc; Accept: TTextProc; var State: TInputState): Boolean;

function ParseEvent(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
function ParseEscapeSeq(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
function ParseX10Mouse(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
function ParseSGRMouse(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
function ParseCSIKey(const Csi: TCSIData; var Ev: TEvent; var State: TInputState): TParseResult;
function ParseSS3Key(var Buf: TGetChBuf; var Ev: TEvent): TParseResult;
function ParseKittyKey(const Csi: TCSIData; var Ev: TEvent): TParseResult;
function ParseDCS(var Buf: TGetChBuf; var State: TInputState): TParseResult;
function ParseOSC(var Buf: TGetChBuf; var State: TInputState): TParseResult;
function ParseCPR(const Csi: TCSIData; var State: TInputState): TParseResult;
function ParseWin32InputModeKeyOrEscapeSeq(const Csi: TCSIData; In_: TInputGetter; var Ev: TEvent;
  var State: TInputState): TParseResult;

{ Reads up to BEL or ST, which are not part of the result. The result ends at its first zero byte. }
function ReadUntilBelOrSt(var Buf: TGetChBuf): string;

{ Writes a Device Status Report request and reads input until its response comes or 200 ms pass. }
procedure ConsumeUnprocessedInput(Writer: TTextProc; In_: TInputGetter; var State: TInputState);

{ The far2l terminal extension }

function ParseFar2lInput(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
function ParseFar2lAnswer(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;

implementation

{ TKeyDownEvent }

function TKeyDownEvent.GetText: string;
begin
  Result := '';
end;

function TKeyDownEvent.ToKey: TKey;
begin
  Result := TKey.Create(KeyCode, ControlKeyState);
end;

{ TGetChBuf }

constructor TGetChBuf.Create(AIn: TInputGetter);
begin
  In_ := AIn;
  Size := 0;
end;

function TGetChBuf.GetUnbuffered: Integer;
begin
  Result := -1;
end;

function TGetChBuf.Get(KeepErr: Boolean): Integer;
begin
  Result := -1;
end;

function TGetChBuf.Last(I: SizeInt): Integer;
begin
  Result := -1;
end;

procedure TGetChBuf.Unget;
begin
end;

procedure TGetChBuf.Reject;
begin
end;

function TGetChBuf.GetNum(var Value: Cardinal): Boolean;
begin
  Result := False;
end;

function TGetChBuf.GetInt(var Value: Integer): Boolean;
begin
  Result := False;
end;

function TGetChBuf.ReadStr(const Str: string): Boolean;
begin
  Result := False;
end;

{ TCSIData }

function TCSIData.ReadFrom(var Buf: TGetChBuf): Boolean;
begin
  Result := False;
end;

function TCSIData.GetValue(I: Cardinal; ADefault: Cardinal): Cardinal;
begin
  Result := ADefault;
end;

function TCSIData.GetSeparator(I: Cardinal): Char;
begin
  Result := #0;
end;

{ Windows console input }

function GetWin32Key(VirtualKey, ScanCode: Word; UnicodeChar, ControlKeyState: Cardinal; var Ev: TEvent;
  var State: TInputState): Boolean;
begin
  Result := False;
end;

procedure GetWin32Mouse(X, Y: SmallInt; ButtonState, ControlKeyState, EventFlags: Cardinal; var Ev: TEvent;
  var State: TInputState);
begin
end;

procedure RegenerateMissingScanCodeFromVirtualKeyCode(VirtualKey: Word; var ScanCode: Word;
  var UnicodeChar: Cardinal; ControlKeyState: Cardinal);
begin
end;

{ Terminal input }

procedure MouseOn(Writer: TTextProc);
begin
end;

procedure MouseOff(Writer: TTextProc);
begin
end;

function KeyModsOnSequence(HasTerm: Boolean; const Term: string): string;
begin
  Result := '';
end;

procedure KeyModsOn(Writer: TTextProc);
begin
end;

procedure KeyModsOff(Writer: TTextProc);
begin
end;

procedure NormalizeKey(var KeyDown: TKeyDownEvent);
begin
end;

function SetClipboardText(Writer: TTextProc; const Text: string; var State: TInputState): Boolean;
begin
  Result := False;
end;

function RequestClipboardText(Writer: TTextProc; Accept: TTextProc; var State: TInputState): Boolean;
begin
  Result := False;
end;

function ParseEvent(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
begin
  Result := Rejected;
end;

function ParseEscapeSeq(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
begin
  Result := Rejected;
end;

function ParseX10Mouse(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
begin
  Result := Rejected;
end;

function ParseSGRMouse(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
begin
  Result := Rejected;
end;

function ParseCSIKey(const Csi: TCSIData; var Ev: TEvent; var State: TInputState): TParseResult;
begin
  Result := Rejected;
end;

function ParseSS3Key(var Buf: TGetChBuf; var Ev: TEvent): TParseResult;
begin
  Result := Rejected;
end;

function ParseKittyKey(const Csi: TCSIData; var Ev: TEvent): TParseResult;
begin
  Result := Rejected;
end;

function ParseDCS(var Buf: TGetChBuf; var State: TInputState): TParseResult;
begin
  Result := Ignored;
end;

function ParseOSC(var Buf: TGetChBuf; var State: TInputState): TParseResult;
begin
  Result := Ignored;
end;

function ParseCPR(const Csi: TCSIData; var State: TInputState): TParseResult;
begin
  Result := Rejected;
end;

function ParseWin32InputModeKeyOrEscapeSeq(const Csi: TCSIData; In_: TInputGetter; var Ev: TEvent;
  var State: TInputState): TParseResult;
begin
  Result := Rejected;
end;

function ReadUntilBelOrSt(var Buf: TGetChBuf): string;
begin
  Result := '';
end;

procedure ConsumeUnprocessedInput(Writer: TTextProc; In_: TInputGetter; var State: TInputState);
begin
end;

{ The far2l terminal extension }

function ParseFar2lInput(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
begin
  Result := Ignored;
end;

function ParseFar2lAnswer(var Buf: TGetChBuf; var Ev: TEvent; var State: TInputState): TParseResult;
begin
  Result := Ignored;
end;

end.
