# RO Controle Tools

Ferramentas para **leitura manual** de contadores de impressoras e **envio forcado** para o servidor RO Controle.

> Desenvolvido por engenharia reversa do software RO Controle da Reis Office.

---

## Indice

1. [O que faz](#o-que-faz)
2. [Instalacao](#instalacao)
3. [Configuracao](#configuracao)
4. [Como Usar](#como-usar)
5. [Agendamento Automatico](#agendamento-automatico)
6. [Solucao de Problemas](#solucao-de-problemas)
7. [Detalhes Tecnicos](#detalhes-tecnicos)

---

## O que faz

O RO Controle original faz leituras e uploads **automaticos em background**. Voce nao tem controle de quando isso acontece.

**Este projeto permite:**

| Acao | RO Original | Esta Ferramenta |
|------|-------------|-----------------|
| Ler contadores agora | Nao | **Sim** |
| Enviar leituras agora | Nao | **Sim** |
| Ver progresso | Nao | **Sim** |
| Escolher quando executar | Nao | **Sim** |

---

## Instalacao

### Passo 1: Copiar os arquivos

Copie toda a pasta para o computador onde o **RO Controle ja esta instalado**.

### Passo 2: Verificar pre-requisitos

O computador precisa ter:

- [x] RO Controle instalado (com banco de dados em `C:\RO\LeituraOID\`)
- [x] Windows com PowerShell
- [x] Acesso de rede as impressoras (mesma rede ou VPN)

### Passo 3: Configurar (primeiro uso)

Veja a secao [Configuracao](#configuracao) abaixo.

---

## Configuracao

### Opcao A: Automatica (Recomendada)

Se o RO Controle esta instalado no caminho padrao, **nao precisa configurar nada!**

O script detecta automaticamente as chaves do arquivo:
```
C:\RO\LeituraOID\Ro.Controle.Start.exe.config
```

### Opcao B: Manual (config.json)

Se a deteccao automatica nao funcionar:

1. Copie `config.example.json` para `config.json`
2. Preencha os dados:

```json
{
    "securityKey": "COLE_A_CHAVE_AQUI",
    "iv": "COLE_O_IV_AQUI",
    "dbPath": "C:\\RO\\LeituraOID\\tarifador.db",
    "snmpCommunity": "public",
    "snmpTimeout": 300,
    "snmpRetries": 2
}
```

### Onde encontrar as chaves?

**Metodo 1: Arquivo de configuracao**

Abra o arquivo:
```
C:\RO\LeituraOID\Ro.Controle.Start.exe.config
```

Procure por:
```xml
<add key="SecurityKey" value="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"/>
```

Copie o valor de 32 caracteres.

**Metodo 2: Pedir para o suporte da Reis Office**

Se nao encontrar, entre em contato com o suporte.

---

## Como Usar

### Ler Contadores das Impressoras

**Clique duas vezes em:**
```
LerContadores.bat
```

**O que acontece:**
1. Busca todas as impressoras cadastradas no banco
2. Faz ping para ver quais estao online
3. Le os contadores via SNMP (paginas, toner, etc)
4. Salva as leituras no banco local

**Exemplo de saida:**
```
=== Leitura SNMP de Contadores ===

Equipamentos encontrados: 40

Lendo: ABC12345 (192.168.1.100)
  [ONLINE]
  OIDs a ler: 4
    OK: TTonerB:100
    OK: TonerB:45
    OK: 123456

Lendo: XYZ67890 (192.168.1.101)
  [OFFLINE] IP nao responde

==========================================
  CONCLUIDO!
  Leituras inseridas: 125
  Equipamentos offline: 8
  Erros: 0
==========================================
```

---

### Enviar Leituras para o Servidor

**Clique duas vezes em:**
```
ForcarUpload.bat
```

**O que acontece:**
1. Autentica com o servidor RO
2. Carrega todas as leituras do banco
3. Envia em lotes para o servidor
4. Mostra progresso em tempo real

**Exemplo de saida:**
```
===========================================
  RO Controle - Forcar Upload de Leituras
===========================================

URL Base: https://rocontrole.com.br/api
ID Cliente: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Equipamentos cadastrados: 40
Leituras no banco: 15000

Enviar 15000 leituras em lotes de 500? (S/N): S

=== Autenticando ===
  Id_auth gerado
  nr_autorizacao obtido!

=== Iniciando upload ===

Lote 1/30
  Enviando 500 leituras (129.5 KB)...
  OK! (resposta: 1)
  Progresso: 500 enviadas, 0 erros

...

===========================================
  CONCLUIDO!
  Enviadas: 15000
  Erros: 0
===========================================
```

---

### Opcoes Avancadas (PowerShell)

```powershell
# Executar sem pedir confirmacao
powershell -File ForcarUpload.ps1 -Auto

# Mudar tamanho do lote (padrao: 500)
powershell -File ForcarUpload.ps1 -Lote 1000

# Modo teste (mostra o que faria, mas nao envia)
powershell -File ForcarUpload.ps1 -DryRun

# Combinar opcoes
powershell -File ForcarUpload.ps1 -Auto -Lote 1000
```

---

## Agendamento Automatico

Voce pode configurar o Windows para executar automaticamente a cada hora.

### Opcao 1: Usar CriarAgendamento.bat (Mais Facil)

1. Clique com **botao direito** em `CriarAgendamento.bat`
2. Selecione **"Executar como administrador"**
3. Pronto!

O script:
- Detecta o caminho automaticamente
- Cria o agendamento a cada 1 hora
- Se ja existir, pergunta se quer substituir

### Opcao 2: Comando Manual

Abra o **Prompt de Comando como Administrador** e cole:

```cmd
schtasks /create /tn "RO Controle" /tr "C:\CAMINHO\ExecutarTudo.bat" /sc hourly /mo 1 /ru SYSTEM
```

### Comandos Uteis

```cmd
# Testar agora (executar imediatamente)
schtasks /run /tn "RO Controle"

# Ver status do agendamento
schtasks /query /tn "RO Controle"

# Remover o agendamento
schtasks /delete /tn "RO Controle" /f

# Habilitar historico de tarefas (para ver logs no Agendador)
wevtutil set-log Microsoft-Windows-TaskScheduler/Operational /enabled:true
```

### Logs de Execucao

O `ExecutarTudo.bat` salva logs automaticamente na pasta `logs/`:

```
logs/
├── 2026-11-21.log    <- Um arquivo por dia
├── 2026-11-22.log
└── ...
```

**Conteudo do log:**
```
============================================
[21/11/2026 19:30:00] INICIANDO
============================================
[21/11/2026 19:30:00] Etapa 1: Leitura SNMP
Equipamentos encontrados: 40
Leituras inseridas: 125
[21/11/2026 19:31:00] Etapa 2: Upload
Enviados: 298429
Erros: 0
[21/11/2026 19:32:00] CONCLUIDO
============================================
```

### Protecao Contra Execucao Simultanea

Se uma execucao ja estiver em andamento, a proxima **nao executa** (evita conflitos).

Funciona assim:
1. Ao iniciar, cria arquivo `lib/.running.lock`
2. Se o lock existir, sai sem executar
3. Ao terminar, remove o lock

### ExecutarTudo.bat

Executa **leitura + upload** na ordem correta:
1. Primeiro `LerContadores` - le os contadores das impressoras
2. Depois `ForcarUpload` - envia as leituras para o servidor

**Para executar manualmente**, basta clicar duas vezes em `ExecutarTudo.bat`

### Por que .exe e .ps1?

| Arquivo | Linguagem | Motivo |
|---------|-----------|--------|
| `LerContadores.exe` | C# | Usa biblioteca SNMP do .NET |
| `ForcarUpload.ps1` | PowerShell | Mais facil de editar sem recompilar |

---

## Solucao de Problemas

### "Banco nao encontrado"

**Causa:** RO Controle nao esta instalado ou esta em outro caminho.

**Solucao:** 
1. Verifique se existe: `C:\RO\LeituraOID\tarifador.db`
2. Se estiver em outro lugar, edite `config.json` com o caminho correto

---

### "SecurityKey nao configurada"

**Causa:** As chaves nao foram encontradas automaticamente.

**Solucao:**
1. Copie `config.example.json` para `config.json`
2. Abra `C:\RO\LeituraOID\Ro.Controle.Start.exe.config`
3. Copie o valor de `SecurityKey` para o `config.json`

---

### "Nenhum equipamento encontrado"

**Causa:** Nao ha impressoras cadastradas ou todas estao com `contrato = NAO`.

**Solucao:**
1. Abra o Configurador do RO Controle
2. Verifique se as impressoras estao cadastradas
3. Verifique se estao marcadas como "Em contrato"

---

### "Todos equipamentos OFFLINE"

**Causa:** Sem acesso de rede as impressoras.

**Solucao:**
1. Verifique se esta na mesma rede das impressoras
2. Se usa VPN, verifique se esta conectado
3. Teste com: `ping 192.168.x.x` (IP de uma impressora)

---

### "ERRO: 401 Unauthorized"

**Causa:** Chaves de criptografia incorretas.

**Solucao:**
1. Verifique se copiou a `SecurityKey` corretamente
2. Deve ter exatamente 32 caracteres
3. Nao pode ter espacos extras

---

### "ERRO: 404 Not Found"

**Causa:** URL do servidor incorreta.

**Solucao:**
1. Verifique a URL no banco de dados
2. Deve ser algo como: `https://rocontrole.com.br/api`

---

## Detalhes Tecnicos

### Arquivos do Projeto

```
ro-controle-tools/
│
│   # CLIQUE AQUI (executaveis)
├── ExecutarTudo.bat       # Leitura + Upload (para agendamento)
├── LerContadores.bat      # Apenas leitura SNMP
├── ForcarUpload.bat       # Apenas upload
├── CriarAgendamento.bat   # Cria agendamento de 1 hora
│
│   # CONFIGURACAO
├── config.example.json    # Exemplo (copiar para config.json)
├── README.md              # Este arquivo
│
│   # LOGS (criado automaticamente)
├── logs/
│   └── 2026-11-21.log     # Um arquivo por dia
│
│   # BIBLIOTECAS (nao mexer)
└── lib/
    ├── LerContadores.ps1  # Script de leitura
    ├── LerContadores.exe  # Executavel SNMP
    ├── LerContadores.cs   # Codigo fonte
    ├── ForcarUpload.ps1   # Script de upload
    ├── SnmpSharpNet.dll   # Biblioteca SNMP
    ├── System.Data.SQLite.dll
    ├── x64/SQLite.Interop.dll
    └── x86/SQLite.Interop.dll
```

### Fluxo de Dados

```
┌─────────────┐    SNMP     ┌────────────────┐    SQLite    ┌──────────────┐
│ Impressoras │ ─────────>  │ LerContadores  │ ──────────>  │ tarifador.db │
└─────────────┘             └────────────────┘              └──────┬───────┘
                                                                   │
                                                                   │ SQLite
                                                                   v
┌─────────────┐    HTTPS    ┌────────────────┐              ┌──────────────┐
│ Servidor RO │ <─────────  │ ForcarUpload   │ <──────────  │ tarifador.db │
└─────────────┘             └────────────────┘              └──────────────┘
```

### API do Servidor

| Endpoint | Metodo | Uso |
|----------|--------|-----|
| `/Autorizacao` | POST | Obter token de acesso |
| `/LeituraOID/PostLeituraOidAuth` | POST | Enviar leituras |

### Estrutura do Banco SQLite

```sql
-- Impressoras cadastradas
equipamentos (id, numero_serie, ip_atual, mac_address, contrato)

-- OIDs para leitura SNMP
oids (id, oid, descricao, hexa)

-- Leituras coletadas
leitura_log (id, id_equipamento, id_oid, valor, data_leitura)
```

### Criptografia

- **Algoritmo:** RijndaelManaged (AES-256)
- **BlockSize:** 256 bits (nao padrao)
- **Mode:** CBC
- **Padding:** PKCS7

---

## Sobre

Este projeto foi desenvolvido atraves de **engenharia reversa** para permitir controle manual sobre as leituras e uploads do RO Controle.

**Nao ha afiliacao com a Reis Office.**

### Engenharia Reversa Realizada

1. Extracao do instalador Inno Setup
2. Decompilacao dos assemblies .NET com dnSpy
3. Analise do fluxo de autenticacao
4. Mapeamento do protocolo SNMP
5. Reconstrucao das queries SQL
