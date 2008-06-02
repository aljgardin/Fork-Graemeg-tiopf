{* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
  The contents of this file are subject to the Mozilla Public
  License Version 1.1 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of
  the License at http://www.mozilla.org/MPL/

  Software distributed under the License is distributed on an "AS
  IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
  implied. See the License for the specific language governing
  rights and limitations under the License.

  Originally developed and released by Peter Hinrichsen, TechInsite Pty. Ltd.
  as the tiOPF (TechInsite Object Persistence Framework)

    23 Victoria Pde, Collingwood, Melbourne, Victoria 3066 Australia
    PO Box 429, Abbotsford, Melbourne, Victoria 3067 Australia
    Phone: +61 3 9419 6456 Fax:   +61 3 9419 1682
    Latest source:   www.techinsite.com.au/tiOPF/Download.htm
    Documentation:   www.techinsite.com.au/tiOPF/Doc/
    Support:         www.techinsite.com.au/tiOPF/MailingList.htm

  Please submit changes to tiOPF@techinsite.com.au

  Purpose:
    Use the Adapter Pattern [GoF 139] to wrapper the TIBQuery
    component to allow a standard interface to be presented to the
    application for all data access APIs.

  Classes:

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *}

{$I tiDefines.inc}

Unit tiQueryUIB_FB;

Interface

Uses
  SysUtils,
  tiQuery,
  tiQueryUIBAbs,
  tiPersistenceLayers;

Type

  TtiPersistenceLayerUIB_FB = Class(TtiPersistenceLayer)
  Protected
    Function GetPersistenceLayerName : String; Override;
    Function GetDatabaseClass : TtiDatabaseClass; Override;
    Function GetQueryClass : TtiQueryClass; Override;
  Public
    Procedure AssignPersistenceLayerDefaults(Const APersistenceLayerDefaults : TtiPersistenceLayerDefaults); Override;
  End;

  // ---------------------------------------------------------------------------
  TtiDatabaseUIB_FB = Class(TtiDatabaseUIBAbs)
  Public
    Constructor create; Override;
    Class Procedure CreateDatabase(Const pDatabaseName, pUserName,
      pPassword : String); Override;
    Class Function DatabaseExists(Const pDatabaseName, pUserName,
      pPassword : String) : Boolean; Override;
    Function TIQueryClass : TtiQueryClass; Override;
  End;

  // ---------------------------------------------------------------------------
  TtiQueryUIB_FB = Class(TtiQueryUIBAbs)
  End;

Implementation

Uses
  tiOPFManager,
  tiDBConnectionPool,
  tiConstants;

{ TtiDatabaseUIB_FB }

Constructor TtiDatabaseUIB_FB.create;
Begin
  Inherited;
  LayerName := cTIPersistUIB_FB;
  UIBDatabase.LibraryName := 'FbClient.dll';
End;

Class Procedure TtiDatabaseUIB_FB.CreateDatabase(Const pDatabaseName, pUserName, pPassword : String);
Var
  lDatabase : TtiDatabaseUIB_FB;
Begin
  lDatabase := TtiDatabaseUIB_FB.Create;
  Try
    With lDatabase.UIBDatabase Do Begin
      DatabaseName := pDatabaseName;
      UserName := pUserName;
      PassWord := pPassword;
      CreateDatabase;
    End;
  Finally
    lDatabase.Free;
  End;
End;

Class Function TtiDatabaseUIB_FB.DatabaseExists(Const pDatabaseName, pUserName,
  pPassword : String) : Boolean;
Var
  lDatabase : TtiDatabaseUIB_FB;
Begin
  lDatabase := TtiDatabaseUIB_FB.Create;
  Try
    With lDatabase.UIBDatabase Do Begin
      DatabaseName := pDatabaseName;
      UserName := pUserName;
      PassWord := pPassword;
      Try
        Connected := true;
        Result := true;
      Except
        On e : exception Do
          result := false;
      End;
      Connected := false;
    End;
  Finally
    lDatabase.Free;
  End;
End;

{ TtiPersistenceLayerUIB_FB }

Procedure TtiPersistenceLayerUIB_FB.AssignPersistenceLayerDefaults(
  Const APersistenceLayerDefaults : TtiPersistenceLayerDefaults);
Begin
  Assert(APersistenceLayerDefaults.TestValid, CTIErrorInvalidObject);
  APersistenceLayerDefaults.PersistenceLayerName := cTiPersistUIB_FB;
  APersistenceLayerDefaults.DatabaseName := CDefaultDatabaseDirectory + CDefaultDatabaseName + '.fdb';
  APersistenceLayerDefaults.Username := 'SYSDBA';
  APersistenceLayerDefaults.Password := 'masterkey';
  APersistenceLayerDefaults.CanCreateDatabase := True;
  APersistenceLayerDefaults.CanSupportMultiUser := True;
End;

Function TtiPersistenceLayerUIB_FB.GetDatabaseClass : TtiDatabaseClass;
Begin
  Result := TtiDatabaseUIB_FB;
End;

Function TtiPersistenceLayerUIB_FB.GetPersistenceLayerName : String;
Begin
  Result := cTiPersistUIB_FB;
End;

Function TtiPersistenceLayerUIB_FB.GetQueryClass : TtiQueryClass;
Begin
  Result := TtiQueryUIB_FB;
End;

Function TtiDatabaseUIB_FB.TIQueryClass : TtiQueryClass;
Begin
  Result := TtiQueryUIB_FB;
End;

Initialization

  gTIOPFManager.PersistenceLayers.__RegisterPersistenceLayer(
    TtiPersistenceLayerUIB_FB);

Finalization
  If Not tiOPFManager.ShuttingDown Then
    gTIOPFManager.PersistenceLayers.__UnRegisterPersistenceLayer(cTIPersistUIB_FB);
End.

