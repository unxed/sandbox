{ Removes the hot key marks '~' from the texts of menus and controls. }
unit TvCStr;

{$mode objfpc}
{$R-}
{$Q-}

interface

{ S without any '~' (the text as the user sees it): '~F~ile' gives 'File'. }
function StripTilde(const S: AnsiString): AnsiString;

implementation

function StripTilde(const S: AnsiString): AnsiString;
const
  MarkCode = 126;
var
  Start, Run, Cnt, Total: SizeInt;
begin
  Result := '';
  if S = '' then
    Exit;
  SetLength(Result, Length(S));
  Total := 0;
  Start := 1;
  while Start <= Length(S) do
  begin
    Run := IndexByte(S[Start], Length(S) - Start + 1, MarkCode);
    if Run < 0 then
      Cnt := Length(S) - Start + 1
    else
      Cnt := Run;
    if Cnt > 0 then
      Move(S[Start], Result[Total + 1], Cnt);
    Inc(Total, Cnt);
    Start := Start + Cnt + 1;
  end;
  SetLength(Result, Total);
end;

end.
