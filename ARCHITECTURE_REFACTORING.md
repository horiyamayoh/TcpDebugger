# TcpDebugger A[LeN`P݌v

## GO[NeBuT}[

݂TcpDebuggerR[hx[X͋@\Iɂ͓삵Ă̂́Aȉ̍{IȐ݌vۑĂ܂F

1. **MCxg̕sSȓ** - Mf[^̃CxgpCvCfAꕔ̋@\삵ĂȂ
2. **Ӗ̞B** - W[Ԃ̐ӖEsmŁAdWbNU
3. **XbhS̕s** - LԂ̓s\ŁAԂ̃XN
4. **eX^reB̌@** - Ȑ݌vɂP̃eXg
5. **ǧE** - VʐMvgR@\̒ǉ

{݌vł́ẢۑAێ琫EgEM啝ɌコIȃt@N^Ov񎦂܂B

---

## 1. 󕪐́F肳ꂽ_

### 1.1 MCxgpCvC̕f

**̖{:**
- `TcpClient.ps1`, `TcpServer.ps1`, `UdpCommunication.ps1` ̎M[v `Invoke-ConnectionAutoResponse` 𒼐ڌĂяoĂ邪AĂяoʒusK؁iMf[^擾OɎsj
- AutoResponse  OnReceived ̏ʁX̃^C~OŎsׂAł AutoResponse 삵ĂȂ

**̓IȖӏ:**

`TcpClient.ps1` (L54-55):
```powershell
# M̌AM̑OɌĂ΂ĂioOj
Invoke-ConnectionAutoResponse -ConnectionId $connId -ReceivedData $receivedData

# MiubLOj
if ($stream.DataAvailable) {
    $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
    # ... $receivedData ŏ߂Ē`
}
```

**e͈:**
- OnReceived vt@C@\Sɕs
- AutoResponse `ϐQƂăG[ɂȂ\
- `iUnifiedj[̉b󂯂Ȃ

### 1.2 Ӗ̞BƏdR[h

**̖{:**
eW[̐ӖsmŁA悤ȏӏɎU݂Ă܂B

**̗:**

1. **[ǂݍ݃WbN̏d**
   - `AutoResponse.ps1`: `Read-AutoResponseRules`
   - `OnReceivedHandler.ps1`: `Read-OnReceivedRules`
   - `ReceivedRuleEngine.ps1`: `Read-ReceivedRules`iʎj
   
    3̃W[œ悤ȏ`Ă邪Aۂɂ `ReceivedRuleEngine` gׂ

2. **LbVǗ̕U**
   - eW[Ǝ̃LbVWbN
   - LbV̖^C~OꂳĂȂ

3. **ϐXR[v̊Ǘ**
   - `Connection.Variables` lXȖړIŎgĂiݒlAsԁALbVj
   - ǂ̕ϐǂ̃W[Ŏg邩ǐՍ

### 1.3 XbhS̖

**̖{:**
}`Xbhł̋LԊǗɕ̖肪܂B

**̓IȖ:**

1. **ConnectionContext ̕Iȓ**
   ```powershell
   # Ă
   $this.Variables = [System.Collections.Hashtable]::Synchronized(@{})
   $this.SendQueue = [System.Collections.ArrayList]::Synchronized(...)
   
   # ĂȂ
   $this.Status = "CONNECTED"  # Xbh珑܂
   $this.ErrorMessage = $_.Exception.Message
   ```

2. **O[oϐւ̃ANZX**
   - `$Global:Connections` ͓Ă邪AX Connection IuWFNg͓̑ĂȂ
   - UI XbhƒʐMXbhIuWFNg𓯎ɓǂݏ

3. **^C}[Cxg̃XbhS**
   - `Register-ObjectEvent` ̃CxgnhʃXbhŎs
   - `$Global:Connections` ւ̃ANZXی삳ĂȂ

### 1.4 W[݌v̍\I

**̖{:**
C[A[LeN`̌Ă炸Aˑ֌WzĂ܂B

**ˑ֌W̖:**

```
TcpClient.ps1
   Ăяo
AutoResponse.ps1
   Ăяo
ReceivedRuleEngine.ps1
   Ăяo
MessageHandler.ps1
   Ăяo
ConnectionManager.ps1 (Send-Data)
   ANZX
$Global:Connections
   XV
TcpClient.ps1  zˑ
```

**zIȍ\:**
```
Presentation Layer (UI)
   
Application Layer (ScenarioEngine, InstanceManager)
   
Domain Layer (ConnectionManager, MessageHandler)
   
Infrastructure Layer (TcpClient, TcpServer, UDP)
```

### 1.5 G[nhOƃO̕s

**̖{:**
G[jꂳĂ炸AQ̒ǐՂłB

**̗:**

1. **G[nhO̕s**
   ```powershell
   # p^[1: try-catch ňԂ
   try { ... } catch { Write-Warning $_ }
   
   # p^[2: try-catch ŃG[𓊂
   try { ... } catch { throw }
   
   # p^[3: G[`FbNȂ
   $result = Do-Something
   # $result  $null ł̂܂܎g
   ```

2. **Ox̕s**
   - `Write-Host`, `Write-Warning`, `Write-Error` 
   - dvx̊sm
   - O̍\ȂĂȂ

### 1.6 eX^reB̌@

**̖{:**
P̃eXgƂɂ߂čȐ݌vɂȂĂ܂B

**̓Iȏ:**

1. **O[oԂւ̋ˑ**
   - ׂĂ̊֐ `$Global:Connections` ɒڃANZX
   - ˑ̎dg݂Ȃ

2. **p̑֐**
   - قƂǂ̊֐ I/O ܂
   - bN

3. **Ȑ݌v**
   - ֐Ԃ̈ˑA̊֐eXgłȂ

---

## 2. PA[LeN`݌v

### 2.1 A[LeN`

ȉ̐݌vɊÂĉPs܂F

1. **PӔC (SRP)**: eW[ENX͈̐Ӗ݂̂
2. **J (OCP)**: gɊJāACɕ݌v
3. **ˑt] (DIP)**: ۂɈˑAۂɈˑȂ
4. **֐S̕ (SoC)**: rWlXWbNAf[^ANZXAUI 𖾊mɕ
5. **C~[^reB**: \ȌsσIuWFNggp
6. **IȈˑ֌W**: O[oϐAˑ𖾎Iɒ

### 2.2 C[A[LeN`̍Đ݌v

```

  Presentation Layer (UI)                        
  - MainForm.ps1                                 
  - ViewModels (VK)                            

                  

  Application Layer                              
  - ScenarioOrchestrator (VK)                  
  - InstanceCoordinator (VK)                   
  - ProfileManager (VK)                        

                  

  Domain Layer                                   
  - ConnectionService (P ConnectionManager) 
  - MessageProcessor (P MessageHandler)     
  - ReceivedEventPipeline (VK)                 
  - RuleRepository (VK)                        

                  

  Infrastructure Layer                           
  - TcpClientAdapter (P TcpClient)          
  - TcpServerAdapter (P TcpServer)          
  - UdpAdapter (P UdpCommunication)         
  - FileRepository (VK)                        
  - Logger (VK)                                

```

### 2.3 MCxgpCvC̍Đ݌v

**Vt[:**

```
Mf[^
    
[ʐMA_v^[w]
     ReceivedEvent 𔭉
[ReceivedEventPipeline]  V݂ꂽ|Cg
    
     [tB^[] (̊g_)
     [MO]
    
[ReceivedRuleProcessor]  [}b`O
    
     [AutoResponse ]
           ev[gWJ
           ML[֒ǉ
    
     [OnReceived ]
            XNvgs
            ϐXV
```

**j:**

1. **Cxg쓮A[LeN`̓**
   ```powershell
   # ʐMA_v^[̓Cxg𔭉΂邾
   class ReceivedEventArgs {
       [string]$ConnectionId
       [byte[]]$Data
       [datetime]$Timestamp
       [object]$RemoteEndPoint
   }
   
   # pCvCCxg󂯎ď
   class ReceivedEventPipeline {
       [void] ProcessEvent([ReceivedEventArgs]$event) {
           $this.Logger.LogReceive($event)
           $this.RuleProcessor.Process($event)
       }
   }
   ```

2. **Ӗ̖mȕ**
   - ʐMw: f[^̑M̂
   - pCvCw: Cxg̃[eBO
   - [w: rWlXWbN̎s

### 2.4 ڑԊǗ̉P

**̖:**
```powershell
class ConnectionContext {
    [string]$Status  # XbhZ[tłȂ
    # ... ̃~[^uȃvpeB
}
```

**P:**

```powershell
# 1. sςȐڑݒƉςȎsԂ𕪗
class ConnectionConfiguration {
    # ǂݎp̐ݒl
    [ValidateNotNullOrEmpty()][string]$Id
    [ValidateNotNullOrEmpty()][string]$DisplayName
    [ValidateSet("TCP", "UDP")][string]$Protocol
    [ValidateSet("Client", "Server")][string]$Mode
    # ... ̑̐ݒ
    
    # ׂăRXgN^ŏAȌύXs
}

class ConnectionRuntimeState {
    # XbhZ[tȃvpeB̂
    hidden [object]$_statusLock = [object]::new()
    hidden [string]$_status = "IDLE"
    
    [string] GetStatus() {
        [System.Threading.Monitor]::Enter($this._statusLock)
        try { return $this._status }
        finally { [System.Threading.Monitor]::Exit($this._statusLock) }
    }
    
    [void] SetStatus([string]$value) {
        [System.Threading.Monitor]::Enter($this._statusLock)
        try { $this._status = $value }
        finally { [System.Threading.Monitor]::Exit($this._statusLock) }
    }
}

class ManagedConnection {
    [ConnectionConfiguration]$Config
    [ConnectionRuntimeState]$State
    [ICommunicationAdapter]$Adapter
    [VariableScope]$Variables  # p̃XR[vNX
}
```

### 2.5 W[̍ĕҐ

**VW[\:**

```
Core/
 Domain/
    ConnectionService.ps1      # ڑCtTCNǗ
    MessageProcessor.ps1       # bZ[W̒j
    ReceivedEventPipeline.ps1  # MCxg
    RuleProcessor.ps1          # [}b`OEs
    VariableScope.ps1          # XbhZ[tȕϐǗ

 Application/
    ScenarioOrchestrator.ps1   # ViIs̓
    ProfileManager.ps1         # vt@CǗ
    InstanceCoordinator.ps1    # CX^XǗ

 Infrastructure/
     Adapters/
        TcpClientAdapter.ps1
        TcpServerAdapter.ps1
        UdpAdapter.ps1
     Repositories/
        RuleRepository.ps1      # [t@Cǂݍ
        TemplateRepository.ps1  # ev[gǗ
        ScenarioRepository.ps1  # ViIt@CǗ
     Common/
         Logger.ps1              # \O
         ErrorHandler.ps1        # G[
         ThreadSafeCollections.ps1

Presentation/
 UI/
     MainForm.ps1
     ConnectionViewModel.ps1     # f[^oCfBOp
     UIUpdateService.ps1         # UIXV̓C^[tF[X
```

### 2.6 ˑRei̓

**ړI:**
- O[oϐւ̈ˑr
- eX^reB̌
- W[Ԃ̑a

**:**

```powershell
# ServiceContainer.ps1
class ServiceContainer {
    hidden [hashtable]$_services = @{}
    hidden [hashtable]$_singletons = @{}
    
    [void] RegisterSingleton([string]$name, [scriptblock]$factory) {
        $this._services[$name] = @{
            Type = 'Singleton'
            Factory = $factory
        }
    }
    
    [void] RegisterTransient([string]$name, [scriptblock]$factory) {
        $this._services[$name] = @{
            Type = 'Transient'
            Factory = $factory
        }
    }
    
    [object] Resolve([string]$name) {
        $service = $this._services[$name]
        if (-not $service) {
            throw "Service not registered: $name"
        }
        
        if ($service.Type -eq 'Singleton') {
            if (-not $this._singletons.ContainsKey($name)) {
                $this._singletons[$name] = & $service.Factory $this
            }
            return $this._singletons[$name]
        }
        
        return & $service.Factory $this
    }
}

# AvP[VN̓o^
$container = [ServiceContainer]::new()

$container.RegisterSingleton('Logger', {
    param($c)
    [Logger]::new("TcpDebugger.log")
})

$container.RegisterSingleton('ConnectionService', {
    param($c)
    $logger = $c.Resolve('Logger')
    [ConnectionService]::new($logger)
})

$container.RegisterSingleton('ReceivedEventPipeline', {
    param($c)
    $logger = $c.Resolve('Logger')
    $ruleProcessor = $c.Resolve('RuleProcessor')
    [ReceivedEventPipeline]::new($logger, $ruleProcessor)
})

# gp
$connectionService = $container.Resolve('ConnectionService')
$connectionService.StartConnection($connectionId)
```

---

## 3. iKIȈڍsv

### tF[Y0: iXNȂj

**ړI:** @\󂳂ɁAVA[LeN`̊Ղ\z

**Ɠe:**

1. **VW[̍쐬**
   - `Core/Common/Logger.ps1` - \O
   - `Core/Common/ErrorHandler.ps1` - G[nhO
   - `Core/Domain/VariableScope.ps1` - XbhZ[tȕϐǗ
   - `Core/Infrastructure/ServiceContainer.ps1` - DI Rei

2. **jbgeXg̍\z**
   - `Tests/` tH_쐬
   - Pester eXgt[[N
   - {IȃeXgP[X쐬

3. **hLg**
   - W[Ӗ}gNX쐬
   - API t@X

**:**
- R[hɈؕύXȂ
- VW[PƂŃeXg\
- CI/CD pCvC\z

### tF[Y1: MCxgpCvC̏CiDxj

**ړI:** ݓ삵ĂȂMCxgC

**Ɠe:**

1. **̏CioOtBbNXj**
   
   `TcpClient.ps1` ̏C:
   ```powershell
   # COioOj
   Invoke-ConnectionAutoResponse -ConnectionId $connId -ReceivedData $receivedData
   if ($stream.DataAvailable) {
       $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
       if ($bytesRead -gt 0) {
           $receivedData = $buffer[0..($bytesRead-1)]
           # ...
       }
   }
   
   # C
   if ($stream.DataAvailable) {
       $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
       if ($bytesRead -gt 0) {
           $receivedData = $buffer[0..($bytesRead-1)]
           
           # Mobt@ɒǉ
           [void]$conn.RecvBuffer.Add(...)
           
           # CxgĂяo
           
           $conn.LastActivity = Get-Date
       }
   }
   ```
   
   l̏C `TcpServer.ps1`, `UdpCommunication.ps1` ɂKp

2. **ReceivedEventPipeline ̋**
   ```powershell
   # ReceivedEventPipeline.ps1 (VK쐬)
   class ReceivedEventPipeline {
       [Logger]$Logger
       [RuleProcessor]$RuleProcessor
       
       [void] ProcessReceivedData([string]$connectionId, [byte[]]$data) {
           # OL^
           $this.Logger.LogReceive($connectionId, $data)
           
           # ڑ擾
           $conn = $this.GetConnection($connectionId)
           if (-not $conn) { return }
           
           # [iAutoResponse + OnReceived j
           $this.RuleProcessor.ProcessRules($conn, $data)
       }
   }
   ```

**:**
- OnReceived vt@C
- AutoResponse Mɐs
- `iUnifiedj[S

**XN]:** 
- ̓Ă镔ւ̉eŏ
- oOC

### tF[Y2: ڑǗ̉PiDxj

**ړI:** XbhZ[tȐڑǗƃCtTCN

**Ɠe:**

1. **ConnectionService ̓**
   ```powershell
   class ConnectionService {
       hidden [hashtable]$_connections
       hidden [Logger]$_logger
       hidden [object]$_lock = [object]::new()
       
       ConnectionService([Logger]$logger) {
           $this._connections = [System.Collections.Hashtable]::Synchronized(@{})
           $this._logger = $logger
       }
       
       [ManagedConnection] GetConnection([string]$id) {
           return $this._connections[$id]
       }
       
       [void] AddConnection([ConnectionConfiguration]$config) {
           [System.Threading.Monitor]::Enter($this._lock)
           try {
               if ($this._connections.ContainsKey($config.Id)) {
                   throw "Connection already exists: $($config.Id)"
               }
               
               $conn = [ManagedConnection]::new($config)
               $this._connections[$config.Id] = $conn
               $this._logger.LogInfo("Connection added: $($config.Id)")
           }
           finally {
               [System.Threading.Monitor]::Exit($this._lock)
           }
       }
       
       [void] StartConnection([string]$id) {
           $conn = $this.GetConnection($id)
           if (-not $conn) {
               throw "Connection not found: $id"
           }
           
           $conn.Adapter.Start()
           $conn.State.SetStatus("CONNECTED")
           $this._logger.LogInfo("Connection started: $id")
       }
   }
   ```

2. **iKIȈڍs**
   - VKڑ `ConnectionService` gp
   - R[h `$Global:Connections` oR `ConnectionService` ɃANZX
   - XɒڃANZXu

**:**
- ׂĂ̐ڑ삪 ConnectionService oR
- XbhS̖肪[
- @\̓mF

### tF[Y3: bZ[W̓iDxj

**ړI:** dbZ[WWbN̓

**Ɠe:**

1. **MessageProcessor ̓**
   ```powershell
   class MessageProcessor {
       [TemplateRepository]$TemplateRepo
       [Logger]$Logger
       
       [byte[]] ProcessTemplate([string]$templatePath, [hashtable]$variables) {
           # ev[gǂݍ݁iLbVtj
           $template = $this.TemplateRepo.GetTemplate($templatePath)
           
           # ϐWJ
           $expanded = $this.ExpandVariables($template, $variables)
           
           # oCgzɕϊ
           return $this.ConvertToBytes($expanded, $template.Encoding)
       }
   }
   ```

2. **[̓**
   - `AutoResponse.ps1`, `OnReceivedHandler.ps1` ̃WbN `RuleProcessor` ɏW
   - LbVǗ `RuleRepository` Ɉꌳ

**:**
- dR[hSɔr
- LbVqbg̉
- ptH[}XeXg

### tF[Y4: UIw̉PiDxj

**ړI:** MVVM p^[̓Kpƃf[^oCfBỎP

**Ɠe:**

1. **ViewModel ̓**
   ```powershell
   class ConnectionViewModel {
       [string]$Id
       [string]$DisplayName
       [string]$Status
       [ObservableCollection]$AvailableProfiles
       [string]$SelectedProfile
       
       # INotifyPropertyChanged ̎
   }
   ```

2. **UIXV̔񓯊**
   - UI XbhƒʐMXbh̊S
   - `Invoke` gS UI XV

**:**
- UI t[YȂ
- ڑԂA^Cɔf
- ̌

---

## 4. KChC

### 4.1 R[fBOK

**PowerShell NX݌v:**

```powershell
# ǂ
class GoodExample {
    # vCx[gtB[h hidden + A_[XRA
    hidden [Logger]$_logger
    
    # pubNvpeB͓ǂݎp
    [string]$Id
    
    # RXgN^ňˑ
    GoodExample([Logger]$logger, [string]$id) {
        $this._logger = $logger
        $this.Id = $id
    }
    
    # \bh͓-`
    [void] ProcessData([byte[]]$data) {
        try {
            # 
        }
        catch {
            $this._logger.LogError("ProcessData failed", $_)
            throw
        }
    }
}

# 
class BadExample {
    $Logger  # ^wȂ
    [string]$Id  # ~[^u
    
    BadExample() {
        $this.Logger = Get-GlobalLogger  # O[oˑ
    }
    
    [void] DoStuff($data) {  # ^wȂABȖO
        # G[nhOȂ
    }
}
```

**֐݌v:**

```powershell
# ǂ
function Invoke-MessageProcessing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionId,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [byte[]]$Data,
        
        [Parameter(Mandatory=$false)]
        [MessageProcessor]$Processor = $script:DefaultProcessor
    )
    
    begin {
        $ErrorActionPreference = 'Stop'
        Write-Verbose "Processing message for connection: $ConnectionId"
    }
    
    process {
        try {
            $result = $Processor.Process($ConnectionId, $Data)
            return $result
        }
        catch {
            Write-Error "Message processing failed: $_"
            throw
        }
    }
}
```

### 4.2 G[nhO헪

**3wG[nhO:**

```powershell
# Layer 1: Infrastructure (჌xG[)
class TcpClientAdapter {
    [void] Send([byte[]]$data) {
        try {
            $this._socket.Send($data)
        }
        catch [System.Net.Sockets.SocketException] {
            # \PbgŗL̃G[rWlXOɕϊ
            throw [CommunicationException]::new(
                "Failed to send data",
                $_.Exception
            )
        }
    }
}

# Layer 2: Domain (rWlXWbNG[)
class ConnectionService {
    [void] StartConnection([string]$id) {
        $conn = $this.GetConnection($id)
        if (-not $conn) {
            # rWlX[ᔽ
            throw [InvalidOperationException]::new(
                "Connection not found: $id"
            )
        }
        
        try {
            $conn.Adapter.Start()
        }
        catch [CommunicationException] {
            # CtG[OčăX[
            $this._logger.LogError("Connection start failed", $id, $_.Exception)
            throw
        }
    }
}

# Layer 3: Application/UI ([U[G[)
function Start-ConnectionFromUI {
    param([string]$ConnectionId)
    
    try {
        $connectionService.StartConnection($ConnectionId)
        Show-SuccessMessage "Connection started successfully"
    }
    catch [InvalidOperationException] {
        Show-ErrorMessage "Connection does not exist. Please refresh the list."
    }
    catch [CommunicationException] {
        Show-ErrorMessage "Failed to establish connection. Check network settings."
    }
    catch {
        Show-ErrorMessage "An unexpected error occurred: $($_.Exception.Message)"
    }
}
```

### 4.3 O헪

**\O̎:**

```powershell
class Logger {
    hidden [string]$_logPath
    hidden [object]$_lock = [object]::new()
    
    [void] LogInfo([string]$message, [hashtable]$context = @{}) {
        $this.Log("INFO", $message, $context)
    }
    
    [void] LogError([string]$message, [Exception]$exception, [hashtable]$context = @{}) {
        $context['Exception'] = $exception.ToString()
        $context['StackTrace'] = $exception.StackTrace
        $this.Log("ERROR", $message, $context)
    }
    
    hidden [void] Log([string]$level, [string]$message, [hashtable]$context) {
        $entry = [PSCustomObject]@{
            Timestamp = (Get-Date).ToString("o")
            Level = $level
            Message = $message
            Context = $context
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }
        
        [System.Threading.Monitor]::Enter($this._lock)
        try {
            $json = $entry | ConvertTo-Json -Compress
            Add-Content -Path $this._logPath -Value $json
        }
        finally {
            [System.Threading.Monitor]::Exit($this._lock)
        }
    }
}

# gp
$logger.LogInfo("Connection started", @{
    ConnectionId = "conn-001"
    Protocol = "TCP"
    RemoteEndpoint = "192.168.1.100:8080"
})
```

### 4.4 eXg헪

**jbgeXg̗iPesterj:**

```powershell
# Tests/Unit/Core/Domain/MessageProcessor.Tests.ps1
Describe 'MessageProcessor' {
    BeforeAll {
        # bN̏
        $mockLogger = [PSCustomObject]@{
            LogInfo = { param($msg) }
            LogError = { param($msg, $ex) }
        }
        
        $mockTemplateRepo = [PSCustomObject]@{
            GetTemplate = { 
                param($path)
                return [PSCustomObject]@{
                    Format = "Test {var}"
                    Encoding = "UTF-8"
                }
            }
        }
        
        $processor = [MessageProcessor]::new($mockTemplateRepo, $mockLogger)
    }
    
    Context 'ProcessTemplate' {
        It 'Should expand variables correctly' {
            $variables = @{ var = "Value" }
            $result = $processor.ProcessTemplate("test.csv", $variables)
            
            $result | Should -Not -BeNullOrEmpty
            $resultString = [System.Text.Encoding]::UTF8.GetString($result)
            $resultString | Should -Be "Test Value"
        }
        
        It 'Should throw on missing template' {
            $mockTemplateRepo.GetTemplate = { throw "Not found" }
            
            { $processor.ProcessTemplate("missing.csv", @{}) } | Should -Throw
        }
    }
}
```

---

## 5. }CO[V`FbNXg

### tF[Y1iMCxgCj

- [ ] `TcpClient.ps1` ̎MC
- [ ] `TcpServer.ps1` ̎MC
- [ ] `UdpCommunication.ps1` ̎MC
- [ ] `ReceivedEventPipeline.ps1` 쐬
- [ ] eXg OnReceived mF
- [ ] `[̓mF
- [ ] ViỈAeXg

### tF[Y2iڑǗPj

- [ ] `ConnectionConfiguration` NX쐬
- [ ] `ConnectionRuntimeState` NX쐬
- [ ] `ManagedConnection` NX쐬
- [ ] `ConnectionService` NX쐬
- [ ] `ServiceContainer` 쐬
- [ ] R[h̒iKIڍs
- [ ] XbhS̃eXg
- [ ] ptH[}XeXg

### tF[Y3ibZ[Wj

- [ ] `MessageProcessor` NX쐬
- [ ] `RuleProcessor` NX쐬
- [ ] `TemplateRepository` NX쐬
- [ ] `RuleRepository` NX쐬
- [ ] LbVWbN̓
- [ ] dR[h̍폜
- [ ] ptH[}XeXg

### tF[Y4iUIPj

- [ ] `ConnectionViewModel` 쐬
- [ ] `UIUpdateService` 쐬
- [ ] f[^oCfBO
- [ ] 񓯊UIXV̎
- [ ] eXg

---

## 6. XNǗ

### XN

1. **}`Xbh̕ύX**
   - **XN:** fbhbNAԂ̔
   - **y:** 
     - iKIȈڍs
     - OꂵXbhZ[teBeXg
     - bN͈͂̍ŏ

2. **@\̔j**
   - **XN:** t@N^Oɂ蓮쒆̋@\~
   - **y:**
     - IȉAeXgXC[g
     - tB[`[tOɂiKIL
     - [obNv

### XN

1. **ptH[}X**
   - **XN:** ۉw̒ǉɂI[o[wbh
   - **y:**
     - ptH[}Xx`}[Ňp{
     - vt@COc[̎gp
     - zbgpX̍œK

2. **wKȐ**
   - **XN:** VA[LeN`̗ɎԂ
   - **y:**
     - ڍׂȃhLg쐬
     - TvR[h̒
     - yAvO~O

---

## 7. ҂

### i

- **oO팸:** ݓ삵ĂȂ OnReceived @\̏C
- **萫:** XbhZ[teB̓Oɂ鋣Ԃ̔r
- **ێ琫:** Ӗ̖mɂAoO̓ECeՂ

### J

- **eX^reB:** jbgeXgJobW 0%  80%ȏ
- **g:** V@\ǉ̉e͈͂I
- **ǐ:** R[ḧӐ}mŁAVKQ҂̃I{[fBOe

### ptH[}X

- **X[vbg:** LbVœKɂ 10-20% ㌩
- **:** UI Xbh̕ɂ̊x
- **\[X:** svȃIuWFNg̍팸

---

## 8. Ql

### ݌vp^[

- **Repository p^[:** f[^ANZXWbN̒ۉ
- **Service p^[:** rWlXWbÑJvZ
- **Dependency Injection:** aȐ݌v
- **Event-Driven Architecture:** 񓯊̐
- **MVVM p^[:** UI ƃrWlXWbN̕

### PowerShell xXgvNeBX

- [PowerShell Practice and Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style/)
- [The PowerShell Best Practices and Style Guide](https://github.com/PoshCode/PowerShellPracticeAndStyle)

### A[LeN`Ql

- Clean Architecture (Robert C. Martin)
- Domain-Driven Design (Eric Evans)
- Patterns of Enterprise Application Architecture (Martin Fowler)

---

## 9. ̃Xebv

1. **{݌ṽr[**
   - ֌W҂ɂ݌vr[
   - tB[hobN̔f

2. **vg^Cv쐬**
   - tF[Y1̈ꕔIɎ
   - ZpIȎ\̌

3. **ڍ׃XPW[̍**
   - etF[Y̍Hς
   - \[Xz

4. **LbNIt**
   - `[Ŝł̕jL
   - Š

---

## t^A: vNXdl

### A.1 ConnectionService

```powershell
<#
.SYNOPSIS
ڑ̃CtTCNǗRAT[rX

.DESCRIPTION
XbhZ[tȐڑǗ񋟂Aڑ̍쐬EJnE~E폜𓝊B
ׂĂ̐ڑ͂̃T[rXoRčsB
#>
class ConnectionService {
    # vCx[gtB[h
    hidden [hashtable]$_connections
    hidden [Logger]$_logger
    hidden [object]$_lock
    
    # RXgN^
    ConnectionService([Logger]$logger) {
        $this._connections = [System.Collections.Hashtable]::Synchronized(@{})
        $this._logger = $logger
        $this._lock = [object]::new()
    }
    
    # pubN\bh
    [ManagedConnection] GetConnection([string]$id) { }
    [void] AddConnection([ConnectionConfiguration]$config) { }
    [void] RemoveConnection([string]$id) { }
    [void] StartConnection([string]$id) { }
    [void] StopConnection([string]$id) { }
    [ManagedConnection[]] GetAllConnections() { }
    [ManagedConnection[]] GetConnectionsByGroup([string]$group) { }
    [ManagedConnection[]] GetConnectionsByTag([string]$tag) { }
}
```

### A.2 ReceivedEventPipeline

```powershell
<#
.SYNOPSIS
MCxg̓pCvC

.DESCRIPTION
ׂĂ̎Mf[^͂̃pCvCʉ߂A[EOL^E
Cxg΂IɍsB
#>
class ReceivedEventPipeline {
    hidden [Logger]$_logger
    hidden [RuleProcessor]$_ruleProcessor
    
    ReceivedEventPipeline([Logger]$logger, [RuleProcessor]$ruleProcessor) {
        $this._logger = $logger
        $this._ruleProcessor = $ruleProcessor
    }
    
    [void] ProcessReceivedData([string]$connectionId, [byte[]]$data) {
        # MOL^
        $this._logger.LogReceive($connectionId, $data)
        
        # [iAutoResponse + OnReceivedj
        $this._ruleProcessor.ProcessRules($connectionId, $data)
    }
}
```

### A.3 MessageProcessor

```powershell
<#
.SYNOPSIS
bZ[W̒jNX

.DESCRIPTION
ev[gWJAϐuAGR[fBOϊȂǁA
bZ[WɊւ邷ׂĂ̋@\񋟂B
#>
class MessageProcessor {
    hidden [TemplateRepository]$_templateRepo
    hidden [Logger]$_logger
    
    MessageProcessor([TemplateRepository]$templateRepo, [Logger]$logger) {
        $this._templateRepo = $templateRepo
        $this._logger = $logger
    }
    
    [byte[]] ProcessTemplate(
        [string]$templatePath,
        [hashtable]$variables
    ) {
        # ev[g擾iLbVtj
        $template = $this._templateRepo.GetTemplate($templatePath)
        
        # ϐWJ
        $expanded = $this.ExpandVariables($template.Format, $variables)
        
        # oCgzɕϊ
        return $this.ConvertToBytes($expanded, $template.Encoding)
    }
    
    hidden [string] ExpandVariables([string]$format, [hashtable]$variables) { }
    hidden [byte[]] ConvertToBytes([string]$data, [string]$encoding) { }
}
```

---

## t^B: pW

| p | ` |
|------|------|
| **Connection** | TCP/UDP ̕IȐڑB1̃\PbgɑΉ |
| **Instance** | 1̒ʐMCX^XBtH_PʂŊǗ |
| **Profile** | Auto Response / OnReceived / Periodic Send ̐ݒZbg |
| **Rule** | Mf[^ɑ΂}b`OƃANV` |
| **Template** | d̐`BϐWJ@\ |
| **Scenario** | ȂMANV`CSVt@C |
| **Pipeline** | f[^ʉ߂鏈̗ |
| **Adapter** | ̒ʐMvgR̎𒊏ۉNX |
| **Repository** | f[^̉iE擾SNX |
| **Service** | rWlXWbN񋟂NX |

---

**o[W:** 1.0  
**쐬:** 2025-01-16  
**ŏIXV:** 2025-01-16  
**Xe[^X:** Draft - r[҂
