unit tiVisitor;

{$I tiDefines.inc}

// ToDo:
//    Audit for const params
//    Group visitors by registered name
//    Refactor VisitorController to remove DB smell
//    Audit & test BreakOnException code
//    Audit for unit tests

interface
uses
   tiBaseObject
  ,tiStreams
  ,Classes
  ,TypInfo
  ,SyncObjs
  ,SysUtils
  ,Contnrs
 ;

const
  CErrorInVisitorExecute = 'Error in %s.Execute(%s) Message: %s';
  CErrorInvalidIterationStyle = 'Invalid TtiIterationStyle';
  CErrorAttemptToRegisterDuplicateVisitor = 'Attempt to register duplicate visitor "%s"';
  CErrorIncompatibleVisitorController = 'VisitorControllerClass not compatible. Required type "%s", Actual type "%s"';

type
  TtiIterationStyle = (isTopDownRecurse, isTopDownSinglePass, isBottomUpSinglePass);

  {$M+}
  TtiVisited = class;
  {$M-}
  TtiVisitor = class;

  // TVisitorClass reference
  TtiVisitorClass = class of TtiVisitor;

  // TtiVisited class reference
  TtiVisitedClass = class of TtiVisited;

  {: Counter for the depth of iteration. There is no theoretical limit, however
     a limit is set as High(Word) = 64435 as it's unlikely that the depth
     will ever reach that limit. If it does, this type can be changed to Cardinal.}
  TIterationDepth = word;

  // Method that is called when each Visited is touched.
  TtiVisitedTouchMethod =   procedure (const ACandidates: TtiVisited;
                                     const AVisitor : TtiVisitor;
                                     const AList: TList;
                                     const AIterationDepth: TIterationDepth) of object;

  TtiVisitedCandidate = class(TtiBaseObject)
  private
    FVisited: TtiVisited;
    FApparentOwner: TtiVisited;
    FIterationDepth: TIterationDepth;
  public
    property ApparentOwner: TtiVisited read FApparentOwner write FApparentOwner;
    property Visited: TtiVisited read FVisited write FVisited;
    property IterationDepth: TIterationDepth read FIterationDepth write FIterationDepth;
  end;

  // TtiVisited
  // The class that gets visited.
  TtiVisited = class(TtiBaseObject)
  protected
    function    GetCaption: string; virtual;
    procedure   Iterate(const AVisitor : TtiVisitor;
                        const ADerivedParent: TtiVisited;
                        const ATouchedObjectList: TList;
                        const ATouchMethod: TtiVisitedTouchMethod;
                        const AIterationDepth: TIterationDepth); overload; virtual;
    procedure   IterateOverList(const AVisitor: TtiVisitor;
                        const ACandidates: TList;
                        const ADerivedParent: TtiVisited;
                        const ATouchecdObjectList: TList;
                        const ATouchMethod: TtiVisitedTouchMethod;
                        const AIterationDepth: TIterationDepth);
    procedure   IterateTopDownRecurse(AVisitor : TtiVisitor); virtual;
    procedure   IterateTopDownSinglePass(AVisitor: TtiVisitor); virtual;
    procedure   IterateBottomUpSinglePass(AVisitor: TtiVisitor); virtual;
    procedure   TouchMethodAddToList(const ACandidates: TtiVisited;
                                      const AVisitor : TtiVisitor;
                                      const AList: TList;
                                      const AIterationDepth: TIterationDepth);
    procedure   TouchMethodExecuteVisitor(const ACandidates: TtiVisited;
                                      const AVisitor : TtiVisitor;
                                      const AList: TList;
                                      const AIterationDepth: TIterationDepth);
    procedure   ExecuteVisitor(const AVisitor: TtiVisitor; const AVisitedCandidate: TtiVisitedCandidate);
    function    GetTerminated: boolean; virtual;
    function    ContinueVisiting(const AVisitor: TtiVisitor): boolean; virtual;
    function    CheckContinueVisitingIfTopDownRecurse(const AVisitor: TtiVisitor): boolean; virtual;
    function    TIOPFManager: TObject; virtual;
  published
    property    Caption   : string  read GetCaption;
  public
    constructor Create; virtual;
    procedure   Iterate(const AVisitor : TtiVisitor); overload;
    procedure   FindAllByClassType(AClass : TtiVisitedClass; AList : TList);
    property    Terminated: Boolean read GetTerminated;
  end;

  TtiVisitorController = class(TtiBaseObject)
  private
    FDBConnectionName: string;
    FPerLayerName   : string;
  protected
    procedure SetPerLayerName(const AValue: string); virtual;
  public
    constructor Create; virtual;
    procedure BeforeExecuteAll(AVisitors : TList)     ; virtual;
    procedure BeforeExecuteOne(AVisitor : TtiVisitor); virtual;
    // Visitors are executed here...
    procedure AfterExecuteOne(AVisitor : TtiVisitor ); virtual;
    procedure AfterExecuteAll(AVisitors : TList)      ; virtual;
    // Executed if there was an error
    procedure AfterExecuteError(AVisitors : TList)    ; virtual;
    // The property DBConnectionName is really only required in DBVisitors, but
    // must be introduce here so it can be set at a generic level by the
    // VisitorMgr. The alternative is to use RTTI or TypeInfo and only set the
    // property on DBVisitorMgr(s), but that would be an ever worse hack.
    property  PerLayerName    : string read FPerLayerName     write SetPerLayerName;
    property  DBConnectionName : string read FDBConnectionName write FDBConnectionName;
  end;

  TtiVisitorControllerClass = class of TtiVisitorController;

  // TtiVisitor: The class that does the visiting
  TtiVisitor = class(TtiBaseObject)
  private
    FVisited          : TtiVisited;
    FContinueVisiting : boolean;
    FVisitorController : TtiVisitorController;
    FDepth: TIterationDepth;
    FIterationStyle: TtiIterationStyle;
    FVisitedsOwner: TtiVisited;
  protected
    function    AcceptVisitor : boolean; overload; virtual;
    function    AcceptVisitor(AVisited: TtiVisited) : boolean; overload; virtual;
    function    VisitBranch(const ADerivedParent, AVisited: TtiVisited) : boolean; virtual;
    function    GetVisited: TtiVisited; virtual;
    procedure   SetVisited(const AValue: TtiVisited);
    procedure   SetDepth(const ADepth: TIterationDepth);
  public
    constructor Create; virtual;
    class function VisitorControllerClass : TtiVisitorControllerClass; virtual;

    procedure   Execute(const AVisited : TtiVisited); virtual;
    property    Visited : TtiVisited read FVisited;

    property    ContinueVisiting : boolean read FContinueVisiting write FContinueVisiting;
    property    VisitorController : TtiVisitorController read FVisitorController write FVisitorController;
    property    Depth : TIterationDepth read FDepth;
    property    IterationStyle : TtiIterationStyle
                  read  FIterationStyle
                  write FIterationStyle;
    property    VisitedsOwner : TtiVisited read FVisitedsOwner write FVisitedsOwner;

  end;

  TtiVisitorMappingGroup = class(TtiBaseObject)
  private
    FMappings: TClassList;
    FGroupName: string;
    FVisitorControllerClass: TtiVisitorControllerClass;
  public
    constructor Create(const AGroupName: string;
      const AVisitorControllerClass: TtiVisitorControllerClass);
    destructor Destroy; override;
    procedure Add(const AVisitorClass: TtiVisitorClass);
    procedure AssignVisitorInstances(const AVisitorList: TObjectList);
    property GroupName: string read FGroupName;
    property VisitorControllerClass: TtiVisitorControllerClass read FVisitorControllerClass;
  end;

  // A procedural type to define the signature used for
  // BeforeExecute, AfterExecute and AfterExecuteError
  TOnProcessVisitorController = procedure(
    const AVisitorController : TtiVisitorController;
    const AVisitors  : TList) of object;

  // The Visitor Manager
  TtiVisitorManager = class(TtiBaseObject)
  private
    FVisitorMappings : TObjectList;
    FSynchronizer: TMultiReadExclusiveWriteSynchronizer;
    FBreakOnException: boolean;
    procedure ProcessVisitorControllers(
      const AVisitors: TList;
      const AVisitorController: TtiVisitorController;
      const AProc : TOnProcessVisitorController);
    procedure DoBeforeExecuteAll(const AVisitorController: TtiVisitorController; const AVisitors : TList);
    procedure DoBeforeExecuteOne(const AVisitorController: TtiVisitorController; const AVisitor: TtiVisitor);
    procedure DoAfterExecuteOne(const AVisitorController: TtiVisitorController; const AVisitor: TtiVisitor);
    procedure DoAfterExecuteAll(const AVisitorController : TtiVisitorController; const AVisitors: TList);
    procedure DoAfterExecuteError(const AVisitorController : TtiVisitorController; const AVisitors  : TList);
    procedure ExecuteVisitors(const AVisitorController: TtiVisitorController;
      const AVisitors: TList; const AVisited : TtiVisited);
    procedure ProcessVisitors(const AGroupName : string;
                               const AVisited : TtiVisited;
                               const ADBConnectionName : string;
                               const APersistenceLayerName     : string);
    function GetVisitorMappings: TList;
  protected
    property    VisitorMappings: TList read GetVisitorMappings;
    procedure   AssignVisitorInstances(const AVisitors : TObjectList; const AGroupName : string); virtual;
    function    FindVisitorMappingGroup(const AGroupName: string): TtiVisitorMappingGroup; virtual;

  public
    constructor Create; virtual;
    destructor  Destroy; override;
    procedure   RegisterVisitor(const AGroupName : string;
                                 const AVisitorClass  : TtiVisitorClass);
    procedure   UnRegisterVisitors(const AGroupName : string);
    function    Execute(const AGroupName      : string;
                         const AVisited         : TtiVisited;
                         const ADBConnectionName : string = '';
                         const APersistenceLayerName    : string = ''): string;
    property    BreakOnException : boolean read FBreakOnException write FBreakOnException;
  end;


  // A wrapper for the TtiPreSizedStream which allows text to be written to the stream
  // with each visit.
  TVisStream = class(TtiVisitor)
  private
    FStream : TtiPreSizedStream;
  protected
    procedure Write(const AValue : string); virtual;
    procedure WriteLn(const AValue : string = ''); virtual;
    procedure SetStream(const AValue: TtiPreSizedStream); virtual;
  public
    property  Stream : TtiPreSizedStream read FStream write SetStream;
  end;

  TVisStringStream = class(TVisStream)
  protected
    function    GetText: string; virtual;
  public
    Constructor Create; override;
    Destructor  Destroy; override;
    Property    Text : string read GetText;
  end;

  // A visitor to count the number of instances of each class owned by the
  // passed object
  TVisClassCount = class(TtiVisitor)
  private
    FList: TStringList;
    function GetClassCount(AClass : TClass): integer;
    procedure SetClassCount(AClass : TClass; const AValue: integer);
  public
    constructor Create; override;
    destructor  Destroy; override;
    procedure   Execute(const AVisited : TtiVisited); override;
    property    ClassCount[ AClass : TClass]: integer
                  read GetClassCount
                  write SetClassCount;
  end;

  // A visitor to find all owned objects of a given class
  TVisFindAllByClass = class(TtiVisitor)
  private
    FList: TList;
    FClassTypeToFind: TtiVisitedClass;
  protected
    function    AcceptVisitor : boolean; override;
  public
    procedure   Execute(const AVisited : TtiVisited); override;
    property    ClassTypeToFind : TtiVisitedClass read FClassTypeToFind write FClassTypeToFind;
    property    List : TList read FList write FList;
  end;

  TVisStreamClass = class of TVisStream;

// Global proc to write a apply a TVisStream (as a TFileStream) to a TtiVisited.
procedure VisStreamToFile(AData       : TtiVisited;
                          AFileName  : string;
                          AVisClassRef : TtiVisitorClass);


implementation
uses
   tiLog     // Logging
  ,tiOPFManager
  ,tiConstants
  ,tiPersistenceLayers
  ,tiExcept
  ,tiUtils
  ,tiRTTI
  {$IFDEF DELPHI5}
  ,FileCtrl
  {$ENDIF}
 ;


procedure VisStreamToFile(AData : TtiVisited;
                           AFileName : string;
                           AVisClassRef : TtiVisitorClass);
var
  lVisitor : TVisStream;
  lStream : TtiPreSizedStream;
  lDir    : string;
begin
  lDir := ExtractFilePath(AFileName);
  tiForceDirectories(AFileName);
  lStream := TtiPreSizedStream.Create(cStreamStartSize, cStreamGrowBy);
  try
    lVisitor  := TVisStream(AVisClassRef.Create);
    try
      lVisitor.Stream := lStream;
      AData.Iterate(lVisitor);
    finally
      lVisitor.Free;
    end;
    lStream.SaveToFile(AFileName);
  finally
     lStream.Free;
  end;
end;

procedure TtiVisited.Iterate(
  const AVisitor: TtiVisitor;
  const ADerivedParent: TtiVisited;
  const ATouchedObjectList: TList;
  const ATouchMethod: TtiVisitedTouchMethod;
  const AIterationDepth: TIterationDepth);
var
  LClassPropNames : TStringList;
  LCandidate : TObject;
  i       : integer;
  LIterationDepth: TIterationDepth;
begin
  if AVisitor.VisitBranch(ADerivedParent, Self) and
     CheckContinueVisitingIfTopDownRecurse(AVisitor) then
  begin
    LIterationDepth:= AIterationDepth+1;
    if AVisitor.AcceptVisitor(Self) then
      ATouchMethod(Self, AVisitor, ATouchedObjectList, LIterationDepth);
    LClassPropNames := TStringList.Create;
    try
      tiGetPropertyNames(Self, LClassPropNames, [tkClass]);
      i:= 0;
      while (i <= LClassPropNames.Count - 1) do
      begin
        LCandidate := GetObjectProp(Self, LClassPropNames.Strings[i]);
        if (LCandidate is TtiVisited) then
          (LCandidate as TtiVisited).Iterate(AVisitor, (LCandidate as TtiVisited), ATouchedObjectList, ATouchMethod, LIterationDepth)
        else if (LCandidate is TList) then
          IterateOverList(AVisitor, (LCandidate as TList), Self, ATouchedObjectList, ATouchMethod, LIterationDepth);
        inc(i);
      end;
    finally
      LClassPropNames.Free;
    end;
  end;
end;

function TtiVisited.CheckContinueVisitingIfTopDownRecurse(
  const AVisitor: TtiVisitor): boolean;
begin
  Assert(AVisitor.TestValid, cTIInvalidObjectError);
  if AVisitor.IterationStyle <> isTopDownRecurse then
    result:= true
  else
    result:= ContinueVisiting(AVisitor);
end;

function TtiVisited.ContinueVisiting(const AVisitor: TtiVisitor): boolean;
begin
  Assert(AVisitor.TestValid, cTIInvalidObjectError);
  result:= AVisitor.ContinueVisiting and not Terminated;
end;

constructor TtiVisited.Create;
begin
  inherited create;
end;


procedure TtiVisited.ExecuteVisitor(const AVisitor: TtiVisitor;
  const AVisitedCandidate: TtiVisitedCandidate);
begin
  Assert(AVisitor.TestValid, cTIInvalidObjectError);
  Assert(AVisitedCandidate.TestValid, cTIInvalidObjectError);
  AVisitor.SetVisited(AVisitedCandidate.Visited);
  AVisitor.SetDepth(AVisitedCandidate.IterationDepth);
  AVisitor.Execute(AVisitedCandidate.Visited);
end;

procedure TtiVisited.FindAllByClassType(AClass: TtiVisitedClass; AList: TList);
var
  lVis : TVisFindAllByClass;
begin
  Assert(AList <> nil, 'AList not assigned');
  AList.Clear;
  lVis := TVisFindAllByClass.Create;
  try
    lVis.ClassTypeToFind := AClass;
    lVis.List := AList;
    Iterate(lVis);
  finally
    lVis.Free;
  end;
end;


procedure TtiVisited.IterateOverList(
  const AVisitor: TtiVisitor;
  const ACandidates: TList;
  const ADerivedParent: TtiVisited;
  const ATouchecdObjectList: TList;
  const ATouchMethod: TtiVisitedTouchMethod;
  const AIterationDepth: TIterationDepth);
var
  i: integer;
begin
  i:= 0;
  while (i <= ACandidates.Count - 1) do
  begin
    if (TObject(ACandidates.Items[i]) is TtiVisited) then
      TtiVisited(ACandidates.Items[i]).Iterate(AVisitor, ADerivedParent,
              ATouchecdObjectList, ATouchMethod, AIterationDepth);
    inc(i);
  end;
end;

function TtiVisited.GetCaption: string;
begin
  result := className;
end;


function TtiVisited.GetTerminated: boolean;
begin
  result:= TtiOPFManager(TIOPFManager).Terminated;
end;

procedure TtiVisited.IterateTopDownRecurse(AVisitor: TtiVisitor);
begin
  Assert(AVisitor.TestValid, cTIInvalidObjectError);
  Iterate(AVisitor, nil, nil, TouchMethodExecuteVisitor, 0);
end;


procedure TtiVisited.IterateTopDownSinglePass(AVisitor: TtiVisitor);
var
  LList: TObjectList;
  i : integer;
begin
  Assert(AVisitor.TestValid, cTIInvalidObjectError);
  LList:= TObjectList.Create(True);
  try
    Iterate(AVisitor, nil, LList, TouchMethodAddToList, 0);
    i:= 0;
    while (i <= LList.Count-1) and
      ContinueVisiting(AVisitor) do
    begin
      ExecuteVisitor(AVisitor, TtiVisitedCandidate(LList.Items[i]));
      Inc(i);
    end;
  finally
    LList.Free;
  end;
end;

function TtiVisited.TIOPFManager: TObject;
begin
  result:= gTIOPFManager;
end;

procedure TtiVisited.TouchMethodAddToList(const ACandidates: TtiVisited;
  const AVisitor: TtiVisitor; const AList: TList; const AIterationDepth: TIterationDepth);
var
  LVisitedCandidate: TtiVisitedCandidate;
begin
  LVisitedCandidate:= TtiVisitedCandidate.Create;
  LVisitedCandidate.Visited:= ACandidates;
  LVisitedCandidate.IterationDepth:= AIterationDepth;
  AList.Add(LVisitedCandidate);
end;

procedure TtiVisited.TouchMethodExecuteVisitor(const ACandidates: TtiVisited;
  const AVisitor: TtiVisitor; const AList: TList; const AIterationDepth: TIterationDepth);
var
  LVisitedCandidate: TtiVisitedCandidate;
begin
  LVisitedCandidate:= TtiVisitedCandidate.Create;
  try
    LVisitedCandidate.Visited:= ACandidates;
  //  LVisitedCandidate.ApparentOwner:= AApparentOwner;
    LVisitedCandidate.IterationDepth:= AIterationDepth;
    ExecuteVisitor(AVisitor, LVisitedCandidate);
  finally
    LVisitedCandidate.Free;
  end;
end;

{ TtiVisitor }

function TtiVisitor.AcceptVisitor(AVisited: TtiVisited): boolean;
begin
  SetVisited(AVisited);
  result:= AcceptVisitor;
end;

constructor TtiVisitor.Create;
begin
  inherited create;
  FContinueVisiting := true;
  FVisitorController := nil;
  FDepth            := 0;
  FIterationStyle  := isTopDownRecurse;
end;

function TtiVisitor.AcceptVisitor: boolean;
begin
  result := true;
end;

procedure TVisStream.SetStream(const AValue: TtiPreSizedStream);
begin
  Assert(AValue.TestValid(TtiPreSizedStream), cTIInvalidObjectError);
  FStream := AValue;
end;


procedure TVisStream.Write(const AValue: string);
begin
  Assert(FStream.TestValid(TtiPreSizedStream), cTIInvalidObjectError);
  FStream.Write(AValue);
end;


procedure TVisStream.WriteLn(const AValue: string = '');
begin
  Assert(FStream.TestValid(TtiPreSizedStream), cTIInvalidObjectError);
  FStream.WriteLn(AValue);
end;


procedure TtiVisitor.Execute(const AVisited: TtiVisited);
begin
  FVisited := AVisited;
end;


function TtiVisitor.VisitBranch(const ADerivedParent,
  AVisited: TtiVisited): boolean;
begin
  result:= True;
end;

class function TtiVisitor.VisitorControllerClass : TtiVisitorControllerClass;
begin
  result := TtiVisitorController;
end;


{ TtiVisitorCtrlr }

procedure TtiVisitorController.AfterExecuteAll(AVisitors : TList);
begin
  Assert(AVisitors = AVisitors);  // Getting rid of compiler hints, param not used.
  // Do nothing
end;


procedure TtiVisitorController.AfterExecuteError(AVisitors : TList);
begin
  Assert(AVisitors = AVisitors);  // Getting rid of compiler hints, param not used.
  // Do nothing
end;


procedure TtiVisitorController.AfterExecuteOne(AVisitor : TtiVisitor);
begin
  Assert(AVisitor = AVisitor);  // Getting rid of compiler hints, param not used.
  // Do nothing
end;


procedure TtiVisitorController.BeforeExecuteAll(AVisitors : TList);
begin
  Assert(AVisitors = AVisitors);  // Getting rid of compiler hints, param not used.
  // Do nothing
end;


procedure TtiVisitorController.BeforeExecuteOne(AVisitor : TtiVisitor);
begin
  Assert(AVisitor = AVisitor);  // Getting rid of compiler hints, param not used.
  // Do nothing
end;


constructor TtiVisitorController.Create;
begin
  // So we can create an instance ot TVisitorMgr from a class reference var.
  inherited;
end;


function TtiVisitor.GetVisited: TtiVisited;
begin
  result := FVisited;
end;


procedure TtiVisitor.SetDepth(const ADepth: TIterationDepth);
begin
  FDepth:= ADepth;
end;

procedure TtiVisitor.SetVisited(const AValue: TtiVisited);
begin
  FVisited := AValue;
end;


{ TVisClassCount }

constructor TVisClassCount.Create;
begin
  inherited;
  FList := TStringList.Create;
end;


destructor TVisClassCount.Destroy;
begin
  FList.Free;
  inherited;
end;


procedure TVisClassCount.Execute(const AVisited: TtiVisited);
begin
  inherited Execute(AVisited);
  ClassCount[ AVisited.ClassType ]:= ClassCount[ AVisited.ClassType ] + 1;
end;


function TVisClassCount.GetClassCount(AClass : TClass): integer;
begin
  Result := StrToIntDef(FList.Values[ AClass.ClassName ], 0);
end;


procedure TVisClassCount.SetClassCount(AClass : TClass; const AValue: integer);
begin
  FList.Values[ AClass.ClassName ]:= IntToStr(AValue);
end;


{ TVisStringStream }

constructor TVisStringStream.Create;
begin
  inherited;
  Stream := TtiPreSizedStream.Create(cStreamStartSize, cStreamGrowBy);
end;


destructor TVisStringStream.Destroy;
begin
  Stream.Free;
  inherited;
end;


function TVisStringStream.GetText: string;
begin
  result := FStream.AsString;
end;


procedure TtiVisited.Iterate(const AVisitor : TtiVisitor);
begin
  Assert(AVisitor.TestValid, cTIInvalidObjectError);
  case AVisitor.IterationStyle of
  isTopDownRecurse:     IterateTopDownRecurse(AVisitor);
  isTopDownSinglePass:  IterateTopDownSinglePass(AVisitor);
  isBottomUpSinglePass: IterateBottomUpSinglePass(AVisitor);
  else
    raise EtiOPFProgrammerException.Create(CErrorInvalidIterationStyle);
  end;
end;

procedure TtiVisited.IterateBottomUpSinglePass(AVisitor: TtiVisitor);
var
  LList: TObjectList;
  i : integer;
begin
  Assert(AVisitor.TestValid, cTIInvalidObjectError);
  LList:= TObjectList.Create(True);
  try
    Iterate(AVisitor, nil, LList, TouchMethodAddToList, 0);
    i:= LList.Count-1;
    while (i >= 0) and
      ContinueVisiting(AVisitor) do
    begin
      ExecuteVisitor(AVisitor, TtiVisitedCandidate(LList.Items[i]));
      Dec(i);
    end;
  finally
    LList.Free;
  end;
end;

{ TVisFindAllByClass }

function TVisFindAllByClass.AcceptVisitor: boolean;
begin
  result := Visited is FClassTypeToFind;
end;


procedure TVisFindAllByClass.Execute(const AVisited: TtiVisited);
begin
  inherited Execute(AVisited);
  if not AcceptVisitor then
    Exit; //==>
  FList.Add(AVisited);
end;


procedure TtiVisitorController.SetPerLayerName(const AValue: string);
begin
  FPerLayerName := AValue;
end;


{ TtiVisitorManager }

constructor TtiVisitorManager.Create;
begin
  inherited;
  FSynchronizer:= TMultiReadExclusiveWriteSynchronizer.Create;
  FVisitorMappings:= TObjectList.Create;
  FBreakOnException:= True;
end;


destructor TtiVisitorManager.destroy;
begin
  FVisitorMappings.Free;
  FreeAndNil(FSynchronizer);
  inherited;
end;


procedure TtiVisitorManager.DoAfterExecuteAll(const AVisitorController: TtiVisitorController;
  const AVisitors: TList);
begin
  AVisitorController.AfterExecuteAll(AVisitors);
end;


procedure TtiVisitorManager.DoAfterExecuteError(
  const AVisitorController: TtiVisitorController;
  const AVisitors: TList);
begin
  AVisitorController.AfterExecuteError(AVisitors);
end;

procedure TtiVisitorManager.DoBeforeExecuteAll(
  const AVisitorController: TtiVisitorController; const AVisitors : TList);
begin
  AVisitorController.BeforeExecuteAll(AVisitors);
end;


procedure TtiVisitorManager.DoBeforeExecuteOne(
  const AVisitorController: TtiVisitorController; const AVisitor: TtiVisitor);
begin
  AVisitorController.BeforeExecuteOne(AVisitor);
end;

procedure TtiVisitorManager.DoAfterExecuteOne(const AVisitorController: TtiVisitorController; const AVisitor: TtiVisitor);
begin
  AVisitorController.AfterExecuteOne(AVisitor);
end;

function TtiVisitorManager.Execute(const AGroupName      : string;
                            const AVisited         : TtiVisited;
                            const ADBConnectionName : string = '';
                            const APersistenceLayerName    : string = ''): string;
var
  lPerLayerName      : string;
  lDBConnectionName  : string;
begin
  // Don't go any further if terminated
  if gTIOPFManager.Terminated then
    Exit; //==>

  Log('About to process visitors for <' + AGroupName + '>', lsVisitor);

  if APersistenceLayerName = '' then
  begin
    Assert(gTIOPFManager.DefaultPerLayer.TestValid(TtiPersistenceLayer), cTIInvalidObjectError);
    lPerLayerName := gTIOPFManager.DefaultPerLayer.PerLayerName
  end else
    lPerLayerName := APersistenceLayerName;

  if ADBConnectionName = '' then
    lDBConnectionName := gTIOPFManager.DefaultDBConnectionName
  else
    lDBConnectionName := ADBConnectionName;

  Assert(lDBConnectionName <> '',
          'Either the gTIOPFManager.DefaultDBConnectionName must be set, ' +
          'or the DBConnectionName must be passed as a parameter to ' +
          'gVisMgr.Execute()');

  try
    Result := '';
    ProcessVisitors(AGroupName, AVisited, lDBConnectionName, lPerLayerName);
  except
    // Log and display any error messages
    on e:exception do
    begin
      Result := e.message;
      LogError(e.message, false);
      if BreakOnException then
        raise;
    end;
  end;

  Log('Finished process visitors for <' + AGroupName + '>', lsVisitor);
end;

procedure TtiVisitorManager.ExecuteVisitors(
  const AVisitorController: TtiVisitorController;
  const AVisitors: TList; const AVisited : TtiVisited);
var
  LVisitor : TtiVisitor;
  i : integer;
begin
  for i := 0 to AVisitors.Count - 1 do
  begin
    LVisitor := TtiVisitor(AVisitors.Items[i]);
    DoBeforeExecuteOne(AVisitorController, LVisitor);
    try
      if AVisited <> nil then
        AVisited.Iterate(LVisitor)
      else
        LVisitor.Execute(nil);
    finally
      DoAfterExecuteOne(AVisitorController, LVisitor);
    end;
  end;
end;


function TtiVisitorManager.FindVisitorMappingGroup(
  const AGroupName: string): TtiVisitorMappingGroup;
var
  i : integer;
  LGroupName : string;
begin
  result:= nil;
  LGroupName := upperCase(AGroupName);
  for i := 0 to FVisitorMappings.Count - 1 do
    if (FVisitorMappings.Items[i] as TtiVisitorMappingGroup).GroupName = LGroupName then
    begin
      Result:= FVisitorMappings.Items[i] as TtiVisitorMappingGroup;
      Exit; //==>
    end;
end;

function TtiVisitorManager.GetVisitorMappings: TList;
begin
  result:= FVisitorMappings;
end;

procedure TtiVisitorManager.AssignVisitorInstances(const AVisitors: TObjectList;const AGroupName: string);
var
  LVisitorMappingGroup: TtiVisitorMappingGroup;
begin
  Assert(Assigned(AVisitors), 'AVisitors not assigned');
  Assert(AGroupName<>'', 'AGroupName not assigned');
  LVisitorMappingGroup:= FindVisitorMappingGroup(AGroupName);
  Assert(Assigned(LVisitorMappingGroup), 'Request for unknown VisitorMappingGroup "' + AGroupName + '"');
  LVisitorMappingGroup.AssignVisitorInstances(AVisitors);
end;

procedure TtiVisitorManager.ProcessVisitorControllers(
  const AVisitors: TList;
  const AVisitorController: TtiVisitorController;
  const AProc: TOnProcessVisitorController);
var
  i : integer;
begin
  for i := 0 to AVisitors.Count-1 do
    AProc(AVisitorController, AVisitors);
end;


procedure TtiVisitorManager.ProcessVisitors(const AGroupName       : string;
  const AVisited: TtiVisited;
  const ADBConnectionName : string;
  const APersistenceLayerName    : string);
var
  LVisitorMappingGroup: TtiVisitorMappingGroup;
  LVisitorController: TtiVisitorController;
  LVisitors : TObjectList;
begin
  LVisitors := TObjectList.Create;
  try
    FSynchronizer.BeginRead;
    try
      LVisitorMappingGroup:= FindVisitorMappingGroup(AGroupName);
      LVisitorController:= LVisitorMappingGroup.VisitorControllerClass.Create;
      LVisitorController.DBConnectionName:= ADBConnectionName;
      LVisitorController.PerLayerName:= APersistenceLayerName;
      LVisitorMappingGroup.AssignVisitorInstances(LVisitors);
      try
        AssignVisitorInstances(LVisitors, AGroupName );
        ProcessVisitorControllers(LVisitors, LVisitorController, DoBeforeExecuteAll);
        try
          ExecuteVisitors(LVisitorController, LVisitors, AVisited);
          ProcessVisitorControllers(LVisitors, LVisitorController, DoAfterExecuteAll);
        except
          on e:exception do
          begin
            ProcessVisitorControllers(LVisitors, LVisitorController, DoAfterExecuteError);
            raise;
          end;
        end;
      finally
        LVisitorController.Free;
      end;
    finally
      FSynchronizer.EndRead;
    end;
  finally
    LVisitors.Free;
  end;
end;


procedure TtiVisitorManager.RegisterVisitor(const AGroupName : string;
                                         const AVisitorClass : TtiVisitorClass);
var
  LVisitorMappingGroup: TtiVisitorMappingGroup;
begin
  FSynchronizer.BeginWrite;
  try
    LVisitorMappingGroup:= FindVisitorMappingGroup(AGroupName);
    if LVisitorMappingGroup = nil then
    begin
      LVisitorMappingGroup:= TtiVisitorMappingGroup.Create(AGroupName,
        AVisitorClass.VisitorControllerClass);
      FVisitorMappings.Add(LVisitorMappingGroup);
    end;
    LVisitorMappingGroup.Add(AVisitorClass);
  finally
    FSynchronizer.EndWrite;
  end;
end;

procedure TtiVisitorManager.UnRegisterVisitors(const AGroupName: string);
var
  LVisitorMappingGroup: TtiVisitorMappingGroup;
begin
  FSynchronizer.BeginWrite;
  try
    LVisitorMappingGroup:= FindVisitorMappingGroup(AGroupName);
    Assert(Assigned(LVisitorMappingGroup),
           'Request to UnRegister visitor group that''s not registered "' +
           AGroupName + '"');
    FVisitorMappings.Remove(LVisitorMappingGroup);
  finally
    FSynchronizer.EndWrite;
  end;
end;

{ TVisitorMappingGroup }

procedure TtiVisitorMappingGroup.Add(const AVisitorClass: TtiVisitorClass);
var
  i: integer;
begin
  Assert(Assigned(AVisitorClass), 'AVisitorClass not assigned');
  if AVisitorClass.VisitorControllerClass <> VisitorControllerClass then
    raise EtiOPFProgrammerException.CreateFmt(CErrorIncompatibleVisitorController,
      [VisitorControllerClass.ClassName, AVisitorClass.VisitorControllerClass.ClassName]);
  for i := 0 to FMappings.Count-1 do
    if FMappings.Items[i] = AVisitorClass then
      Raise EtiOPFProgrammerException.CreateFmt(CErrorAttemptToRegisterDuplicateVisitor, [AVisitorClass.ClassName]);
  FMappings.Add(AVisitorClass);
end;

procedure TtiVisitorMappingGroup.AssignVisitorInstances(const AVisitorList: TObjectList);
var
  i: integer;
begin
  Assert(Assigned(AVisitorList), 'AVisitors not assigned');
  for i := 0 to FMappings.Count-1 do
    AVisitorList.Add(TtiVisitorClass(FMappings.Items[i]).Create);
end;

constructor TtiVisitorMappingGroup.Create(const AGroupName: string;
  const AVisitorControllerClass: TtiVisitorControllerClass);
begin
  inherited Create;
  FGroupName:= UpperCase(AGroupName);
  FMappings:= TClassList.Create;
  FVisitorControllerClass:= AVisitorControllerClass;
end;

destructor TtiVisitorMappingGroup.Destroy;
begin
  FMappings.Free;
  inherited;
end;

end.












