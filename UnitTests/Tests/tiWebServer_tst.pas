unit tiWebServer_tst;

{$I tiDefines.inc}

interface
uses
   tiTestFrameWork
 ;

type

  TTestTIWebServerClientConnectionDetails = class(TtiTestCase)
  published
    procedure Equals;
    procedure Assign;
  end;

  TTestTIWebServer = class(TtiTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    function  TestHTTPRequest(const ADocument: string;
      const AFormatException: boolean = True;
      const AParams: string = ''): string;
    function  TestHTTPRequestInBlocks(const ADocument: string;
                                      var   ABlockIndex, ABlockCount, ABlockSize, ATransID: Longword): string;
    procedure TestRunCGIExtension(const AParam: string);
  published
    procedure tiBlockStreamCache_AddRead;
    procedure tiBlockStreamCache_SweepForTimeOuts;

    procedure tiWebServer_Create;
    procedure tiWebServer_CreateStartAndStop;
    procedure tiWebServer_Ignore;
    procedure tiWebServer_Default;
    procedure tiWebServer_CanNotFindPage;
    procedure tiWebServer_CanFindPage;
    procedure tiWebServer_GetLogFile;
    procedure tiWebServer_TestWebServerCGIForTestingEXE;
    procedure tiWebServer_RunCGIExtensionSmallParameter;
    procedure tiWebServer_RunCGIExtensionLargeParameter;
    procedure tiWebServer_PageInBlocks;
    procedure tiWebServerVersion;

  end;

  TTestTICGIParams = class(TtiTestCase)
  published
    procedure Values;
    procedure Assign;
  end;

procedure RegisterTests;

implementation
uses
   tiUtils

  ,tiTestDependencies
  ,tiWebServerConfig
  ,tiWebServer

  ,tiWebServerClientConnectionDetails
  ,tiWebServerConstants
  ,tiWebServerVersion
  ,tiHTTPIndy
  ,tiLog
  ,tiHTTP
  ,tiCGIParams
  ,tiStreams
  ,tiConsoleApp
  ,tiConstants

  ,SysUtils
  ,Classes
  ;

procedure RegisterTests;
begin
  RegisterNonPersistentTest(TTestTIWebServerClientConnectionDetails);
  RegisterNonPersistentTest(TTestTIWebServer);
  RegisterNonPersistentTest(TtestTICGIParams);
end;

const
  cPort= 81;

{ TTestTIWebServer }

procedure TTestTIWebServer.SetUp;
begin
  inherited;

end;

procedure TTestTIWebServer.TearDown;
begin
  inherited;

end;

type
  TtiWebServerForTesting = class(TtiWebServer)
  public
    procedure SetStaticPageLocation(const AValue: string); override;
    procedure SetCGIBinLocation(const AValue: string); override;
    property  BlockStreamCache;
  end;

procedure TTestTIWebServer.tiWebServer_Create;
var
  LO: TtiWebServerForTesting;
begin
  LO:= TtiWebServerForTesting.Create(cPort);
  try
    Check(True);
    Sleep(1000);
  finally
    LO.Free;
  end;
end;

procedure TTestTIWebServer.tiWebServer_CreateStartAndStop;
var
  LConfig: TtiWebServerConfig;
  LO: TtiWebServerForTesting;
  LExpectedStaticPageDir: string;
  LExpectedCGIBinDir: string;
begin
  LConfig:= nil;
  LO:= nil;
  try
    LConfig:= TtiWebServerConfig.Create;
    LO:= TtiWebServerForTesting.Create(cPort);
    LO.BlockStreamCache.SleepSec:= 0;
    LExpectedStaticPageDir:= tiAddTrailingSlash(LConfig.PathToStaticPages);
    LExpectedCGIBinDir:= tiAddTrailingSlash(LConfig.PathToCGIBin);
    LO.Start;
    CheckEquals(LExpectedStaticPageDir, LO.StaticPageLocation);
    Check(DirectoryExists(LO.StaticPageLocation));
    CheckEquals(LExpectedCGIBinDir, LO.CGIBinLocation);
    LO.Stop;
  finally
    LO.Free;
    LConfig.Free;
  end;
end;

procedure TTestTIWebServer.tiWebServerVersion;
var
  L: TtiAppServerVersion;
  LS: string;
begin

  L:= TtiAppServerVersion.Create;
  try
    CheckEquals(cWebServerStatus_unknown, L.ConnectionStatus);
    CheckEquals('', L.XMLVersion);
    CheckEquals('', L.FileSyncVersion);

    L.LoadDefaultValues;
    CheckEquals(cWebServerStatus_unknown, L.ConnectionStatus);
    CheckEquals(cXMLVersion,              L.XMLVersion);
    CheckEquals(cFileSyncVersion,         L.FileSyncVersion);

    L.SetConnectionStatus(True);
    CheckEquals(cWebServerStatus_passed, L.ConnectionStatus);

    L.SetConnectionStatus(False);
    CheckEquals(cWebServerStatus_failed, L.ConnectionStatus);

  finally
    L.free;
  end;

  L:= TtiAppServerVersion.Create;
  try
    L.ConnectionStatus:= 'test1';
    L.XMLVersion:= 'test2';
    L.FileSyncVersion:= 'test3';
    LS:= L.AsString;
  finally
    L.free;
  end;

  L:= TtiAppServerVersion.Create;
  try
    L.AsString:= LS;
    CheckEquals('test1', L.ConnectionStatus);
    CheckEquals('test2', L.XMLVersion);
    CheckEquals('test3', L.FileSyncVersion);
  finally
    L.free;
  end;

end;
procedure TTestTIWebServer.tiWebServer_CanFindPage;
var
  LO: TtiWebServerForTesting;
  LResult: string;
  LFileName: string;
  LPage: string;
  LDir: string;
begin
  LPage:= '<html>test page</html>';
  LFileName:= TempFileName('testpage.htm');
  LDir:= ExtractFilePath(LFileName);
  tiForceDirectories(LDir);
  tiStringToFile(LPage, LFileName);

  LO:= TtiWebServerForTesting.Create(cPort);
  try
    // ToDo: This is too fragile. SleepSec must be set before the web server is
    //       started but StaticPageLocation must be set after web server is started
    LO.BlockStreamCache.SleepSec:= 0;
    LO.Start;
    LO.SetStaticPageLocation(LDir);

    LResult:= TestHTTPRequest('testpage.htm');
    CheckEquals(LPage, LResult);

    LResult:= TestHTTPRequest('testpage');
    CheckEquals(LPage, LResult);

    tiDeleteFile(LFileName);
    LFileName:= tiSwapExt(LFileName, 'html');
    tiStringToFile(LPage, LFileName);

    LResult:= TestHTTPRequest('testpage');
    CheckEquals(LPage, LResult);

  finally
    LO.Free;
  end;
end;

procedure TTestTIWebServer.tiWebServer_CanNotFindPage;
var
  LO: TtiWebServer;
  LResult: string;
begin
  LO:= TtiWebServer.Create(cPort);
  try
    LO.Start;
    try
      LResult:= TestHTTPRequest('pagethatsnotthere.htm', False);
      fail('Exception not raised');
    except
      on e:exception do
      begin
        CheckIs(e, Exception);
        CheckEquals('HTTP/1.1 404 Not Found', e.message);
      end;
    end;
    CheckEquals('', LResult);

    try
      LResult:= TestHTTPRequest('pagethatsnotthere.htm', True);
      fail('Exception not raised');
    except
      on e:exception do
      begin
        CheckIs(e, Exception);
        CheckEquals(
          Format(cErrorAccessingHTTPServer,
                 ['HTTP/1.1 404 Not Found',
                  'Post',
                  'http://localhost:81/pagethatsnotthere.htm',
                  '']),
        e.message);
      end;
    end;
    CheckEquals('', LResult);
  finally
    LO.Free;
  end;
end;

procedure TTestTIWebServer.tiWebServer_Default;
var
  LO: TtiWebServer;
  LResult: string;
begin
  LO:= TtiWebServer.Create(cPort);
  try
    LO.Start;
    LResult:= TestHTTPRequest('');
    CheckEquals(cDefaultPageText, LResult);
  finally
    LO.Free;
  end;
end;

procedure TTestTIWebServer.tiWebServer_GetLogFile;
  function _WaitForLogFile(const AFileName: string): boolean;
  var
    LStream: TFileStream;
  begin
    if not FileExists(AFileName) then
      result:= True
    else
      try
        LStream:= TFileStream.Create(AFileName, fmShareExclusive or fmOpenRead);
        LStream.Free;
        result:= true;
      except
        on e: exception do
          result:= false;
      end;
  end;
var
  LO: TtiWebServerForTesting;
  LResult: string;
  LPage: string;
  LFileName: string;
  LTryCount: integer;
  LSavedSevToLog: TtiSevToLog;
begin
  LSavedSevToLog:= GLog.SevToLog;
  try
    GLog.SevToLog:= [];
    LFileName:= gLog.LogToFileName;
    LPage:= 'test log file';
    LO:= TtiWebServerForTesting.Create(cPort);
    try
      LO.BlockStreamCache.SleepSec:= 0;
      LO.Start;
      LTryCount:= 0 ;
      while not _WaitForLogFile(LFileName) and (LTryCount <= 10) do
        Sleep(100);
      tiDeleteFile(LFileName);
      tiStringToFile(LPage, LFileName);
      LResult:= TestHTTPRequest(cgTIDBProxyGetLog);
      CheckEquals('<HTML><PRE>'+LPage+'</PRE></HTML>', LResult);
    finally
      LO.Free;
    end;
  finally
    GLog.SevToLog:= LSavedSevToLog;
  end;
end;

procedure TTestTIWebServer.tiWebServer_Ignore;
var
  LO: TtiWebServer;
  LResult: string;
begin
  LO:= TtiWebServer.Create(cPort);
  try
    LO.Start;
    LResult:= TestHTTPRequest(cDocumentToIgnore);
    CheckEquals('', LResult);
  finally
    LO.Free;
  end;
end;

procedure TTestTIWebServer.tiWebServer_RunCGIExtensionLargeParameter;
var
  LWebServer: TtiWebServerForTesting;
  LHTTP: TtiHTTPIndy;
  LEncoded: string;
  LExpected: string;
  LActual: string;
  LSize: Cardinal;
begin
  LSize:= CMaximumCommandLineLength + 1;
  LExpected:= tiCreateStringOfSize(LSize);
  // The actual size of the string passed will be larger than
  // CMaximumCommandLineLength because MIME encoding inflates the string
  LEncoded:= MimeEncodeString(LExpected);
  LWebServer:= nil;
  LHTTP:= nil;
  try
    LWebServer:= TtiWebServerForTesting.Create(cPort);
    LHTTP:= TtiHTTPIndy.Create;
    LWebServer.Start;
    LWebServer.SetCGIBinLocation(tiAddTrailingSlash(tiGetEXEPath) + 'CGI-Bin');
    LHTTP.FormatExceptions:= False;
    LHTTP.Input.WriteString(LEncoded);
    LHTTP.Post('http://localhost:' + IntToStr(cPort) + '/tiWebServerCGIForTesting.exe');
    LEncoded:= LHTTP.Output.DataString;
    LActual:= MimeDecodeString(LEncoded);
    CheckEquals(Trim(LExpected), Trim(LActual));
  finally
    LHTTP.Free;
    LWebServer.Free;
  end;
end;

procedure TTestTIWebServer.tiWebServer_RunCGIExtensionSmallParameter;
begin
  TestRunCGIExtension('teststring');
end;

procedure TTestTIWebServer.tiWebServer_TestWebServerCGIForTestingEXE;
var
  LExpected: string;
  LActual: string;
  LPath: string;
  LEncode: string;
  LMaxCommandLineLength: Cardinal;
begin
  // tiExecConsoleApp will inject CrLf every 255 characters, so comparing strings
  // of less than this length will be OK, but longer strings will be mangled
  // so must be encoded first.
  LPath:= tiAddTrailingSlash(tiGetEXEPath) + 'CGI-Bin\tiWebServerCGIForTesting.exe';
   // Testing against a different EXE location
  //LPath:= 'C:\Temp\tiWebServerCGIForTesting.exe';

  // Test a short string
  LActual:= '';
  LExpected:= 'abcd';
  tiExecConsoleApp(LPath, LExpected, LActual, nil, False);
  CheckEquals(Trim(LExpected), Trim(LActual));
  // Must do something about this leading CrLf that's being added
  CheckEquals(#13#10+LExpected, LActual);

  // Test a long string
  LActual:= '';
  LExpected:= tiCreateStringOfSize(20*1024);
  tiExecConsoleApp(LPath, MimeEncodeString(LExpected), LActual, nil, False);
  CheckEquals(Trim(LExpected), Trim(MimeDecodeString(LActual)));

  // Test a string string on the limit
  LMaxCommandLineLength:=
    CMaximumCommandLineLength - Length(LPath);
  LActual:= '';
  LEncode:= tiReplicate('X', LMaxCommandLineLength);
  tiExecConsoleApp(LPath, LEncode, LActual, nil, False);

  // Test a string string 1 byte above the limit
  try
    LActual:= '';
    LEncode:= tiReplicate('X', LMaxCommandLineLength + 1);
    tiExecConsoleApp(LPath, LEncode, LActual, nil, False);
    Fail('Exception not raised');
  except
    on e:exception do
      Check(Pos('Maximum command line length', e.message) <> 0);
  end;
end;

function TTestTIWebServer.TestHTTPRequest(const ADocument: string;
  const AFormatException: boolean = True;
  const AParams: string = ''): string;
var
  LHTTP: TtiHTTPIndy;
begin
  LHTTP:= TtiHTTPIndy.Create;
  try
    LHTTP.FormatExceptions:= AFormatException;
    LHTTP.Input.WriteString(AParams);
    LHTTP.Post('http://localhost:' + IntToStr(cPort) + '/' + ADocument);
    Result:= LHTTP.Output.DataString;
  finally
    LHTTP.Free;
  end;
end;

procedure TTestTIWebServer.tiWebServer_PageInBlocks;
var
  LO: TtiWebServerForTesting;
  LFileName: string;
  LPage: string;
  LBlockCount, LBlockIndex, LBlockSize, LTransID: Longword;
  LDir: string;
  LHTTP: TtiHTTPIndy;
  LHeader: string;
  LSaveBlockSize: LongWord;
begin

  LFileName:= TempFileName('testpage.htm');
  LDir:= ExtractFilePath(LFileName);
  tiForceDirectories(LDir);
  LPage:= 'abcDEFghiJKLmn';
  tiStringToFile(LPage, LFileName);

  LO:= TtiWebServerForTesting.Create(cPort);
  try
    LO.BlockStreamCache.SleepSec:= 0;
    LO.Start;
    LO.SetStaticPageLocation(LDir);

    LBlockCount:= 0;
    LBlockIndex:= 0;
    LBlockSize:=  3;
    LTransID:=    0;

    LSaveBlockSize:= tiHTTP.GTIOPFHTTPDefaultBlockSize;
    try
      LHTTP:= TtiHTTPIndy.Create;
      try
        tiHTTP.GTIOPFHTTPDefaultBlockSize:= LBlockSize;
        LHTTP.Post('http://localhost:' + IntToStr(cPort) + '/' + 'testpage.htm');
        LHeader:= LHTTP.ResponseTIOPFBlockHeader;
        tiHTTP.tiParseTIOPFHTTPBlockHeader(LHeader, LBlockIndex, LBlockCount, LBlockSize, LTransID);
      finally
        LHTTP.Free;
      end;
    finally
      tiHTTP.GTIOPFHTTPDefaultBlockSize:= LSaveBlockSize;
    end;

    CheckEquals(5, LBlockCount, 'BlockCount #1');
    CheckEquals(4, LBlockIndex, 'BlockIndex #1');
    CheckEquals(3, LBlockSize,  'BlockSize #1');
    CheckEquals(1, LTransID,    'TransID #1');

  finally
    LO.Free;
  end;

end;

function TTestTIWebServer.TestHTTPRequestInBlocks(const ADocument: string;
  var ABlockIndex, ABlockCount, ABlockSize, ATransID: Longword): string;
var
  LHTTP: TtiHTTPIndy;
  LHeader: string;
  LSaveBlockSize: LongWord;
begin
  LSaveBlockSize:= tiHTTP.GTIOPFHTTPDefaultBlockSize;
  try
    LHTTP:= TtiHTTPIndy.Create;
    try
      tiHTTP.GTIOPFHTTPDefaultBlockSize:= ABlockSize;
      LHTTP.Post('http://localhost:' + IntToStr(cPort) + '/' + ADocument);
      Result:= LHTTP.Output.DataString;
      LHeader:= LHTTP.ResponseTIOPFBlockHeader;
      tiHTTP.tiParseTIOPFHTTPBlockHeader(LHeader, ABlockIndex, ABlockCount, ABlockSize, ATransID);
    finally
      LHTTP.Free;
    end;
  finally
    tiHTTP.GTIOPFHTTPDefaultBlockSize:= LSaveBlockSize;
  end;
end;

procedure TTestTIWebServer.TestRunCGIExtension(const AParam: string);
var
  LO: TtiWebServerForTesting;
  LResult: string;
begin
  LO:= TtiWebServerForTesting.Create(cPort);
  try
    LO.Start;
    LO.SetCGIBinLocation(tiAddTrailingSlash(tiGetEXEPath) + 'CGI-Bin');
    LResult:= TestHTTPRequest('tiWebServerCGIForTesting.exe', True, AParam);
    // ToDo: Tidy up the white space padding before and after the result string
    CheckEquals(Trim(AParam), Trim(LResult));
  finally
    LO.Free;
  end;
end;

type
  TtiBlockStreamCacheForTesting = class(TtiBlockStreamCache)
  public
    property Count;
  end;

procedure TTestTIWebServer.tiBlockStreamCache_AddRead;
var
  L: TtiBlockStreamCacheForTesting;
  LBlockText: string;
  LBlockCount: Longword;
  LTransID: Longword;
begin
  L:= TtiBlockStreamCacheForTesting.Create;
  try
    L.AddBlockStream('abcDEFgh', 3, LBlockText, LBlockCount, LTransID);
    CheckEquals(1, L.Count);
    CheckEquals('abc', LBlockText);
    CheckEquals(3, LBlockCount);
    CheckEquals(1, LTransID);

    L.AddBlockStream('jklMNOpq', 3, LBlockText, LBlockCount, LTransID);
    CheckEquals(2, L.Count);
    CheckEquals('jkl', LBlockText);
    CheckEquals(3, LBlockCount);
    CheckEquals(2, LTransID);

    L.ReadBlock(2, 0, LBlockText);
    CheckEquals('jkl', LBlockText);
    L.ReadBlock(2, 1, LBlockText);
    CheckEquals('MNO', LBlockText);
    L.ReadBlock(2, 2, LBlockText);
    CheckEquals('pq', LBlockText);
    CheckEquals(1, L.Count);

    L.ReadBlock(1, 0, LBlockText);
    CheckEquals('abc', LBlockText);
    L.ReadBlock(1, 1, LBlockText);
    CheckEquals('DEF', LBlockText);
    L.ReadBlock(1, 2, LBlockText);
    CheckEquals('gh', LBlockText);
    CheckEquals(0, L.Count);

  finally
    L.Free;
  end;
end;

procedure TTestTIWebServer.tiBlockStreamCache_SweepForTimeOuts;
var
  L: TtiBlockStreamCacheForTesting;
  LBlockText: string;
  LBlockCount: Longword;
  LTransID: Longword;
begin
  L:= TtiBlockStreamCacheForTesting.Create;
  try
    L.SleepSec:= 1;
    L.SweepEverySec:= 1;
    L.Start;
    L.AddBlockStream('abcDEFgh', 3, LBlockText, LBlockCount, LTransID);
    L.AddBlockStream('jklMNOpq', 3, LBlockText, LBlockCount, LTransID);
    Sleep(2500);
    CheckEquals(2, L.Count);
    L.TimeOutSec:= 1;
    Sleep(2500);
    CheckEquals(0, L.Count);
  finally
    L.Free;
  end;
end;

{ TTestTIWebServerConnectionDetails }

procedure TTestTIWebServerClientConnectionDetails.Assign;
var
  LA: TtiWebServerClientConnectionDetails;
  LB: TtiWebServerClientConnectionDetails;
const
  CAppServerURL= '1';
  CConnectWith= '2';
  CProxyServerActive= True;
  CProxyServerName= '3';
  CProxyServerPort= 4;

begin
  LA:= nil;
  LB:= nil;
  try
    LA:= TtiWebServerClientConnectionDetails.Create;
    LB:= TtiWebServerClientConnectionDetails.Create;

    LA.AppServerURL:= CAppServerURL;
    LA.ConnectWith:= CConnectWith;
    LA.ProxyServerActive:= CProxyServerActive;
    LA.ProxyServerName:= CProxyServerName;
    LA.ProxyServerPort:= CProxyServerPort;

    LB.Assign(LA);

    CheckEquals(CAppServerURL, LA.AppServerURL);
    CheckEquals(CConnectWith, LA.ConnectWith);
    CheckEquals(CProxyServerActive, LA.ProxyServerActive);
    CheckEquals(CProxyServerName, LA.ProxyServerName);
    CheckEquals(CProxyServerPort, LA.ProxyServerPort);

  finally
    LA.Free;
    LB.Free;
  end;
end;

procedure TTestTIWebServerClientConnectionDetails.Equals;
var
  LA: TtiWebServerClientConnectionDetails;
  LB: TtiWebServerClientConnectionDetails;
const
  CAppServerURL= '1';
  CConnectWith= '2';
  CProxyServerActive= True;
  CProxyServerName= '3';
  CProxyServerPort= 4;

begin
  LA:= nil;
  LB:= nil;
  try
    LA:= TtiWebServerClientConnectionDetails.Create;
    LB:= TtiWebServerClientConnectionDetails.Create;

    LA.AppServerURL:= CAppServerURL;
    LA.ConnectWith:= CConnectWith;
    LA.ProxyServerActive:= CProxyServerActive;
    LA.ProxyServerName:= CProxyServerName;
    LA.ProxyServerPort:= CProxyServerPort;

    LB.AppServerURL:= CAppServerURL;
    LB.ConnectWith:= CConnectWith;
    LB.ProxyServerActive:= CProxyServerActive;
    LB.ProxyServerName:= CProxyServerName;
    LB.ProxyServerPort:= CProxyServerPort;

    Check(LA.Equals(LB));
    LB.AppServerURL:= 'test';
    Check(not LA.Equals(LB));
    LB.AppServerURL:= CAppServerURL;

    Check(LA.Equals(LB));
    LB.ConnectWith:= 'test';
    Check(not LA.Equals(LB));
    LB.ConnectWith:= CConnectWith;

    Check(LA.Equals(LB));
    LB.ProxyServerActive:= not LB.ProxyServerActive;
    Check(not LA.Equals(LB));
    LB.ProxyServerActive:= CProxyServerActive;

    Check(LA.Equals(LB));
    LB.ProxyServerName:= 'test';
    Check(not LA.Equals(LB));
    LB.ProxyServerName:= CProxyServerName;

    Check(LA.Equals(LB));
    LB.ProxyServerPort:= LB.ProxyServerPort+1;
    Check(not LA.Equals(LB));
    LB.ProxyServerPort:= CProxyServerPort;

  finally
    LA.Free;
    LB.Free;
  end;
end;

{ TTestTICGIParams }

const
  CParam1 = 'param1';
  CParam2 = 'param2';
  CValue1 = 'value1';
  CValue2 = 'value2';

procedure TTestTICGIParams.Assign;
var
  LA: TtiCGIParams;
  LB: TtiCGIParams;
begin
  LA:= nil;
  LB:= nil;
  try
    LA:= TtiCGIParams.Create;
    LB:= TtiCGIParams.Create;
    LA.Values[CParam1]:= CValue1;
    LA.Values[CParam2]:= CValue2;
    LB.Assign(LA);
    CheckEquals(2, LB.Count);
    CheckEquals(CValue1, LB.Values[CParam1]);
    CheckEquals(CValue2, LB.Values[CParam2]);
  finally
    LA.Free;
    LB.Free;
  end;
end;

procedure TTestTICGIParams.Values;
var
  L: TtiCGIParams;
  LAsString: string;
  LCompressEncode: string;
begin

  L:= TtiCGIParams.Create;
  try
    L.Values[CParam1]:= CValue1;
    CheckEquals(1, L.Count);
    L.Values[CParam2]:= CValue2;
    CheckEquals(2, L.Count);
    CheckEquals(CValue1, L.Values[CParam1]);
    CheckEquals(CValue2, L.Values[CParam2]);

    LAsString:= L.AsString;
    LCompressEncode:= L.AsCompressedEncodedString;

  finally
    L.Free;
  end;

  L:= TtiCGIParams.Create;
  try
    L.AsString:= LAsString;
    CheckEquals(2, L.Count);
    CheckEquals(CValue1, L.Values[CParam1]);
    CheckEquals(CValue2, L.Values[CParam2]);
  finally
    L.Free;
  end;

  L:= TtiCGIParams.Create;
  try
    L.AsCompressedEncodedString:= LCompressEncode;
    CheckEquals(2, L.Count);
    CheckEquals(CValue1, L.Values[CParam1]);
    CheckEquals(CValue2, L.Values[CParam2]);
  finally
    L.Free;
  end;

end;

{ TtiWebServerForTesting }

procedure TtiWebServerForTesting.SetCGIBinLocation(const AValue: string);
begin
  inherited;
end;

procedure TtiWebServerForTesting.SetStaticPageLocation(const AValue: string);
begin
  inherited;
end;

end.
