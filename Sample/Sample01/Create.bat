@echo off
REM /*! -------------------------------------------------
REM * @file Create.bat
REM * @brief Configuration.json情報をもとに開発環境を構築する
REM * @author nishihama takashi
REM * 
REM */ --------------------------------------------------

powershell -ExecutionPolicy RemoteSigned ..\..\Make\CreateBuildEnviroment -rootPath %CD%/../../ -ProjectPath %CD%/ -ConfigPath %CD%/Configuration.json
pause