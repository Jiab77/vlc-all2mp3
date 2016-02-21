@echo off
REM Made by Jon for Himself - 2014
REM Last Modification: 17.02.2016 - 14:58
REM Last Changes:
REM - Updated counter code
REM - Changed params delimiter in for loops
REM - Removed quotes on dragDrop variable
REM - Fixed output directory
REM - Added metadata 'album'
REM - Renamed 'extFile' var to 'extension'

REM Header
for %%a in (cls echo) do %%a.
setlocal EnableDelayedExpansion
title %~nx0 - VLC / Lame Transcode Script

REM Config
set dragDrop=%*
set retryCount=0
REM Change Here
set extension=*.*
set replayGainEnabled=true
set pathVLC=C:\Program Files\VideoLAN\VLC
set pathLAME=D:\Documents\Jon\Downloads\lame3.99.5-64
set "sourceFolder=%~dp1" & set sourceFolder=!sourceFolder:~0,-1!
set outFolder=!sourceFolder!\transcoded-tag
set logFolder=%outFolder%\log
REM End Change

REM Action
call :countItems
goto quit

:countItems
REM Counter Settings
set id=0
set count=0
set countTotal=0

REM Temporary list creation
set "tempList=%temp%\tempList_%random%.txt"
if exist "!tempList!" type NUL>!tempList!
if not defined dragDrop (
	REM Classic mode
	for /f "delims=" %%i in ('dir /b/s/a-d "!sourceFolder!\%extension%"') do (
		REM Initializing counter
		set /a countTotal=!countTotal!+1

		echo [I] is %%i on [!countTotal!]
		echo %%i>>!tempList!
	)
) else (
	REM Drag'n'Drop mode
	for %%x in (%dragDrop%) do (
		if "%%~ax"=="d--------" (
			echo Scanning directory [%%x]... & echo.
			for /f "delims=" %%d in ('dir /b/s/a-d "%%x\%extension%"') do (
				REM Initializing counter
				set /a countTotal=!countTotal!+1

				echo [D] is %%d on [!countTotal!]
				echo %%d>>!tempList!
			)
		) else (
			REM Initializing counter
			set /a countTotal=!countTotal!+1

			echo [X] is %%x on [!countTotal!]
			echo %%~x>>!tempList!
		)
	)
)

REM List file created, processing
if exist "!tempList!" (
	echo. & pause
	call :process
) else (
	goto quit
)
goto :EOF

:process
setlocal
echo.
for /f "delims=" %%f in (!tempList!) do (
	REM Initializing counters
	set /a id=!id!+1
	set /a count=!count!+1

	REM Processing
	if !count! LEQ !countTotal! (
		REM DON'T PROCESSING IF THERE IS ONLY THE BATCH SCRIPT IT SELF
		if /i not "%%~xf"==".bat" (
			REM BYPASSING VLC FUNCTION IF CONTENT IS IN WAV FORMAT ALREADY
			if /i "%%~xf"==".wav" (
				call :_processLAME !id! !countTotal! "%%f" "%outFolder%\mp3"
			) else (
				call :_startProcess !id! !countTotal! "%%f" "%outFolder%\wav"
			)
		)
	)

	if !count! EQU !countTotal! (
		echo. & echo ^	  ^********************************************************
		echo ^		^Processed finished, Transcoded files [!count! ^/ !countTotal!]
		echo ^	  ^******************************************************** & echo.
		goto quit
	)
)
endlocal
goto :EOF

:_startProcess
setlocal
set fileId=%1
set fileTotal=%2
set "filePath=%~dp3" & set filePath=!filePath:~0,-1!
set fileName=%~n3
set fileFullName=%~nx3
set destFolder=%~4
set sleepTime=2
REM PATCHING PING 1s LATENCY
set /a sleepTime=!sleepTime!+1

REM FIX VLC BUG WITH ',' IN OUT FILENAME
set fixedFileName=!fileName:, = + !
set fixedFileFullName=!fileFullName:, = + !

REM STARTING PROCESS
(call :_processVLC !id! !countTotal! "!filePath!\!fileFullName!" "%outFolder%\wav") && (
	REM if exist "!destFolder!\!fileName!.wav" (
	if exist "!destFolder!\!fixedFileName!.wav" (
		REM Size detection loop
		REM for /f "usebackq delims=" %%S in ('!destFolder!\!fileName!.wav') do set size=%%~zS
		for /f "usebackq delims=" %%S in ('!destFolder!\!fixedFileName!.wav') do set size=%%~zS
		REM End of loop
		if !size! LEQ 0 (
			REM COUNTDOWN BEFORE RESTART THE PROCESS
			set /a retryCount=%retryCount%+1
			for /l %%s in (!sleepTime!,-1,1) do (
				echo VLC PROCESS ERROR - SIZE - [File: !fileFullName! ^| Size: !size! ^| Retry: !retryCount!], RESTARTING %%s SECONDS... & ping 172.0.0.1 -n 1 -w 1000 >NUL
			)
			call :_startProcess !id! !countTotal! "!filePath!\!fileFullName!" "%outFolder%\wav"
		) else if !size! NEQ 0 (
			REM call :_processLAME !fileId! !fileTotal! "%outFolder%\wav\!fileName!.wav" "%outFolder%\mp3"
			call :_processLAME !fileId! !fileTotal! "%outFolder%\wav\!fixedFileName!.wav" "%outFolder%\mp3"
		)
	) else (
		REM COUNTDOWN BEFORE RESTART THE PROCESS
		set /a retryCount=%retryCount%+1
		for /l %%s in (!sleepTime!,-1,1) do (
			echo VLC PROCESS ERROR - CREATION - [File: !outFileFullName! ^| Retry: !retryCount!], RESTARTING %%s SECONDS... & ping 172.0.0.1 -n 1 -w 1000 >NUL
		)
		REM call :_startProcess !id! !countTotal! "!filePath!\!fileFullName!" "%outFolder%\wav"
		call :_startProcess !id! !countTotal! "!filePath!\!fixedFileFullName!" "%outFolder%\wav"
	)
) || (
	echo. & echo SERIOUS VLC PROCESS ERROR ^^!^^! [ErrorCode: !ERRORLEVEL!], EXITING...
	goto quit
)
endlocal
goto :EOF

:_processVLC
setlocal
REM for %%a in (*.mp4) do (
	REM title Processing file [%%~nxa] TO WAV...
	REM call "%pathVLC%\VLC\vlc.exe" -I dummy -vvv "%%a" --no-sout-video --sout=#transcode{acodec=s16l,channels=2,samplerate=48000}:standard{access=file,mux=wav,dst="%outpath%\wav\%%~na.wav"} vlc://quit
REM )
set fileId=%1
set fileTotal=%2
set "filePath=%~dp3" & set filePath=!filePath:~0,-1!
set fileName=%~n3
set fileFullName=%~nx3
set destFolder=%~4

REM STATUS
set "processTitle=Processing file [!fileId!/!fileTotal!] ^| [!fileFullName!] To WAV..." & title !processTitle!
echo. & echo !processTitle! & echo.

REM CREATING LOG DIR IF NOT EXIST ALREADY
if not exist "%logFolder%" mkdir "%logFolder%"

REM CREATING DESTINATION DIR IF NOT EXIST ALREADY
if not exist "!destFolder!" mkdir "!destFolder!"

REM FIX VLC BUG WITH ',' IN OUT FILENAME
set fileName=!fileName:, = + !

REM LOADING PROCESS
call "%pathVLC%\vlc.exe" -I dummy --verbose=2 --file-logging --logfile="%logFolder%\vlc-log_!fileName!.txt" "!filePath!\!fileFullName!" --no-sout-video --sout=#transcode{acodec=s16l,channels=2,samplerate=48000}:standard{access=file,mux=wav,dst="!destFolder!\!fileName!.wav"} vlc://quit
endlocal
goto :EOF

:_processLAME
setlocal
REM for %%a in (*.wav) do (
	REM title Processing file [%%~nxa] TO MP3...
	REM call "%pathLAME%\lame.exe" -m j -V 0 -q 0 --lowpass 24 --vbr-new -b 32 "%%a" "%outpath%\mp3\%%~na.mp3"
REM )
set fileId=%1
set fileTotal=%2
set "filePath=%~dp3" & set filePath=!filePath:~0,-1!
set fileName=%~n3
set fileExtension=%~x3
set fileFullName=%~nx3
set destFolder=%~4

REM STATUS
if /i "%replayGainEnabled%"=="true" (
	set "processTitle=Processing file [!fileId!/!fileTotal!] ^| [!fileName!.wav] To MP3 [RG]..." & title !processTitle!
) else (
	set "processTitle=Processing file [!fileId!/!fileTotal!] ^| [!fileName!.wav] To MP3..." & title !processTitle!
)
echo. & echo !processTitle! & echo.

REM CREATING DESTINATION DIR IF NOT EXIST ALREADY
if not exist "!destFolder!" mkdir "!destFolder!"

REM MP3-ID-TAG STEP
set "fileFullNameClean=%~nx3" & set fileFullNameClean=!fileFullNameClean: - =-!
for /f "usebackq tokens=1-3 delims=-" %%t in ('!fileFullNameClean!') do (
	set trackTitle=%%u
	set trackArtist=%%t
	set trackAlbum=%%v
)

REM Assign default tag
if "!trackArtist!"=="" set trackArtist=Unknown Artist
if "!trackTitle!"=="" set trackTitle=!fileName!

REM Using 'call' to handle the var %fileExtension% in the replace string
call set trackTitle=%%trackTitle:%fileExtension%=%%
if not "!trackAlbum!"=="" call set trackAlbum=%%trackAlbum:%fileExtension%=%%
if not "!trackAlbum!"=="" (
	set trackMetas=--tt "!trackTitle!" --ta "!trackArtist!" --tl "!trackAlbum!"
) else (
	set trackMetas=--tt "!trackTitle!" --ta "!trackArtist!"
)

REM echo. & echo [!trackArtist! - !trackTitle! - !trackAlbum! - !trackMetas!] & pause
REM END MP3-ID-TAG STEP

REM LOADING PROCESS
if /i "%replayGainEnabled%"=="true" (
	call "%pathLAME%\lame.exe" -m j -V 0 -q 0 --lowpass 24 --vbr-new -b 32 --replaygain-accurate !trackMetas! "!filePath!\!fileFullName!" "!destFolder!\!fileName!.mp3"
) else (
	call "%pathLAME%\lame.exe" -m j -V 0 -q 0 --lowpass 24 --vbr-new -b 32 !trackMetas! "!filePath!\!fileFullName!" "!destFolder!\!fileName!.mp3"
)
endlocal
goto :EOF

:quit
REM DON'T ERASE TEMP FILE ON ERROR
if !ERRORLEVEL! EQU 0 (
	if exist "!tempList!" del /f/q "!tempList!" > NUL
)
echo. & echo Press any key to exit...
pause > NUL
exit