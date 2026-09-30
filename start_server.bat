@echo off
chcp 65001 >nul
title Minecraft Server

cd /d C:\mine_server
"C:\Users\super\.jdks\openjdk-25.0.2\bin\java.exe" -Xmx4G -Xms2G -jar server.jar nogui
pause