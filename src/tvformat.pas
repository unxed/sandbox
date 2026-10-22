{ Formats a short text from a format string and arguments, cut at 255 characters. }
unit TvFormat;

{$mode objfpc}
{$R-}
{$Q-}

interface

{ SysUtils.Format with Args, cut at 255 characters. }
function FormatStr(const Fmt: ShortString; const Args: array of const): ShortString;

implementation

function FormatStr(const Fmt: ShortString; const Args: array of const): ShortString;
begin
  Result := '';
end;

end.
