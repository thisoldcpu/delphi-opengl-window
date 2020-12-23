{ ==============================================================================

  Delphi OpenGL Window Demo

  ==============================================================================

  Copyright (C) Jason McClain (ThisOldCPU)
  All Rights Reserved

  https://github.com/thisoldcpu/delphi-opengl-window

  In memory of Jan Horn (sulaco.co.za)

  Additional thanks:
  Sascha Willems (dglOpenGL)

  ==============================================================================

  You may retrieve the latest version of this file at the Delphi OpenGL
  Community home page, located at http://www.delphigl.com/

  This Source Code Form is subject to the terms of the Mozilla Public License,
  v. 2.0. If a copy of the MPL was not distributed with this file,
  You can obtain one at http://mozilla.org/MPL/2.0/.

  Software distributed under the License is distributed on an
  "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
  implied. See the License for the specific language governing
  rights and limitations under the License.

  ============================================================================ }

program dglwnd;

{$WARN SYMBOL_PLATFORM OFF}

uses
  Windows,
  Messages,
  SysUtils,
  dglOpenGL,
  gl_window in 'gl_window.pas',
  timer in 'timer.pas';

const
  // Demo data
  triangle: array [0 .. 8] of single = (-1.0, -1.0, 0.0, 1.0, -1.0, 0.0, 0.0, 1.0, 0.0);
  colors: array [0 .. 8] of single = (1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0);

var
  // Demo vars
  VertexArrayID: Cardinal;
  triangleVBO: Cardinal;

{$R *.res}

procedure Print(x, y: GLUint; ptext: ansistring);
var
  Wnd_Rect: TRect;
begin
  if ptext = '' then
    Exit;

  glPushAttrib(GL_DEPTH_TEST); // Save the current Depth test settings (Used for blending )
  glDisable(GL_DEPTH_TEST); // Turn off depth testing (otherwise we get no FPS)
  glDisable(GL_TEXTURE_2D); // Turn off textures, don't want our text textured
  glMatrixMode(GL_PROJECTION); // Switch to the projection matrix
  glPushMatrix(); // Save current projection matrix
  glLoadIdentity();

  GetWindowRect(window.hWnd, Wnd_Rect);
  glOrtho(0, Wnd_Rect.right, 0, Wnd_Rect.bottom, -1, 1); // Change the projection matrix using an orthgraphic projection

  glMatrixMode(GL_MODELVIEW); // Return to the modelview matrix
  glPushMatrix(); // Save the current modelview matrix
  glLoadIdentity();
  glColor3f(1.0, 1.0, 1.0); // Text color

  glRasterPos2i(x, y); // Position the Text
  glPushAttrib(GL_LIST_BIT); // Save the current base list
  glListBase(baseFontDL); // Set the base list to our character list
  glCallLists(length(ptext), GL_UNSIGNED_BYTE, Pointer(ptext)); // Display the text
  glPopAttrib(); // Restore the old base list

  glMatrixMode(GL_PROJECTION); // Switch to projection matrix
  glPopMatrix(); // Restore the old projection matrix
  glMatrixMode(GL_MODELVIEW); // Return to modelview matrix
  glPopMatrix(); // Restore old modelview matrix
  glEnable(GL_TEXTURE_2D); // Turn on textures, don't want our text textured
  glPopAttrib(); // Restore depth testing
end;

procedure ShowStats;
begin
  Print(10, 10, AnsiString(format('%d fps', [g_Timer.GetFPS])));
  Print(10, 25, AnsiString(format('Average: %d fps | Frame: %gms',[g_Timer.GetAverageFPS, FrameTime])));
  Print(10, 40, AnsiString(format('Rotation - x: %n y: %n', [xRotation, yRotation])));
  Print(10, 55, AnsiString(format('Position - x: %n y: %n z: %n', [xPos, yPos, zPos])));
end;

procedure DrawFrame(hDc: hDc);
begin
  startTime := g_Timer.GetTime;
  UpdateFrame := False;
  g_Timer.Refresh;

  glClear(GL_COLOR_BUFFER_BIT);
  glLoadIdentity();

  glTranslatef(xPos, yPos, zPos); // move scene to screen center

  if window.Mouse.Button = -1 then
  begin
    glRotatef(90 * sin(g_Timer.TotalTime), 0, 1, 0);
  end
  else
  begin
    glRotatef(xRotation, 1, 0, 0); // rotate to mouse coords
    glRotatef(yRotation, 0, 1, 0); // rotate to mouse coords
  end;

  glEnableVertexAttribArray(0);
  glBindBuffer(GL_ARRAY_BUFFER, triangleVBO);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, nil);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  glDisableVertexAttribArray(0);

  ShowStats;

  SwapBuffers(hDc);
  endTime := g_Timer.GetTime;
  FrameTime := g_Timer.DiffTime(startTime, endTime);
  UpdateFrame := True;
end;

// =============================================================================
// Initialize demo
// =============================================================================
function Initialize(window: PglWindow; Key: PKeys): Boolean;
begin
  g_Window := window;
  g_Keys := Key;

  glViewport(0, 0, window.Init.Width, window.Init.Height);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  gluPerspective(VIEWPORT_FOV, window.Init.Width / window.Init.Height, 1.0, VIEWPORT_DEPTH);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;
  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);

  glClearColor(0.0, 0.5, 0.8, 0.0);

  glGenVertexArrays(1, @VertexArrayID);
  glBindVertexArray(VertexArrayID);
  glGenBuffers(1, @triangleVBO);
  glBindBuffer(GL_ARRAY_BUFFER, triangleVBO);
  glBufferData(GL_ARRAY_BUFFER, SizeOf(triangle), @triangle, GL_STATIC_DRAW);

  UpdateFrame := True;

  // Default view
  xRotation := 0.0;
  yRotation := 0.0;
  xPos := 0.0;
  yPos := 0.0;
  zPos := -5.0;
  window.Mouse.Button := -1;

  // Font
  // font: = GetStockObject(SYSTEM_FONT); // Get system font

  baseFontDL := glGenLists(256); // Generate enough display lists to hold
  font := CreateFont(fontsize, // height of font
    0, // average character width
    0, // angle of escapement
    0, // base-line orientation angle
    FW_NORMAL, // font weight
    0, // italic
    0, // underline
    0, // strikeout
    ANSI_CHARSET, // character set
    OUT_TT_PRECIS, // output precision
    CLIP_DEFAULT_PRECIS, // clipping precision
    NONANTIALIASED_QUALITY, // output quality
    FF_DONTCARE or DEFAULT_PITCH, // pitch and family
    pchar(fontname)); // font

  SelectObject(window.hDc, font); // Sets the new font as the current font in the device context
  wglUseFontBitmaps(window.hDc, 0, 255, baseFontDL); // Creates a set display lists containing the bitmap fonts

  g_Timer := THiResTimer.Create;
  SetTimer(window.hWnd, FPS_TIMER, FPS_INTERVAL, nil);

  Result := True;
end;

// =============================================================================
// Deinitialize
// =============================================================================
procedure Deinitialize;
begin
  glDeleteLists(baseFontDL, 96); // Delete the font display lists, returning used memory
end;

// =============================================================================
// Processes Keystrokes
// =============================================================================
procedure ProcessKeys;
begin
  if g_Keys.keyDown[Ord(VK_ESCAPE)] then
  begin
    PostMessage(window.hWnd, WM_QUIT, 0, 0);

    g_Keys.keyDown[Ord(VK_ESCAPE)] := False;
  end;

  if g_Keys.keyDown[VK_OEM_3] then
  begin
    // Console.Visible := not Console.Visible;

    g_Keys.keyDown[VK_OEM_3] := False;
  end
  else
  begin
    // if g_Keys.keyDown[VK_UP] or g_Keys.keyDown[VK_NUMPAD8] then Camera.MoveCamera(speed);
    // if g_Keys.keyDown[VK_DOWN] or g_Keys.keyDown[VK_NUMPAD2] then Camera.MoveCamera(-speed);
    // if g_Keys.keyDown[VK_LEFT] or g_Keys.keyDown[VK_NUMPAD4] then Camera.StrafeCamera(speed);
    // if g_Keys.keyDown[VK_RIGHT] or g_Keys.keyDown[VK_NUMPAD6] then Camera.StrafeCamera(-speed);
    // if g_Keys.keyDown[VK_NUMPAD7] or g_Keys.keyDown[VK_HOME] then Camera.RotateView(0, -0.025, 0);
    // if g_Keys.keyDown[VK_NUMPAD9] or g_Keys.keyDown[VK_PRIOR] then Camera.RotateView(0, 0.025, 0);
  end;

  if g_Keys.keyDown[Ord(VK_TAB)] then
  begin
    // showMenu := not showMenu;

    g_Keys.keyDown[Ord(VK_TAB)] := False;
  end;

  if g_Keys.keyDown[Ord(VK_F9)] then
  begin
    PostMessage(g_Window^.hWnd, WM_SAVESCREENSHOT, 0, 0);

    g_Keys.keyDown[Ord(VK_F9)] := False;
  end;

  if g_Keys.keyDown[VK_F11] then
  begin
    PostMessage(g_Window^.hWnd, WM_TOGGLEFULLSCREEN, 0, 0);

    g_Keys.keyDown[VK_F11] := False;
  end;

  if g_Keys.keyDown[VK_F12] then
  begin
    PostMessage(g_Window^.hWnd, WM_TOGGLEVSYNC, 0, 0);

    g_Keys.keyDown[VK_F12] := False;
  end;

  if g_Keys.keyDown[VK_F6] then
  begin
    xRotation := 0.0;
    yRotation := 0.0;
    xPos := 0.0;
    yPos := 0.0;
    zPos := -5.0;
    window.Mouse.Button := -1;

    g_Keys.keyDown[VK_F6] := False;
  end;
end;

// =============================================================================
// WinMain
// =============================================================================
function WinMain(hInstance: HINST; hPrevInstance: HINST; lpCmdLine: pchar; nCmdShow: integer): integer; stdcall;
var
  Msg: TMsg;
  App: TApplication;
  Key: TKeys;
  MessagePumpActive: Boolean;
begin
  App.ClassName := 'OpenGL';
  App.hInstance := hInstance;

  ZeroMemory(@window, SizeOf(window));
  with window do
  begin
    keys := @Key;
    Init.application := @App;
    Init.CaptionBarHeight := GetSystemMetrics(SM_CYCAPTION);
    Init.Title := WND_TITLE;
    Init.Width := SCREEN_WIDTH;
    Init.Height := SCREEN_HEIGHT;
    Init.bitsPerPixel := COLOR_BITS;
    Init.FullScreen := ENABLE_FULLSCREEN;
    Init.vsync := ENABLE_VYSYNC;
  end;

  ZeroMemory(@Key, SizeOf(Key));

  // if MessageBox(HWND_DESKTOP, 'Would You Like To Run In FullScreen Mode?',
  // 'Start FullScreen', MB_YESNO or MB_ICONQUESTION) = IDNO then
  // Window.Init.FullScreen := False;

  // Register a class for our window
  if not RegisterWindowClass(App) then
  begin
    MessageBox(HWND_DESKTOP, 'Window: Error: Unable to register window class', 'Error', MB_OK or MB_ICONEXCLAMATION);
    Result := -1;
    Exit;
  end;

  g_Looping := True;
  g_FullScreen := window.Init.FullScreen;

  while g_Looping do
  begin
    window.Init.FullScreen := g_FullScreen;

    if glCreateWnd(window) then
    begin
      if not Initialize(@window, @Key) then
        TerminateApplication(window)
      else
      begin
        MessagePumpActive := True;

        while MessagePumpActive do
          if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then
            if Msg.Message <> WM_QUIT then
            begin
              TranslateMessage(Msg);
              DispatchMessage(Msg);
            end
            else
              MessagePumpActive := False
          else if not window.isVisible then
            WaitMessage
          else
          begin
            window.lastTickCount := g_Timer.GetTime;

            ProcessKeys;

            // ====================================================
            // Input->readInput();
            // isRunning = GameLogic->doLogic();
            // Camera->update();
            // World->update();
            // GUI->update();
            // AI->update();
            // Audio->play();
            // Render->draw();
            // ====================================================

            if UpdateFrame then
            begin
              // Camera.MoveCameraByMouse;
              // newpos := Camera.Position;

              DrawFrame(window.hDc);
            end;
          end;
      end;
      Deinitialize;
      DestroyWindowGL(window);
    end
    else
    begin
      MessageBox(HWND_DESKTOP, 'Error Unable to create OpenGL Window.', 'Error', MB_OK or MB_ICONEXCLAMATION);
      g_Looping := False;
    end;
  end;

  UnregisterClass(pchar(App.ClassName), App.hInstance);

  Result := Msg.wParam;
end;

// =============================================================================
// Execution
// =============================================================================
begin
  WinMain(hInstance, 0, CmdLine, CmdShow);

end.
