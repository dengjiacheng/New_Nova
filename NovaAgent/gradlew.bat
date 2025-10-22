@echo off

setlocal

set DIRNAME=%~dp0
if "%DIRNAME%" == "" set DIRNAME=.
set APP_BASE_DIR=%DIRNAME%
set CLASSPATH=%APP_BASE_DIR%\gradle\wrapper\gradle-wrapper.jar
set APP_NAME=Gradle

if not defined JAVA_HOME (
    set JAVA_EXE=java.exe
) else (
    set JAVA_EXE=%JAVA_HOME%\bin\java.exe
)

if exist "%JAVA_EXE%" goto execute

echo ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH. 1>&2
goto end

:execute
set DEFAULT_JVM_OPTS=-Xmx64m -Xms64m
"%JAVA_EXE%" %DEFAULT_JVM_OPTS% -Dorg.gradle.appname=%APP_NAME% -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*

:end
endlocal
