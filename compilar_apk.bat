@echo off
set JAVA_HOME=D:\src\jdk-17
cd android
call gradlew.bat :app:assembleRelease
cd ..
echo.
echo Compilacion terminada. El archivo APK esta en build\app\outputs\flutter-apk\app-release.apk
pause
