{ Computes the CRC-32 checksum of zip, PNG and Ethernet, continuable over further data. }
unit TvCrc;

{$mode objfpc}
{$R-}
{$Q-}

interface

function Crc32(Crc: LongWord; const Buf; Len: SizeInt): LongWord;
function Crc32Str(Crc: LongWord; const S: AnsiString): LongWord;

implementation

const
  ReflectedPoly = LongWord($EDB88320);

var
  Lookup: array[Byte] of LongWord;
  LookupBuilt: Boolean = False;

{ Entry B is the remainder of the byte B, processed one bit at a time from the low end. }
procedure BuildLookup;
var
  B, N: Integer;
  Rem: LongWord;
begin
  for B := 0 to 255 do
  begin
    Rem := LongWord(B);
    for N := 1 to 8 do
    begin
      if Odd(Rem) then
        Rem := ReflectedPoly xor (Rem shr 1)
      else
        Rem := Rem shr 1;
    end;
    Lookup[B] := Rem;
  end;
  LookupBuilt := True;
end;

function Crc32(Crc: LongWord; const Buf; Len: SizeInt): LongWord;
var
  Cur: PByte;
  Left: SizeInt;
  Reg: LongWord;
begin
  if Len <= 0 then
    Exit(Crc);
  if not LookupBuilt then
    BuildLookup;
  Cur := @Buf;
  Reg := LongWord(not Crc);
  for Left := Len downto 1 do
  begin
    Reg := Lookup[Byte(Reg) xor Cur^] xor (Reg shr 8);
    Inc(Cur);
  end;
  Result := LongWord(not Reg);
end;

function Crc32Str(Crc: LongWord; const S: AnsiString): LongWord;
begin
  if Length(S) = 0 then
    Result := Crc
  else
    Result := Crc32(Crc, S[1], Length(S));
end;

end.
