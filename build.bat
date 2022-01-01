@echo off
ECHO Building Prometheus ...
RMDIR /s /q build
MKDIR build
glue.exe ./srlua.exe prometheus-main.lua build/prometheus.exe
robocopy ./src ./build/lua /E>nul
ECHO Done!