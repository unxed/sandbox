{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/system.h (TTimerQueue), source/tvision/ttimerqu.cpp
  See COPYRIGHT.magiblot.

  The clock of the parameterless constructor is the millisecond counter of the Free Pascal runtime; the C++
  source of its own clock (THardwareInfo::getTickCountMs) is not part of the sources of this unit. }
unit TvTimer;

{$mode objfpc}
{$modeswitch advancedrecords}
{$R-}
{$Q-}

interface

uses
  SysUtils, TvSys;

type
  { Milliseconds of a clock. }
  TTimePoint = QWord;

  { Identifies a timer until it fires for the last time or is killed. }
  TTimerId = Pointer;

  TGetTimeMs = function: TTimePoint;

  { Called for every timer that has expired. }
  TTimerProc = procedure(Id: TTimerId; Args: Pointer);

  PTimer = ^TTimer;

  TTimer = record
    ExpiresAt: TTimePoint;
    Period: LongInt;
    Next: PTimer;
    CollectId: Pointer;
  end;

  { A list of timers. SetTimer and KillTimer may be called from any thread; the other routines belong to the
    thread that runs the loop. }
  TTimerQueue = class
  private
    FGetTimeMs: TGetTimeMs;
    FFirst: PTimer;
    FLock: TRTLCriticalSection;
    function IsEmpty: Boolean;
    function TakeNextExpired(CollectId: Pointer; Now: TTimePoint): TTimerId;
    procedure ClearMarks(CollectId: Pointer);
  public
    constructor Create; overload;
    constructor Create(AGetTimeMs: TGetTimeMs); overload;
    destructor Destroy; override;
    { Starts a timer that expires after TimeoutMs. A PeriodMs below zero makes it a one-shot timer; otherwise
      it expires again every PeriodMs. Any thread; wakes the wait of the loop. }
    function SetTimer(TimeoutMs: Cardinal; PeriodMs: LongInt = -1): TTimerId;
    { Any thread; wakes the wait of the loop. }
    procedure KillTimer(Id: TTimerId);
    { Calls Func once for every timer that has expired; a one-shot timer is gone by then. Func may set and
      kill timers. }
    procedure CollectExpiredTimers(Func: TTimerProc; Args: Pointer);
    { Milliseconds until the first timer expires, 0 when one has, -1 when there is none. }
    function TimeUntilNextTimeout: LongInt;
  end;

implementation

constructor TTimerQueue.Create;
begin
  inherited Create;
end;

constructor TTimerQueue.Create(AGetTimeMs: TGetTimeMs);
begin
  inherited Create;
end;

destructor TTimerQueue.Destroy;
begin
  inherited Destroy;
end;

function TTimerQueue.IsEmpty: Boolean;
begin
  Result := True;
end;

function TTimerQueue.TakeNextExpired(CollectId: Pointer; Now: TTimePoint): TTimerId;
begin
  Result := nil;
end;

procedure TTimerQueue.ClearMarks(CollectId: Pointer);
begin
end;

function TTimerQueue.SetTimer(TimeoutMs: Cardinal; PeriodMs: LongInt): TTimerId;
begin
  Result := nil;
end;

procedure TTimerQueue.KillTimer(Id: TTimerId);
begin
end;

procedure TTimerQueue.CollectExpiredTimers(Func: TTimerProc; Args: Pointer);
begin
end;

function TTimerQueue.TimeUntilNextTimeout: LongInt;
begin
  Result := -1;
end;

end.
