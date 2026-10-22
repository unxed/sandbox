{ Test harness for the programs tests/t_*.pas (mode objfpc).

  Check(Cond, Name) counts a check and prints "FAIL <Name>" when Cond is false.
  Done prints "ALL OK (<n> checks)", or "<k> FAILED of <n>" and then ends the program with exit code 1. }

var
  TestChecks: Integer = 0;
  TestFailures: Integer = 0;

procedure Check(Cond: Boolean; const Name: string);
begin
  Inc(TestChecks);
  if not Cond then
  begin
    Inc(TestFailures);
    WriteLn('FAIL ', Name);
  end;
end;

procedure Done;
begin
  if TestFailures = 0 then
    WriteLn('ALL OK (', TestChecks, ' checks)')
  else
  begin
    WriteLn(TestFailures, ' FAILED of ', TestChecks);
    Halt(1);
  end;
end;
