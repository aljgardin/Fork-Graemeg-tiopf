{-----------------------------------------------------------------------------
 Unit Name: tiOIDHex
 Author:    Lukasz Zeligowski
 Purpose:   OID generator. Each OID is 32 character Hexadecimal number. This
            is equal to 128 bit unsigned INTEGER.
            By default 'cache' is 256 OIDs
            There are three usefull 'static' functions:
            TOID.CheckValue - checks if given parameter is proper HEX value
            TOID.IncHex - inc. HEX given by parameter by one
            TOID.ZeroHex - gives ZERO AValue Hex with the proper no. of chars

 History:   0.9Beta first version    
-----------------------------------------------------------------------------}

unit tiOIDHex;

{$I tiDefines.inc}

{$IFNDEF OID_AS_INT64}

interface

uses
  tiOID
  ,tiBaseObject
  ,tiObject
  ,tiVisitorDB
  ,tiVisitor
  ,SyncObjs
 ;

type
  TOIDHex = class(TOID)
  private
    FAsString : string;
  protected
    function  GetAsString: ShortString; override;
    procedure SetAsString(const AValue: ShortString); override;
    function  GetAsVariant: Variant;override;
    procedure SetAsVariant(const AValue: Variant);override;
  public
    function  IsNull : boolean; override;
    procedure AssignToTIQueryParam(const AFieldName : string; const AParams : TtiBaseObject); override;
    procedure AssignToTIQuery(const AFieldName : string; const AQuery : TtiBaseObject); override;
    procedure AssignFromTIQuery(const AFieldName : string; const AQuery : TtiBaseObject); override;
    function  EqualsQueryField(const AFieldName : string; const AQuery : TtiBaseObject): boolean; override;
    procedure Assign(const ASource : TOID); override;
    function  Compare(const ACompareWith : TOID): integer; override;
    procedure SetToNull; override;
    function  NullOIDAsString : string; override;
    class function CheckValue(AValue : ShortString): boolean;
    class function IncHex(pHex : ShortString; pInc : integer = 1): ShortString;
    class function ZeroHex : ShortString;
  end;

  TNextOIDHexData = class(TtiObject)
  private
    FNextHexOID: ShortString;
  public
    property NextHexOID : ShortString read FNextHexOID write FNextHexOID;
  end;

  TNextOIDGeneratorHex = class(TNextOIDGenerator)
  private
//    FHigh : Integer;
    FLow, FLowRange : integer;
    FLowRangeMask: string;
    FLastOIDValue : string;
    FDirty: boolean;
    FNextOIDHexData : TNextOIDHexData;
    FCritSect: TCriticalSection;
    function NextOID : String;
  public
    constructor Create; override;
    destructor  Destroy; override;
    procedure   AssignNextOID(const AAssignTo : TOID; const ADatabaseName : string; APersistenceLayerName : string); override;
  end;

  TVisDBNextOIDHexAmblerRead = class(TtiObjectVisitor)
  protected
    function    AcceptVisitor : boolean; override;
  public
    procedure   Execute(const AData : TtiVisited); override;
  end;

  TVisDBNextOIDHexAmblerUpdate = class(TtiObjectVisitor)
  protected
    function    AcceptVisitor : boolean; override;
  public
    procedure   Execute(const AData : TtiVisited); override;
  end;


const
  cOIDClassNameHex = 'OIDClassNameHex';
  cgsNextOIDHexReadHigh = 'NextOIDHexReadHigh';
  cOIDHexSize = 32;
  cOIDHexChacheSize = 2;

implementation

uses
  tiQuery
  ,SysUtils
  ,tiUtils
  ,tiOPFManager
  ,tiConstants
 ;

const
  cOIDHexNumber : array [0..15] of char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
{ TOIDHex }

procedure TOIDHex.Assign(const ASource: TOID);
begin
  AsString := ASource.AsString;
end;

procedure TOIDHex.AssignFromTIQuery(const AFieldName: string; const AQuery: TtiBaseObject);
var
  lQuery : TtiQuery;
begin
  Assert(AQuery is TtiQuery, 'AQuery not a TtiQuery');
  lQuery := TtiQuery(AQuery);
  FAsString := lQuery.FieldAsString[ AFieldName ];
end;

procedure TOIDHex.AssignToTIQuery(const AFieldName: string;
  const AQuery: TtiBaseObject);
var
  lQuery : TtiQuery;
begin
  Assert(AQuery is TtiQuery, 'AQuery not a TtiQuery');
  lQuery := TtiQuery(AQuery);
  lQuery.ParamAsString[ AFieldName ]:= FAsString;
end;

procedure TOIDHex.AssignToTIQueryParam(const AFieldName: string;const AParams: TtiBaseObject);
var
  lParams : TtiQueryParams;
begin
  Assert(AParams is TtiQueryParams, 'AQuery not a TtiQuery');
  lParams := TtiQueryParams(AParams);
  lParams.SetValueAsString(AFieldName, FAsString);
end;

class function TOIDHex.CheckValue(AValue: ShortString): boolean;
var
//  lI64 : int64;
  lHex1, lHex2 : string;
begin
  // Length 32 chars
  result:=false;
  if length(AValue)<>32 then
    exit;
  // Divide: 2 parts 16 chars is 8 bytes is 64 bits...
  lHex1:='$'+Copy(AValue,1,16);
  lHex2:='$'+Copy(AValue,17,16);
  try
    StrToInt64(lHex1);
    StrToInt64(lHex2);   
    //lI64:=StrToInt64(lHex1);
    //lI64:=StrToInt64(lHex2);
    result:=true;
  except
  end;
end;

function TOIDHex.Compare(const ACompareWith: TOID): integer;
begin
  if AsString < ACompareWith.AsString then
    result := -1
  else if AsString > ACompareWith.AsString then
    result := 1
  else
    result := 0;
end;

function TOIDHex.EqualsQueryField(const AFieldName: string;
  const AQuery: TtiBaseObject): boolean;
var
  lQuery : TtiQuery;
begin
  Assert(AQuery is TtiQuery, 'AQuery not a TtiQuery');
  lQuery := TtiQuery(AQuery);
  result := (FAsString = lQuery.FieldAsString[ AFieldName ]);
end;

function TOIDHex.GetAsString: ShortString;
begin
  result:=FAsString;
end;

function TOIDHex.GetAsVariant: Variant;
begin
  result := FAsString;
end;

class function TOIDHex.IncHex(pHex: ShortString;
  pInc: integer): ShortString;
  procedure _IncHex(APos : integer);
  var
    lChar : char;
    lValue : integer;
  begin
    if APos>length(result) then
      raise Exception.Create('Inc Hex (1) exception');
    if APos<1 then
      raise Exception.Create('Inc Hex (2) exception');
    lChar:=result[APos];
    lValue:=StrToInt('$'+lChar);
    inc(lValue);
    if lValue>15 then
      _IncHex(APos-1);
    lValue:=lValue mod 16;
    lChar:=cOIDHexNumber[lValue];
    result[APos]:=lChar;
  end;
begin
  if pInc<>1 then
    raise Exception.Create('IncHex only with 1');
  result:=pHex;
  _IncHex(length(result));
end;

function TOIDHex.IsNull: boolean;
begin
  result:=(FAsString=NullOIDAsString);
end;

function TOIDHex.NullOIDAsString: string;
begin
  result := '';
end;

procedure TOIDHex.SetAsString(const AValue: ShortString);
begin
  if CheckValue(AValue) then
    FAsString:=AValue;
end;

procedure TOIDHex.SetAsVariant(const AValue: Variant);
begin
  FAsString := AValue;
end;

procedure TOIDHex.SetToNull;
begin
  FAsString:= NullOIDAsString;
end;

class function TOIDHex.ZeroHex: ShortString;
begin
  result:=StringOfChar('0',cOIDHexSize);
end;

{ TNextOIDGeneratorHex }

procedure TNextOIDGeneratorHex.AssignNextOID(const AAssignTo: TOID; const ADatabaseName : string; APersistenceLayerName : string);
begin
  Assert(AAssignTo.TestValid(TOID), CTIErrorInvalidObject);
  AAssignTo.AsString := NextOID;
end;

constructor TNextOIDGeneratorHex.Create;
begin
  inherited;
  FLow := 0;
  FLowRangeMask := StringOfChar('0',cOIDHexChacheSize);;
  FLowRange:=StrToInt('$1'+FLowRangeMask);
  FDirty := true;
  FNextOIDHexData := TNextOIDHexData.Create;
  FCritSect:= TCriticalSection.Create;
end;

destructor TNextOIDGeneratorHex.destroy;
begin
  FNextOIDHexData.Free;
  FCritSect.Free;
  inherited;
end;

function TNextOIDGeneratorHex.NextOID: String;
begin
  FCritSect.Enter;
  try
    if FDirty then
    begin
      gTIOPFManager.VisitorManager.Execute(cgsNextOIDHexReadHigh, FNextOIDHexData);
      FDirty := false;
      FLastOIDValue:=FNextOIDHexData.NextHexOID + FLowRangeMask;
    end;

    result := TOIDHex.IncHex(FLastOIDValue);


    inc(FLow);
    if FLow = FLowRange then
    begin
      FDirty := true;
      FLow := 0;
    end;

    FLastOIDValue:=result;
  finally
    FCritSect.Leave;
  end;
end;

{ TVisDBNextOIDHexAmblerRead }

function TVisDBNextOIDHexAmblerRead.AcceptVisitor: boolean;
begin
  result := (Visited is TNextOIDHexData);
end;

procedure TVisDBNextOIDHexAmblerRead.Execute(const AData: TtiVisited);
begin
  if gTIOPFManager.Terminated then
    Exit; //==>

  Inherited Execute(AData);

  if not AcceptVisitor then
    Exit; //==>

  Query.SelectRow('Next_OIDHEX', nil);
  try
    TNextOIDHexData(Visited).NextHexOID := Query.FieldAsString[ 'OID' ];
    if TNextOIDHexData(Visited).NextHexOID='' then
      TNextOIDHexData(Visited).NextHexOID:=StringOfChar('0',cOIDHexSize-cOIDHexChacheSize);;
  finally
    Query.Close;
  end;
end;

{ TVisDBNextOIDHexAmblerUpdate }

function TVisDBNextOIDHexAmblerUpdate.AcceptVisitor: boolean;
begin
  result := (Visited is TNextOIDHexData);
end;

procedure TVisDBNextOIDHexAmblerUpdate.Execute(const AData: TtiVisited);
var
  lParams : TtiQueryParams;
  lHex : ShortString;
begin
  if gTIOPFManager.Terminated then
    Exit; //==>

  Inherited Execute(AData);

  if not AcceptVisitor then
    Exit; //==>

  lParams := TtiQueryParams.Create;
  try
    lHex:=TNextOIDHexData(Visited).NextHexOID;
    lHex:=TOIDHex.IncHex(lHex);
    lParams.SetValueAsString('OID', String(lHex));
    Query.UpdateRow('Next_OIDHEX', lParams, nil);
  finally
    lParams.Free;
  end;
end;

initialization

  gTIOPFManager.OIDFactory.RegisterMapping(cOIDClassNameHex, TOIDHex, TNextOIDGeneratorHex) ;

  if gTIOPFManager.DefaultOIDClassName = '' then
    gTIOPFManager.DefaultOIDClassName := cOIDClassNameHex;

  gTIOPFManager.VisitorManager.RegisterVisitor(cgsNextOIDHexReadHigh, TVisDBNextOIDHexAmblerRead);
  gTIOPFManager.VisitorManager.RegisterVisitor(cgsNextOIDHexReadHigh, TVisDBNextOIDHexAmblerUpdate);

{$ELSE}
interface
implementation
{$ENDIF}

end.
