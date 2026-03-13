@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
set PATH=C:\msys64\mingw64\bin;C:\Program Files\Go\bin;C:\Program Files\CMake\bin;%PATH%
cd /d C:\Users\admin\source\ollama
echo.
echo === Verifying tools ===
gcc --version | findstr gcc
go version
cmake --version | findstr version
echo.
echo === Building Ollama ===
powershell -ExecutionPolicy Bypass -File .\scripts\build_windows.ps1
