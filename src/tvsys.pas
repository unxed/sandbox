{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/system.h (TEventQueue), source/tvision/tevent.cpp,
  include/tvision/internal/events.h, source/platform/events.cpp
  See COPYRIGHT.magiblot.

  The unit is for Unix systems: the wake-up source is a pipe. The wake-up sources of Windows and DOS are not
  part of it. The detection of a paste by a count of consecutive text events is not part of it either, because
  the constant of that count is not in the C++ sources; the paste text (SetPasteText) is. }
unit TvSys;

{$mode objfpc}
{$modeswitch advancedrecords}
{$R-}
{$Q-}

interface

uses
  ctypes, UnixType, BaseUnix, TvEvents;

type
  { The handle that a thread waits on: a file descriptor. }
  TSysHandle = cint;
  TSysManualEventHandle = TFilDes;

  { A signal that stays set until it is cleared: a pipe. }
  TSysManualEvent = class
  private
    FHandle: TSysManualEventHandle;
  public
    class function CreateHandle(var Handle: TSysManualEventHandle): Boolean; static;
    class function GetWaitableHandle(const Handle: TSysManualEventHandle): TSysHandle; static;
    { Takes over Handle, which Destroy closes. }
    constructor Create(const AHandle: TSysManualEventHandle);
    destructor Destroy; override;
    procedure Signal;
    procedure Clear;
  end;

  { A source of events that the waiter polls through Handle. }
  TEventSource = class
  private
    FHandle: TSysHandle;
  public
    constructor Create(AHandle: TSysHandle);
    function HasPendingEvents: Boolean; virtual;
    function GetEvent(var Ev: TEvent): Boolean; virtual;
    property Handle: TSysHandle read FHandle;
  end;

  { Called when the wake-up is taken; it returns whether Ev holds an event. }
  TWakeUpCallback = function(Args: Pointer; var Ev: TEvent): Boolean;

  TWakeUpEventSource = class(TEventSource)
  private
    FSys: TSysManualEvent;
    FCallback: TWakeUpCallback;
    FCallbackArgs: Pointer;
    FSignaled: LongInt;
    function Clear: Boolean;
  public
    { Pre: if ACallback or ACallbackArgs are set, they outlive Self. }
    constructor Create(const AHandle: TSysManualEventHandle; ACallback: TWakeUpCallback;
      ACallbackArgs: Pointer);
    destructor Destroy; override;
    { Any thread. }
    procedure Signal;
    { The thread that waits only. }
    function GetEvent(var Ev: TEvent): Boolean; override;
  end;

  TPollState = (psNothing, psReady, psDisconnect);

  TPollData = record
    Handles: array of TSysHandle;
    States: array of TPollState;
    procedure Push(H: TSysHandle);
    procedure Erase(I: SizeInt);
    function Size: SizeInt;
  end;

  TEventSourceArray = array of TEventSource;

  TEventWaiter = class
  private
    FSources: TEventSourceArray;
    FPD: TPollData;
    FWakeUp: TWakeUpEventSource;
    FReadyEvent: TEvent;
    FReadyEventPresent: Boolean;
    procedure RemoveSourceAt(I: SizeInt);
    procedure PollSources(TimeoutMs: Integer);
    function HasReadyEvent: Boolean;
    procedure GetReadyEvent(var Ev: TEvent);
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddSource(Src: TEventSource);
    procedure RemoveSource(Src: TEventSource);
    function GetEvent(var Ev: TEvent): Boolean;
    { Returns on a ready event or after Ms milliseconds; a negative Ms waits without limit. }
    procedure WaitForEvents(Ms: Integer);
    { Any thread. }
    procedure InterruptEventWait;
  end;

  { A first-in first-out list of events. }
  TEventFifo = class
  private
    FItems: array of TEvent;
    FHead: SizeInt;
    FCount: SizeInt;
  public
    procedure Push(const Ev: TEvent);
    function Pop(var Ev: TEvent): Boolean;
    procedure Clear;
    property Count: SizeInt read FCount;
  end;

  { The input hardware and the wait for it, as TEventQueue uses them. The base class takes its input from
    Feed and waits on a TEventWaiter; a backend for a real terminal overrides what it needs. }
  TEventBackend = class
  private
    FWaiter: TEventWaiter;
    FLock: TRTLCriticalSection;
    FKeys: TEventFifo;
    FMice: TEventFifo;
    FMouseState: TMouseEventType;
    FWidth: Integer;
    FHeight: Integer;
    procedure Accept(const Ev: TEvent);
    function HasInput: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function MousePresent: Boolean; virtual;
    procedure MouseResume; virtual;
    procedure MouseSuspend; virtual;
    procedure MouseSetRange(MaxX, MaxY: Integer); virtual;
    { The state of the mouse now. }
    procedure MouseGetState(var Mouse: TMouseEventType); virtual;
    procedure ClearPendingEvent; virtual;
    { Returns the next change of the mouse state, False when there is none. }
    function GetMouseEvent(var Mouse: TMouseEventType): Boolean; virtual;
    function GetKeyEvent(var Ev: TEvent): Boolean; virtual;
    { Ticks of 1/18.2 s. }
    function GetTickCount: Cardinal; virtual;
    function ScreenWidth: Integer; virtual;
    function ScreenHeight: Integer; virtual;
    procedure WaitForEvents(TimeoutMs: Integer); virtual;
    { Any thread. }
    procedure InterruptEventWait; virtual;
    { Adds a key event (What in evKeyboard) or a mouse event (What in evMouse) to the input and wakes the wait.
      Any thread. }
    procedure Feed(const Ev: TEvent);
    procedure SetScreenSize(AWidth, AHeight: Integer);
    property Waiter: TEventWaiter read FWaiter;
  end;

  TEventQueue = class
  private
    class var LastMouse: TMouseEventType;
    class var CurMouse: TMouseEventType;
    class var DownMouse: TMouseEventType;
    class var DownTicks: Word;
    class var MouseEvents: Boolean;
    class var PendingMouseUp: Boolean;
    class var RepeatDelay: Word;
    class var AutoTicks: Word;
    class var AutoDelay: Word;
    class var PasteText: string;
    class var PasteActive: Boolean;
    class var PasteTextIndex: SizeInt;
    class var ShouldSkipLf: Boolean;
    class function GetMouseState(var Ev: TEvent): Boolean; static;
    class function GetPasteEvent(var Ev: TEvent): Boolean; static;
    class procedure GetKeyOrPasteEvent(var Ev: TEvent); static;
    class function ReadKeyPress(var Ev: TEvent): Boolean; static;
  public
    class var DoubleDelay: Word;
    class var MouseReverse: Boolean;
    { The input hardware. The program sets it before the first queue is created. }
    class var Backend: TEventBackend;
    constructor Create;
    destructor Destroy; override;
    class procedure GetMouseEvent(var Ev: TEvent); static;
    class procedure GetKeyEvent(var Ev: TEvent); static;
    class procedure Suspend; static;
    class procedure Resume; static;
    { Returns on input, on WakeUp, on a posted event, or after TimeoutMs milliseconds. }
    class procedure WaitForEvents(TimeoutMs: Integer); static;
    { Thread-safe: ends the wait of WaitForEvents, the one now running or the next one. }
    class procedure WakeUp; static;
    class procedure SetPasteText(const Text: string); static;
    { Thread-safe: adds Ev to the posted events and wakes the wait. }
    class procedure PostEvent(const Ev: TEvent); static;
    { The thread of the views only: takes the oldest posted event. }
    class function GetPostedEvent(var Ev: TEvent): Boolean; static;
    { Thread-safe. }
    class function HasPostedEvents: Boolean; static;
  end;

implementation

{ TSysManualEvent }

class function TSysManualEvent.CreateHandle(var Handle: TSysManualEventHandle): Boolean;
begin
  Result := False;
end;

class function TSysManualEvent.GetWaitableHandle(const Handle: TSysManualEventHandle): TSysHandle;
begin
  Result := 0;
end;

constructor TSysManualEvent.Create(const AHandle: TSysManualEventHandle);
begin
end;

destructor TSysManualEvent.Destroy;
begin
  inherited Destroy;
end;

procedure TSysManualEvent.Signal;
begin
end;

procedure TSysManualEvent.Clear;
begin
end;

{ TEventSource }

constructor TEventSource.Create(AHandle: TSysHandle);
begin
  inherited Create;
  FHandle := AHandle;
end;

function TEventSource.HasPendingEvents: Boolean;
begin
  Result := False;
end;

function TEventSource.GetEvent(var Ev: TEvent): Boolean;
begin
  Result := False;
end;

{ TWakeUpEventSource }

constructor TWakeUpEventSource.Create(const AHandle: TSysManualEventHandle; ACallback: TWakeUpCallback;
  ACallbackArgs: Pointer);
begin
end;

destructor TWakeUpEventSource.Destroy;
begin
  inherited Destroy;
end;

function TWakeUpEventSource.Clear: Boolean;
begin
  Result := False;
end;

procedure TWakeUpEventSource.Signal;
begin
end;

function TWakeUpEventSource.GetEvent(var Ev: TEvent): Boolean;
begin
  Result := False;
end;

{ TPollData }

procedure TPollData.Push(H: TSysHandle);
begin
end;

procedure TPollData.Erase(I: SizeInt);
begin
end;

function TPollData.Size: SizeInt;
begin
  Result := 0;
end;

{ TEventWaiter }

constructor TEventWaiter.Create;
begin
end;

destructor TEventWaiter.Destroy;
begin
  inherited Destroy;
end;

procedure TEventWaiter.AddSource(Src: TEventSource);
begin
end;

procedure TEventWaiter.RemoveSource(Src: TEventSource);
begin
end;

procedure TEventWaiter.RemoveSourceAt(I: SizeInt);
begin
end;

procedure TEventWaiter.PollSources(TimeoutMs: Integer);
begin
end;

function TEventWaiter.HasReadyEvent: Boolean;
begin
  Result := False;
end;

procedure TEventWaiter.GetReadyEvent(var Ev: TEvent);
begin
end;

function TEventWaiter.GetEvent(var Ev: TEvent): Boolean;
begin
  Result := False;
end;

procedure TEventWaiter.WaitForEvents(Ms: Integer);
begin
end;

procedure TEventWaiter.InterruptEventWait;
begin
end;

{ TEventFifo }

procedure TEventFifo.Push(const Ev: TEvent);
begin
end;

function TEventFifo.Pop(var Ev: TEvent): Boolean;
begin
  Result := False;
end;

procedure TEventFifo.Clear;
begin
end;

{ TEventBackend }

constructor TEventBackend.Create;
begin
end;

destructor TEventBackend.Destroy;
begin
  inherited Destroy;
end;

procedure TEventBackend.Accept(const Ev: TEvent);
begin
end;

function TEventBackend.HasInput: Boolean;
begin
  Result := False;
end;

function TEventBackend.MousePresent: Boolean;
begin
  Result := False;
end;

procedure TEventBackend.MouseResume;
begin
end;

procedure TEventBackend.MouseSuspend;
begin
end;

procedure TEventBackend.MouseSetRange(MaxX, MaxY: Integer);
begin
end;

procedure TEventBackend.MouseGetState(var Mouse: TMouseEventType);
begin
end;

procedure TEventBackend.ClearPendingEvent;
begin
end;

function TEventBackend.GetMouseEvent(var Mouse: TMouseEventType): Boolean;
begin
  Result := False;
end;

function TEventBackend.GetKeyEvent(var Ev: TEvent): Boolean;
begin
  Result := False;
end;

function TEventBackend.GetTickCount: Cardinal;
begin
  Result := 0;
end;

function TEventBackend.ScreenWidth: Integer;
begin
  Result := 0;
end;

function TEventBackend.ScreenHeight: Integer;
begin
  Result := 0;
end;

procedure TEventBackend.WaitForEvents(TimeoutMs: Integer);
begin
end;

procedure TEventBackend.InterruptEventWait;
begin
end;

procedure TEventBackend.Feed(const Ev: TEvent);
begin
end;

procedure TEventBackend.SetScreenSize(AWidth, AHeight: Integer);
begin
end;

{ TEventQueue }

constructor TEventQueue.Create;
begin
  inherited Create;
end;

destructor TEventQueue.Destroy;
begin
  inherited Destroy;
end;

class procedure TEventQueue.GetMouseEvent(var Ev: TEvent);
begin
  Ev.What := evNothing;
end;

class function TEventQueue.GetMouseState(var Ev: TEvent): Boolean;
begin
  Result := False;
end;

class procedure TEventQueue.GetKeyEvent(var Ev: TEvent);
begin
  Ev.What := evNothing;
end;

class procedure TEventQueue.Suspend;
begin
end;

class procedure TEventQueue.Resume;
begin
end;

class procedure TEventQueue.SetPasteText(const Text: string);
begin
end;

class function TEventQueue.GetPasteEvent(var Ev: TEvent): Boolean;
begin
  Result := False;
end;

class procedure TEventQueue.GetKeyOrPasteEvent(var Ev: TEvent);
begin
  Ev.What := evNothing;
end;

class function TEventQueue.ReadKeyPress(var Ev: TEvent): Boolean;
begin
  Result := False;
end;

class procedure TEventQueue.WaitForEvents(TimeoutMs: Integer);
begin
end;

class procedure TEventQueue.WakeUp;
begin
end;

class procedure TEventQueue.PostEvent(const Ev: TEvent);
begin
end;

class function TEventQueue.GetPostedEvent(var Ev: TEvent): Boolean;
begin
  Result := False;
end;

class function TEventQueue.HasPostedEvents: Boolean;
begin
  Result := False;
end;

end.
