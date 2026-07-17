@echo off
set JAVA_HOME=D:\src\jdk-17
cd android
call gradlew.bat :app:bundleRelease
cd ..
echo.
echo Compilacion terminada. El archivo AAB esta en build\app\outputs\bundle\release\app-release.aab
pause
