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

function MaxInt(P, Q: Integer): Integer;
begin
  if P > Q then
    Result := P
  else
    Result := Q;
end;

function MinInt(P, Q: Integer): Integer;
begin
  if P < Q then
    Result := P
  else
    Result := Q;
end;

{ TPoint }

function TPoint.AddAssign(const Adder: TPoint): TPoint;
begin
  X := X + Adder.X;
  Y := Y + Adder.Y;
  Result := Self;
end;

function TPoint.SubAssign(const Subber: TPoint): TPoint;
begin
  X := X - Subber.X;
  Y := Y - Subber.Y;
  Result := Self;
end;

class operator TPoint.+(const One, Two: TPoint): TPoint;
begin
  Result.X := One.X + Two.X;
  Result.Y := One.Y + Two.Y;
end;

class operator TPoint.-(const One, Two: TPoint): TPoint;
begin
  Result.X := One.X - Two.X;
  Result.Y := One.Y - Two.Y;
end;

class operator TPoint.=(const One, Two: TPoint): Boolean;
begin
  Result := (One.X = Two.X) and (One.Y = Two.Y);
end;

class operator TPoint.<>(const One, Two: TPoint): Boolean;
begin
  Result := (One.X <> Two.X) or (One.Y <> Two.Y);
end;

{ TRect }

constructor TRect.Create(AX, AY, BX, BY: Integer);
begin
  A.X := AX;
  A.Y := AY;
  B.X := BX;
  B.Y := BY;
end;

constructor TRect.Create(const P1, P2: TPoint);
begin
  A := P1;
  B := P2;
end;

function TRect.Move(ADX, ADY: Integer): TRect;
begin
  A.X := A.X + ADX;
  A.Y := A.Y + ADY;
  B.X := B.X + ADX;
  B.Y := B.Y + ADY;
  Result := Self;
end;

function TRect.Grow(ADX, ADY: Integer): TRect;
begin
  A.X := A.X - ADX;
  A.Y := A.Y - ADY;
  B.X := B.X + ADX;
  B.Y := B.Y + ADY;
  Result := Self;
end;

function TRect.Intersect(const R: TRect): TRect;
begin
  A.X := MaxInt(A.X, R.A.X);
  A.Y := MaxInt(A.Y, R.A.Y);
  B.X := MinInt(B.X, R.B.X);
  B.Y := MinInt(B.Y, R.B.Y);
  Result := Self;
end;

function TRect.Union(const R: TRect): TRect;
begin
  A.X := MinInt(A.X, R.A.X);
  A.Y := MinInt(A.Y, R.A.Y);
  B.X := MaxInt(B.X, R.B.X);
  B.Y := MaxInt(B.Y, R.B.Y);
  Result := Self;
end;

function TRect.Contains(const P: TPoint): Boolean;
begin
  Result := False;
  if (P.X < A.X) or (P.X >= B.X) then
    Exit;
  if (P.Y < A.Y) or (P.Y >= B.Y) then
    Exit;
  Result := True;
end;

function TRect.IsEmpty: Boolean;
begin
  Result := (B.X <= A.X) or (B.Y <= A.Y);
end;

class operator TRect.=(const One, Two: TRect): Boolean;
begin
  Result := (One.A = Two.A) and (One.B = Two.B);
end;

class operator TRect.<>(const One, Two: TRect): Boolean;
begin
  Result := not (One = Two);
end;

end.
