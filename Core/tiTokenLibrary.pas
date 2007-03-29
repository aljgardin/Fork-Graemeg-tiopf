{Tokens Library.

 Copyright (C) 1996, Earl F. Glynn.  All Rights Reserved.
 Converted from C++ Tokens unit, December 1996

 [Note:  The diagram below will appear with correct line-drawing characters
         in DOS or on an HP LaserJet printer. In Delphi set the editor font
         to Terminal, to see the correct diagram.

         If you can't see the diagram for some reason have a look at the
         following image Docs/diagrams/tiTokenLibrary_Diagram.png          ]


                Finite State Machine to Recognize Tokens

                                START
                                  �           *
               else               � separators           else
               ���Ŀ              �   ���Ŀ              ���Ŀ
               �         Left       �                 �   
           �����������Ŀ  Mark  �����������Ŀ else   �����������Ŀ
           �  Accept   �������ĳ           ���������  Accept   �
           � MultiWord �        �    Skip   �        �SingleWord �
           �   Token   �        � Separators�        �   Token   �
           �   State   ���������   State   �������ĳ   State   �
           �������������  Right ������������� separa-�������������
        escape�          Mark                 tors
     character�     �
              �     � any
                   � character
           �����������Ŀ
           �   Escape  �
           �   State   �
           �������������


       *
        Multiple separators can be treated as one (e.g., space or tab),
        or treated as multiple null tokens (e.g, comma delimited data).

  Sample Usage:

    FieldSpec := TTokens.Create(FieldSpecLine, ', ', '"', '"', '\', FALSE);
    try
      FieldType := UpperCase(FieldSpec.Token(2));
    finally
      FieldSpec.Free;
    end;
}

unit tiTokenLibrary;

{$I tiDefines.inc}

interface

type
  TTokenSeparator = (tsSingleSeparatorBetweenTokens,
                     tsMultipleSeparatorsBetweenTokens);

  TTokens = class(TObject)
  private
    FOriginalString: string;
    FCount: integer;
    FTokenString: string;  // Separator-stripped string with tokens separated by NULLs
  public
    constructor Create(const OriginalString: string; const Separators: string;
        const LeftMark: char; const RightMark: char; const Escape: char;
        const SeparatorBetweenTokens: TTokenSeparator); overload;
    destructor  Destroy; override;
    function    Token(const index: integer): string;
    function    TokenCount: integer;
  end;


implementation

const
  NULL = #$00;

type
    TFiniteStates = (fsSkipSeparatorsState,
                     fsAcceptSingleWordTokenState,
                     fsAcceptMultiWordTokenState,
                     fsEscapeState);

constructor TTokens.Create(const OriginalString: string; const Separators: string;
    const LeftMark: char; const RightMark: char; const Escape: char;
    const SeparatorBetweenTokens: TTokenSeparator);
var
  c: char;
  i: integer;
  IgnoreNextSeparator: boolean;
  state: TFiniteStates;
begin
  inherited Create;

  FOriginalString := OriginalString;
  FTokenString    := '';
  FCount          := 0;

  // The following "flag" is somewhat of a kludge to allow a single
  // separator to follow the closing RightMark of a Multiword Token
  // when SeparatorBetweenTokens = tsSingleSeparatorBetweenTokens
  IgnoreNextSeparator := False;

  // Initial state of finite state machine that recognizes tokens
  state := fsSkipSeparatorsState;

  for i := 1 to Length(FOriginalString) do
  begin
    c := FOriginalString[i];
    case state of
      fsSkipSeparatorsState:
        // Do nothing if character is separator
        if Pos(c, Separators) > 0 then
        begin
          // For cases like multiple comma-delimited fields, treat each
          // separator as end of a token, e.g, "x,,,y" would be 4 tokens
          if SeparatorBetweenTokens = tsSingleSeparatorBetweenTokens then
          begin
            if IgnoreNextSeparator then
              IgnoreNextSeparator := False
            else
            begin
              Inc(FCount);
              FTokenString := FTokenString + NULL;
            end;
          end;
        end
        else if c = LeftMark then
        begin
          state := fsAcceptMultiWordTokenState;
          Inc(FCount);
        end
        else
        begin
          state := fsAcceptSingleWordTokenState;
          Inc(FCount);
          FTokenString := FTokenString + c;
        end;

      fsAcceptSingleWordTokenState:
        if Pos(c, Separators) = 0 then
          FTokenString := FTokenString + c    // not a separator
        else
        begin                                 // separator
          FTokenString := FTokenString + NULL;
          state := fsSkipSeparatorsState;
        end;

      fsAcceptMultiWordTokenState:
        if c = RightMark then
        begin
          FTokenString := FTokenString + NULL;
          state := fsSkipSeparatorsState;
          IgnoreNextSeparator := True;
        end
        else if c = Escape then
          state := fsEscapeState
        else
          FTokenString := FTokenString + c;

      fsEscapeState:
        begin
          FTokenString := FTokenString + c;
          state := fsAcceptMultiWordTokenState;
        end
    end;  { case }
  end;  { for }
end;

destructor TTokens.Destroy;
begin
  inherited Destroy;
end;

function TTokens.Token(const index: integer): string;
var
  c: char;
  found: integer;
  i: integer;
begin
  Result  := '';
  found   := 1;
  i       := 1;

  while (i <= length(FTokenString)) and (found <= index) do
  begin
    c := FTokenString[i];

    if c = NULL then
      Inc(found)
    else if (found = index) then
      Result := Result + c;

    Inc(i);
  end;
end;

function TTokens.TokenCount: integer;
begin
  Result := FCount;
end;


end.

