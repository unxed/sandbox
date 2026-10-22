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

type
  PPTimer = ^PTimer;

function DefaultGetTimeMs: TTimePoint;
begin
  Result := TTimePoint(GetTickCount64);
end;

{ The thread that waits learns of a change of the list. }
procedure WakeLoop;
begin
  if TEventQueue.Backend <> nil then
    TEventQueue.WakeUp;
end;

constructor TTimerQueue.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
  FGetTimeMs := @DefaultGetTimeMs;
  FFirst := nil;
end;

constructor TTimerQueue.Create(AGetTimeMs: TGetTimeMs);
begin
  inherited Create;
  InitCriticalSection(FLock);
  FGetTimeMs := AGetTimeMs;
  FFirst := nil;
end;

destructor TTimerQueue.Destroy;
var
  Timer, Next: PTimer;
begin
  Timer := FFirst;
  while Timer <> nil do
  begin
    Next := Timer^.Next;
    Dispose(Timer);
    Timer := Next;
  end;
  FFirst := nil;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

function TTimerQueue.SetTimer(TimeoutMs: Cardinal; PeriodMs: LongInt): TTimerId;
var
  Timer: PTimer;
  P: PPTimer;
begin
  New(Timer);
  FillChar(Timer^, SizeOf(TTimer), 0);
  Timer^.ExpiresAt := FGetTimeMs() + TimeoutMs;
  Timer^.Period := PeriodMs;
  EnterCriticalSection(FLock);
  try
    P := @FFirst;
    while P^ <> nil do
      P := @P^^.Next;
    P^ := Timer;
  finally
    LeaveCriticalSection(FLock);
  end;
  WakeLoop;
  Result := Timer;
end;

procedure TTimerQueue.KillTimer(Id: TTimerId);
var
  P: PPTimer;
begin
  EnterCriticalSection(FLock);
  try
    P := @FFirst;
    while P^ <> nil do
    begin
      if P^ = PTimer(Id) then
      begin
        P^ := PTimer(Id)^.Next;
        Dispose(PTimer(Id));
        Break;
      end;
      P := @P^^.Next;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
  WakeLoop;
end;

{ Pre: ExpiresAt <= Now and Period > 0. }
function CalcNextExpiresAt(ExpiresAt, Now: TTimePoint; Period: LongInt): TTimePoint;
var
  Step: TTimePoint;
begin
  Step := TTimePoint(Period);
  Result := (1 + (Now - ExpiresAt + Step) div Step) * Step + ExpiresAt - Step;
end;

function TTimerQueue.IsEmpty: Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := FFirst = nil;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

{ Finds the first timer that has expired and is not marked with CollectId. A periodic timer is marked and moved
  on; a one-shot timer is removed. Returns nil when there is none. }
function TTimerQueue.TakeNextExpired(CollectId: Pointer; Now: TTimePoint): TTimerId;
var
  P: PPTimer;
  Next: PTimer;
begin
  EnterCriticalSection(FLock);
  try
    P := @FFirst;
    while (P^ <> nil) and ((P^^.CollectId <> nil) or (Now < P^^.ExpiresAt)) do
      P := @P^^.Next;
    Result := P^;
    if Result = nil then
      Exit;
    if P^^.Period >= 0 then
    begin
      P^^.CollectId := CollectId;
      if P^^.Period > 0 then
        P^^.ExpiresAt := CalcNextExpiresAt(P^^.ExpiresAt, Now, P^^.Period);
    end
    else
    begin
      Next := P^^.Next;
      Dispose(P^);
      P^ := Next;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TTimerQueue.ClearMarks(CollectId: Pointer);
var
  Timer: PTimer;
begin
  EnterCriticalSection(FLock);
  try
    Timer := FFirst;
    while Timer <> nil do
    begin
      if Timer^.CollectId = CollectId then
        Timer^.CollectId := nil;
      Timer := Timer^.Next;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TTimerQueue.CollectExpiredTimers(Func: TTimerProc; Args: Pointer);
var
  CollectId: Pointer;
  Now: TTimePoint;
  Id: TTimerId;
begin
  if IsEmpty then
    Exit;
  { Func may change the list, so it is searched from its start every time. A timer that has been handled
    in this call carries the address of CollectId, which differs between calls. }
  CollectId := @CollectId;
  Now := FGetTimeMs();
  Id := TakeNextExpired(CollectId, Now);
  while Id <> nil do
  begin
    Func(Id, Args);
    Id := TakeNextExpired(CollectId, Now);
  end;
  ClearMarks(CollectId);
end;

function TTimerQueue.TimeUntilNextTimeout: LongInt;
const
  MaxValue = Cardinal($7FFFFFFF);
var
  Now: TTimePoint;
  Timer: PTimer;
  Remaining: Cardinal;
begin
  EnterCriticalSection(FLock);
  try
    if FFirst = nil then
    begin
      Result := -1;
      Exit;
    end;
    Now := FGetTimeMs();
    Result := LongInt(MaxValue);
    Timer := FFirst;
    repeat
      if Timer^.ExpiresAt <= Now then
      begin
        Result := 0;
        Break;
      end;
      Remaining := Cardinal((Timer^.ExpiresAt - Now) and $FFFFFFFF);
      if Remaining > MaxValue then
        Remaining := MaxValue;
      if LongInt(Remaining) < Result then
        Result := LongInt(Remaining);
      Timer := Timer^.Next;
    until Timer = nil;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

end.
