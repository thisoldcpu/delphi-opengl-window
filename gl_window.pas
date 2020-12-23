unit gl_window;

// =============================================================================
// OpenGL Window unit with timer, keyboard, and mouse support.
// =============================================================================

interface

uses
  Windows, Messages, SysUtils, dglOpenGL, timer;

const
  // Settings
  WND_TITLE = 'OpenGL Window Framework Demo';
  COLOR_BITS = 32;
  DEPTH_BITS = 24;
  STENCIL_BITS = 8;
  SCREEN_WIDTH = 1280;
  SCREEN_HEIGHT = 720;
  ENABLE_FULLSCREEN = False;
  ENABLE_VYSYNC = True;
  VIEWPORT_FOV = 45;
  VIEWPORT_DEPTH = 1000;

  fontname = 'Arial';
  fontsize = -12;

  WM_TOGGLEFULLSCREEN = WM_USER + 1;
  WM_TOGGLEVSYNC = WM_USER + 2;
  WM_SAVESCREENSHOT = WM_USER + 3;

type
  TVSyncMode = (vsmSync, vsmNoSync);

  TApplication = record
    hInstance: HINST;
    className: string;
  end;

  TglWindowInit = Record
    Application: ^TApplication;
    CaptionBarHeight: Integer;
    title: String;
    width: Integer;
    height: Integer;
    bitsPerPixel: Integer;
    FullScreen: Boolean;
    vsync: Boolean;
  end;

  TKeys = record
    keyDown: array [0 .. 255] of Boolean;
  end;

  PKeys = ^TKeys;

  TMouse = record
    X, Y, Z: Integer;
    Button: Integer;
  end;

  TglWindow = record
    Keys: PKeys;
    hWnd: hWnd;
    hDc: hDc;
    hRc: HGLRC;
    Mouse: TMouse;
    init: TglWindowInit;
    vsync: TVSyncMode;
    isVisible: Boolean;
    lastTickCount: DWORD;
  end;

  PglWindow = ^TglWindow;

procedure TerminateApplication(window: TglWindow);
procedure glResizeWnd(width, height: GLsizei);
procedure SetVSync(vsync: TVSyncMode);
function RegisterWindowClass(Application: TApplication): Boolean;
function glCreateWnd(var window: TglWindow): Boolean;
function DestroyWindowGL(var window: TglWindow): Boolean;
procedure CenterGLWindow(var window: TglWindow; X_Offset, Y_Offset: Integer);
procedure Screenshot;

var
  g_Looping: Boolean;
  g_FullScreen: Boolean;
  g_Timer: THiResTimer;
  UpdateFrame: Boolean;
  StartTime: int64;
  EndTime: int64;
  FrameTime: Double;
  fps: Integer;

  // GLWindow
  window: TglWindow;
  g_Window: PglWindow;
  g_Keys: PKeys;

  // Font
  font        : HFONT;
  fontTexture : GLUint;
  baseFontDL  : GLUint;                                                        // The font display lists base

  // Rotation
  xRotation: Single;
  yRotation: Single;

  // Viewer Position
  xPos: Single;
  yPos: Single;
  zPos: Single;

implementation

procedure TerminateApplication(window: TglWindow);
begin
  PostMessage(window.hWnd, WM_QUIT, 0, 0);
  g_Looping := False;
end;

// =============================================================================
// Message Pump
// =============================================================================
function WindowProc(hWnd: hWnd; uMsg: UINT; wParam: wParam; lParam: lParam)
  : LRESULT; stdcall;
var
  window: ^TglWindow;
  Creation: ^CREATESTRUCT;
  width: Integer;
  height: Integer;
  zDelta: Integer; // Mousewheel
begin
  Result := 0;
  window := Pointer(GetWindowLong(hWnd, GWL_USERDATA));

  case uMsg of
    WM_CREATE:
      begin
        Creation := Pointer(lParam);
        window := Pointer(Creation.lpCreateParams);
        SetWindowLong(hWnd, GWL_USERDATA, Integer(window));
        Result := 0;
      end;

    WM_CLOSE:
      begin
        TerminateApplication(window^);
        Result := 0
      end;

    WM_HELP:
      begin
        MessageBox(HWND_DESKTOP, 'ToDo: Display Help', 'Help',
          MB_OK or MB_ICONINFORMATION);
        Result := 0;
      end;

    WM_KEYDOWN:
      begin
        window^.Keys^.keyDown[wParam] := True;

        Result := 0;
      end;

    WM_KEYUP:
      begin
        window^.Keys^.keyDown[wParam] := False;

        Result := 0;
      end;

    // Mouse
    WM_LBUTTONDOWN:
      begin
        ReleaseCapture(); // need them here, because if mouse moves off
        SetCapture(window.hWnd); // window and returns, it needs to reset status
        window.Mouse.Button := 1;
        window.Mouse.X := LOWORD(lParam);
        window.Mouse.Y := HIWORD(lParam);
        Result := 0;
      end;

    WM_LBUTTONUP:
      begin
        ReleaseCapture(); // above
        window.Mouse.Button := 0;
        window.Mouse.X := 0;
        window.Mouse.Y := 0;
        Result := 0;
      end;

    WM_RBUTTONDOWN:
      begin
        ReleaseCapture(); // need them here, because if mouse moves off
        SetCapture(window.hWnd); // window and returns, it needs to reset status
        window.Mouse.Button := 2;
        window.Mouse.Z := HIWORD(lParam);
        Result := 0;
      end;

    WM_RBUTTONUP:
      begin
        ReleaseCapture(); // above
        window.Mouse.Button := 0;
        Result := 0;
      end;

    WM_MBUTTONDOWN:
      begin
        ReleaseCapture(); // need them here, because if mouse moves off
        SetCapture(window.hWnd); // window and returns, it needs to reset status
        window.Mouse.Button := 3;
        window.Mouse.X := LOWORD(lParam);
        window.Mouse.Y := HIWORD(lParam);
        Result := 0;
      end;

    WM_MBUTTONUP:
      begin
        ReleaseCapture(); // above
        window.Mouse.Button := 0;
        Result := 0;
      end;

    WM_MOUSEMOVE:
      begin
        if window.Mouse.Button = 1 then
        begin
          xRotation := xRotation + (HIWORD(lParam) - window.Mouse.Y) / 2;
          // moving up and down = rot around X-axis
          yRotation := yRotation + (LOWORD(lParam) - window.Mouse.X) / 2;
          window.Mouse.X := LOWORD(lParam);
          window.Mouse.Y := HIWORD(lParam);
        end;
        if window.Mouse.Button = 2 then
        begin
          zPos := zPos - (HIWORD(lParam) - window.Mouse.Z) / 10;
          window.Mouse.Z := HIWORD(lParam);
        end;
        if window.Mouse.Button = 3 then
        begin
          xPos := xPos + (LOWORD(lParam) - window.Mouse.X) / 24;
          yPos := yPos - (HIWORD(lParam) - window.Mouse.Y) / 24;
          window.Mouse.X := LOWORD(lParam);
          window.Mouse.Y := HIWORD(lParam);
        end;
        Result := 0;
      end;

    WM_MOUSEWHEEL:
      begin
        zDelta := SmallInt(HIWORD(wParam));

        if zDelta < 0 then
          zPos := zPos - 0.2;

        if zDelta > 0 then
          zPos := zPos + 0.2;
      end;

    WM_SAVESCREENSHOT:
      begin
        Screenshot;

        Result := 0;
      end;

    WM_TOGGLEFULLSCREEN:
      begin
        g_FullScreen := not g_FullScreen;
        PostMessage(hWnd, WM_QUIT, 0, 0);

        Result := 0;
      end;

    WM_TOGGLEVSYNC:
      begin
        if window.vsync = vsmSync then
          window.vsync := vsmNoSync
        else if window.vsync = vsmNoSync then
          window.vsync := vsmSync;
        g_Timer.TotalTime := 0;
        g_Timer.Frames := 0;
        SetVSync(window.vsync);

        Result := 0;
      end;

    WM_TIMER:
      begin
        if wParam = 1 then
        begin
          SetWindowText(hWnd,
            PChar(format
            ('%s [ %d fps | Average: %d fps | Frametime: %gms ] [x: %n y: %n z: %n][xR: %n yR: %n]',
            [WND_TITLE, g_Timer.GetFPS, g_Timer.GetAverageFPS, FrameTime, xPos,
            yPos, zPos, xRotation, yRotation])));

          Result := 0;
        end;
      end;

    // Window management
    WM_MOVE:
      begin
        // SetWindowPos

        Result := 0;
      end;

    WM_SIZE:
      begin
        width := LOWORD(lParam);
        height := HIWORD(lParam);
        glResizeWnd(width, height);
        // MessageBox(HWND_DESKTOP, PChar(format('WM_SIZE: %dx%d',[width, height])), 'Info', MB_OK or MB_ICONINFORMATION);

        case wParam of
          SIZE_MINIMIZED:
            begin
              glResizeWnd(width, height);
              window.isVisible := False;
              Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
            end;

          SIZE_MAXIMIZED:
            begin
              glResizeWnd(width, height);
              window.isVisible := True;

              Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
            end;

          SIZE_RESTORED:
            begin
              glResizeWnd(width, height);
              window.isVisible := True;

              Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
            end;
        end;
      end;

    WM_SYSCOMMAND:
      begin
        case wParam of
          SC_MAXIMIZE:
            begin
              Result := 0;
              Exit;
            end;

          SC_MINIMIZE:
            begin
              Result := 0;
              Exit;
            end;

          SC_MONITORPOWER:
            begin
              Result := 0;
              Exit;
            end;

          SC_SCREENSAVE:
            begin
              Result := 0;
              Exit;
            end;

          SC_CLOSE:
            begin
              TerminateApplication(g_Window^);

              Result := 0;
              Exit;
            end;
        end;
      end
  else
    begin
      Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
    end;
  end;
end;

// =============================================================================
// RegisterWindowClass
// =============================================================================
function RegisterWindowClass(Application: TApplication): Boolean;
var
  windowClass: WNDCLASSEX;
begin
  ZeroMemory(@windowClass, sizeof(windowClass));

  with windowClass do
  begin
    cbSize := sizeof(windowClass);
    style := CS_HREDRAW or CS_VREDRAW or CS_OWNDC;
    lpfnWndProc := @WindowProc;
    hInstance := Application.hInstance;
    hbrBackground := COLOR_APPWORKSPACE;
    hCursor := LoadCursor(0, IDC_ARROW);
    lpszClassName := PChar(Application.className);
  end;

  if RegisterClassEx(windowClass) = 0 then
  begin
    MessageBox(HWND_DESKTOP, 'Window: Error: RegisterClassEx failed', 'Error',
      MB_OK or MB_ICONEXCLAMATION);
    Result := False;
    Exit;
  end;
  Result := True;
end;

// =============================================================================
// Window Resize
// =============================================================================
procedure glResizeWnd(width, height: GLsizei);
begin
  if height = 0 then
    height := 1;
  if width = 0 then
    width := 1;

  glViewport(0, 0, width, height);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  gluPerspective(VIEWPORT_FOV, width / height, 1.0, VIEWPORT_DEPTH);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
end;

function ChangeScreenResolution(width, height, bitsPerPixel: Integer): Boolean;
var
  dmScreenSettings: DEVMODE;
begin
  try
    ZeroMemory(@dmScreenSettings, sizeof(dmScreenSettings));
    with dmScreenSettings do
    begin
      dmSize := sizeof(dmScreenSettings);
      dmPelsWidth := width;
      dmPelsHeight := height;
      dmBitsPerPel := bitsPerPixel;
      dmFields := DM_BITSPERPEL or DM_PELSWIDTH or DM_PELSHEIGHT;
    end;

    if ChangeDisplaySettings(dmScreenSettings, CDS_FULLSCREEN) <> DISP_CHANGE_SUCCESSFUL
    then
    begin
      MessageBox(HWND_DESKTOP, 'Unable to change display settings', 'Error',
        MB_OK or MB_ICONEXCLAMATION);
      Exit;
    end
  finally
    Result := True;
  end;
end;

// =============================================================================
// CenterGLWindow
// =============================================================================
procedure CenterGLWindow(var window: TglWindow; X_Offset, Y_Offset: Integer);
var
  Wnd_Rect, Appl_Rect: TRect;
  Client_XY, Appl_XY: TPoint;
  X, Y: Integer;
Begin
  GetWindowRect(window.hWnd, Wnd_Rect);

  if IsIconic(window.hWnd) then
    Exit;

  if IsZoomed(window.hWnd) then
  Begin
    X := GetSystemMetrics(SM_CXScreen) div 2;
    Y := GetSystemMetrics(SM_CYScreen) div 2;
    with Wnd_Rect do
      SetWindowPos(window.hWnd, 0, X - ((Right - Left) div 2),
        Y - ((Bottom - Top) div 2), Wnd_Rect.Right, Wnd_Rect.Bottom,
        swp_NoSize or swp_NoZOrder);
  End
  else
  Begin
    ClientToScreen(window.hWnd, Client_XY);
    ClientToScreen(window.hWnd, Appl_XY);
    GetWindowRect(window.hWnd, Appl_Rect);
    X := ((((Appl_Rect.Right - Appl_Rect.Left) div 2) -
      ((Wnd_Rect.Right - Wnd_Rect.Left) div 2)) div 2);
    Y := ((((Appl_Rect.Bottom - Appl_Rect.Top) div 2) -
      ((Wnd_Rect.Bottom - Wnd_Rect.Top) div 2)) div 2);
    SetWindowPos(window.hWnd, 0, X, Y, 0, 0, swp_NoSize or swp_NoZOrder);
  end;
end;

// =============================================================================
// glCreateWnd - Create a window and attach an OpenGL rendering context
// =============================================================================
function glCreateWnd(var window: TglWindow): Boolean;
var
  windowStyle: DWORD;
  windowExtendedStyle: DWORD;
  pfd: PIXELFORMATDESCRIPTOR;
  WindowRect: TRect;
  pixelFormat: GLuint;
begin
  if not InitOpenGL then
  begin
    Result := False;
    MessageBox(HWND_DESKTOP, 'InitOpenGL failed', 'Status',
      MB_OK or MB_ICONEXCLAMATION);
    PostQuitMessage(0);
    Exit;
  end;

  windowStyle := WS_OVERLAPPEDWINDOW;
  windowExtendedStyle := WS_EX_APPWINDOW;

  with pfd do
  begin
    nSize := sizeof(PIXELFORMATDESCRIPTOR);
    nVersion := 1;
    dwFlags := PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER;
    iPixelType := PFD_TYPE_RGBA;
    cColorBits := window.init.bitsPerPixel;
    cRedBits := 0;
    cRedShift := 0;
    cGreenBits := 0;
    cGreenShift := 0;
    cBlueBits := 0;
    cBlueShift := 0;
    cAlphaBits := 0;
    cAlphaShift := 0;
    cAccumBits := 0;
    cAccumRedBits := 0;
    cAccumGreenBits := 0;
    cAccumBlueBits := 0;
    cAccumAlphaBits := 0;
    cDepthBits := 24;
    cStencilBits := 8;
    cAuxBuffers := 0;
    iLayerType := PFD_MAIN_PLANE;
    bReserved := 0;
    dwLayerMask := 0;
    dwVisibleMask := 0;
    dwDamageMask := 0;
  end;

  WindowRect.Left := 0;
  WindowRect.Top := 0;
  WindowRect.Right := window.init.width;
  WindowRect.Bottom := window.init.height;

  // --------------------------------------------------------------------------
  // Fullscreen
  // --------------------------------------------------------------------------
  if window.init.FullScreen then
    if not ChangeScreenResolution(window.init.width, window.init.height,
      window.init.bitsPerPixel) then
    begin
      ShowCursor(False);
      MessageBox(HWND_DESKTOP,
        'Unable to use fullscreen. Running in windowed mode.', 'Error',
        MB_OK or MB_ICONEXCLAMATION);
      window.init.FullScreen := False;
    end
    else
    begin
      ShowCursor(False);
      windowStyle := WS_POPUP;
      windowExtendedStyle := windowExtendedStyle; // or WS_EX_TOPMOST;
    end
  else
    AdjustWindowRectEx(WindowRect, windowStyle, False, windowExtendedStyle);

  window.hWnd := CreateWindowEx(windowExtendedStyle,
    PChar(window.init.Application^.className), PChar(window.init.title),
    windowStyle, 0, 0, WindowRect.Right - WindowRect.Left,
    WindowRect.Bottom - WindowRect.Top, HWND_DESKTOP, 0,
    window.init.Application^.hInstance, @window); // Do WM_CREATE

  if window.hWnd = 0 then
  begin
    MessageBox(HWND_DESKTOP, 'CreateWindowEx failed.', 'Error',
      MB_OK or MB_ICONEXCLAMATION);
    Result := False;
    Exit;
  end;

  window.hDc := GetDC(window.hWnd);
  if window.hDc = 0 then
  begin
    MessageBox(HWND_DESKTOP, 'Window: GetDC failed', 'Error',
      MB_OK or MB_ICONEXCLAMATION);
    DestroyWindow(window.hWnd);
    window.hWnd := 0;
    Result := False;
    Exit;
  end;

  pixelFormat := ChoosePixelFormat(window.hDc, @pfd);
  if pixelFormat = 0 then
  begin
    MessageBox(HWND_DESKTOP, 'Window: ChoosePixelFormat failed', 'Error',
      MB_OK or MB_ICONEXCLAMATION);

    ReleaseDC(window.hWnd, window.hDc);
    window.hDc := 0;
    DestroyWindow(window.hWnd);
    window.hWnd := 0;
    Result := False;
    Exit;
  end;

  if not SetPixelFormat(window.hDc, pixelFormat, @pfd) then
  begin
    ReleaseDC(window.hWnd, window.hDc);
    window.hDc := 0;
    DestroyWindow(window.hWnd);
    window.hWnd := 0;
    Result := False;
    Exit;
  end;

  window.hRc := CreateRenderingContext(window.hDc, [opDoubleBuffered],
    COLOR_BITS, DEPTH_BITS, STENCIL_BITS, 0, 0, 0);
  if window.hRc = 0 then
  begin
    MessageBox(HWND_DESKTOP, 'Window: CreateRenderingContext failed', 'Error',
      MB_OK or MB_ICONEXCLAMATION);
    ReleaseDC(window.hWnd, window.hDc);
    window.hDc := 0;
    DestroyWindow(window.hWnd);
    window.hWnd := 0;
    Result := False;
    Exit;
  end;

  if window.hDc > 0 then
    ActivateRenderingContext(window.hDc, window.hRc);

  if window.init.vsync then
    window.vsync := vsmSync
  else
    window.vsync := vsmNoSync;
  SetVSync(window.vsync);

  ShowWindow(window.hWnd, SW_NORMAL);
  window.isVisible := True;
  glResizeWnd(window.init.width, window.init.height);
  ZeroMemory(window.Keys, sizeof(TKeys));

  // Hide minimize and maximize buttons
  // l := GetWindowLong(window.hWnd, GWL_STYLE);
  // l := l and not(WS_MINIMIZEBOX);
  // l := l and not(WS_MAXIMIZEBOX);
  // l := SetWindowLong(window.hWnd, GWL_STYLE, l);

  window.lastTickCount := GetTickCount;

  Result := True;
end;

// =============================================================================
// Destroy the Window
// =============================================================================
function DestroyWindowGL(var window: TglWindow): Boolean;
begin
  if window.hWnd <> 0 then
  begin
    if window.hDc <> 0 then
    begin
      wglMakeCurrent(window.hDc, 0);
      if window.hRc <> 0 then
      begin
        DeactivateRenderingContext;
        wglDeleteContext(window.hRc);
        window.hRc := 0;
      end;
      ReleaseDC(window.hWnd, window.hDc);
      window.hDc := 0;
    end;
    DestroyWindow(window.hWnd);
    window.hWnd := 0;
  end;

  if window.init.FullScreen then
    ChangeDisplaySettings(DEVMODE(nil^), 0);

  ShowCursor(True);
  Result := True;
end;

// =============================================================================
// VSYNC
// =============================================================================
procedure SetVSync(vsync: TVSyncMode);
var
  i: Integer;
begin
  if WGL_EXT_swap_control then
  begin
    i := wglGetSwapIntervalEXT;
    case vsync of
      vsmSync:
        if i <> 1 then
          wglSwapIntervalEXT(1);
      vsmNoSync:
        if i <> 0 then
          wglSwapIntervalEXT(0);
    else
      Assert(False);
    end;
  end;
end;

procedure Screenshot;
begin
  MessageBox(HWND_DESKTOP, 'ToDo: Save screenshot', 'Window',
    MB_OK or MB_ICONINFORMATION);
end;

end.
