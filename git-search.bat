@ECHO off
SETLOCAL EnableDelayedExpansion
REM ====================================================================================================
REM This script checks for updates in all git repositories, starting in the current directory.
REM ====================================================================================================

SET temp_out=%~dp0
SET temp_out=%temp_out%temp.txt

SET no_repo="fatal: not a git repository (or any of the parent directories): .git"
SET no_repo=%no_repo:"=%
SET no_commits[0]="On branch master"
SET no_commits[1]="Your branch is up-to-date with 'origin/master'."
SET no_commits[2]="nothing to commit, working directory clean"

SET /A status=0
SET /A count=-1
SET repos[0]=""
SET has_commits[0]=""
SET has_remote_changes[0]=""

REM Parse arguments
SET /A search_recursive=0
SET /A show_progress=0
SET /A path_taken=0
FOR %%i in (%*) DO (
	REM Copy argument to variable and strip quotes
	SET arg=%%i
	SET arg=!arg:"=!
	
	IF "!arg!"=="-r" (
	REM Recursive flag
		ECHO Recursive mode enabled
		SET /A search_recursive=1
	) ELSE IF "!arg!"=="-p" (
	REM Progress flag
		ECHO Progress will be shown
		SET /A show_progress=1
	) ELSE IF EXIST "!arg!\" (
	REM If a path is given, start in that directory
		IF !path_taken!==1 (
			ECHO(
			ECHO [91mFatal: git-search does not accept more than one path as arguments[0m
			EXIT /B 0
		) ELSE (
			ECHO Starting search in "!arg!"
			SET /A path_taken=1
			CD "!arg!"
		)
	) ELSE (
	REM Invalid argument
		ECHO [91mWarning: unused argument "!arg!"[0m
	)
)
IF %path_taken%==0 (
	ECHO Starting search in "%CD%"
)
IF %show_progress%==1 (
	ECHO(
)
REM Iterate through directories and check git status and git fetch
IF %show_progress%==1 ( ECHO Progress: )
FOR /D %%i in (./*) DO (
	IF %show_progress%==1 ( ECHO     Searching "%%i" )
	CALL :CheckDir "%%i"
)

REM Print report
ECHO(
IF %count%==-1 (
	ECHO No git repositories found.
) ELSE (
	SET /A count+=1
	ECHO !count! git repos found:
	SET /A count-=1
	FOR /L %%i in (0, 1, %count%) DO (
		ECHO     !repos[%%i]!
		IF !has_commits[%%i]!==1 (
			ECHO         [96mUnsaved changes[0m
		)
		IF !has_remote_changes[%%i]!==1 (
			ECHO		[95mNew changes in the remote[0m
		)
	)
)

REM Clear temp output file
COPY NUL "%temp_out%" > NUL

EXIT /B %ERRORLEVEL%




REM Functions
REM ====================================================================================================
:CheckDir
	CD "%~dpnx1"
	REM Get output from git status into output
	CALL :RunGitStatus status
	IF %status%==0 (
	REM Not a git repo: iterate through subdirectories if recursive option is selected
		IF %search_recursive%==1 (
			FOR /D %%i in (./*) DO (
				CALL :CheckDir "%%i"
			)
		)
	) ELSE (
	REM Valid git repo
		SET /A count+=1
		SET repos[!count!]="%~dpnx1"
		IF %status%==2 (
			SET /A has_commits[!count!]=1
		) ELSE (
			SET /A has_commits[!count!]=0
		)
		
		REM Check for changes in the remote
		CALL :RunGitFetch status
		IF !status!==0 (
			SET /A has_remote_changes[!count!]=0
		) ELSE (
			SET /A has_remote_changes[!count!]=1
		)
	)
	CD ..
EXIT /B 0

REM Runs git status and returns an integer indicating the result:
REM		0: Not a git repo
REM		1: No changes or untracked files
REM 	2: Changes to be committed or untracked files
:RunGitStatus
	GIT status > "%temp_out%" 2>&1
	SET /A index=-1
	FOR /F "eol=; tokens=* usebackq" %%i in ("%temp_out%") DO (
		SET /A index+=1
		SET output[!index!]="%%i"
	)
	REM Process output
	IF %output[0]%=="%no_repo%" (
	REM Not a git repo
		SET /A %~1=0
	) ELSE IF !index!==2 (
	REM Possibly no commits
		SET /A %~1=1
	) ELSE (
	REM Unsaved commits
		SET /A %~1=2
	)
EXIT /B 0

REM Runs git fetch and returns an integer indicating the result:
REM		0: Nothing to fetch
REM		1: new changes in the remote
:RunGitFetch
	GIT fetch > "%temp_out%" 2>&1
	SET /A index=-1
	FOR /F "eol=; tokens=* usebackq" %%i in ("%temp_out%") DO (
		SET /A index+=1
		SET output[!index!]="%%i"
	)
	REM Process output
	IF !index!==-1 (
	REM No message: nothing to fetch
		SET /A %~1=0
	) ELSE (
	REM New changes in the remote
		SET /A %~1=1
	)
EXIT /B 0