```markdown
██████╗ ██╗  ██╗██████╗ ██████╗  ██████╗
██╔══██╗██║  ██║██╔══██╗██╔══██╗██╔═══██╗
██████╔╝███████║██████╔╝██████╔╝██║   ██║
██╔═══╝ ██╔══██║██╔══██╗██╔══██╗██║   ██║
██║     ██║  ██║██████╔╝██║  ██║╚██████╔╝
╚═╝     ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝
Your PHP Development Buddy

```

Ambiente portátil para desenvolvimento PHP contendo **Apache**, **PHP** e **MySQL**, sem necessidade de instalação como serviço do Windows.
O PHBro foi criado para permitir alternar facilmente entre versões do PHP, iniciar e parar todo o ambiente através de um único comando e manter tudo isolado dentro da pasta do projeto.

---

# 🚀 Recursos

* Apache 2.4
* PHP com múltiplas versões
* MySQL
* Ambiente portátil (não instala serviços no Windows)
* Seleção dinâmica e automática da versão do PHP
* Inicialização automatizada do banco de dados (`datadir`)
* Checklist de status dos serviços e portas em tempo real
* Reinicialização rápida do ambiente
* Reset completo do banco de dados via CLI
* Script único em lote (`.bat`) para gerenciamento completo

---

# 🌍 Acesso Global (Variáveis de Ambiente)

Para conseguir executar o comando `bro` a partir de **qualquer pasta** no seu terminal (Prompt de Comando ou PowerShell), você pode adicionar a pasta raiz do **PHBro** às Variáveis de Ambiente do Windows:

1. Copie o caminho completo da pasta onde o arquivo `bro.bat` está localizado (ex: `C:\Desenvolvimento\PHBro`).
2. Pressione a tecla `Windows`, digite **"variáveis de ambiente"** e selecione **"Editar as variáveis de ambiente do sistema"**.
3. Clique no botão **"Variáveis de Ambiente..."**.
4. Na seção *Variáveis do sistema* (subindo ou descendo a lista), localize a variável **`Path`** e clique em **"Editar..."**.
5. Clique em **"Novo"** e cole o caminho completo da pasta do PHBro.
6. Clique em **"OK"** em todas as janelas para salvar.
7. Abra um novo terminal e use o comando diretamente de onde quiser:
```cmd
bro --status

```



---

# 📂 Estrutura do Projeto

```text
PHBro/
│
├── bro.bat
├── www/
│
└── bin/
    ├── apache/
    │
    ├── php/
    │   ├── php8.2/
    │   ├── php8.3/
    │   └── php8.4/
    │
    ├── mysql/
    │
    ├── data/
    │
    ├── logs/
    │
    ├── my.ini
    │
    └── .php_version

```

---

# 📋 Requisitos

* Windows 10 ou superior
* CMD (Prompt de Comando) ou PowerShell
* **Não** é necessário ter Apache, PHP ou MySQL previamente instalados ou configurados globalmente no sistema.

---

# 📦 Download e Atualização dos Binários (Opcional)

> 💡 **Nota:** Os passos de download abaixo são **totalmente opcionais**! O repositório do PHBro já vem configurado e acompanhado das versões mais recentes e estáveis dos binários do Apache, PHP e MySQL prontos para uso. Recorra a esta seção apenas se quiser adicionar novas versões por conta própria ou atualizar o ambiente manualmente.

### Apache

Baixe a versão Win64 do Apache em: [apachelounge.com/download/](https://www.apachelounge.com/download/)

Extraia para: `bin/apache/httpd-2.4.xx/Apache24` (Exemplo: `bin/apache/httpd-2.4.68/Apache24`).

*Caso mude o padrão da pasta, altere a variável `APACHE_HOME` dentro do `bro.bat`.*

### PHP

Baixe qualquer versão **Thread Safe** em: [windows.php.net/download/](https://windows.php.net/download/)

Extraia cada versão em uma pasta dedicada dentro de `bin/php/` (ex: `bin/php/php8.5`).

Cada pasta deve conter diretamente os arquivos `php.exe`, `php.ini` e a pasta `ext/`.

### MySQL

Baixe o ZIP do MySQL Community Server em: [link suspeito removido]

Extraia o conteúdo em: `bin/mysql`. A estrutura deve manter o caminho `bin/mysql/bin/mysqld.exe`.

---

# 🏁 Primeira Execução

Abra o terminal na pasta do projeto (ou em qualquer local caso tenha configurado o Acesso Global) e execute:

```cmd
bro --start

```

Na primeira execução, o PHBro irá automaticamente:

1. Detectar as versões do PHP disponíveis em `bin/php/`.
2. Solicitar qual delas você deseja utilizar (caso haja mais de uma) e salvar a escolha.
3. Criar e inicializar o diretório de dados (`datadir`) do MySQL de forma segura.
4. Subir os serviços do Apache e do MySQL em segundo plano.

---

# 🔄 Selecionando outra versão do PHP

Sempre que desejar alternar a versão do PHP que está rodando no ecossistema:

```cmd
bro --php-select

```

A escolha será salva no arquivo oculto `bin/.php_version` e usada de forma automática em todas as inicializações seguintes.

---

# 🛠️ Comandos Disponíveis

### Iniciar o Ambiente

```cmd
bro --start

```

Inicia o Apache e o MySQL usando as configurações portáteis.

### Iniciar Limpando Processos (Clean Start)

```cmd
bro --start-clean

```

Força o encerramento de processos travados do Apache/MySQL na memória, limpa os arquivos de log antigos e inicia o ecossistema do zero. Ideal para quando o ambiente foi fechado incorretamente.

### Parar o Ambiente

```cmd
bro --stop

```

Encerra com segurança os servidores Apache e MySQL, liberando as portas do sistema.

### Reiniciar

```cmd
bro --restart

```

Executa a rotina de parada completa, aguarda a liberação das portas pelo Windows e inicia o ambiente novamente.

### Verificar Status

```cmd
bro --status

```

Valida se os processos estão ativos e realiza testes de conexão nas portas `8080` (Apache) e `3306` (MySQL).

### Verificar Versões

```cmd
bro --version

```

Retorna de forma limpa as versões atuais do script PHBro, do PHP ativo, do Apache e do MySQL.

### Resetar Banco de Dados (Wipe Data)

```cmd
bro --wipe-data

```

⚠️ **ATENÇÃO:** Este comando remove completamente a pasta `bin/data/`. Todos os bancos de dados criados localmente serão **permanentemente perdidos**. Na próxima inicialização (`--start`), o MySQL recriará a estrutura limpa de fábrica.

### Menu de Ajuda

```cmd
bro --help

```

ou `bro --h` exibe o menu interativo com a listagem rápida de comandos diretamente no terminal.

---

# 🌐 Endereços e Portas Padrão

### Apache (Servidor Web)

* **URL:** [http://localhost:8080](https://www.google.com/search?q=http://localhost:8080)
* **Onde ficam meus projetos?** Todos os seus arquivos `.php` e diretórios de projetos devem ser colocados dentro da pasta `www/` na raiz do PHBro.

### MySQL (Banco de Dados)

* **Host:** `127.0.0.1`
* **Porta:** `3306`
* **Usuário:** `root`
* **Senha:** *Sem senha por padrão* (O banco é inicializado sem credenciais; sinta-se livre para definir uma senha posteriormente via Client SQL).

---

# 🔍 Solução de Problemas

* **Apache não inicia:** Verifique se a porta `8080` já está em uso por outra aplicação. Execute `bro --status` para diagnosticar.
* **MySQL não inicia:** Confirme se você já não possui uma instância global do MySQL ou MariaDB rodando nativamente na porta `3306`.
* **Ambiente travado ou corrompido:** Tente rodar o comando de inicialização limpa: `bro --start-clean`.

---

# 🐲 Autor

**Willian Juliate** * **GitHub:** [github.com/willianjuliate/PHBro](https://github.com/willianjuliate/PHBro)

* **Contato:** contato@76sys.com.br

---

## 📄 Licença

Este projeto é distribuído sob a **Licença MIT**. Sinta-se livre para utilizar, modificar e distribuir o PHBro da forma que melhor atender o seu fluxo de desenvolvimento local!
