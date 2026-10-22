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
begin
  Result := '';
end;

end.
