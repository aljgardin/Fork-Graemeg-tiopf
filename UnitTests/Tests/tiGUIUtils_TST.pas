unit tiGUIUtils_TST;

interface
uses
  tiTestFramework
 ;

type

  TTestTIGUIUtils = class(TtiTestCase)
  published
    procedure   tiListToClipboardDefault;
    procedure   tiListToClipboardFields;
  end;

procedure RegisterTests;

implementation
uses
  tiDUnitDependencies
  ,tstPerFramework_BOM
  ,tiGUIUtils
  ,Classes
  ,ClipBrd
  ;
  
procedure RegisterTests;
begin
  RegisterNonPersistentTest(TTestTIGUIUtils);
end;

procedure TTestTIGUIUtils.tiListToClipboardDefault;
var
  lList: TTestListOfPersistents;
  lString1: string;
  lString2: string;
  lFields: TStringList;
begin
  lList := TTestListOfPersistents.Create;
  try
    lFields := TStringList.Create;
    try
      lFields.Add('Caption');
      lFields.Add('StringProp');
      lFields.Add('IntProp');
      lFields.Add('DateTimeProp');
      lFields.Add('FloatProp');
      tiGUIUtils.tiListToClipboard(lList);
      lString1 := ClipBoard.AsText;
      lString2 := lList.AsString(#9, #13#10, lFields);
    finally
      lFields.Free;
    end;
  finally
    lList.Free;
  end;

  CheckEquals(Length(lString1), Length(lString2), 'Failed on 1');
  CheckEquals(lString1, lString2, 'Failed on 2');
end;


procedure TTestTIGUIUtils.tiListToClipboardFields;
var
  lList      : TTestListOfPersistents;
  lString1: string;
  lString2 : string;
  lFields: TStringList;
begin
  lList  := TTestListOfPersistents.Create;
  try
    lFields:= TStringList.Create;
    try
      lFields.Add('StringProp');
      lFields.Add('IntProp');
      lFields.Add('FloatProp');
      tiGUIUtils.tiListToClipboard(lList, lFields);
      lString1 := ClipBoard.AsText;
      lString2 := lList.AsString(#9, #13#10, lFields);
    finally
      lFields.Free;
    end;
  finally
    lList.Free;
  end;

  CheckEquals(Length(lString1), Length(lString2), 'Length');
  CheckEquals(lString1, lString2, 'String');
end;


end.
