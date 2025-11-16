# TCP Test Controller

TCP/UDPʐM̃eXgEfobOs߂̎ułBݒt@Cx[XŃViIs\ŁAoIɐڑԂmFłGUIĂ܂B

## dvȒ
{Av Windows  Powershell Ŏs邽߃eLXgGR[fBO UTF8 ł͂Ȃ Shift-JIS 𗘗pĂB

## A[LeN`Tv
- `TcpDebugger.ps1`  Modules/ ȉ̒ʐMEW[ UI/MainForm.ps1  dot-source AWinForms ŐڑEViIsEM[ݒꌳĂB
- `ConnectionManager.ps1`  ConnectionContext ML[/Mobt@/ϐXR[v/^C}[𓯊tŕێA`TcpClient.ps1` `TcpServer.ps1` `UdpCommunication.ps1` ̊eXbhB
- `ScenarioEngine.ps1`  CSV x[X SEND/WAIT/LOOP/TIMER ANV߂A`QuickSender.ps1`  `templates/databank.csv` ǂݏoĒ^bZ[W𐶐B
- `AutoResponse.ps1` + `ReceivedRuleEngine.ps1`  AutoResponse/OnReceived/Unified [𔻕ʂăev[gXNvgWJA`MessageHandler.ps1`/`OnReceivedLibrary.ps1` ev[gWJoCg API 񋟂B
- `UI/MainForm.ps1`  DataGridView  Auto Response / On Received / Periodic Send / Quick Action ʂ `Set-ConnectionAutoResponseProfile` Ȃǂ API 𒼐ڌĂсAvt@CؑւViIs𑦎fłB

## 

- **ڑ̓Ǘ**: TCP/UDP̕ڑ𓯎ɈAꌳǗ
- **ViIs**: CSV`̃ViIt@CőMV[PX`
- **ϐ@\**: Mf[^ϐƂĕۑA񑗐MɓIɖߍ
- ****: Mp^[ɉԐM@\
- **f[^oN**: 悭gdev[gƂĊǗANbNM
- **lbg[Nff**: Ping/|[gaʊmFȂǁAڑguV[eBO@\
- **GUIC^[tF[X**: WinFormsx[X̃VvŎg₷UI

## Kv

- **OS**: Windows 10/11
- **PowerShell**: 5.1ȍ~iWindowsWځj
- **.NET Framework**: WindowsW
- **ǉCXg[**: sv

## CXg[

1. |WgN[܂ZIPŃ_E[h
2. Cӂ̃tH_ɓWJ
3. `TcpDebugger.ps1`s

```powershell
# s|V[ꎞIɕύXꍇ
powershell.exe -ExecutionPolicy Bypass -File ".\TcpDebugger.ps1"

# ܂́Ã݂ZbVŎs|V[ύX
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\TcpDebugger.ps1
```

## fBNg\

```
TcpDebugger/
 TcpDebugger.ps1              # CXNvgiNt@Cj
 DESIGN.md                    # ݌v
 README.md                    # {t@C
 Modules/                     # @\W[Q
    ConnectionManager.ps1        # ڑǗ
    TcpClient.ps1               # TCPNCAg
    TcpServer.ps1               # TCPT[o[
    UdpCommunication.ps1        # UDPʐM
    ScenarioEngine.ps1          # ViIs
    MessageHandler.ps1          # bZ[W
    AutoResponse.ps1            # 
    QuickSender.ps1             # NCbNM
    InstanceManager.ps1         # CX^XǗ
    NetworkAnalyzer.ps1         # lbg[Nff
 Config/                      # ʐݒ
    defaults.psd1                # ftHgݒ
 Instances/                   # ʐMCX^XtH_Q
    Example/                     # TvCX^X
        instance.psd1            # CX^Xݒ
        scenarios/               # ViIt@C
           echo_test.csv
        templates/               # dev[g
            databank.csv
            messages.csv
 Scripts/                     # JX^XNvgigpj
 UI/                          # UI`
     MainForm.ps1                # CtH[
```

## m̐
- `TcpClient.ps1`  `UdpCommunication.ps1` ł `Invoke-ConnectionAutoResponse` ̌ĂяoʒuMOɂA`receivedData` `̂܂ܕ]鋰ꂪB
- `UI/MainForm.ps1`  Periodic Send ݒŖ` `Get-InstancePath` QƂĂA`Connection.Variables['InstancePath']` ȂǂgCKvB
- `ScenarioEngine.ps1`  IF ANV (`Invoke-IfAction`) ͖̌xo߁AtViI͂܂słȂB
- OnReceived vt@Cؑւ Unified [oRł̂݌ʂA OnReceived CSV 𐶂ɂ͎M[v `Invoke-ConnectionOnReceived` gݍޕKvB

## gp@

### 1. CX^X̍쐬

`Instances/` tH_zɐVtH_쐬A`instance.psd1` t@Czu܂B

**: Instances/MyServer/instance.psd1**

```powershell
@{
    Id = "my-server"
    DisplayName = "My TCP Server"
    Description = "eXgpTCPT[o["
    
    Connection = @{
        Protocol = "TCP"           # TCP/UDP
        Mode = "Server"           # Client/Server/Sender/Receiver
        LocalIP = "127.0.0.1"
        LocalPort = 9000
        RemoteIP = ""
        RemotePort = 0
    }
    
    AutoStart = $false
    AutoScenario = ""
    
    Tags = @("Test", "TCP")
    Group = "TestServers"
    
    DefaultEncoding = "UTF-8"
}
```

### 2. AvP[V̋N

```powershell
.\TcpDebugger.ps1
```

GUINA`Instances/` z̃CX^XIɓǂݍ܂܂B

### 3. ڑ̊Jn

1. CX^XꗗڑCX^XI
2. **Connect**{^NbN
3. Xe[^X񂪁uCONNECTEDvɂȂΐڑ

### 4. f[^M

`Instances/Example/scenarios/loop_test.csv` ɂ̓lXg[v܂ރeXgViIpӂĂA蓮sœmFł܂B

- **LOOP**: wubNJԂs܂B`Parameter1`  `BEGIN` ܂ `END` w肵A`Parameter2` ŉ (`COUNT=3` Ȃ)A`Parameter3` ŔCӂ̃x (`LABEL=outer` Ȃ) w肵܂Bxt邱ƂŃlXg[vǗł܂B
  ```csv
  1,LOOP,BEGIN,COUNT=2,LABEL=outer,Outer loop start
  2,LOOP,BEGIN,COUNT=3,LABEL=inner,Inner loop start
  3,SEND,Inner iteration ${TIMESTAMP},UTF-8,,Example payload
  4,LOOP,END,LABEL=inner,,Close inner loop
  5,LOOP,END,LABEL=outer,,Close outer loop
  ```
  ̌݊` (`LOOP,1,,COUNT=3` Ȃ) T|[g܂AlXgɂ͑Ή܂B

݂̃o[Wł́AViI@\gpăf[^𑗐M܂B

**ViIt@C̗: scenarios/simple_send.csv**

```csv
Step,Action,Parameter1,Parameter2,Parameter3,Description
1,SEND,Hello World!,UTF-8,,eLXgM
2,WAIT_RECV,TIMEOUT=5000,,,ҋ@
3,SAVE_RECV,VAR_NAME=response,,,Mf[^ۑ
4,SEND,Echo: ${response},UTF-8,,Mf[^GR[obN
```

### 5. ViI̎s

PowerShellR\[ȉ̃R}hŃViIsł܂F

```powershell
# CX^X̃pXw
$scenarioPath = "C:\path\to\TcpDebugger\Instances\Example\scenarios\echo_test.csv"
$connectionId = "example-server"

# ViIs
Start-Scenario -ConnectionId $connectionId -ScenarioPath $scenarioPath
```

### 6. vt@C̐؂ւ

- eCX^XtH_ `scenarios/auto/` zɁAMgK[Ɖe`CSVt@Czu܂B
- ꗗʂ **Auto Response** 񂩂vt@CIƁAI𒆂̐ڑɑɓKp܂B
- vt@Cu(None)vɖ߂Ǝ𖳌ł܂B

#### Auto Responseł̃ViIs

- Auto Responsẽhbv_Eɂ́AspViI `? t@C` `ŕ\܂B
- ViIsIƑ `Start-Scenario` ĂяoAZ̑IԂ͒Õvt@Cɖ߂܂iݒ肪ς邱Ƃ͂܂jB
- UI DataGridView ̃G[oȂ悤Ƀof[VĂ邽߁ASɃViIgK[ł܂Bsꍇ͏]ʂ胁bZ[W{bNXŒʒm܂B

#### @\̓p

- **Auto Response**A**On Received**A**Periodic Send** ̊e͊SɓƗĂ܂BCӂ̑gݍ킹Ńvt@CIĂAق̗̐ݒ肪㏑邱Ƃ͂܂B
- Auto ResponseŎݒ肵AOn ReceivedŃXNvggK[A Periodic Send Œd𗬂Ƃł܂B
- ̐ݒ͐ڑƂɕێAGUIXVĂێ܂BKpɎsꍇ̂݌x_CAO\A̐ݒ֎IɃ[obN܂B

**: Instances/Example/scenarios/auto/normal.csv**

```csv
TriggerPattern,ResponseTemplate,Encoding,Delay,MatchType
PING,PONG,UTF-8,0,Exact
REQUEST,OK ${TIMESTAMP},UTF-8,100,Contains
```

**: Instances/Example/scenarios/auto/error.csv**

```csv
TriggerPattern,ResponseTemplate,Encoding,Delay,MatchType
PING,ERROR_TIMEOUT,UTF-8,3000,Exact
REQUEST,ERROR 500,UTF-8,0,Contains
```

## ViIANV

### MANV

- **SEND**: eLXgf[^MiϐWJΉj
  ```csv
  1,SEND,Hello ${TIMESTAMP},UTF-8,,ݎ܂ވA
  ```

- **SEND_HEX**: HEXf[^M
  ```csv
  1,SEND_HEX,48656C6C6F,,,uHellovHEXőM
  ```

- **SEND_FILE**: t@CeM
  ```csv
  1,SEND_FILE,C:\data\test.bin,,,oCit@CM
  ```

### MANV

- **WAIT_RECV**: Mҋ@
  ```csv
  1,WAIT_RECV,TIMEOUT=5000,PATTERN=OK,,uOKv܂ރf[^ҋ@
  ```

- **SAVE_RECV**: Mf[^ϐɕۑ
  ```csv
  1,SAVE_RECV,VAR_NAME=mydata,,,Mf[^mydataϐɕۑ
  ```

### ANV

- **SLEEP**: ҋ@
  ```csv
  1,SLEEP,1000,,,1bҋ@
  ```

- **SET_VAR**: ϐݒ
  ```csv
  1,SET_VAR,counter,10,,counterϐ10ݒ
  ```

- **TIMER_START / START_TIMER / TIMER_SEND**: ^C}ŒMi񓯊j
  ```csv
  1,TIMER_START,HEARTBEAT ${TIMESTAMP},INTERVAL=2000,NAME=hb,,2bƂɃn[gr[gM
  2,WAIT_RECV,TIMEOUT=5000,,,M҂Ȃ^C}Mp
  3,TIMER_STOP,NAME=hb,,,o^ς݃^C}~
  ```
  - `Parameter1`: MbZ[WiϐWJj
  - `Parameter2/3`: `INTERVAL=<~b>`A`DELAY=<x>`A`ENCODING=<R[h>`A`NAME=<ʎq>`A`COUNT=<M>` Ȃǂw\

- **TIMER_STOP / STOP_TIMER**: ^C}~i`Parameter1=ALL` őS~j
  ```csv
  1,TIMER_STOP,ALL,,,o^ς݃^C}S~
  ```


- **CALL_SCRIPT**: JX^XNvgs
  ```csv
  1,CALL_SCRIPT,Scripts\custom.ps1,,,OXNvgs
  ```

- **DISCONNECT**: ؒf
  ```csv
  1,DISCONNECT,,,,ڑؒf
  ```

- **RECONNECT**: Đڑ
  ```csv
  1,RECONNECT,,,,ؒfčĐڑ
  ```

## ϐWJ

bZ[Wňȉ̕ϐgpł܂F

- `${ϐ}`: [U[`ϐiSAVE_RECVŕۑf[^Ȃǁj
- `${TIMESTAMP}`: ݎiyyyyMMddHHmmss`j
- `${DATETIME:format}`: w
- `${RANDOM:min-max}`: _li: `${RANDOM:1-100}`j
- `${SEQ:name}`: V[PXԍiCNgj
- `${CALC:expression}`: vZ]

**:**
```csv
1,SEND,TIME=${TIMESTAMP}|SEQ=${SEQ:main}|RAND=${RANDOM:1-100},UTF-8,,
```

## f[^oN

`templates/databank.csv` ł悭gdev[gł܂B

```csv
DataID,Category,Description,Type,Content
HELLO,Basic,A,TEXT,Hello!
PING,Health,aʊmF,TEXT,PING
STATUS,Status,Xe[^Xv,TEMPLATE,STATUS|TIME=${TIMESTAMP}
```

̃o[WGUI烏NbNM@\\łB

## lbg[Nff

PowerShellR\[ff@\sł܂F

```powershell
# ڑIDw肵Đffs
Invoke-ComprehensiveDiagnostics -ConnectionId "example-server"
```

sʁF
- PingaʊmF
- |[gJ
- [eBO
- ANV

## guV[eBO

### ڑłȂ

1. lbg[NffsĖӏ
2. t@CAEH[ݒmF
3. ΏۑuNĂ邩mF
4. IPAhXA|[gԍmF

### ViIsȂ

1. CSVt@Č`mF
2. t@CpXmF
3. G[bZ[WR\[ŊmF

### GUINȂ

1. PowerShell 5.1ȍ~CXg[Ă邩mF
2. s|V[mF: `Get-ExecutionPolicy`
3. W[t@CzuĂ邩mF

### Ctrl + C ŏI

- PowerShellR\[ `TcpDebugger.ps1` sĂꍇA`Ctrl + C` GUIɏIvAIɃtH[܂B
- GUIȂꍇ́AEBhEÉ~{^ŏI邩AʃR\[ `Stop-Process -Name powershell` ȂǂŃvZXIĂB

## ̊g\

- [ ] GUĨViIsE~
- [ ] GUĨNCbNMif[^oNAgj
- [ ] MȌڍו\
- [ ] ÕGNX|[g@\
- [ ] CX^Xւ̈ꊇM
- [ ] vgR̓vOC
- [ ] \@\

## CZX

{\tgEFA͋EړIŒ񋟂Ă܂B

## o[W

- **v1.0.0** (2025-11-15): Ń[X
  - {ITCP/UDPʐM@\
  - ViIsGW
  - ϐ@\E
  - WinFormsx[XGUI
  - lbg[Nff@\

## ₢킹

s@\v]́AGitHubIssuesł񍐂B
