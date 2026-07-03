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
set "PORT_CONFIG=%BASEDIR%.apache_port"
set "DOMAIN_CONFIG=%BASEDIR%.apache_domain"
set "SSL_CONFIG=%BASEDIR%.apache_ssl"
set "SSL_DIR=%APACHE_HOME%\conf\ssl"
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

if "%~1"=="--port" (
    set "OLD_PORT="
    if exist "%PORT_CONFIG%" set /p OLD_PORT=<"%PORT_CONFIG%"
    if exist "%PORT_CONFIG%" del /Q "%PORT_CONFIG%" >nul 2>&1
    call :DETECT_PORT
    if not defined APACHE_PORT (
        if defined OLD_PORT (
            >"%PORT_CONFIG%" echo !OLD_PORT!
        )
        echo %GRAY%Nenhuma alteracao foi feita.%RESET%
        echo.
        goto :END
    )
    echo.
    echo %GREEN%Porta do Apache definida: !APACHE_PORT!%RESET%
    echo.
    call :OFFER_RESTART
    goto :END
)

if "%~1"=="--domain" (
    call :DETECT_DOMAIN
    if defined APACHE_DOMAIN (
        echo.
        call :OFFER_RESTART
    )
    goto :END
)

if "%~1"=="--https" (
    call :TOGGLE_SSL
    echo.
    call :OFFER_RESTART
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
echo   %BLUE%--port%RESET%         Escolhe/troca a porta do Apache
echo   %BLUE%--domain%RESET%       Escolhe/troca o dominio local (ex: phbro.me), exige Admin
echo   %BLUE%--https%RESET%        Liga/desliga HTTPS (certificado autoassinado)
echo   %BLUE%--version, --v%RESET% Mostra a versao do script e dos componentes
echo   %GRAY%--help, --h%RESET%    Mostra este menu de ajuda
echo.
echo %BOLD%Exemplos:%RESET%
echo   %~n0 --v
echo   %~n0 --status
echo   %~n0 --start
echo   %~n0 --stop
echo   %~n0 --restart
echo.
call :LOAD_PORT
call :LOAD_DOMAIN
call :LOAD_SSL
echo %BOLD%Enderecos apos o --start:%RESET%
echo   Apache : %CYAN%http://%APACHE_DOMAIN%:%APACHE_PORT%%RESET%
if "%SSL_ENABLED%"=="1" (
echo   SSL    : %CYAN%https://%APACHE_DOMAIN%%RESET%
)
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

call :LOAD_PORT
call :LOAD_DOMAIN
call :LOAD_SSL

@REM if "!SSL_ENABLED!"=="1" (
@REM     set "IS_HTTPS=https"
@REM ) else (
@REM     set "IS_HTTPS=http"
@REM )

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
call :LOAD_PORT
netstat -ano | find "LISTENING" | find ":%APACHE_PORT% " >nul
if %errorlevel%==0 (
    echo %GREEN%[√] Porta %APACHE_PORT% - respondendo ^(Apache^)%RESET%
) else (
    echo %RED%[ ] Porta %APACHE_PORT% - sem resposta%RESET%
)

netstat -ano | find "LISTENING" | find ":3306" >nul
if %errorlevel%==0 (
    echo %GREEN%[√] Porta 3306 - respondendo ^(MySQL^)%RESET%
) else (
    echo %RED%[ ] Porta 3306 - sem resposta%RESET%
)

call :LOAD_DOMAIN
call :LOAD_SSL
echo.
echo %BOLD%Configuracao atual:%RESET%

echo   Dominio : %CYAN%!APACHE_DOMAIN!%RESET%
if "%SSL_ENABLED%"=="1" (
    echo   HTTPS   : %GREEN%ativado%RESET%
) else (
    echo   HTTPS   : %GRAY%desativado%RESET%
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
:: OFFER_RESTART - se Apache/MySQL estiverem rodando,
:: oferece reiniciar para aplicar uma config nova (porta,
:: dominio ou https). Usada por --port, --domain e --https.
:: =====================================================
:OFFER_RESTART
call :CHECK_RUNNING
if "!RUNNING!"=="1" (
    echo %YELLOW%[AVISO] Apache e/ou MySQL ainda estao rodando com a configuracao antiga.%RESET%
    set /p RESTART_NOW="Reiniciar agora para aplicar a mudanca? (S/N): "
    if /I "!RESTART_NOW!"=="S" (
        call :STOP
        echo.
        echo %CYAN%Aguardando liberar as portas...%RESET%
        timeout /t 3 /nobreak >nul
        call :START
    ) else (
        echo %GRAY%Ok, a configuracao antiga continua ativa ate voce rodar "%~n0 --restart".%RESET%
        echo.
    )
)
goto :eof

:: =====================================================
:: CHECK_ADMIN - detecta se o script esta rodando elevado
:: (necessario para editar o hosts do Windows)
:: =====================================================
:CHECK_ADMIN
set "IS_ADMIN=0"
net session >nul 2>&1
if %errorlevel%==0 set "IS_ADMIN=1"
goto :eof

:: =====================================================
:: LOAD_DOMAIN - le o dominio salvo sem perguntar nada.
:: Se nunca foi configurado, cai no padrao "localhost".
:: =====================================================
:LOAD_DOMAIN
set "APACHE_DOMAIN=localhost"
if exist "%DOMAIN_CONFIG%" (
    set /p APACHE_DOMAIN=<"%DOMAIN_CONFIG%"
)
goto :eof

:: =====================================================
:: DETECT_DOMAIN - pergunta o dominio local do projeto,
:: aponta ele para 127.0.0.1 no hosts do Windows e salva
:: a escolha. Exige Administrador.
:: =====================================================
:DETECT_DOMAIN
set "APACHE_DOMAIN="
echo %CYAN%Dominio local do projeto%RESET%
echo Sugestao: %BOLD%phbro.me%RESET%  ^(ou digite outro, ex: meuprojeto.me^)
echo Deixe em branco para cancelar, ou digite "localhost" para voltar ao padrao.
echo.
set /p APACHE_DOMAIN="Dominio: "

if not defined APACHE_DOMAIN (
    echo %GRAY%Operacao cancelada.%RESET%
    echo.
    goto :eof
)

if /I "!APACHE_DOMAIN!"=="localhost" (
    if exist "%DOMAIN_CONFIG%" del /Q "%DOMAIN_CONFIG%" >nul 2>&1
    call :CHECK_ADMIN
    if "!IS_ADMIN!"=="1" call :UPDATE_HOSTS_CLEAR
    echo %GREEN%[Dominio] Voltando a usar "localhost".%RESET%
    echo.
    goto :eof
)

call :CHECK_ADMIN
if not "!IS_ADMIN!"=="1" (
    echo %RED%[ERRO] Preciso rodar como Administrador para editar o arquivo hosts do Windows.%RESET%
    echo Feche este terminal e abra o %~n0 novamente com "Executar como administrador".
    echo.
    set "APACHE_DOMAIN="
    goto :eof
)

call :UPDATE_HOSTS
>"%DOMAIN_CONFIG%" echo !APACHE_DOMAIN!

REM --- Se o SSL ja estava ativo, o certificado antigo nao serve mais pro novo dominio ---
call :LOAD_SSL
if "!SSL_ENABLED!"=="1" (
    del /Q "%SSL_DIR%\phbro.crt" >nul 2>&1
    del /Q "%SSL_DIR%\phbro.key" >nul 2>&1
    echo %YELLOW%[HTTPS] Certificado antigo removido, sera gerado de novo para "!APACHE_DOMAIN!" no proximo --start.%RESET%
)

echo %GREEN%[Dominio] "!APACHE_DOMAIN!" apontando para 127.0.0.1 ^(hosts atualizado^).%RESET%
echo.
goto :eof

:: =====================================================
:: UPDATE_HOSTS - remove um bloco PHBro anterior (se
:: existir) e adiciona o dominio atual no hosts do Windows
:: =====================================================
:UPDATE_HOSTS
set "HOSTS_FILE=%WINDIR%\System32\drivers\etc\hosts"
call :STRIP_HOSTS_BLOCK
(
    echo # PHBro inicio
    echo 127.0.0.1    !APACHE_DOMAIN!
    echo 127.0.0.1    www.!APACHE_DOMAIN!
    echo # PHBro fim
)>> "%HOSTS_FILE%"
goto :eof

:: =====================================================
:: UPDATE_HOSTS_CLEAR - so remove o bloco PHBro do hosts
:: (usado ao voltar para "localhost")
:: =====================================================
:UPDATE_HOSTS_CLEAR
set "HOSTS_FILE=%WINDIR%\System32\drivers\etc\hosts"
call :STRIP_HOSTS_BLOCK
goto :eof

:: --- helper interno: reescreve o hosts sem o bloco PHBro ---
:STRIP_HOSTS_BLOCK
if not exist "%HOSTS_FILE%" goto :eof
set "SKIP=0"
> "%TEMP%\phbro_hosts_new.txt" (
    for /f "usebackq delims=" %%L in ("%HOSTS_FILE%") do (
        set "LINE=%%L"
        if "!LINE!"=="# PHBro inicio" set "SKIP=1"
        if "!SKIP!"=="0" echo(!LINE!
        if "!LINE!"=="# PHBro fim" set "SKIP=0"
    )
)
copy /Y "%TEMP%\phbro_hosts_new.txt" "%HOSTS_FILE%" >nul
del /Q "%TEMP%\phbro_hosts_new.txt" >nul 2>&1
goto :eof

:: =====================================================
:: LOAD_SSL - le se o HTTPS esta ativo sem perguntar nada
:: =====================================================
:LOAD_SSL
set "SSL_ENABLED=0"
if exist "%SSL_CONFIG%" (
    set /p SSL_ENABLED=<"%SSL_CONFIG%"
)
goto :eof

:: =====================================================
:: TOGGLE_SSL - liga/desliga o HTTPS. Ao ligar, gera (se
:: preciso) um certificado autoassinado para o dominio atual.
:: =====================================================
:TOGGLE_SSL
call :LOAD_SSL
if "!SSL_ENABLED!"=="1" (
    >"%SSL_CONFIG%" echo 0
    echo %YELLOW%[HTTPS] Desativado. O Apache voltara a responder so por HTTP.%RESET%    
    goto :eof
)

call :ENSURE_SSL_CERT
if not defined SSL_CERT_OK (
    echo %RED%[ERRO] Nao foi possivel preparar o certificado. HTTPS nao foi ativado.%RESET%
    goto :eof
)

>"%SSL_CONFIG%" echo 1
echo %GREEN%[HTTPS] Ativado.%RESET%
echo %YELLOW%O navegador vai mostrar um aviso de certificado nao confiavel (e autoassinado) - isso e esperado em ambiente de dev, so aceitar/prosseguir.%RESET%
goto :eof

:: =====================================================
:: ENSURE_SSL_CERT - gera um certificado autoassinado com
:: o openssl que acompanha o Apache, se ainda nao existir
:: um para o dominio atual.
:: =====================================================
:ENSURE_SSL_CERT
set "SSL_CERT_OK="
set "OPENSSL_EXE=%APACHE_HOME%\bin\openssl.exe"

echo %GRAY%Procurando openssl em: %OPENSSL_EXE%%RESET%

if not exist "%OPENSSL_EXE%" (
    echo %RED%[ERRO] openssl.exe nao encontrado nesse caminho.%RESET%
    echo Esse binario normalmente acompanha o Apache para Windows, dentro da pasta bin\.
    echo Se sua build do Apache nao vem com ele, baixe o OpenSSL para Windows e ajuste
    echo a variavel OPENSSL_EXE no bro.bat para apontar pro openssl.exe correto.
    goto :eof
)

if not exist "%SSL_DIR%" mkdir "%SSL_DIR%"

if exist "%SSL_DIR%\phbro.crt" if exist "%SSL_DIR%\phbro.key" (
    set "SSL_CERT_OK=1"
    goto :eof
)

call :LOAD_DOMAIN
echo %CYAN%Gerando certificado autoassinado para "!APACHE_DOMAIN!"...%RESET%
set "SSL_ERR_LOG=%TEMP%\phbro_openssl_error.log"

REM --- O openssl.exe de algumas builds do Apache vem com um caminho fixo
REM     (ex: C:\Apache24\conf\openssl.cnf) gravado de fabrica, que nao existe
REM     se o Apache estiver instalado em outra pasta. Forcamos o caminho certo.
set "OPENSSL_CONF=%APACHE_HOME%\conf\openssl.cnf"
if not exist "%OPENSSL_CONF%" (
    set "OPENSSL_CONF=%SSL_DIR%\openssl.cnf"
    if not exist "!OPENSSL_CONF!" (
        echo %GRAY%Nenhum openssl.cnf encontrado no Apache, criando uma config minima...%RESET%
        (
            echo [req]
            echo distinguished_name = req_distinguished_name
            echo prompt = no
            echo.
            echo [req_distinguished_name]
            echo CN = localhost
        ) > "!OPENSSL_CONF!"
    )
)
echo %GRAY%Usando openssl.cnf em: !OPENSSL_CONF!%RESET%

"%OPENSSL_EXE%" req -x509 -nodes -newkey rsa:2048 -keyout "%SSL_DIR%\phbro.key" -out "%SSL_DIR%\phbro.crt" -days 825 -subj "/CN=!APACHE_DOMAIN!" -addext "subjectAltName=DNS:!APACHE_DOMAIN!,DNS:www.!APACHE_DOMAIN!,DNS:localhost,IP:127.0.0.1" 2>"%SSL_ERR_LOG%"
set "OPENSSL_RC=!errorlevel!"

if exist "%SSL_DIR%\phbro.crt" if exist "%SSL_DIR%\phbro.key" (
    set "SSL_CERT_OK=1"
    echo %GREEN%[SSL] Certificado gerado em "%SSL_DIR%".%RESET%
    del /Q "%SSL_ERR_LOG%" >nul 2>&1
) else (
    echo %RED%[ERRO] Falha ao gerar o certificado com openssl ^(codigo !OPENSSL_RC!^).%RESET%
    echo %GRAY%Saida do openssl:%RESET%
    type "%SSL_ERR_LOG%" 2>nul
    echo.
    echo %GRAY%Tentando sem -addext ^(openssl mais antigo pode nao suportar essa opcao^)...%RESET%
    "%OPENSSL_EXE%" req -x509 -nodes -newkey rsa:2048 -keyout "%SSL_DIR%\phbro.key" -out "%SSL_DIR%\phbro.crt" -days 825 -subj "/CN=!APACHE_DOMAIN!" 2>"%SSL_ERR_LOG%"
    if exist "%SSL_DIR%\phbro.crt" if exist "%SSL_DIR%\phbro.key" (
        set "SSL_CERT_OK=1"
        echo %GREEN%[SSL] Certificado gerado ^(sem SAN^) em "%SSL_DIR%".%RESET%
        del /Q "%SSL_ERR_LOG%" >nul 2>&1
    ) else (
        echo %RED%[ERRO] Ainda falhou. Saida do openssl:%RESET%
        type "%SSL_ERR_LOG%" 2>nul
    )
)
goto :eof

:: =====================================================
:: LOAD_PORT - le a porta salva sem perguntar nada.
:: Usada por --help e --status. Se nunca foi escolhida,
:: cai no padrao 8080.
:: =====================================================
:LOAD_PORT
set "APACHE_PORT=8080"
if exist "%PORT_CONFIG%" (
    set /p APACHE_PORT=<"%PORT_CONFIG%"
)
goto :eof

:: =====================================================
:: DETECT_PORT - escolhe/valida a porta do Apache. Mostra
:: as portas mais comuns com status livre/em uso e lembra
:: a escolha em bin\.apache_port.
:: =====================================================
:DETECT_PORT
set "APACHE_PORT="

REM --- Se ja existe uma porta salva, usa direto ---
if exist "%PORT_CONFIG%" (
    set /p APACHE_PORT=<"%PORT_CONFIG%"
)
if defined APACHE_PORT goto :eof

echo %CYAN%Verificando portas disponiveis...%RESET%
echo.

set "PORT_LIST=80 8080 8000 8081 8888 3000"
set "PORT_COUNT=0"
for %%P in (%PORT_LIST%) do (
    set /a PORT_COUNT+=1
    set "PORT_OPT!PORT_COUNT!=%%P"
    netstat -ano | find "LISTENING" | find ":%%P " >nul
    if !errorlevel!==0 (
        set "PORT_STATUS!PORT_COUNT!=%RED%em uso%RESET%"
    ) else (
        set "PORT_STATUS!PORT_COUNT!=%GREEN%livre%RESET%"
    )
)

for /l %%I in (1,1,!PORT_COUNT!) do (
    echo   %BOLD%%%I^)%RESET% Porta !PORT_OPT%%I!   [!PORT_STATUS%%I!]
)
set /a CUSTOM_OPT=!PORT_COUNT!+1
echo   %BOLD%!CUSTOM_OPT!^)%RESET% Digitar outra porta
echo   %BOLD%0^)%RESET% Cancelar
echo.
set /p PORT_CHOICE="Escolha uma opcao: "

if "!PORT_CHOICE!"=="0" (
    echo %GRAY%Operacao cancelada.%RESET%
    echo.
    goto :eof
)

if "!PORT_CHOICE!"=="!CUSTOM_OPT!" (
    set /p APACHE_PORT="Digite a porta desejada (vazio para cancelar): "
    if not defined APACHE_PORT (
        echo %GRAY%Operacao cancelada.%RESET%
        echo.
        goto :eof
    )
) else (
    if defined PORT_OPT!PORT_CHOICE! (
        set "APACHE_PORT=!PORT_OPT%PORT_CHOICE%!"
    )
)

if not defined APACHE_PORT (
    echo %RED%[ERRO] Opcao invalida.%RESET%
    goto :eof
)

REM --- Confere se a porta escolhida esta livre ---
netstat -ano | find "LISTENING" | find ":%APACHE_PORT% " >nul
if !errorlevel!==0 (
    echo %YELLOW%[AVISO] A porta %APACHE_PORT% ja esta em uso por outro processo.%RESET%
    set /p CONFIRM_PORT="Usar mesmo assim? (S/N): "
    if /I not "!CONFIRM_PORT!"=="S" (
        set "APACHE_PORT="
        echo %GRAY%Operacao cancelada.%RESET%
        echo.
        goto :eof
    )
)

>"%PORT_CONFIG%" echo !APACHE_PORT!
echo %GREEN%[Porta] Selecionada: !APACHE_PORT! (salva para as proximas execucoes)%RESET%
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

call :DETECT_PORT
if not defined APACHE_PORT (
    echo %RED%[ERRO] Nenhuma porta valida foi definida para o Apache.%RESET%
    echo Use "%~n0 --port" para escolher uma porta.
    goto :eof
)

netstat -ano | find "LISTENING" | find ":%APACHE_PORT% " >nul
if !errorlevel!==0 (
    echo %YELLOW%[AVISO] A porta %APACHE_PORT% parece estar em uso por outro processo.%RESET%
    echo O Apache pode falhar ao subir. Use "%~n0 --port" para trocar de porta.
    echo.
)

call :LOAD_DOMAIN
call :LOAD_SSL

set APACHE_EXTRA_ARGS=-C "Define APACHEDOMAIN %APACHE_DOMAIN%"

if "!SSL_ENABLED!"=="1" (
    call :ENSURE_SSL_CERT
    if defined SSL_CERT_OK (
        set "SSL_DIR_FWD=%SSL_DIR:\=/%"
        set APACHE_EXTRA_ARGS=!APACHE_EXTRA_ARGS! -C "Define SSLDIR \"!SSL_DIR_FWD!\"" -D SSL
    ) else (
        echo %YELLOW%[AVISO] HTTPS ficou desativado nesta execucao por falta de certificado.%RESET%
        set "SSL_ENABLED=0"
    )
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
    echo "%APACHE_HOME%\bin\httpd.exe" -d "%APACHE_HOME%" -C "Define SRVROOT \"%APACHE_HOME_FWD%\"" -C "Define WWWROOT \"%WWW_HOME_FWD%\"" -C "Define PHPROOT \"%PHP_HOME_FWD%\"" -C "Define APACHEPORT %APACHE_PORT%" !APACHE_EXTRA_ARGS! -f "%APACHE_HOME%\conf\httpd.conf"
)

echo %GREEN%[√] MySQL  iniciado%RESET% %GRAY%(processo oculto)%RESET%
cscript //nologo "%BASEDIR%hidden_run.vbs" "%TEMP%\phbro_mysql_launch.bat"

echo %GREEN%[√] Apache iniciado%RESET% %GRAY%(PHP: %PHP_HOME%, processo oculto)%RESET%
cscript //nologo "%BASEDIR%hidden_run.vbs" "%TEMP%\phbro_apache_launch.bat"

echo.
echo %GREEN%==========================================%RESET%
echo %GREEN%  Ambiente no ar!%RESET%
echo   Apache : %CYAN%http://!APACHE_DOMAIN!:%APACHE_PORT%%RESET%
if "!SSL_ENABLED!"=="1" ( 
echo   SSL    : %CYAN%https://!APACHE_DOMAIN!%RESET%
)

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
cls
exit /b