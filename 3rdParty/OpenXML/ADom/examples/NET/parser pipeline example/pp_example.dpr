program pp_example;

uses
  Forms,
  main in 'main.pas' {Form1};

[STAThread]
begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
