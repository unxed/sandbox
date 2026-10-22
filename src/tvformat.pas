{ Formats a short text from a format string and arguments, cut at 255 characters. }
unit TvFormat;

{$mode objfpc}
{$R-}
{$Q-}

interface

{ SysUtils.Format with Args, cut at 255 characters. }
function FormatStr(const Fmt: ShortString; const Args: array of const): ShortString;

implementation

uses
  SysUtils;

const
  MaxShortLen = 255;

function FormatStr(const Fmt: ShortString; const Args: array of const): ShortString;
var
  Full: AnsiString;
begin
  Full := Format(Fmt, Args);
  if Length(Full) > MaxShortLen then
    SetLength(Full, MaxShortLen);
  Result := Full;
end;

end.
