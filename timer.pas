unit timer;

// =============================================================================
//
//
//
// =============================================================================

interface

uses
  Windows;

const
  FPS_TIMER = 1;
  FPS_INTERVAL = 1000;

type
  THiResTimer = class(TObject)
  private
    Frequency: Int64;
    FoldTime: Int64; // last system time
  public
    TotalTime: Double; // time since app started
    FrameTime: Double; // time elapsed since last frame
    Frames: Cardinal; // total number of frames
    constructor Create;
    function Refresh: Cardinal;
    function GetFPS: Integer;
    function GetAverageFPS: Integer;
    function GetTime: Int64;
    function DiffTime(start_time, end_time: Int64): Double;
  end;

implementation

constructor THiResTimer.Create;
begin
  Frames := 0;
  QueryPerformanceFrequency(Frequency); // get high-resolution Frequency
  QueryPerformanceCounter(FoldTime);
end;

function THiResTimer.Refresh: Cardinal;
var
  tmp: Int64;
  t2: Double;
begin
  QueryPerformanceCounter(tmp);
  t2 := tmp - FoldTime;
  FrameTime := t2 / Frequency;
  TotalTime := TotalTime + FrameTime;
  FoldTime := tmp;
  inc(Frames);
  result := Frames;
end;

function THiResTimer.GetFPS: Integer;
begin
  result := Round(1 / FrameTime);
end;

function THiResTimer.GetAverageFPS: Integer;
begin
  result := 0;

  if TotalTime > 0 then
    result := Round(Frames / TotalTime);
end;

function THiResTimer.GetTime: Int64;
var
  tmp: Int64;
begin
  QueryPerformanceCounter(tmp);
  result := tmp;
end;

function THiResTimer.DiffTime(start_time, end_time: Int64): Double;
begin
  result := (end_time - start_time) / Frequency;
end;

end.
