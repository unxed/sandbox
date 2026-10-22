{ Translated from magiblot/tvision @ b4831e2
  C++ sources: include/tvision/objects.h (TPoint, TRect)
  See COPYRIGHT.magiblot. }
program t_geom;

{$mode objfpc}
{$modeswitch advancedrecords}

uses
  TvGeom;

{$I testlib.inc}

function Pt(AX, AY: Integer): TPoint;
begin
  Result.X := AX;
  Result.Y := AY;
end;

var
  P, Q, S: TPoint;
  R, T, U: TRect;
  Ret: TPoint;
  RetR: TRect;

begin
  { TPoint arithmetic }
  P := Pt(3, 5);
  Q := Pt(10, -2);
  S := P + Q;
  Check((S.X = 13) and (S.Y = 3), 'point add');
  S := P - Q;
  Check((S.X = -7) and (S.Y = 7), 'point subtract');
  S := Pt(1, 1);
  Ret := S.AddAssign(P);
  Check((S.X = 4) and (S.Y = 6), 'point AddAssign changes the point');
  Check((Ret.X = 4) and (Ret.Y = 6), 'point AddAssign result');
  Ret := S.SubAssign(Q);
  Check((S.X = -6) and (S.Y = 8), 'point SubAssign changes the point');
  Check((Ret.X = -6) and (Ret.Y = 8), 'point SubAssign result');
  Check((P + Pt(0, 0)) = P, 'point add zero');
  Check((P - P) = Pt(0, 0), 'point subtract itself');

  { TPoint comparison }
  Check(Pt(2, 3) = Pt(2, 3), 'point equal');
  Check(not (Pt(2, 3) = Pt(2, 4)), 'point not equal in y');
  Check(not (Pt(2, 3) = Pt(1, 3)), 'point not equal in x');
  Check(Pt(2, 3) <> Pt(2, 4), 'point differs in y');
  Check(Pt(2, 3) <> Pt(1, 3), 'point differs in x');
  Check(not (Pt(2, 3) <> Pt(2, 3)), 'point same is not different');

  { TRect construction }
  R := TRect.Create(1, 2, 11, 12);
  Check((R.A.X = 1) and (R.A.Y = 2) and (R.B.X = 11) and (R.B.Y = 12), 'rect create from ints');
  T := TRect.Create(Pt(4, 5), Pt(6, 7));
  Check((T.A.X = 4) and (T.A.Y = 5) and (T.B.X = 6) and (T.B.Y = 7), 'rect create from points');
  FillChar(U, SizeOf(U), 0);
  Check((U.A.X = 0) and (U.A.Y = 0) and (U.B.X = 0) and (U.B.Y = 0), 'rect zero');

  { comparison }
  Check(TRect.Create(1, 2, 3, 4) = TRect.Create(1, 2, 3, 4), 'rect equal');
  Check(not (TRect.Create(1, 2, 3, 4) = TRect.Create(1, 2, 3, 5)), 'rect not equal in b.y');
  Check(TRect.Create(1, 2, 3, 4) <> TRect.Create(0, 2, 3, 4), 'rect differs in a.x');
  Check(TRect.Create(1, 2, 3, 4) <> TRect.Create(1, 2, 4, 4), 'rect differs in b.x');
  Check(TRect.Create(1, 2, 3, 4) <> TRect.Create(1, 0, 3, 4), 'rect differs in a.y');
  Check(not (TRect.Create(1, 2, 3, 4) <> TRect.Create(1, 2, 3, 4)), 'rect same is not different');

  { Move }
  R := TRect.Create(1, 2, 11, 12);
  RetR := R.Move(3, -1);
  Check(R = TRect.Create(4, 1, 14, 11), 'rect move');
  Check(RetR = R, 'rect move result');
  R.Move(-4, -1);
  Check(R = TRect.Create(0, 0, 10, 10), 'rect move back');

  { Grow }
  R := TRect.Create(5, 5, 10, 10);
  RetR := R.Grow(2, 1);
  Check(R = TRect.Create(3, 4, 12, 11), 'rect grow');
  Check(RetR = R, 'rect grow result');
  R.Grow(-2, -1);
  Check(R = TRect.Create(5, 5, 10, 10), 'rect shrink');
  R.Grow(-3, 0);
  Check(R.IsEmpty, 'rect shrunk past its width is empty');

  { Intersect }
  R := TRect.Create(0, 0, 10, 10);
  T := TRect.Create(5, 3, 15, 8);
  RetR := R.Intersect(T);
  Check(R = TRect.Create(5, 3, 10, 8), 'rect intersect');
  Check(RetR = R, 'rect intersect result');
  Check(not R.IsEmpty, 'rect intersect not empty');
  R := TRect.Create(0, 0, 4, 4);
  T := TRect.Create(6, 6, 9, 9);
  R.Intersect(T);
  Check(R = TRect.Create(6, 6, 4, 4), 'rect intersect disjoint keeps the bounds');
  Check(R.IsEmpty, 'rect intersect disjoint is empty');
  R := TRect.Create(0, 0, 10, 10);
  T := TRect.Create(2, 2, 5, 5);
  R.Intersect(T);
  Check(R = T, 'rect intersect inner');

  { Union }
  R := TRect.Create(0, 0, 4, 4);
  T := TRect.Create(6, 2, 9, 3);
  RetR := R.Union(T);
  Check(R = TRect.Create(0, 0, 9, 4), 'rect union');
  Check(RetR = R, 'rect union result');
  R := TRect.Create(2, 2, 5, 5);
  T := TRect.Create(0, 0, 10, 10);
  R.Union(T);
  Check(R = T, 'rect union outer');

  { Contains: a is inclusive, b is exclusive }
  R := TRect.Create(2, 3, 6, 8);
  Check(R.Contains(Pt(2, 3)), 'contains top left');
  Check(R.Contains(Pt(5, 7)), 'contains last cell');
  Check(R.Contains(Pt(4, 5)), 'contains inner');
  Check(not R.Contains(Pt(6, 5)), 'excludes right edge');
  Check(not R.Contains(Pt(4, 8)), 'excludes bottom edge');
  Check(not R.Contains(Pt(1, 5)), 'excludes left of a.x');
  Check(not R.Contains(Pt(4, 2)), 'excludes above a.y');

  { IsEmpty }
  Check(not TRect.Create(0, 0, 1, 1).IsEmpty, 'one cell is not empty');
  Check(TRect.Create(0, 0, 0, 5).IsEmpty, 'zero width is empty');
  Check(TRect.Create(0, 0, 5, 0).IsEmpty, 'zero height is empty');
  Check(TRect.Create(5, 0, 2, 5).IsEmpty, 'negative width is empty');
  Check(TRect.Create(0, 5, 5, 2).IsEmpty, 'negative height is empty');
  Check(TRect.Create(3, 3, 3, 3).IsEmpty, 'degenerate rect is empty');
  Check(not TRect.Create(-5, -5, -1, -1).IsEmpty, 'negative coordinates, positive size');
  U := TRect.Create(1, 1, 1, 1);
  Check(not U.Contains(Pt(1, 1)), 'empty rect contains nothing');

  Done;
end.
