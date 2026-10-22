{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/ttext.h, source/platform/ttext.cpp, include/tvision/scrncell.h
  See COPYRIGHT.magiblot.

  The members of the C++ class TText that write into screen cells (drawChar, drawStr, drawOne and what they need).
  The other members of TText are in TvUtf8. A Pascal class cannot be extended in another unit, so these members are
  class methods of TTextCells.

  Only the branch of ttext.h for compilers other than Borland C++ is translated. A TSpan<TScreenCell> is an open
  array of TScreenCell that is passed by reference, a TStringView is a string, a TSpan<const uint32_t> is an open
  array of Cardinal. Indices into a text are zero-based (the character at index J is Text[J + 1]); indices into
  Cells are zero-based. A function template parameter that transforms an attribute is a TTransformAttr.

  The conversion of control characters and of extended ASCII to a code page character goes through the variable
  CodePageToPackedUtf8, which returns the bytes of the UTF-8 sequence as a Cardinal with the first byte lowest, as
  InitWithMultiByteChar expects. Its default returns the byte itself. }
unit TvText;

{$mode objfpc}
{$modeswitch advancedrecords}
{$R-}
{$Q-}

interface

uses
  TvColors, TvCell;

type
  { The callback of the Ex variants: changes the color attribute of a cell. }
  TTransformAttr = procedure(var Attr: TColorAttr);

  { Converts a code page character to a packed UTF-8 character. }
  TPackedUtf8Func = function(C: Char): Cardinal;

  TTextCells = class
  public
    { Fills Cells with the character C.
      The variant with Attr also sets the color attribute to Attr. }
    class procedure DrawChar(var Cells: array of TScreenCell; C: Char); overload; static;
    class procedure DrawChar(var Cells: array of TScreenCell; C: Char; Attr: TColorAttr); overload; static;

    { Copies text from Text into Cells, starting at position Indent of Cells and at column TextIndent of Text.
      Returns the number of cells that were filled with text.
      The variants with Attr also set the color attribute to Attr.
      The variants without Indent and TextIndent use Indent = 0 and TextIndent = 0.
      When column TextIndent of Text is in the middle of a double-width character, a whitespace is copied in its
      place. }
    class function DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
      TextIndent: Integer): SizeInt; overload; static;
    class function DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
      TextIndent: Integer; Attr: TColorAttr): SizeInt; overload; static;
    class function DrawStr(var Cells: array of TScreenCell; const Text: string): SizeInt; overload; static;
    class function DrawStr(var Cells: array of TScreenCell; const Text: string;
      Attr: TColorAttr): SizeInt; overload; static;

    { Reads a single character from a multibyte-encoded string, and writes it into a screen cell.
      I is an index into Cells that is increased by the number of cells that have been updated. J is an index into
      Text that is increased by the number of bytes read from Text. Attr is the color attribute to set in the cell.
      Returns False when no character was read.
      A screen cell may contain one printable character (of width 1 or more) and several combining characters
      appended to it (of width 0). When a zero-width character is found in Text, it is combined with the previous
      cell, Cells[I - 1], if I > 0. In this case, I is not increased and the color attribute is not set. }
    class function DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: string;
      var J: SizeInt): Boolean; overload; static;
    class function DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: string; var J: SizeInt;
      Attr: TColorAttr): Boolean; overload; static;

    { Variants of the functions above which call Transform to change the color attribute of each cell (rather than
      setting it to a fixed value). }
    class procedure DrawCharEx(var Cells: array of TScreenCell; C: Char; Transform: TTransformAttr); static;
    class function DrawStrEx(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
      TextIndent: Integer; Transform: TTransformAttr): SizeInt; overload; static;

    { UTF-32 variants of some of the functions above. }
    class function DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
      TextIndent: Integer): SizeInt; overload; static;
    class function DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
      TextIndent: Integer; Attr: TColorAttr): SizeInt; overload; static;
    class function DrawStrEx(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
      TextIndent: Integer; Transform: TTransformAttr): SizeInt; overload; static;
    class function DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: array of Cardinal;
      var J: SizeInt): Boolean; overload; static;
    class function DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: array of Cardinal;
      var J: SizeInt; Attr: TColorAttr): Boolean; overload; static;
  end;

var
  CodePageToPackedUtf8: TPackedUtf8Func;

implementation

{ TTextCells }

class procedure TTextCells.DrawChar(var Cells: array of TScreenCell; C: Char);
begin
end;

class procedure TTextCells.DrawChar(var Cells: array of TScreenCell; C: Char; Attr: TColorAttr);
begin
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
  TextIndent: Integer): SizeInt;
begin
  Result := 0;
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
  TextIndent: Integer; Attr: TColorAttr): SizeInt;
begin
  Result := 0;
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; const Text: string): SizeInt;
begin
  Result := 0;
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; const Text: string; Attr: TColorAttr): SizeInt;
begin
  Result := 0;
end;

class function TTextCells.DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: string;
  var J: SizeInt): Boolean;
begin
  Result := False;
end;

class function TTextCells.DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: string;
  var J: SizeInt; Attr: TColorAttr): Boolean;
begin
  Result := False;
end;

class procedure TTextCells.DrawCharEx(var Cells: array of TScreenCell; C: Char; Transform: TTransformAttr);
begin
end;

class function TTextCells.DrawStrEx(var Cells: array of TScreenCell; Indent: SizeInt; const Text: string;
  TextIndent: Integer; Transform: TTransformAttr): SizeInt;
begin
  Result := 0;
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
  TextIndent: Integer): SizeInt;
begin
  Result := 0;
end;

class function TTextCells.DrawStr(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
  TextIndent: Integer; Attr: TColorAttr): SizeInt;
begin
  Result := 0;
end;

class function TTextCells.DrawStrEx(var Cells: array of TScreenCell; Indent: SizeInt; const Text: array of Cardinal;
  TextIndent: Integer; Transform: TTransformAttr): SizeInt;
begin
  Result := 0;
end;

class function TTextCells.DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: array of Cardinal;
  var J: SizeInt): Boolean;
begin
  Result := False;
end;

class function TTextCells.DrawOne(var Cells: array of TScreenCell; var I: SizeInt; const Text: array of Cardinal;
  var J: SizeInt; Attr: TColorAttr): Boolean;
begin
  Result := False;
end;

end.
