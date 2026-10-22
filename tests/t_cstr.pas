{ Test program of the unit TvCStr. }
program t_cstr;

{$mode objfpc}

uses
  SysUtils, TvCStr;

{$I testlib.inc}

function MarksIn(const S: AnsiString): Integer;
begin
  Result := Length(S) - Length(StringReplace(S, '~', '', [rfReplaceAll]));
end;

var
  Sh, ShOut: ShortString;
  Src, Res, Dst: AnsiString;
  I, Lo: Integer;
  AllKept, AllCut, Sound: Boolean;
  Samples: array[0..9] of AnsiString;

begin
  { The rows of the table }
  Check(StripTilde('~F~ile') = 'File', '~F~ile');
  Check(StripTilde('Save ~a~s...') = 'Save as...', 'Save ~a~s...');
  Check(StripTilde('plain') = 'plain', 'plain');
  Check(StripTilde('') = '', 'empty string');
  Check(StripTilde('~') = '', 'lone mark');
  Check(StripTilde('a~b') = 'ab', 'a~b');
  Check(StripTilde('a~~b') = 'ab', 'two marks in a row');
  Check(StripTilde('x~y~z~w') = 'xyzw', 'x~y~z~w');

  Src := #$D0#$A4 + '~' + #$D0#$B0 + '~';
  Check(StripTilde(Src) = #$D0#$A4#$D0#$B0, 'UTF-8 bytes around marks');

  Src := '';
  for I := 1 to 300 do
    Src := Src + '~';
  Src := Src + 'end';
  Check(Length(Src) = 303, 'length of the long input');
  Check(StripTilde(Src) = 'end', '300 marks and a tail');

  Sh := '~O~pen';
  ShOut := StripTilde(Sh);
  Check(ShOut = 'Open', 'short string in and out');
  Check(Length(ShOut) = 4, 'length of the short string result');

  { Unclosed and repeated marks }
  Check(StripTilde('~abc') = 'abc', 'mark at the start');
  Check(StripTilde('abc~') = 'abc', 'mark at the end');
  Check(StripTilde('~~~') = '', 'only marks');
  Check(StripTilde('~~a~~') = 'a', 'doubled marks around a character');
  Check(StripTilde(' ~ ') = '  ', 'marks between spaces');

  { Properties over several texts }
  Samples[0] := '~F~ile';
  Samples[1] := 'Save ~a~s...';
  Samples[2] := 'plain';
  Samples[3] := '';
  Samples[4] := '~';
  Samples[5] := 'a~~b~';
  Samples[6] := '~~~~~~~~';
  Samples[7] := 'text with ~ one mark';
  Samples[8] := '~A~~B~~C~';
  Samples[9] := 'Tilde-free text, 123.';
  Sound := True;
  AllKept := True;
  AllCut := True;
  for I := 0 to High(Samples) do
  begin
    Res := StripTilde(Samples[I]);
    if Length(Res) <> Length(Samples[I]) - MarksIn(Samples[I]) then
      Sound := False;
    if MarksIn(Res) <> 0 then
      AllCut := False;
    if (MarksIn(Samples[I]) = 0) and (Res <> Samples[I]) then
      AllKept := False;
  end;
  Check(Sound, 'result length is the input length minus the marks');
  Check(AllCut, 'no mark is left');
  Check(AllKept, 'a text without marks is returned equal');

  Src := '';
  for I := 1 to 50 do
    Src := Src + '~';
  Check(StripTilde(Src) = '', 'a text of only marks');
  Check(Length(StripTilde(Src)) = 0, 'a text of only marks has length 0');

  { Bytes of $80 and above }
  Src := '';
  for I := $80 to $FF do
    Src := Src + '~' + Chr(I);
  Src := Src + '~';
  Dst := '';
  for I := $80 to $FF do
    Dst := Dst + Chr(I);
  Check(StripTilde(Src) = Dst, 'bytes $80..$FF around marks');
  Check(StripTilde(Dst) = Dst, 'bytes $80..$FF alone');

  { All byte values but the mark are kept in order }
  Src := '';
  Dst := '';
  for I := 0 to 255 do
  begin
    Src := Src + Chr(I);
    if I <> 126 then
      Dst := Dst + Chr(I);
  end;
  Check(StripTilde(Src) = Dst, 'all byte values, the mark removed');
  Check(Length(StripTilde(Src)) = 255, 'length without the mark of the 256 byte values');

  { The argument is not changed }
  Src := 'a~b~c';
  Res := StripTilde(Src);
  Check(Src = 'a~b~c', 'the argument is not changed');
  Check(Res = 'abc', 'result of the kept argument');

  Res := '~x~';
  Res := StripTilde(Res);
  Check(Res = 'x', 'result assigned to the argument variable');

  Src := '';
  Res := StripTilde(Src);
  Check((Src = '') and (Res = ''), 'empty argument stays empty');

  Sh := 'a~b';
  ShOut := StripTilde(Sh);
  Check((Sh = 'a~b') and (ShOut = 'ab'), 'the short string argument is not changed');

  { Repeated calls }
  Lo := 0;
  for I := 1 to 100 do
    if StripTilde('~F~ile') = 'File' then
      Inc(Lo);
  Check(Lo = 100, 'repeated calls');

  Done;
end.
