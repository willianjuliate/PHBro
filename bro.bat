@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
cls

REM --- Habilita cores ANSI no console ---
for /F %%a in ('echo prompt $E^|cmd') do set "ESC=%%a"
set "RESET=%ESC%[0m"
set "BOLD=%ESC%[1m"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "BLUE=%ESC%[94m"
set "MAGENTA=%ESC%[95m"
set "CYAN=%ESC%[96m"
set "GRAY=%ESC%[90m"

set "BASEDIR=%~dp0bin\"
set "APACHE_HOME=%BASEDIR%apache\httpd-2.4.68\Apache24"
set "PHP_BASE=%BASEDIR%php"
set "PHP_CONFIG=%BASEDIR%.php_version"
set "MYSQL_HOME=%BASEDIR%mysql"
set "MYSQL_DATA=%BASEDIR%data"
set "WWW_HOME=%~dp0%www"
set "SCRIPT_VERSION=1.0.0"

REM Apache exige "/" em vez de "\" dentro do httpd.conf
set "APACHE_HOME_FWD=%APACHE_HOME:\=/%"
set "WWW_HOME_FWD=%WWW_HOME:\=/%"

if "%~1"=="--h" (
    call :HELP
    goto :END
)
if "%~1"=="--help" (
    call :HELP
    goto :END
)
if "%~1"=="--start" (
    call :START
    goto :END
)
if "%~1"=="--start-clean" (
    call :CLEANUP
    call :START
    goto :END
)
if "%~1"=="--stop" (
    call :STOP
    goto :END
)
if "%~1"=="--restart" (
    call :STOP
    echo.
    echo %CYAN%Aguardando liberar as portas...%RESET%
    timeout /t 3 /nobreak >nul
    call :START
    goto :END
)
if "%~1"=="--status" (
    call :STATUS
    goto :END
)
if "%~1"=="--wipe-data" (
    call :WIPE_DATA
    goto :END
)
if "%~1"=="--version" (
    call :VERSION
    goto :END
)
if "%~1"=="--v" (
    call :VERSION
    goto :END
)
if "%~1"=="--php-select" (
    if exist "%PHP_CONFIG%" del /Q "%PHP_CONFIG%" >nul 2>&1
    call :DETECT_PHP
    if defined PHP_HOME (
        echo.
        echo %GREEN%PHP selecionado: %PHP_HOME%%RESET%
        echo.
    )
    goto :END
)

call :HELP
goto :END

:: =====================================================
:: HELP
:: =====================================================
:HELP
echo %MAGENTA%██████╗ ██╗  ██╗██████╗ ██████╗  ██████╗%RESET%
echo %MAGENTA%██╔══██╗██║  ██║██╔══██╗██╔══██╗██╔═══██╗%RESET%
echo %MAGENTA%██████╔╝███████║██████╔╝██████╔╝██║   ██║%RESET%
echo %MAGENTA%██╔═══╝ ██╔══██║██╔══██╗██╔══██╗██║   ██║%RESET%
echo %MAGENTA%██║     ██║  ██║██████╔╝██║  ██║╚██████╔╝%RESET%
echo %MAGENTA%╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝%RESET%
echo %CYAN%Your PHP Development Buddy%RESET%
echo.
echo %BOLD%Uso:%RESET% %~n0 [opcao]   
echo.
echo %BOLD%Opcoes disponiveis:%RESET%
echo   %GREEN%--start%RESET%        Inicia Apache e MySQL (sem limpar execucoes anteriores)
echo   %GREEN%--start-clean%RESET%  Limpa execucoes anteriores (mata processos e apaga logs) e inicia
echo   %RED%--stop%RESET%         Encerra Apache e MySQL
echo   %YELLOW%--restart%RESET%      Executa --stop e em seguida --start
echo   %CYAN%--status%RESET%       Mostra checklist do que esta rodando
echo   %RED%--wipe-data%RESET%    Apaga a pasta data\ (reseta o banco MySQL do zero)
echo   %BLUE%--php-select%RESET%   Escolhe/troca qual versao de PHP usar
echo   %BLUE%--version, --v%RESET% Mostra a versao do script e dos componentes
echo   %GRAY%--help, --h%RESET%    Mostra este menu de ajuda
echo.
echo %BOLD%Exemplos:%RESET%
echo   %~n0 --start
echo   %~n0 --start-clean
echo   %~n0 --restart
echo   %~n0 --status
echo   %~n0 --wipe-data
echo   %~n0 --php-select
echo   %~n0 --version
echo.
echo %BOLD%Enderecos apos o --start:%RESET%
echo   Apache : %CYAN%http://localhost:8080%RESET%
echo   MySQL  : %CYAN%127.0.0.1:3306%RESET% ^(usuario root, sem senha^)
echo.
goto :eof

:: =====================================================
:: DETECT_PHP - identifica as pastas de PHP disponiveis
:: dentro de php\ e define PHP_HOME. Lembra a escolha em
:: um arquivo .php_version para nao perguntar toda vez.
:: =====================================================
:DETECT_PHP
set "PHP_HOME="
set "PHP_COUNT=0"

if not exist "%PHP_BASE%" (
    echo %RED%[ERRO] Pasta "%PHP_BASE%" nao existe.%RESET%
    goto :eof
)

for /f "delims=" %%D in ('dir /b /ad "%PHP_BASE%" 2^>nul') do (
    set /a PHP_COUNT+=1
    set "PHP_OPT!PHP_COUNT!=%%D"
)

if !PHP_COUNT! equ 0 (
    echo %RED%[ERRO] Nenhuma pasta de versao do PHP encontrada em "%PHP_BASE%".%RESET%
    echo Crie subpastas como "%PHP_BASE%\php8.5" com o PHP extraido dentro.
    goto :eof
)

REM --- Se ja existe uma selecao salva e ainda valida, usa direto ---
set "SAVED_PHP="
if exist "%PHP_CONFIG%" (
    set /p SAVED_PHP=<"%PHP_CONFIG%"
)
if defined SAVED_PHP (
    if exist "%PHP_BASE%\!SAVED_PHP!\php.exe" (
        set "PHP_HOME=%PHP_BASE%\!SAVED_PHP!"
        goto :eof
    )
)

REM --- Uma unica versao encontrada: seleciona automaticamente ---
if !PHP_COUNT! equ 1 (
    set "PHP_HOME=%PHP_BASE%\!PHP_OPT1!"
    >"%PHP_CONFIG%" echo !PHP_OPT1!
    echo %CYAN%[PHP] Unica versao encontrada, usando: !PHP_OPT1!%RESET%
    goto :eof
)

REM --- Varias versoes: pergunta qual usar ---
echo %CYAN%Versoes de PHP encontradas em "%PHP_BASE%":%RESET%
echo.
for /l %%I in (1,1,!PHP_COUNT!) do (
    echo   %BOLD%%%I^)%RESET% !PHP_OPT%%I!
)
echo.
set /p PHP_CHOICE="Escolha o numero da versao desejada: "

set "PHP_PICK="
if defined PHP_OPT%PHP_CHOICE% set "PHP_PICK=!PHP_OPT%PHP_CHOICE%!"

if not defined PHP_PICK (
    echo %RED%[ERRO] Opcao invalida.%RESET%
    goto :eof
)

set "PHP_HOME=%PHP_BASE%\%PHP_PICK%"
>"%PHP_CONFIG%" echo %PHP_PICK%
echo %GREEN%[PHP] Selecionado: %PHP_PICK% (salvo para as proximas execucoes)%RESET%
goto :eof

:: =====================================================
:: VERSION - versao do script e dos componentes instalados
:: =====================================================
:VERSION
echo %MAGENTA%██████╗ ██╗  ██╗██████╗ ██████╗  ██████╗%RESET%
echo %MAGENTA%██╔══██╗██║  ██║██╔══██╗██╔══██╗██╔═══██╗%RESET%
echo %MAGENTA%██████╔╝███████║██████╔╝██████╔╝██║   ██║%RESET%
echo %MAGENTA%██╔═══╝ ██╔══██║██╔══██╗██╔══██╗██║   ██║%RESET%
echo %MAGENTA%██║     ██║  ██║██████╔╝██║  ██║╚██████╔╝%RESET%
echo %MAGENTA%╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝%RESET%
echo %CYAN%Your PHP Development Buddy%RESET% %GRAY%~ %SCRIPT_VERSION%%RESET%
echo.

call :DETECT_PHP

set "TMPVER=%TEMP%\PHBro_ver_%RANDOM%.tmp"
REM --- PHP ---
if defined PHP_HOME (
    if exist "%PHP_HOME%\php.exe" (
        "%PHP_HOME%\php.exe" -v > "%TMPVER%" 2>nul
        set "PHPVER="
        for /f "delims=" %%V in ('findstr /B "PHP " "%TMPVER%"') do set "PHPVER=%%V"
        for /f "tokens=1,2" %%A in ("!PHPVER!") do set "PHPVER=%%A %%B"
        echo %GREEN%[PHP]%RESET%    !PHPVER! %GRAY% [PATH: !PHP_HOME!]%RESET%
    ) else (
        echo %RED%[PHP]%RESET%    php.exe nao encontrado em "!PHP_HOME!"
    )
) else (
    echo %RED%[PHP]%RESET%    nenhuma versao selecionada/encontrada
)

REM --- Apache ---
if exist "%APACHE_HOME%\bin\httpd.exe" (
    "%APACHE_HOME%\bin\httpd.exe" -v > "%TMPVER%" 2>nul
    set "APACHEVER="
    for /f "delims=" %%V in ('findstr /B "Server version" "%TMPVER%"') do set "APACHEVER=%%V"
    for /f "tokens=3" %%A in ("!APACHEVER!") do set "APACHEVER=%%A"
    for /f "tokens=1,2 delims=/" %%A in ("!APACHEVER!") do set "APACHEVER=%%A %%B"
    echo %GREEN%[Apache]%RESET% !APACHEVER!
) else (
    echo %RED%[Apache]%RESET% nao encontrado em "%APACHE_HOME%\bin"
)

REM --- MySQL ---
if exist "%MYSQL_HOME%\bin\mysqld.exe" (
    "%MYSQL_HOME%\bin\mysqld.exe" --version > "%TMPVER%" 2>nul
    set "MYSQLVER="
    for /f "delims=" %%V in ('findstr /C:"Ver " "%TMPVER%"') do set "MYSQLVER=%%V"
    set "MYSQL_NUM="
    set "FOUND_VER="
    for %%T in (!MYSQLVER!) do (
        if defined FOUND_VER (
            if not defined MYSQL_NUM set "MYSQL_NUM=%%T"
        )
        if /I "%%T"=="Ver" set "FOUND_VER=1"
    )
    echo %GREEN%[MySQL]%RESET%  MySQL !MYSQL_NUM!
) else (
    echo %RED%[MySQL]%RESET%  nao encontrado em "%MYSQL_HOME%\bin"
)

if exist "%TMPVER%" del /Q "%TMPVER%" >nul 2>&1
echo.
goto :eof

:: =====================================================
:: CHECK_RUNNING - define RUNNING=1 se Apache ou MySQL
:: ja estiverem em execucao
:: =====================================================
:CHECK_RUNNING
set "RUNNING=0"
tasklist /FI "IMAGENAME eq httpd.exe" 2>nul | find /I "httpd.exe" >nul
if %errorlevel%==0 set "RUNNING=1"
tasklist /FI "IMAGENAME eq mysqld.exe" 2>nul | find /I "mysqld.exe" >nul
if %errorlevel%==0 set "RUNNING=1"
goto :eof

:: =====================================================
:: STATUS - checklist do que esta rodando
:: =====================================================
:STATUS
echo %MAGENTA%██████╗ ██╗  ██╗██████╗ ██████╗  ██████╗%RESET%
echo %MAGENTA%██╔══██╗██║  ██║██╔══██╗██╔══██╗██╔═══██╗%RESET%
echo %MAGENTA%██████╔╝███████║██████╔╝██████╔╝██║   ██║%RESET%
echo %MAGENTA%██╔═══╝ ██╔══██║██╔══██╗██╔══██╗██║   ██║%RESET%
echo %MAGENTA%██║     ██║  ██║██████╔╝██║  ██║╚██████╔╝%RESET%
echo %MAGENTA%╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝%RESET%
echo %CYAN%Your PHP Development Buddy%RESET%
echo.

tasklist /FI "IMAGENAME eq httpd.exe" 2>nul | find /I "httpd.exe" >nul
if %errorlevel%==0 (
    echo %GREEN%[√] Apache   - rodando%RESET%
) else (
    echo %RED%[ ] Apache   - parado%RESET%
)

tasklist /FI "IMAGENAME eq mysqld.exe" 2>nul | find /I "mysqld.exe" >nul
if %errorlevel%==0 (
    echo %GREEN%[√] MySQL    - rodando%RESET%
) else (
    echo %RED%[ ] MySQL    - parado%RESET%
)

echo.
echo %BOLD%Verificando portas...%RESET%
netstat -ano | find "LISTENING" | find ":8080" >nul
if %errorlevel%==0 (
    echo %GREEN%[√] Porta 8080 - respondendo ^(Apache^)%RESET%
) else (
    echo %RED%[ ] Porta 8080 - sem resposta%RESET%
)

netstat -ano | find "LISTENING" | find ":3306" >nul
if %errorlevel%==0 (
    echo %GREEN%[√] Porta 3306 - respondendo ^(MySQL^)%RESET%
) else (
    echo %RED%[ ] Porta 3306 - sem resposta%RESET%
)

echo.
echo %GRAY%──────────────────────────────────────────%RESET%
echo   %BOLD%PHBro%RESET% %GRAY%v%SCRIPT_VERSION%%RESET%
echo   %GRAY%Repositorio:%RESET% %CYAN%https://github.com/willianjuliate/PHBro%RESET%
echo   %GRAY%Contato    :%RESET% %CYAN%contato@76sys.com.br%RESET%
echo %GRAY%──────────────────────────────────────────%RESET%
echo.
goto :eof

:: =====================================================
:: ENSURE_HIDDEN_VBS - cria (uma unica vez) o script que
:: dispara um processo com janela 100% oculta e desanexada
:: do console que chamou o bro.bat
:: =====================================================
:ENSURE_HIDDEN_VBS
if exist "%BASEDIR%hidden_run.vbs" goto :eof
(
    echo Set objShell = CreateObject("WScript.Shell"^)
    echo objShell.Run """" ^& WScript.Arguments(0^) ^& """", 0, False
) > "%BASEDIR%hidden_run.vbs"
goto :eof

:: =====================================================
:: START
:: =====================================================
:START
echo %MAGENTA%██████╗ ██╗  ██╗██████╗ ██████╗  ██████╗%RESET%
echo %MAGENTA%██╔══██╗██║  ██║██╔══██╗██╔══██╗██╔═══██╗%RESET%
echo %MAGENTA%██████╔╝███████║██████╔╝██████╔╝██║   ██║%RESET%
echo %MAGENTA%██╔═══╝ ██╔══██║██╔══██╗██╔══██╗██║   ██║%RESET%
echo %MAGENTA%██║     ██║  ██║██████╔╝██║  ██║╚██████╔╝%RESET%
echo %MAGENTA%╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝%RESET%
echo %CYAN%Your PHP Development Buddy%RESET%
echo.

call :CHECK_RUNNING
if "%RUNNING%"=="1" (
    echo.
    echo %YELLOW%[AVISO] Apache e/ou MySQL ja estao em execucao.%RESET%
    echo Use --status para ver o que esta rodando,
    echo --restart para reiniciar, ou --stop para encerrar antes.
    goto :eof
)

call :DETECT_PHP
if not defined PHP_HOME (
    echo %RED%[ERRO] Nao foi possivel determinar a versao do PHP a usar.%RESET%
    goto :eof
)
set "PHP_HOME_FWD=%PHP_HOME:\=/%"

REM --- Verifica se o PHP existe ---
if not exist "%PHP_HOME%\php.exe" (
    echo %RED%[ERRO] PHP nao encontrado em "%PHP_HOME%".%RESET%
    goto :eof
)

REM --- Verifica se o Apache existe ---
if not exist "%APACHE_HOME%\bin\httpd.exe" (
    echo %RED%[ERRO] Apache nao encontrado em "%APACHE_HOME%\bin".%RESET%
    goto :eof
)

REM --- Verifica se o MySQL existe ---
if not exist "%MYSQL_HOME%\bin\mysqld.exe" (
    echo %RED%[ERRO] MySQL nao encontrado em "%MYSQL_HOME%\bin".%RESET%
    goto :eof
)

REM --- Inicializa o datadir do MySQL na primeira execucao ---
if not exist "%MYSQL_DATA%\mysql" (
    echo %YELLOW%[MySQL] Primeira execucao detectada. Inicializando datadir...%RESET%
    if not exist "%MYSQL_DATA%" mkdir "%MYSQL_DATA%"
    "%MYSQL_HOME%\bin\mysqld.exe" --defaults-file="%BASEDIR%my.ini" --initialize-insecure --basedir="%MYSQL_HOME%" --datadir="%MYSQL_DATA%"
    echo %GREEN%[MySQL] Datadir criado.%RESET% Usuario root sem senha ^(defina uma depois^).
    echo.
)

if not exist "%BASEDIR%\data\logs" mkdir "%BASEDIR%\data\logs"

call :ENSURE_HIDDEN_VBS

REM --- Gera lancadores temporarios (evita gambiarra de aspas dentro do VBS) ---
> "%TEMP%\phbro_mysql_launch.bat" (
    echo @echo off
    echo "%MYSQL_HOME%\bin\mysqld.exe" --defaults-file="%BASEDIR%my.ini" --basedir="%MYSQL_HOME%" --datadir="%MYSQL_DATA%" --standalone ^> "%BASEDIR%\data\logs\mysql.log" 2^>^&1
)
> "%TEMP%\phbro_apache_launch.bat" (
    echo @echo off
    echo "%APACHE_HOME%\bin\httpd.exe" -d "%APACHE_HOME%" -C "Define SRVROOT \"%APACHE_HOME_FWD%\"" -C "Define WWWROOT \"%WWW_HOME_FWD%\"" -C "Define PHPROOT \"%PHP_HOME_FWD%\"" -f "%APACHE_HOME%\conf\httpd.conf"
)

echo %GREEN%[√] MySQL  iniciado%RESET% %GRAY%(processo oculto)%RESET%
cscript //nologo "%BASEDIR%hidden_run.vbs" "%TEMP%\phbro_mysql_launch.bat"

echo %GREEN%[√] Apache iniciado%RESET% %GRAY%(PHP: %PHP_HOME%, processo oculto)%RESET%
cscript //nologo "%BASEDIR%hidden_run.vbs" "%TEMP%\phbro_apache_launch.bat"

echo.
echo %GREEN%==========================================%RESET%
echo %GREEN%  Ambiente no ar!%RESET%
echo   Apache : %CYAN%http://localhost:8080%RESET%
echo   MySQL  : %CYAN%127.0.0.1:3306%RESET% ^(root sem senha^)
echo %GREEN%==========================================%RESET%
echo.
goto :eof

:: =====================================================
:: CLEANUP - limpa resquicios da execucao anterior
:: =====================================================
:CLEANUP
echo %YELLOW%[Limpeza] Encerrando processos remanescentes de execucoes anteriores...%RESET%
taskkill /IM httpd.exe /T /F >nul 2>&1
taskkill /IM mysqld.exe /T /F >nul 2>&1

if not exist "%BASEDIR%\data\logs" mkdir "%BASEDIR%\data\logs"

if exist "%BASEDIR%\data\logs\mysql.log" del /Q "%BASEDIR%\data\logs\mysql.log" >nul 2>&1
if exist "%APACHE_HOME%\logs\error.log" del /Q "%APACHE_HOME%\logs\error.log" >nul 2>&1
if exist "%APACHE_HOME%\logs\access.log" del /Q "%APACHE_HOME%\logs\access.log" >nul 2>&1

REM Da um respiro para o Windows liberar as portas/arquivos do processo anterior
timeout /t 2 /nobreak >nul
echo %GREEN%[Limpeza] Concluida.%RESET%
echo.
goto :eof

:: =====================================================
:: STOP
:: =====================================================
:STOP
echo %YELLOW%[Apache] Parando servidor...%RESET%
taskkill /IM httpd.exe /T /F >nul 2>&1

echo %YELLOW%[MySQL] Parando servidor...%RESET%
"%MYSQL_HOME%\bin\mysqladmin.exe" --user=root shutdown 2>nul
if errorlevel 1 (
    echo %YELLOW%[MySQL] mysqladmin nao respondeu, forcando encerramento do processo...%RESET%
    taskkill /F /IM mysqld.exe >nul 2>&1
)

echo.
echo %MAGENTA%██████╗ ██╗  ██╗██████╗ ██████╗  ██████╗%RESET%
echo %MAGENTA%██╔══██╗██║  ██║██╔══██╗██╔══██╗██╔═══██╗%RESET%
echo %MAGENTA%██████╔╝███████║██████╔╝██████╔╝██║   ██║%RESET%
echo %MAGENTA%██╔═══╝ ██╔══██║██╔══██╗██╔══██╗██║   ██║%RESET%
echo %MAGENTA%██║     ██║  ██║██████╔╝██║  ██║╚██████╔╝%RESET%
echo %MAGENTA%╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝%RESET%
echo %CYAN%Your PHP Development Buddy%RESET%
echo.
echo %GREEN%√ Ambiente encerrado com sucesso.%RESET% Ate a proxima!
echo.
echo %GRAY%──────────────────────────────────────────%RESET%
echo   %BOLD%PHBro%RESET% %GRAY%v%SCRIPT_VERSION%%RESET%
echo   %GRAY%Repositorio:%RESET% %CYAN%https://github.com/willianjuliate/PHBro%RESET%
echo   %GRAY%Contato    :%RESET% %CYAN%contato@76sys.com.br%RESET%
echo %GRAY%──────────────────────────────────────────%RESET%
echo.
goto :eof

:: =====================================================
:: WIPE_DATA - apaga a pasta data\ (reset total do MySQL)
:: =====================================================
:WIPE_DATA
call :CHECK_RUNNING
if "%RUNNING%"=="1" (
    echo %RED%[ERRO] Pare os servicos antes de apagar os dados.%RESET%
    echo Use "%~n0 --stop" primeiro.
    goto :eof
)

echo %RED%==========================================%RESET%
echo %RED%  ATENCAO: isso vai apagar TODO o banco de dados MySQL%RESET%
echo   Pasta: %MYSQL_DATA%
echo %RED%  Essa acao NAO pode ser desfeita.%RESET%
echo %RED%==========================================%RESET%
echo.
set /p CONFIRM="Digite SIM para confirmar: "
if /I not "%CONFIRM%"=="SIM" (
    echo.
    echo %YELLOW%Operacao cancelada.%RESET%
    goto :eof
)

echo.
echo %YELLOW%[Data] Apagando "%MYSQL_DATA%"...%RESET%
rmdir /S /Q "%MYSQL_DATA%" 2>nul
echo %GREEN%[Data] Concluido.%RESET% Na proxima "--start" o banco sera reinicializado do zero.
echo.
goto :eof

:: =====================================================
:: FIM
:: =====================================================
:END
pause
exit /b