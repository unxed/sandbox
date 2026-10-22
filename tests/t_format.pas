{ Test program of the unit TvFormat. }
program t_format;

{$mode objfpc}

uses
  SysUtils, TvFormat;

{$I testlib.inc}

function Repeated(Ch: Char; Count: Integer): AnsiString;
begin
  Result := StringOfChar(Ch, Count);
end;

var
  A: ShortString;
  Long, Full: AnsiString;
  Res: ShortString;
  Raised: Boolean;

begin
  { The rows of the table }
  Check(FormatStr('%s=%d', ['n', 5]) = 'n=5', 'string and integer');
  A := 'file';
  Check(FormatStr('name %s, %d items', [A, 42]) = 'name file, 42 items', 'short string argument');
  Check(FormatStr('[%5d][%-4s]', [7, 'ab']) = '[    7][ab  ]', 'width and left justification');
  Check(FormatStr('no items', []) = 'no items', 'format without specifiers');
  Check(FormatStr('', []) = '', 'empty format');
  Check(Length(FormatStr('', [])) = 0, 'empty format has length 0');
  Long := Repeated('a', 300);
  Res := FormatStr('%s', [Long]);
  Check(Length(Res) = 255, 'long argument is cut to 255');
  Check(Res = Repeated('a', 255), 'long argument keeps 255 characters');

  { The limit of 255 characters }
  Long := Repeated('x', 255);
  Res := FormatStr('%s', [Long]);
  Check(Length(Res) = 255, 'exactly 255 characters: length');
  Check(Res = Long, 'exactly 255 characters: unchanged');

  Full := '';
  while Length(Full) < 256 do
    Full := Full + '0123456789';
  SetLength(Full, 256);
  Res := FormatStr('%s', [Full]);
  Check(Length(Res) = 255, '256 characters: length');
  Check(Res = Copy(Full, 1, 255), '256 characters: first 255 kept');

  Full := '';
  while Length(Full) < 600 do
    Full := Full + 'abcdefghij';
  Res := FormatStr('<%s>', [Full]);
  Check(Length(Res) = 255, 'much longer text: length');
  Check(Res = Copy('<' + Full + '>', 1, 255), 'much longer text: prefix');

  Res := FormatStr('%d:%s', [12, Repeated('q', 300)]);
  Check(Length(Res) = 255, 'cut after a number: length');
  Check(Copy(Res, 1, 3) = '12:', 'cut after a number: start');

  { Equality with SysUtils.Format }
  Check(FormatStr('%x', [255]) = Format('%x', [255]), 'hexadecimal');
  Check(FormatStr('%.2f', [3.14159]) = Format('%.2f', [3.14159]), 'fixed point');
  Check(FormatStr('%%', []) = Format('%%', []), 'percent sign');
  Check(FormatStr('%e', [1234.5]) = Format('%e', [1234.5]), 'exponent');
  Check(FormatStr('%2:s %1:s %0:s', ['a', 'b', 'c']) = Format('%2:s %1:s %0:s', ['a', 'b', 'c']),
    'index specifiers');
  Check(FormatStr('%*d', [6, 42]) = Format('%*d', [6, 42]), 'width from an argument');
  Check(FormatStr('%8.3f|', [2.5]) = Format('%8.3f|', [2.5]), 'width and precision');

  { Errors are not caught }
  Raised := False;
  try
    FormatStr('%d', ['x']);
  except
    on Exception do
      Raised := True;
  end;
  Check(Raised, 'a specifier that does not fit the argument raises');

  Raised := False;
  try
    FormatStr('%s %s', ['only one']);
  except
    on Exception do
      Raised := True;
  end;
  Check(Raised, 'too few arguments raise');

  Done;
end.
