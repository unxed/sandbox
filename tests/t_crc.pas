{ Test program of the unit TvCrc. }
program t_crc;

{$mode objfpc}

uses
  TvCrc;

{$I testlib.inc}

const
  Fox = 'The quick brown fox jumps over the lazy dog';

var
  Bytes: array[0..255] of Byte;
  Sh: ShortString;
  Whole, Part, Back: LongWord;
  I, J: Integer;
  Dummy: Byte;
  AllSplits: Boolean;
  Chars: AnsiString;

begin
  { Empty input and unchanged continuation values }
  Check(Crc32Str(0, '') = 0, 'empty string');
  Check(Crc32Str(5, '') = 5, 'empty string keeps the start value 5');
  Check(Crc32Str($FFFFFFFF, '') = $FFFFFFFF, 'empty string keeps a start value with the high bit');
  Dummy := 0;
  Check(Crc32(7, Dummy, 0) = 7, 'zero length keeps the start value');
  Check(Crc32(0, Dummy, 0) = 0, 'zero length from 0');
  Check(Crc32(9, Dummy, -3) = 9, 'negative length keeps the start value');

  { Values of the examples }
  Check(Crc32Str(0, 'a') = $E8B7BE43, 'a');
  Check(Crc32Str(0, '123456789') = $CBF43926, '123456789');
  Check(Crc32Str(0, Fox) = $414FA339, 'quick brown fox');
  Check(Crc32Str(0, 'MICROSOFT') = $795B3767, 'MICROSOFT');
  Check(Crc32Str(0, 'BORLAND') = $4DF4784C, 'BORLAND');

  { The 256 byte values, which also covers the bytes of $80 and above }
  for I := 0 to 255 do
    Bytes[I] := I;
  Check(Crc32(0, Bytes[0], 256) = $29058C73, 'bytes 0..255');
  Check(Crc32(0, Bytes, SizeOf(Bytes)) = $29058C73, 'bytes 0..255 passed as the whole array');

  SetLength(Chars, 256);
  for I := 0 to 255 do
    Chars[I + 1] := Chr(I);
  Check(Crc32Str(0, Chars) = $29058C73, 'string of the 256 characters');
  Check(Crc32Str(0, Chars) = Crc32(0, Bytes[0], 256), 'string and buffer agree');

  { Chaining }
  Part := Crc32Str(0, 'The quick brown ');
  Check(Crc32Str(Part, 'fox jumps over the lazy dog') = $414FA339, 'chained fox');
  Check(Crc32Str(Crc32Str(0, ''), Fox) = $414FA339, 'empty first part');
  Check(Crc32Str(Crc32Str(0, Fox), '') = $414FA339, 'empty last part');

  AllSplits := True;
  for I := 0 to Length(Fox) do
    if Crc32Str(Crc32Str(0, Copy(Fox, 1, I)), Copy(Fox, I + 1, Length(Fox))) <> $414FA339 then
      AllSplits := False;
  Check(AllSplits, 'every split point of the fox text');

  AllSplits := True;
  for I := 0 to 256 do
  begin
    Part := Crc32(0, Bytes[0], I);
    if I < 256 then
      Whole := Crc32(Part, Bytes[I], 256 - I)
    else
      Whole := Crc32(Part, Dummy, 0);
    if Whole <> $29058C73 then
      AllSplits := False;
  end;
  Check(AllSplits, 'every split point of the 256 bytes');

  AllSplits := True;
  for I := 0 to 256 do
    for J := I to 256 do
    begin
      Part := Crc32(0, Bytes[0], I);
      if J > I then
        Part := Crc32(Part, Bytes[I], J - I);
      if J < 256 then
        Part := Crc32(Part, Bytes[J], 256 - J);
      if Part <> $29058C73 then
        AllSplits := False;
    end;
  Check(AllSplits, 'every split of the 256 bytes into three parts');

  { One byte at a time }
  Whole := 0;
  for I := 0 to 255 do
    Whole := Crc32(Whole, Bytes[I], 1);
  Check(Whole = $29058C73, 'single bytes');
  Whole := 0;
  for I := 1 to Length('123456789') do
    Whole := Crc32Str(Whole, Copy('123456789', I, 1));
  Check(Whole = $CBF43926, 'single characters');

  { A short string and an offset into a buffer }
  Sh := '123456789';
  Check(Crc32(0, Sh[1], Length(Sh)) = $CBF43926, 'short string');
  Sh := Fox;
  Check(Crc32(0, Sh[1], Length(Sh)) = Crc32Str(0, Fox), 'short string and ansi string agree');
  Check(Crc32(0, Sh[1], 0) = 0, 'zero length at a character');
  Check(Crc32(0, Chars[2], 255) = Crc32(0, Bytes[1], 255), 'string character as the start address');

  { Several runs give the same result, also with a continuation value that has the high bit set }
  Whole := Crc32Str($89ABCDEF, Fox);
  Back := Crc32Str($89ABCDEF, Fox);
  Check(Whole = Back, 'repeated call');
  Check(Whole <> Crc32Str(0, Fox), 'start value changes the result');

  Done;
end.
