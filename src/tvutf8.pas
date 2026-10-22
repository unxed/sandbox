{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/internal/utf8.h, source/platform/ttext.cpp, include/tvision/ttext.h
  See COPYRIGHT.magiblot. }
unit TvUtf8;

{$mode objfpc}

interface

{ Indices into a text are zero-based, as in the C++ (the character at Index is Text[Index + 1]).
  The text is a sequence of bytes; the characters are UTF-8 sequences. }

type
  TUtf8Bytes = array[0..3] of Byte;
  TUtf16Pair = array[0..1] of Word;

  TTextMetrics = record
    Width: Cardinal;
    CharacterCount: Cardinal;
    GraphemeCount: Cardinal; { Number of non-combining characters. }
  end;

  TText = class
  public
    { Returns the width of Text. }
    class function Width(const Text: string): SizeInt; static;

    { Returns the width, the character count and the grapheme count of Text. }
    class function Measure(const Text: string): TTextMetrics; static;

    { Returns the length in bytes of the first character in Text. }
    class function Next(const Text: string): SizeInt; overload; static;

    { Increases Index by the length in bytes of the character starting at position Index of Text.
      The variant with AWidth increases AWidth by the width of the character.
      Returns whether Index was increased at all. }
    class function Next(const Text: string; var Index: SizeInt): Boolean; overload; static;
    class function Next(const Text: string; var Index, AWidth: SizeInt): Boolean; overload; static;
    class function Next(const Text: array of Cardinal; var Index, AWidth: SizeInt): Boolean; overload; static;

    { Returns the length in bytes of the character in Text right before position Index. }
    class function Prev(const Text: string; Index: SizeInt): SizeInt; static;

    { Returns the length in bytes of a leading substring of Text which is Count columns wide.
      If Text is less than Count columns wide, returns the length of Text.
      Negative values of Count are treated as 0.
      The variants with ALength and AWidth return the length and the width of the substring.
      When column Count is in the middle of a double-width character in Text, IncludeIncomplete
      determines whether the double-width character is included in the result. }
    class function Scroll(const Text: string; Count: Integer; IncludeIncomplete: Boolean): SizeInt; overload; static;
    class procedure Scroll(const Text: string; Count: Integer; IncludeIncomplete: Boolean;
      var ALength, AWidth: SizeInt); overload; static;
    class procedure Scroll(const Text: array of Cardinal; Count: Integer; IncludeIncomplete: Boolean;
      var ALength, AWidth: SizeInt); overload; static;
  end;

{ Returns the number of continuation bytes that follow FirstByte, 0 when it does not start a sequence. }
function Utf8BytesLeft(FirstByte: Byte): Cardinal;

{ Pre: S is a valid UTF-8 sequence of one to four bytes. }
function Utf8To32(const S: string): Cardinal;

{ Writes the UTF-8 sequence of U32 into U8 and returns its length. }
function Utf32To8(U32: Cardinal; var U8: TUtf8Bytes): SizeInt;

{ Pre: U16 is a valid UTF-16 sequence. If the character is a single code unit, U16[1] = 0. }
function Utf16To8(const U16: TUtf16Pair; var U8: TUtf8Bytes): SizeInt;

{ Returns the number of code units written into U16, or -1. }
function Utf32To16(U32: Cardinal; var U16: TUtf16Pair): Integer;

{ Returns the width in columns of the code point Cp: -1 for a control character, 0 for a combining or
  other zero-width character, 2 for a double-width character, 1 otherwise. }
function CharWidth(Cp: Cardinal): Integer;

implementation

function Utf8BytesLeft(FirstByte: Byte): Cardinal;
begin
  Result := 0;
end;

function Utf8To32(const S: string): Cardinal;
begin
  Result := 0;
end;

function Utf32To8(U32: Cardinal; var U8: TUtf8Bytes): SizeInt;
begin
  FillChar(U8, SizeOf(U8), 0);
  Result := 0;
end;

function Utf16To8(const U16: TUtf16Pair; var U8: TUtf8Bytes): SizeInt;
begin
  FillChar(U8, SizeOf(U8), 0);
  Result := 0;
end;

function Utf32To16(U32: Cardinal; var U16: TUtf16Pair): Integer;
begin
  FillChar(U16, SizeOf(U16), 0);
  Result := -1;
end;

function CharWidth(Cp: Cardinal): Integer;
begin
  Result := 1;
end;

class function TText.Width(const Text: string): SizeInt;
begin
  Result := 0;
end;

class function TText.Measure(const Text: string): TTextMetrics;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

class function TText.Next(const Text: string): SizeInt;
begin
  Result := 0;
end;

class function TText.Next(const Text: string; var Index: SizeInt): Boolean;
begin
  Result := False;
end;

class function TText.Next(const Text: string; var Index, AWidth: SizeInt): Boolean;
begin
  Result := False;
end;

class function TText.Next(const Text: array of Cardinal; var Index, AWidth: SizeInt): Boolean;
begin
  Result := False;
end;

class function TText.Prev(const Text: string; Index: SizeInt): SizeInt;
begin
  Result := 0;
end;

class function TText.Scroll(const Text: string; Count: Integer; IncludeIncomplete: Boolean): SizeInt;
begin
  Result := 0;
end;

class procedure TText.Scroll(const Text: string; Count: Integer; IncludeIncomplete: Boolean;
  var ALength, AWidth: SizeInt);
begin
  ALength := 0;
  AWidth := 0;
end;

class procedure TText.Scroll(const Text: array of Cardinal; Count: Integer; IncludeIncomplete: Boolean;
  var ALength, AWidth: SizeInt);
begin
  ALength := 0;
  AWidth := 0;
end;

end.
