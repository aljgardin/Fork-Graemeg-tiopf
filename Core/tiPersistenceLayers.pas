unit tiPersistenceLayers;

{$I tiDefines.inc}

interface
uses
  SysUtils
  ,Classes
  ,tiDBConnectionPool
  ,tiQuery
  {$IFDEF MSWINDOWS}
  ,Windows
  {$ENDIF MSWINDOWS}
  ,tiObject
  ,tiOID
;

const
  cErrorUnableToFindPerLayerToUnload = 'Unable to determine which persistence layer to unload.';
  cErrorAttemtpToLoadPerLayerThatsNotLoaded = 'Attempt to unload persistence layer <%s> that''s not currently loaded.';

type

  TtiPerLayerLoadingStyle = (pllsStaticLinking, pllsDynamicLoading);
  TtiPersistenceLayers = class;
  TtiPersistenceLayer  = class;
  TtiPersistenceLayerClass = class of TtiPersistenceLayer;

  TtiPersistenceLayers = class(TtiObjectList)
  private
    FDefaultPerLayer : TtiPersistenceLayer;
    FLayerLoadingStyle: TtiPerLayerLoadingStyle;
    function    PackageIDToPackageName(const APackageID: string): TFileName;
    function    GetDefaultPerLayer: TtiPersistenceLayer;
    procedure   SetDefaultPerLayer(const AValue: TtiPersistenceLayer);
    function    GetDefaultPerLayerName: string;
    procedure   SetDefaultPerLayerName(const AValue: string);
  protected
    function    GetItems(i: integer): TtiPersistenceLayer; reintroduce;
    procedure   SetItems(i: integer; const AValue: TtiPersistenceLayer); reintroduce;
    function    GetOwner: TtiPersistenceLayer; reintroduce;
    procedure   SetOwner(const AValue: TtiPersistenceLayer); reintroduce;
  public
    constructor Create; override;
    destructor  Destroy; override;
    property    Items[i:integer]: TtiPersistenceLayer read GetItems write SetItems;
    procedure   Add(AObject : TtiPersistenceLayer); reintroduce;

    // These manage the loading and unloading of the packages
    function    LoadPersistenceLayer(const APersistenceLayerName : string): TtiPersistenceLayer;
    procedure   UnLoadPersistenceLayer(const APersistenceLayerName : string);
    function    IsLoaded(const APersistenceLayerName : string): boolean;
    function    IsDefault(const APersistenceLayerName : string): boolean;

    function    FindByPerLayerName(const ALayerName : string): TtiPersistenceLayer;
    function    FindByTIDatabaseClass(const ADatabaseClass : TtiDatabaseClass): TtiPersistenceLayer;
    property    DefaultPerLayer    : TtiPersistenceLayer read GetDefaultPerLayer     write SetDefaultPerLayer;
    property    DefaultPerLayerName : string         read GetDefaultPerLayerName write SetDefaultPerLayerName;
    property    LoadingStyle: TtiPerLayerLoadingStyle read FLayerLoadingStyle write FLayerLoadingStyle;

    // Do not call these your self. They are called in the initialization section
    // of tiQueryXXX.pas that contains the concrete classes.
    procedure   __RegisterPersistenceLayer(const APersistenceLayerClass: TtiPersistenceLayerClass);
    procedure   __UnRegisterPersistenceLayer(const ALayerName: string);

    function    CreateTIQuery(const ALayerName : string {= '' })           : TtiQuery; overload;
    function    CreateTIQuery(const ADatabaseClass : TtiDatabaseClass): TtiQuery; overload;
    function    CreateTIDatabase(const ALayerName : string {= '' })    : TtiDatabase;
    function    CreateTIDBConnectionPoolData(const ALayerName : string {= ''}): TtiDBConnectionPoolDataAbs;
    function    LockDatabase(const ADBConnectionName : string; APersistenceLayerName : string): TtiDatabase;
    procedure   UnLockDatabase(const ADatabase : TtiDatabase;const ADBConnectionName : string; APersistenceLayerName : string);

    {$IFDEF FPC}
    {$I tiPersistenceLayersIntf.inc}
    {$ENDIF}
  end;

  TtiPersistenceLayer = class(TtiObject)
  private
    FModuleID: HModule;
    FDBConnectionPools: TtiDBConnectionPools;
    FDefaultDBConnectionPool : TtiDBConnectionPool;
    FNextOIDMgr: TNextOIDMgr;
    FDynamicallyLoaded: boolean;
    function  GetDefaultDBConnectionPool: TtiDBConnectionPool;
    function  GetDefaultDBConnectionName: string;
    procedure SetDefaultDBConnectionName(const AValue: string);
  protected
    function    GetOwner: TtiPersistenceLayers; reintroduce;
    procedure   SetOwner(const AValue: TtiPersistenceLayers); reintroduce;

    // These must be overridden in the concrete classes
    function GetDatabaseClass: TtiDatabaseClass; virtual; abstract;
    function GetDBConnectionPoolDataClass: TtiDBConnectionPoolDataClass; virtual; abstract;
    function GetPersistenceLayerName: string; virtual; abstract;
    function GetQueryClass: TtiQueryClass; virtual; abstract;

  public
    constructor Create; override;
    destructor  Destroy; override;
    property    Owner      : TtiPersistenceLayers            read GetOwner      write SetOwner;

    property  DBConnectionPoolDataClass  : TtiDBConnectionPoolDataClass read GetDBConnectionPoolDataClass;
    property  QueryClass                 : TtiQueryClass read GetQueryClass;
    property  DatabaseClass              : TtiDatabaseClass read GetDatabaseClass;
    property  PersistenceLayerName       : string read GetPersistenceLayerName;

    property  DynamicallyLoaded          : boolean read FDynamicallyLoaded write FDynamicallyLoaded;
    property  ModuleID                   : HModule read FModuleID write FModuleID;
    property  DefaultDBConnectionName    : string read GetDefaultDBConnectionName write SetDefaultDBConnectionName;
    property  DefaultDBConnectionPool    : TtiDBConnectionPool read GetDefaultDBConnectionPool;
    property  DBConnectionPools          : TtiDBConnectionPools read FDBConnectionPools;
    property  NextOIDMgr                 : TNextOIDMgr read FNextOIDMgr;

    function  DatabaseExists(const ADatabaseName, AUserName, APassword : string): boolean;
    procedure CreateDatabase(const ADatabaseName, AUserName, APassword : string);
    function  TestConnectToDatabase(const ADatabaseName, AUserName, APassword, AParams : string): boolean;
  end;


implementation
uses
   tiUtils
  ,tiLog
  ,tiConstants
  ,tiOPFManager
  ,tiExcept
;

constructor TtiPersistenceLayer.Create;
begin
  inherited;
  ModuleID := 0;
  FDBConnectionPools:= TtiDBConnectionPools.Create(Self);
  FNextOIDMgr := TNextOIDMgr.Create;
  {$IFNDEF OID_AS_INT64}
  FNextOIDMgr.Owner := Self;
  {$ENDIF}
  FDynamicallyLoaded := false;
end;

procedure TtiPersistenceLayers.Add(AObject: TtiPersistenceLayer);
begin
  inherited Add(AObject);
end;

function TtiPersistenceLayers.FindByPerLayerName(const ALayerName: string): TtiPersistenceLayer;
var
  i : integer;
begin
  result := nil;
  if (ALayerName = '') and
     (Count = 1) then
  begin
    result := Items[0];
    Exit; //==>
  end;

  for i := 0 to Count - 1 do
    if SameText(Items[i].PersistenceLayerName, ALayerName) then
    begin
      result := Items[i];
      Exit; //==>
    end;
end;

function TtiPersistenceLayers.GetItems(i: integer): TtiPersistenceLayer;
begin
  result := TtiPersistenceLayer(inherited GetItems(i));
end;

function TtiPersistenceLayers.GetOwner: TtiPersistenceLayer;
begin
  result := TtiPersistenceLayer(GetOwner);
end;

procedure TtiPersistenceLayers.__RegisterPersistenceLayer(
  const APersistenceLayerClass: TtiPersistenceLayerClass);
var
  LData : TtiPersistenceLayer;
begin
  Assert(APersistenceLayerClass <> nil, 'APersistenceLayerClass not assigned');
  LData := APersistenceLayerClass.Create;
  if IsLoaded(LData.PersistenceLayerName) then
    LData.Free
  else
    Add(LData);
end;

procedure TtiPersistenceLayers.SetItems(i: integer; const AValue: TtiPersistenceLayer);
begin
  inherited SetItems(i, AValue);
end;

procedure TtiPersistenceLayers.SetOwner(const AValue: TtiPersistenceLayer);
begin
  inherited SetOwner(AValue);
end;

function TtiPersistenceLayers.CreateTIDatabase(const ALayerName : string {= ''}): TtiDatabase;
var
  LPersistenceLayer : TtiPersistenceLayer;
begin
  LPersistenceLayer := FindByPerLayerName(ALayerName);
  if LPersistenceLayer = nil then
    raise Exception.Create('Request for unregistered persistence layer <' + ALayerName + '>');
  result := LPersistenceLayer.DatabaseClass.Create;
end;

function TtiPersistenceLayers.CreateTIQuery(const ALayerName : string {= ''}): TtiQuery;
var
  LPersistenceLayer : TtiPersistenceLayer;
begin
  LPersistenceLayer := FindByPerLayerName(ALayerName);
  if LPersistenceLayer = nil then
    raise Exception.Create('Request for unregistered persistence layer <' + ALayerName + '>');
  result := LPersistenceLayer.QueryClass.Create;
end;

function TtiPersistenceLayers.CreateTIDBConnectionPoolData(const ALayerName : string {= ''}): TtiDBConnectionPoolDataAbs;
var
  LPersistenceLayer : TtiPersistenceLayer;
begin
  LPersistenceLayer := FindByPerLayerName(ALayerName);
  if LPersistenceLayer = nil then
    raise Exception.Create('Request for unregistered persistence layer <' + ALayerName + '>');
  result := LPersistenceLayer.DBConnectionPoolDataClass.Create;
end;

procedure TtiPersistenceLayer.CreateDatabase(const ADatabaseName, AUserName,
  APassword: string);
begin
  Assert(DatabaseClass<>nil, 'DatabaseClass not assigned');
  DatabaseClass.CreateDatabase(ADatabaseName, AUserName, APassword);
end;

function TtiPersistenceLayer.DatabaseExists(const ADatabaseName, AUserName, APassword: string): boolean;
begin
  Assert(DatabaseClass<>nil, 'DatabaseClass not assigned');
  result := DatabaseClass.DatabaseExists(ADatabaseName, AUserName, APassword);
end;

destructor TtiPersistenceLayer.Destroy;
begin
  FDBConnectionPools.Free;
  FNextOIDMgr.Free;
  inherited;
end;

function TtiPersistenceLayer.GetDefaultDBConnectionName: string;
var
  lDBConnectionPool : TtiDBConnectionPool;
begin
  lDBConnectionPool := DefaultDBConnectionPool;
  if lDBConnectionPool = nil then
  begin
    result := '';
    Exit; //==>
  end;
  result := lDBConnectionPool.DatabaseAlias;
end;

function TtiPersistenceLayer.GetDefaultDBConnectionPool: TtiDBConnectionPool;
begin
  Assert(FDefaultDBConnectionPool.TestValid(TtiDBConnectionPool, true), CTIErrorInvalidObject);
  if FDefaultDBConnectionPool <> nil then
  begin
    result := FDefaultDBConnectionPool;
    Exit; //==>
  end;

  if DBConnectionPools.Count = 0 then
  begin
    result := nil;
    Exit; //==>
  end;

  result := DBConnectionPools.Items[0];
  Assert(Result.TestValid(TtiDBConnectionPool), CTIErrorInvalidObject);
end;

function TtiPersistenceLayer.GetOwner: TtiPersistenceLayers;
begin
  result := TtiPersistenceLayers(inherited GetOwner);
end;

procedure TtiPersistenceLayer.SetDefaultDBConnectionName(const AValue: string);
begin
  FDefaultDBConnectionPool := FDBConnectionPools.Find(AValue);
  Assert(FDefaultDBConnectionPool.TestValid(TtiDBConnectionPool, true), CTIErrorInvalidObject);
end;

procedure TtiPersistenceLayer.SetOwner(const AValue: TtiPersistenceLayers);
begin
  inherited SetOwner(AValue);
end;

destructor TtiPersistenceLayers.Destroy;
var
  i : integer;
begin
  for i := Count - 1 downto 0 do
    UnLoadPersistenceLayer(Items[i].PersistenceLayerName);
  inherited;
end;

procedure TtiPersistenceLayers.__UnRegisterPersistenceLayer(const ALayerName: string);
var
  lData : TtiPersistenceLayer;
begin
  lData := FindByPerLayerName(ALayerName);
  if lData = nil then
    Exit; //==>
  if gTIOPFManager.DefaultPerLayer = lData then
    gTIOPFManager.DefaultPerLayer := nil;
  Remove(lData);
end;

function TtiPersistenceLayers.IsDefault(const APersistenceLayerName: string): boolean;
begin
  result := SameText(DefaultPerLayerName, APersistenceLayerName);
end;

function TtiPersistenceLayers.IsLoaded(const APersistenceLayerName: string): boolean;
begin
  result := (FindByPerLayerName(APersistenceLayerName) <> nil);
end;

function TtiPersistenceLayers.CreateTIQuery(
  const ADatabaseClass: TtiDatabaseClass): TtiQuery;
var
  LPersistenceLayer : TtiPersistenceLayer;
begin
  LPersistenceLayer := FindByTIDatabaseClass(ADatabaseClass);
  if LPersistenceLayer = nil then
    raise Exception.Create('Unable to find persistence layer for database class <' + ADatabaseClass.ClassName + '>');
  result := LPersistenceLayer.QueryClass.Create;
end;

function TtiPersistenceLayers.FindByTIDatabaseClass(
  const ADatabaseClass: TtiDatabaseClass): TtiPersistenceLayer;
var
  i : integer;
begin
  Assert(ADatabaseClass <> nil, 'ADatabaseClass <> nil');
  result := nil;
  for i := 0 to Count - 1 do
    if Items[i].DatabaseClass = ADatabaseClass then
    begin
      result := Items[i];
      Exit; //==>
    end;
end;

function TtiPersistenceLayers.LoadPersistenceLayer(const APersistenceLayerName: string): TtiPersistenceLayer;
var
  lPackageName : TFileName;
  lPackageModule : HModule;
  lMessage : string;
begin
  result := FindByPerLayerName(APersistenceLayerName);
  if result <> nil then
    Exit; //==>

  lPackageName := PackageIDToPackageName(APersistenceLayerName);
  Log('Loading %s', [lPackageName], lsConnectionPool);

  try
    lPackageModule := LoadPackage(ExtractFileName(lPackageName));
    result  := FindByPerLayerName(APersistenceLayerName);
    if result = nil then
      raise exception.Create('Unable to locate package in memory after it was loaded.' + Cr +
                              'Check that this application was build with the runtime package tiPersistCore');
    result.DynamicallyLoaded := true;
    result.ModuleID := lPackageModule;
  except
    on e:exception do
    begin
      lMessage := 'Unable to initialize persistence layer <' +
                  APersistenceLayerName + '> Package name <' +
                  lPackageName + '>' + Cr(2) +
                  'Error message: ' + e.message;
      raise Exception.Create(lMessage);
    end;
  end;
end;

function TtiPersistenceLayers.PackageIDToPackageName(const APackageID : string): TFileName;
begin
  result :=
    tiAddTrailingSlash(tiGetEXEPath) +
    cTIPersistPackageRootName +
    APackageID +
    cPackageSuffix +
    '.bpl';
end;

{
function TtiPersistenceLayers.PackageNameToPackageID(const pPackageName : TFileName): string;
begin
  result := tiExtractFileNameOnly(pPackageName);
  result := tiStrTran(result, cPackageSuffix, '');
  result := tiStrTran(result,
                       cTIPersistPackageRootName,
                       '');
end;
}

procedure TtiPersistenceLayers.UnLoadPersistenceLayer(const APersistenceLayerName: string);
var
  LPackageID    : string;
  LPersistenceLayer : TtiPersistenceLayer;
begin
  if APersistenceLayerName <> '' then
    LPackageID := APersistenceLayerName
  else if Count = 1 then
    LPackageID  := Items[0].PersistenceLayerName
  else
    raise EtiOPFProgrammerException.Create(cErrorUnableToFindPerLayerToUnload);

  if not IsLoaded(APersistenceLayerName) then
    raise EtiOPFProgrammerException.CreateFmt(cErrorAttemtpToLoadPerLayerThatsNotLoaded, [LPackageID]);

  LPersistenceLayer := FindByPerLayerName(APersistenceLayerName);
  Assert(LPersistenceLayer.TestValid, CTIErrorInvalidObject);

  LPersistenceLayer.DBConnectionPools.DisConnectAll;
  Log('Unloading persistence layer <' + LPersistenceLayer.PersistenceLayerName + '>', lsConnectionPool);

  if LPersistenceLayer.ModuleID <> 0 then
    UnLoadPackage(LPersistenceLayer.ModuleID) // lRegPerLayer has now been destroyed
  else
    Remove(LPersistenceLayer);

  if Count > 0 then
    DefaultPerLayer:= Items[0]
  else
    DefaultPerLayer:= nil;
end;

function TtiPersistenceLayers.LockDatabase(const ADBConnectionName: string;APersistenceLayerName: string): TtiDatabase;
var
  lRegPerLayer : TtiPersistenceLayer;
  lDBConnectionName : string;
begin
  if APersistenceLayerName <> '' then
    lRegPerLayer := FindByPerLayerName(APersistenceLayerName)
  else
    lRegPerLayer := DefaultPerLayer;

  Assert(lRegPerLayer.TestValid(TtiPersistenceLayer), CTIErrorInvalidObject);

  if ADBConnectionName <> '' then
    lDBConnectionName := ADBConnectionName
  else
    lDBConnectionName := lRegPerLayer.DefaultDBConnectionName;

  Result := lRegPerLayer.DBConnectionPools.Lock(lDBConnectionName);

end;

procedure TtiPersistenceLayers.UnLockDatabase(const ADatabase: TtiDatabase;
  const ADBConnectionName: string; APersistenceLayerName: string);
var
  lDBConnectionName : string;
  lRegPerLayer : TtiPersistenceLayer;
begin
  if APersistenceLayerName <> '' then
    lRegPerLayer := FindByPerLayerName(APersistenceLayerName)
  else
    lRegPerLayer := DefaultPerLayer;

  Assert(lRegPerLayer.TestValid(TtiPersistenceLayer), CTIErrorInvalidObject);

  if ADBConnectionName <> '' then
    lDBConnectionName := ADBConnectionName
  else
    lDBConnectionName := lRegPerLayer.DefaultDBConnectionName;

  lRegPerLayer.DBConnectionPools.UnLock(lDBConnectionName, ADatabase);
end;

function TtiPersistenceLayers.GetDefaultPerLayer: TtiPersistenceLayer;
begin
  Assert(FDefaultPerLayer.TestValid(TtiPersistenceLayer, true), CTIErrorInvalidObject);
  if FDefaultPerLayer <> nil then
  begin
    result := FDefaultPerLayer;
    Exit; //==>
  end;
  if Count = 0 then
  begin
    result := nil;
    Exit; //==>
  end;
  FDefaultPerLayer := Items[0];
  Assert(FDefaultPerLayer.TestValid(TtiPersistenceLayer), CTIErrorInvalidObject);
  result := FDefaultPerLayer;
end;

procedure TtiPersistenceLayers.SetDefaultPerLayer(const AValue: TtiPersistenceLayer);
begin
  FDefaultPerLayer := AValue;
end;

function TtiPersistenceLayers.GetDefaultPerLayerName: string;
begin
  if DefaultPerLayer <> nil then
    result := DefaultPerLayer.PersistenceLayerName
  else
    result := '';
end;

procedure TtiPersistenceLayers.SetDefaultPerLayerName(const AValue: string);
begin
  FDefaultPerLayer := FindByPerLayerName(AValue);
end;

function TtiPersistenceLayer.TestConnectToDatabase(const ADatabaseName,
  AUserName, APassword, AParams: string): boolean;
begin
  Assert(DatabaseClass<>nil, 'DatabaseClass not assigned');
  result := DatabaseClass.TestConnectTo(ADatabaseName, AUserName, APassword,
                                           AParams);
end;

constructor TtiPersistenceLayers.Create;
begin
  inherited;
  FLayerLoadingStyle := pllsDynamicLoading;
end;

{$IFDEF FPC}
{$I tiPersistenceLayersImpl.inc}
{$ENDIF}

end.








