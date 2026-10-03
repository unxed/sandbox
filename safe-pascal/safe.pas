{ Safe Pascal v0.1 — безопасный по умолчанию Free Pascal одним файлом.
  Спецификация: SPEC.md. Подключение: положить файл рядом с исходниками и
  написать `uses ..., Safe;` ПОСЛЕДНИМ в каждом модуле. Опции компилятора не нужны.

  Что делает модуль:
  - UTF-8 везде (initialization): строки, имена файлов, консоль; cwstring спрятан внутри;
  - TOwned/TShared/TWeak/TSlice/TArena (SPEC §4–5);
  - "отравляет" опасные примитивы затенением имён (SPEC §6): GetMem(...) в модуле,
    где Safe последний в uses, не скомпилируется. Полное имя (System.GetMem) — явный unsafe.

  Перенос в FPC/Lazarus приветствуется. }
unit Safe;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  {$if defined(unix) and not defined(SAFE_NO_CWSTRING)}cwstring,{$endif} // UTF-8 <-> UTF-16 и регистр букв через libc (SAFE_NO_CWSTRING: статическая сборка без libc)
  {$ifdef windows}Windows,{$endif}
  SysUtils;

type
  ESafety = class(Exception);

  { ---------- Внутреннее устройство. Прикладной код это не использует. ---------- }

  { Ячейка для слабых ссылок. Живёт, пока жив объект или хоть один TWeak. }
  TSafeCell = class(TInterfacedObject)
  public
    Life: TObject; // TSafeLife, пока объект жив; nil после смерти
  end;

  { Время жизни объекта. Счётчик ведёт компилятор: на TSafeLife ссылаются
    поля-интерфейсы в записях TOwned/TShared. Последняя ссылка ушла — объект уничтожен. }
  TSafeLife = class(TInterfacedObject)
  public
    Obj: TObject;
    CellObj: TSafeCell;
    CellRef: IInterface;
    destructor Destroy; override;
    function Cell: TSafeCell; // создаётся при первом TShared.Weak
  end;

  TSafeArenaImpl = class(TInterfacedObject)
  public
    Items: array of TObject;
    Count: SizeInt;
    procedure FreeAll;
    destructor Destroy; override;
  end;

{ Для обобщений: их тела компилируются в модуле пользователя и могут
  ссылаться только на символы интерфейса. }
function SafeNewLife(AObj: TObject; const Who: string): TSafeLife;
procedure SafeFail(const Msg: string);

{ Счётчик живых объектов под владением (аналог testing.allocator из Zig): растёт при Own/Share/Adopt,
  убывает при уничтожении. Тест, который «всё освободил», проверяет SafeCheckNoLeaks (R5). }
function SafeLiveCount: LongInt;
procedure SafeCheckNoLeaks;
{ Исключения, подавленные в отложенных вызовах TDefer (см. ниже). }
function SafeDeferFailures: LongInt;

type
  { ---------- API (SPEC §5) ---------- }

  generic TOwned<T: class> = record
  private
    FObj: T;
    FLife: IInterface;
  public
    class function Own(AObj: T): TOwned; static;
    function Get: T;
    function TryGet(out AObj: T): Boolean;
    function IsEmpty: Boolean;
    function Move: TOwned;
    procedure Reset;
  end;

  generic TWeak<T: class> = record
  private
    FCellObj: TSafeCell;
    FCell: IInterface;
  public
    procedure SetCell(ACell: TSafeCell); // внутреннее
    function CellObj: TSafeCell;         // внутреннее
    function IsAlive: Boolean;
    procedure Reset;
  end;

  generic TShared<T: class> = record
  private
    FObj: T;
    FLifeObj: TSafeLife;
    FLife: IInterface;
  public
    class function Share(AObj: T): TShared; static;
    function Get: T;
    function TryGet(out AObj: T): Boolean;
    function IsEmpty: Boolean;
    procedure Reset;
    function Weak: specialize TWeak<T>;
    function TryLock(const W: specialize TWeak<T>): Boolean;
  end;

  generic TSlice<T> = record
  private
    FData: specialize TArray<T>;
    FStart, FLen: SizeInt;
    function GetItem(I: SizeInt): T;
    procedure SetItem(I: SizeInt; const V: T);
  public
    class function From(const A: specialize TArray<T>): TSlice; static;
    function Sub(AStart, ALen: SizeInt): TSlice;
    function Len: SizeInt;
    function ToArray: specialize TArray<T>;
    property Items[I: SizeInt]: T read GetItem write SetItem; default;
  end;

  TArena = record
  private
    FImpl: TSafeArenaImpl;
    FRef: IInterface;
    procedure Check;
  public
    class function Create: TArena; static;
    function Adopt(AObj: TObject): TObject;
    procedure FreeAll;
    function Count: SizeInt;
  end;

  { ---------- defer (идея из Zig) ----------
    Запись-сторож: вызывает процедуру при выходе переменной из области видимости, в том числе при исключении.
    D := TDefer.Call(@Self.CloseHandle);  // ... дальше любой код ...   // CloseHandle вызовется сама
    Cancel — «errdefer наоборот»: успех, вызывать не нужно.
    Исключение внутри отложенной процедуры нельзя бросить из деструктора во время раскрутки стека: оно
    подавляется и учитывается (SafeDeferFailures; SafeCheckNoLeaks тоже падает), а не теряется молча. }
  TSafeDeferProc = procedure of object;

  TSafeDeferImpl = class(TInterfacedObject)
  public
    Proc: TSafeDeferProc;
    Cancelled: Boolean;
    destructor Destroy; override;
  end;

  TDefer = record
  private
    FImpl: TSafeDeferImpl;
    FRef: IInterface;
  public
    class function Call(AProc: TSafeDeferProc): TDefer; static;
    procedure Cancel;
  end;

  { ---------- UTF-8 ---------- }

  { Перечислитель символов (code points). Current: один символ как String. }
  TCodePointEnumerator = record
  private
    FS: RawByteString;
    FPos, FLen: SizeInt;
    function GetCurrent: string;
  public
    function GetEnumerator: TCodePointEnumerator;
    function MoveNext: Boolean;
    property Current: string read GetCurrent;
  end;

{ for Ch in CodePoints('aё😀') do ...  // 'a', 'ё', '😀' }
function CodePoints(const S: string): TCodePointEnumerator;
{ Длина в символах (code points), а не в байтах. }
function CPLength(const S: string): SizeInt;

type
  { ---------- Отравленные примитивы (SPEC §6) ----------
    Тип-заглушка с тем же именем закрывает процедуру из System/SysUtils:
    вызов превращается в недопустимое приведение типа (ошибка компиляции),
    а deprecated-сообщение объясняет, что писать вместо. }
  TSafeForbidden = record end;

  GetMem     = TSafeForbidden deprecated 'SAFE-S1: raw allocation. Use TOwned/TShared/TArena or TArray<T>; in unsafe code write System.GetMem with // UNSAFE: comment';
  AllocMem   = TSafeForbidden deprecated 'SAFE-S1: raw allocation. Use TOwned/TShared/TArena or TArray<T>; in unsafe code write System.AllocMem';
  ReallocMem = TSafeForbidden deprecated 'SAFE-S1: raw allocation. Use TArray<T> + SetLength; in unsafe code write System.ReallocMem';
  FreeMem    = TSafeForbidden deprecated 'SAFE-S1: raw deallocation. Owners free memory; in unsafe code write System.FreeMem';
  New        = TSafeForbidden deprecated 'SAFE-S1: raw allocation. Use a record value or TOwned; in unsafe code write System.New';
  Dispose    = TSafeForbidden deprecated 'SAFE-S1: raw deallocation. Owners free memory; in unsafe code write System.Dispose';
  Move       = TSafeForbidden deprecated 'SAFE-S2: raw memory copy. Use assignment or Copy(); in unsafe code write System.Move';
  FillChar   = TSafeForbidden deprecated 'SAFE-S2: raw memory fill. Use X := Default(TType); in unsafe code write System.FillChar';
  FreeAndNil = TSafeForbidden deprecated 'SAFE-S3: manual destruction. Use TOwned.Reset; in unsafe code write SysUtils.FreeAndNil';

  { Типы оставлены рабочими (миграция), но каждое использование — предупреждение. }
  Pointer   = System.Pointer   deprecated 'SAFE-S4: raw pointer. Use TOwned/TSlice/open array; in unsafe code write System.Pointer';
  PByte     = System.PByte     deprecated 'SAFE-S4: raw pointer. Use TSlice<Byte> or array of Byte; in unsafe code write System.PByte';
  PChar     = System.PChar     deprecated 'SAFE-S4: raw pointer. Use String; at OS boundary write System.PChar in unsafe code';
  PAnsiChar = System.PAnsiChar deprecated 'SAFE-S4: raw pointer. Use String; at OS boundary write System.PAnsiChar in unsafe code';
  PWideChar = System.PWideChar deprecated 'SAFE-S4: raw pointer. Use String; at OS boundary write System.PWideChar in unsafe code';

  { Free — метод, его закрывает хелпер. Поведение прежнее, но с предупреждением.
    Ограничение: другой хелпер для TObject, подключённый после Safe, перекроет этот (S7). }
  TSafeObjectHelper = class helper for TObject
  public
    procedure Free; deprecated 'SAFE-S3: manual destruction. Use TOwned/TShared/TArena; in unsafe code call .Destroy with // UNSAFE: comment';
  end;

implementation

{ ---------- внутреннее ---------- }

var
  GLive: LongInt = 0;         // объекты под владением (TOwned/TShared/TArena), живые сейчас
  GDeferFailures: LongInt = 0; // исключения, подавленные в отложенных вызовах

function SafeLiveCount: LongInt;
begin
  Result := GLive;
end;

function SafeDeferFailures: LongInt;
begin
  Result := GDeferFailures;
end;

procedure SafeCheckNoLeaks;
begin
  if GLive <> 0 then
    SafeFail(Format('SAFE-R5: %d owned object(s) still alive', [GLive]));
  if GDeferFailures <> 0 then
    SafeFail(Format('SAFE-R5: %d exception(s) were suppressed in deferred calls', [GDeferFailures]));
end;

procedure SafeFail(const Msg: string);
begin
  raise ESafety.Create(Msg);
end;

function SafeNewLife(AObj: TObject; const Who: string): TSafeLife;
begin
  if AObj = nil then
    Exit(nil);
  if AObj is TInterfacedObject then
    SafeFail('SAFE-R3: ' + Who + '(' + AObj.ClassName +
      '): TInterfacedObject is owned by its interface refcount; hold it through an interface');
  Result := TSafeLife.Create;
  Result.Obj := AObj;
  InterlockedIncrement(GLive);
end;

destructor TSafeLife.Destroy;
var
  O: TObject;
begin
  if CellObj <> nil then
    CellObj.Life := nil; // слабые ссылки больше не залочат объект
  O := Obj;
  Obj := nil;
  if O <> nil then
  begin
    O.Destroy; // Free здесь затенён хелпером
    InterlockedDecrement(GLive);
  end;
  CellRef := nil;
  inherited Destroy;
end;

function TSafeLife.Cell: TSafeCell;
begin
  if CellObj = nil then
  begin
    CellObj := TSafeCell.Create;
    CellObj.Life := Self;
    CellRef := CellObj;
  end;
  Result := CellObj;
end;

procedure TSafeArenaImpl.FreeAll;
var
  I: SizeInt;
  O: TObject;
begin
  for I := Count - 1 downto 0 do // обратный порядок: позже созданные могут ссылаться на ранние
  begin
    O := Items[I];
    Items[I] := nil;
    O.Destroy;
    InterlockedDecrement(GLive);
  end;
  Count := 0;
  SetLength(Items, 0);
end;

destructor TSafeArenaImpl.Destroy;
begin
  FreeAll;
  inherited Destroy;
end;

{ ---------- TOwned ---------- }

class function TOwned.Own(AObj: T): TOwned;
begin
  Result.FLife := SafeNewLife(AObj, 'TOwned.Own');
  Result.FObj := AObj;
end;

function TOwned.Get: T;
begin
  if FLife = nil then
    SafeFail('SAFE-R1: TOwned.Get on empty owner (after Move or Reset)');
  Result := FObj;
end;

function TOwned.TryGet(out AObj: T): Boolean;
begin
  Result := FLife <> nil;
  if Result then AObj := FObj else AObj := nil;
end;

function TOwned.IsEmpty: Boolean;
begin
  Result := FLife = nil;
end;

function TOwned.Move: TOwned;
var
  L: IInterface;
  O: T;
begin
  // Через локальные: корректно даже если Result и Self — одна память (A := A.Move).
  L := FLife;
  O := FObj;
  FLife := nil;
  FObj := nil;
  Result.FObj := O;
  Result.FLife := L;
end;

procedure TOwned.Reset;
begin
  FObj := nil;
  FLife := nil;
end;

{ ---------- TWeak ---------- }

procedure TWeak.SetCell(ACell: TSafeCell);
begin
  FCellObj := ACell;
  FCell := ACell;
end;

function TWeak.CellObj: TSafeCell;
begin
  Result := FCellObj;
end;

function TWeak.IsAlive: Boolean;
begin
  Result := (FCellObj <> nil) and (FCellObj.Life <> nil);
end;

procedure TWeak.Reset;
begin
  FCellObj := nil;
  FCell := nil;
end;

{ ---------- TShared ---------- }

class function TShared.Share(AObj: T): TShared;
begin
  Result.FLifeObj := SafeNewLife(AObj, 'TShared.Share');
  Result.FLife := Result.FLifeObj;
  Result.FObj := AObj;
end;

function TShared.Get: T;
begin
  if FLife = nil then
    SafeFail('SAFE-R1: TShared.Get on empty reference (after Reset or failed TryLock)');
  Result := FObj;
end;

function TShared.TryGet(out AObj: T): Boolean;
begin
  Result := FLife <> nil;
  if Result then AObj := FObj else AObj := nil;
end;

function TShared.IsEmpty: Boolean;
begin
  Result := FLife = nil;
end;

procedure TShared.Reset;
begin
  FObj := nil;
  FLifeObj := nil;
  FLife := nil;
end;

function TShared.Weak: specialize TWeak<T>;
begin
  if FLife = nil then
    Result.SetCell(nil)
  else
    Result.SetCell(FLifeObj.Cell);
end;

function TShared.TryLock(const W: specialize TWeak<T>): Boolean;
var
  C: TSafeCell;
  L: TSafeLife;
begin
  C := W.CellObj;
  Result := (C <> nil) and (C.Life <> nil);
  if Result then
  begin
    L := TSafeLife(C.Life);
    FLife := L; // сильная ссылка: объект не умрёт, пока она есть
    FLifeObj := L;
    FObj := T(L.Obj);
  end
  else
    Reset;
end;

{ ---------- TSlice ---------- }

class function TSlice.From(const A: specialize TArray<T>): TSlice;
begin
  Result.FData := A;
  Result.FStart := 0;
  Result.FLen := Length(A);
end;

function TSlice.Sub(AStart, ALen: SizeInt): TSlice;
begin
  if (AStart < 0) or (ALen < 0) or (AStart > FLen - ALen) then
    SafeFail(Format('SAFE-R2: TSlice.Sub(%d, %d) out of bounds, length %d', [AStart, ALen, FLen]));
  Result.FData := FData;
  Result.FStart := FStart + AStart;
  Result.FLen := ALen;
end;

function TSlice.Len: SizeInt;
begin
  Result := FLen;
end;

function TSlice.ToArray: specialize TArray<T>;
begin
  Result := Copy(FData, FStart, FLen);
end;

function TSlice.GetItem(I: SizeInt): T;
begin
  if (I < 0) or (I >= FLen) then
    SafeFail(Format('SAFE-R2: TSlice index %d out of bounds, length %d', [I, FLen]));
  Result := FData[FStart + I];
end;

procedure TSlice.SetItem(I: SizeInt; const V: T);
begin
  if (I < 0) or (I >= FLen) then
    SafeFail(Format('SAFE-R2: TSlice index %d out of bounds, length %d', [I, FLen]));
  FData[FStart + I] := V;
end;

{ ---------- TArena ---------- }

class function TArena.Create: TArena;
begin
  Result.FImpl := TSafeArenaImpl.Create;
  Result.FRef := Result.FImpl;
end;

procedure TArena.Check;
begin
  if FRef = nil then
    SafeFail('SAFE-R4: TArena used before TArena.Create');
end;

function TArena.Adopt(AObj: TObject): TObject;
begin
  Check;
  Result := AObj;
  if AObj = nil then
    Exit;
  if AObj is TInterfacedObject then
    SafeFail('SAFE-R3: TArena.Adopt(' + AObj.ClassName +
      '): TInterfacedObject is owned by its interface refcount; hold it through an interface');
  if FImpl.Count = Length(FImpl.Items) then
    SetLength(FImpl.Items, 2 * FImpl.Count + 8);
  FImpl.Items[FImpl.Count] := AObj;
  Inc(FImpl.Count);
  InterlockedIncrement(GLive);
end;

procedure TArena.FreeAll;
begin
  Check;
  FImpl.FreeAll;
end;

function TArena.Count: SizeInt;
begin
  Check;
  Result := FImpl.Count;
end;

{ ---------- defer ---------- }

destructor TSafeDeferImpl.Destroy;
begin
  if (not Cancelled) and Assigned(Proc) then
    try
      Proc();
    except
      InterlockedIncrement(GDeferFailures); // из деструктора бросать нельзя: учитываем, SafeCheckNoLeaks заметит
    end;
  inherited Destroy;
end;

class function TDefer.Call(AProc: TSafeDeferProc): TDefer;
begin
  Result.FImpl := TSafeDeferImpl.Create;
  Result.FImpl.Proc := AProc;
  Result.FRef := Result.FImpl;
end;

procedure TDefer.Cancel;
begin
  if FImpl <> nil then
    FImpl.Cancelled := True;
end;

{ ---------- UTF-8 ---------- }

{ Длина символа по ведущему байту. Битый байт или "хвост" — отдельный символ:
  обход никогда не зацикливается и не теряет байты. }
function CPByteLen(B: Byte): SizeInt; inline;
begin
  case B of
    $C0..$DF: Result := 2;
    $E0..$EF: Result := 3;
    $F0..$F7: Result := 4;
  else
    Result := 1;
  end;
end;

function TCodePointEnumerator.GetCurrent: string;
begin
  Result := Copy(FS, FPos, FLen);
end;

function TCodePointEnumerator.GetEnumerator: TCodePointEnumerator;
begin
  Result := Self;
end;

function TCodePointEnumerator.MoveNext: Boolean;
begin
  Inc(FPos, FLen);
  Result := FPos <= Length(FS);
  if Result then
  begin
    FLen := CPByteLen(Byte(FS[FPos]));
    if FLen > Length(FS) - FPos + 1 then // обрезанный символ в конце строки
      FLen := Length(FS) - FPos + 1;
  end;
end;

function CodePoints(const S: string): TCodePointEnumerator;
begin
  Result.FS := S;
  Result.FPos := 1;
  Result.FLen := 0;
end;

function CPLength(const S: string): SizeInt;
var
  Ch: string;
begin
  Result := 0;
  for Ch in CodePoints(S) do
    Inc(Result);
end;

{ ---------- хелпер Free ---------- }

procedure TSafeObjectHelper.Free;
begin
  if Self <> nil then
    Destroy;
end;

initialization
{$ifndef SAFE_NO_UTF8}
  // Кодировка String по умолчанию (а с ней и всех неявных конверсий).
  DefaultSystemCodePage := CP_UTF8;
  // Имена файлов: на входе в RTL и на выходе (FindFirst, GetCurrentDir...).
  DefaultFileSystemCodePage := CP_UTF8;
  DefaultRTLFileSystemCodePage := CP_UTF8;
  // Консоль и стандартные потоки.
  SetTextCodePage(Input, CP_UTF8);
  SetTextCodePage(Output, CP_UTF8);
  SetTextCodePage(ErrOutput, CP_UTF8);
  SetTextCodePage(StdOut, CP_UTF8);
  SetTextCodePage(StdErr, CP_UTF8);
  {$ifdef windows}
  SetConsoleOutputCP(CP_UTF8);
  SetConsoleCP(CP_UTF8);
  {$endif}
{$endif}
end.
