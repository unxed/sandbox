{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/system.h (TEventQueue), source/tvision/tevent.cpp,
  include/tvision/internal/events.h, source/platform/events.cpp
  See COPYRIGHT.magiblot. }
program t_async;

{$mode objfpc}
{$modeswitch advancedrecords}

uses
  cthreads,
  Classes, SysUtils, TvKeys, TvEvents, TvSys;

{$I testlib.inc}

const
  { No wait of these tests lasts longer than this, so that a failure ends the program. }
  Guard = 10000;
  { What counts as at once, in milliseconds. }
  Quick = 2000;

type
  TWakeKind = (wkWakeUp, wkPost, wkFeed);

  { Waits Delay milliseconds, then wakes the queue, posts Count events or feeds a key. }
  TWorker = class(TThread)
  private
    FKind: TWakeKind;
    FDelay: Integer;
    FCount: Integer;
    FBase: Integer;
    FBackend: TEventBackend;
  protected
    procedure Execute; override;
  public
    constructor Create(AKind: TWakeKind; ADelay, ACount, ABase: Integer; ABackend: TEventBackend);
  end;

constructor TWorker.Create(AKind: TWakeKind; ADelay, ACount, ABase: Integer; ABackend: TEventBackend);
begin
  FKind := AKind;
  FDelay := ADelay;
  FCount := ACount;
  FBase := ABase;
  FBackend := ABackend;
  inherited Create(False);
end;

procedure TWorker.Execute;
var
  Ev: TEvent;
  I: Integer;
begin
  if FDelay > 0 then
    Sleep(FDelay);
  FillChar(Ev, SizeOf(Ev), 0);
  case FKind of
    wkWakeUp:
      TEventQueue.WakeUp;
    wkPost:
      for I := 1 to FCount do
      begin
        Ev.What := evCommand;
        Ev.Message.Command := FBase + I;
        TEventQueue.PostEvent(Ev);
      end;
    wkFeed:
      begin
        Ev.What := evKeyDown;
        Ev.KeyDown.KeyCode := kbF3;
        FBackend.Feed(Ev);
      end;
  end;
end;

function Now64: Int64;
begin
  Result := Int64(GetTickCount64);
end;

var
  B: TEventBackend;
  Q: TEventQueue;
  Ev: TEvent;
  Start: Int64;
  T: TWorker;
  Workers: array[0..3] of TWorker;
  Last: array[0..3] of Integer;
  I, Got, Group: Integer;
  Ok: Boolean;

begin
  B := TEventBackend.Create;
  TEventQueue.Backend := B;
  Q := TEventQueue.Create;

  { a wake-up before the wait ends the next wait at once }
  TEventQueue.WakeUp;
  Start := Now64;
  TEventQueue.WaitForEvents(Guard);
  Check(Now64 - Start < Quick, 'a wake-up before the wait ends it at once');

  { and only the next one }
  Start := Now64;
  TEventQueue.WaitForEvents(150);
  Check(Now64 - Start >= 100, 'the wait after a wake-up blocks again');

  { several wake-ups before the wait are one }
  TEventQueue.WakeUp;
  TEventQueue.WakeUp;
  TEventQueue.WakeUp;
  Start := Now64;
  TEventQueue.WaitForEvents(Guard);
  Check(Now64 - Start < Quick, 'three wake-ups end the next wait at once');
  Start := Now64;
  TEventQueue.WaitForEvents(150);
  Check(Now64 - Start >= 100, 'three wake-ups end only one wait');

  { a wake-up from a second thread ends a blocked wait }
  T := TWorker.Create(wkWakeUp, 250, 0, 0, B);
  Start := Now64;
  TEventQueue.WaitForEvents(Guard);
  Check(Now64 - Start < Guard - 1000, 'a wake-up from a second thread ends a blocked wait');
  Check(Now64 - Start >= 150, 'the wait was blocked until the wake-up');
  T.WaitFor;
  T.Free;

  { and again, for a wait that came after the first one }
  T := TWorker.Create(wkWakeUp, 250, 0, 0, B);
  Start := Now64;
  TEventQueue.WaitForEvents(Guard);
  Check(Now64 - Start < Guard - 1000, 'a second wake-up from a second thread ends a blocked wait');
  T.WaitFor;
  T.Free;

  { a posted event from a second thread is delivered }
  Check(not TEventQueue.HasPostedEvents, 'nothing is posted before the thread starts');
  T := TWorker.Create(wkPost, 250, 5, 100, B);
  Start := Now64;
  Got := 0;
  Ok := True;
  while (Got < 5) and (Now64 - Start < Guard) do
    if TEventQueue.GetPostedEvent(Ev) then
    begin
      Inc(Got);
      Ok := Ok and (Ev.What = evCommand) and (Ev.Message.Command = 100 + Got);
    end
    else
      TEventQueue.WaitForEvents(1000);
  Check(Got = 5, 'all posted events of a second thread are delivered');
  Check(Ok, 'they come in the order they were posted');
  Check(Now64 - Start < Guard - 1000, 'the posted events ended the wait');
  T.WaitFor;
  T.Free;

  { events posted by several threads at once: all delivered, in order per thread }
  for Group := 0 to 3 do
  begin
    Last[Group] := 0;
    Workers[Group] := TWorker.Create(wkPost, 0, 50, (Group + 1) * 1000, B);
  end;
  Start := Now64;
  Got := 0;
  Ok := True;
  while (Got < 200) and (Now64 - Start < Guard) do
    if TEventQueue.GetPostedEvent(Ev) then
    begin
      Inc(Got);
      Group := Ev.Message.Command div 1000 - 1;
      if (Group < 0) or (Group > 3) or (Ev.Message.Command mod 1000 <> Last[Group] + 1) then
        Ok := False
      else
        Last[Group] := Last[Group] + 1;
    end
    else
      TEventQueue.WaitForEvents(1000);
  Check(Got = 200, 'all events posted by four threads are delivered');
  Check(Ok, 'the events of each thread keep their order');
  for I := 0 to 3 do
  begin
    Workers[I].WaitFor;
    Workers[I].Free;
  end;
  Check(not TEventQueue.HasPostedEvents, 'no posted event is left');

  { an input fed by a second thread ends a blocked wait, and the key is there }
  TEventQueue.WaitForEvents(0);
  T := TWorker.Create(wkFeed, 250, 0, 0, B);
  Start := Now64;
  TEventQueue.WaitForEvents(Guard);
  Check(Now64 - Start < Guard - 1000, 'an input from a second thread ends a blocked wait');
  T.WaitFor;
  T.Free;
  FillChar(Ev, SizeOf(Ev), 0);
  TEventQueue.GetKeyEvent(Ev);
  Check((Ev.What = evKeyDown) and (Ev.KeyDown.KeyCode = kbF3), 'the key of the second thread is read');

  Q.Free;
  TEventQueue.Backend := nil;
  B.Free;
  Done;
end.
