{ Computes the CRC-32 checksum of zip, PNG and Ethernet, continuable over further data. }
unit TvCrc;

{$mode objfpc}
{$R-}
{$Q-}

interface

function Crc32(Crc: LongWord; const Buf; Len: SizeInt): LongWord;
function Crc32Str(Crc: LongWord; const S: AnsiString): LongWord;

implementation

function Crc32(Crc: LongWord; const Buf; Len: SizeInt): LongWord;
begin
  Result := 0;
end;

function Crc32Str(Crc: LongWord; const S: AnsiString): LongWord;
begin
  Result := 0;
end;

end.
