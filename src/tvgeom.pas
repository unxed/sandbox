{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/objects.h (TPoint, TRect)
  See COPYRIGHT.magiblot. }
unit TvGeom;

{$mode objfpc}
{$modeswitch advancedrecords}

interface

type
  TPoint = record
    X, Y: Integer;
    function AddAssign(const Adder: TPoint): TPoint;
    function SubAssign(const Subber: TPoint): TPoint;
    class operator +(const One, Two: TPoint): TPoint;
    class operator -(const One, Two: TPoint): TPoint;
    class operator =(const One, Two: TPoint): Boolean;
    class operator <>(const One, Two: TPoint): Boolean;
  end;

  TRect = record
    A, B: TPoint;
    constructor Create(AX, AY, BX, BY: Integer); overload;
    constructor Create(const P1, P2: TPoint); overload;
    function Move(ADX, ADY: Integer): TRect;
    function Grow(ADX, ADY: Integer): TRect;
    function Intersect(const R: TRect): TRect;
    function Union(const R: TRect): TRect;
    function Contains(const P: TPoint): Boolean;
    function IsEmpty: Boolean;
    class operator =(const One, Two: TRect): Boolean;
    class operator <>(const One, Two: TRect): Boolean;
  end;

implementation

{ TPoint }

function TPoint.AddAssign(const Adder: TPoint): TPoint;
begin
end;

function TPoint.SubAssign(const Subber: TPoint): TPoint;
begin
end;

class operator TPoint.+(const One, Two: TPoint): TPoint;
begin
end;

class operator TPoint.-(const One, Two: TPoint): TPoint;
begin
end;

class operator TPoint.=(const One, Two: TPoint): Boolean;
begin
end;

class operator TPoint.<>(const One, Two: TPoint): Boolean;
begin
end;

{ TRect }

constructor TRect.Create(AX, AY, BX, BY: Integer);
begin
end;

constructor TRect.Create(const P1, P2: TPoint);
begin
end;

function TRect.Move(ADX, ADY: Integer): TRect;
begin
end;

function TRect.Grow(ADX, ADY: Integer): TRect;
begin
end;

function TRect.Intersect(const R: TRect): TRect;
begin
end;

function TRect.Union(const R: TRect): TRect;
begin
end;

function TRect.Contains(const P: TPoint): Boolean;
begin
end;

function TRect.IsEmpty: Boolean;
begin
end;

class operator TRect.=(const One, Two: TRect): Boolean;
begin
end;

class operator TRect.<>(const One, Two: TRect): Boolean;
begin
end;

end.
