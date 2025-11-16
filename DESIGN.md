# TCP/IP u ݌v

## 1. Tv

### 1.1 ړI
TCP/UDPʐM̃eXgEfobOs߂̎u񋟂B
ݒt@Cx[XŃViIs\ŁAoIɐڑԂmFłGUIB

### 1.2 s
- **OS**: Windows 10/11
- **s**: PowerShell 5.1ȍ~iǉCXg[svj
- **GUI**: Windows Forms (WinForms)BWPFPoCx̃IvVƂAłWinFormsŒ񋟁B
- **O**: .NET FrameworkiWindowsWځj

### 1.3 ݌vj
- **M` (Send-First Architecture)**: {c[͑MŏdvAVbgMf[^ؑւŏANVōsUI^API񋟂BMf[^͊mFp̍ŏ\ɗ߂B
- **w (Test-Oriented)**: Č̍ViIƃf[^oNł̓dǗAƎ҂Ɏp^[؂ւ邱ƂdB
- **XP[uǗ (Scalable Instance Management)**: 10?20ȏ̒ʐMCX^X_O[vE^OŐAтƈꊇ񋟂B
- **1tH_=1CX^X**: ׂĂ̒ʐMCX^X̓tH_PʂŊǗAݒEViIEOSɓƗB
- **ffx (Diagnostic Support)**: lbg[NaʊmFA|[gJ`FbNA[eBOmF񋟂Aグ̌˘f炷B

### 1.4 x`}[NiUdome Socket Debuggerj
> J񂨂ьꗘpԂɊÂʓIȋ@\rBڍ׎dlsȉӏ͐܂ށB

| ϓ_ | Udome Socket Debugger () | {݌v̗Dʐ |
| --- | --- | --- |
| ڑ | P or \Pbg̎蓮ؑ | 10?20ȏ_O[vœ^pAoN\ |
| M | eLXg/HEX́{^M | f[^oNŃev[gւANbNM |
| ViI | XNvg/}N | CSVViI{PowerShellgAEE[vȌLq |
| M\ | ڍ׃O^oCi\ | VvȊmF\ASend-FirstɍœK |
| ffx | Ȃ | Ping/Port/Route`FbNAANV |
| UI/UX | ėpfobKUI | NCbNMA_r[AVOANVŎw |

{݌v͊iӂƂ蓮fobOvfJo[AƂďdvȁuʃCX^XǗvuMev[g̑ؑցvu\/ffT|[gvǉ邱ƂŁA[UreBƋ@\̑oŏ邱ƂڕWƂB

### 1.5 ʌ݊ƂȂ̓I@\
1. **f[^oN{NbNM**: 悭gdJeSʂɓo^Ahbv_EI܂̓{^1NbNŃVbgMB
2. **_r[Ǘ**: CX^Xupr~^OvŐA20ڑK͂ł킸BO[vꊇMĐڑNbNB
3. **ViIg**: CSV`̃ViILqAPowerShellXNvgAgAEE[vȌɋLqłdg݁B
4. **ZbgAbvff**: Ping/Port/Route_AΏ{Œ񎦁Bڑ̖B
5. **Mf[^p**: ViIŎMf[^ϐƂĕێA񑗐Mɖߍ݉\BIȓdB
6. **1tH_=1CX^X**: ׂĂ̐ݒEViIEOtH_PʂŊSƗBRs[Ŋ\B

---

## 2. @\v

### 2.1 ʐM@\
- **TCPʐM**: NCAg/T[o[[hΉ
- **UDPʐM**: M/MΉ
- **ڑ**: قȂIP:Port̑gݍ킹ŕCX^X𓯎N
- **ڑǗ**: ڑ/ؒf̐AĐڑ@\

### 2.2 dM@\iCX^XPʂœƗj
eʐMCX^X͓Ǝ̃f[^oNEMݒEMێACX^XƂ͊SɕꂽԂœ삷B
- **f[^oNǗ**: CX^XtH_CSVŒ`OtdZbgǂݍ݁AJeS^OŐB
- **NbNM**: hbv_EI܂̓{^1ŁA**I𒆂̃CX^X**֑MłSend-First UIB
- **ʂȑM**: eLXgAHEXAt@CMAev[gWJAϐߍ݁BׂăCX^XƂɓƗϐXR[vŏB
- **M**: ViI܂̓ob`ł̘AMBCX^Xւ̈ꊇM\AeCX^X͓Ɨ^C~OEԂŎsB
- **M\iŏj**: Mʂ̓CX^XƂɃT}ƃXe[^X݂̂\B
- **Mf[^p**: Mf[^ϐƂĕێA񑗐Mf[^ɖߍ݉\BIȓdB
- **GR[fBO**: ASCII, UTF-8, Shift-JIS, oCi(HEX)ΉBCX^XƂɐݒ\B

### 2.3 ViI@\iCX^XPʂœƗsj
eCX^X͓Ǝ̃ViIt@CACX^X̃ViIsԂɉe邱ƂȂ삷B
- **ViIt@C**: CX^XtH_CSV`ŃViI`
- **ҋ@**: ԑҋ@AMҋ@Bҋ@Ԃ͊eCX^XœƗǗB
- ****: Mf[^ɊÂBEϐ̓CX^XXR[vŕ]B
- **[v**: JԂsB[vJE^̓CX^XƂɓƗB
- **ϐ@\**: Mf[^ϐƂĕێA񑗐MɓIɖߍ݁BϐXR[v̓CX^XɕACX^XƋLȂB
- **XNvgAg**: JX^PowerShellWbNĂяoAGȐU镑ȌɋLqBXNvgɂ݂͌̃CX^XReLXgnB
- **O[vM**: CX^XֈꊇMw\Aۂ̑M͊eCX^XƗĎsB

### 2.4 g@\iCX^XPʂœƗݒj
- ****: p^[M̎ԐMB[̓CX^XƂɒ`AƗB
- **IXV**: ev[gx[X̓diϐujBϐEV[PXԍ̓CX^XXR[vŊǗB
- **JX^XNvg**: PowerShellXNvgɂgBCX^XReLXgƂĎ󂯎B
- **vOC@\**: OPSXNvg̓ǂݍ݁BCX^XƂɈقȂvOCZbgKp\B

### 2.5 GUI@\
- **ڑꗗ**: ANeBuȐڑ̈ꗗ\BeCX^X̏Ԃʂɕ\B
- **Xe[^X\iFj**: eڑ̏ԂA^CɐF\i=ڑA=ؒfA=G[AO[=ڑjBWinForms`DataGridView`܂`ListView`ŊesEJ[h̔wiF𓮓IɕύXAoIɏԂc\BCX^XPʂœƗB
- **Or[A**: M̕\BICX^X̃OtB^\\B
- **ݒpl**: ڑݒAViIIBI𒆂̃CX^Xɑ΂đB
- **XP[u݌v**: ̐ڑɂΉ\UIB
- **NCbNANVo[**: Mev[ghbv_E܂̓{^ősBΏۃCX^XIđMB
- **_r[^r[ؑ**: O[vA^OAvgRʂ̐ꂽꗗőCX^XǗB
- **ffpl**: ڑeXgAݒ񎦁B

### 2.6 ffx@\iCX^XPʂœƗffj
- **lbg[NaʊmF**: IPBA|[gJ󋵁A[eBOBICX^X̐ڑffB
- **`FbNXg**: 悭\~XoAĂ񎦁BCX^XƂ̐ݒ؁B
- **ڑh_E**: eCX^X̏ԑJځAŏIG[nŊmFB
- **ZbgAbvKCh**: NɏǂEBU[hŎ𐮔B
- **lbg[NAiCU**: IPBA|[gJ󋵁A[eBOBICX^X̐ڑffB
- **`FbNXg**: 悭\~XoAĂ񎦁BCX^XƂ̐ݒ؁B
- **ڑh_E**: eCX^X̏ԑJځAŏIG[nŊmFB
- **ZbgAbvKCh**: NɏǂEBU[hŎ𐮔B

---

## 3. VXe\

### 3.1 fBNg\

#### 3.1.1 ʐMCX^X̊TO
{AvɂāA**1tH_ = 1ʐMCX^X = 1\Pbgڑ(IP:Port) = 1OuEAv͋[**ƂΉ֌W{݌vƂBeCX^X͈ȉ̗vfƗĕێÃCX^XƊSɕꂽԂœ삷:

- **ڑݒ**: TCP/UDPANCAg/T[o[[hAoChIP:PortAڑIP:Port
- **ViIs**: MV[PXAҋ@EE[vAϐXR[v
- **dev[g**: f[^oNA[AQuickSendXbg
- **\v**: X[vbg/CeVAo[XgMݒ
- **s**: MOAffʁAv|[g

̐݌vɂA1PCŕ̊Ou𓯎ɖ͋[łAuA͒IȃXe[^XMAuB͗v^AuC͍׃Xg[ƂقȂU镑ssłB

#### 3.1.2 tH_\
`Instances/` zɔCӂ̃tH_ŒʐMCX^XzuBtH_͎ʂ₷́iuEprȂǁjRɐݒłAAv̓tH_݂̑mĎFBtH_ǉΐVȃCX^XǉA폜ΑɈꗗ珜OiFileSystemWatcherŊĎjB
```
TcpDebugger/
 TcpDebugger.ps1              # CXNvgiGUIGg[|Cgj
 DESIGN.md                    # {݌v
 README.md                    # gp@
 Modules/                     # W[Q
    ConnectionManager.ps1        # ڑǗ
    TcpClient.ps1               # TCPNCAg
    TcpServer.ps1               # TCPT[o[
    UdpCommunication.ps1        # UDPʐM
    ScenarioEngine.ps1          # ViIsGW
    MessageHandler.ps1          # d
    AutoResponse.ps1            # 
    QuickSender.ps1             # f[^oN & NbNM
    InstanceManager.ps1         # _O[vǗ
    NetworkAnalyzer.ps1         # ff
 Config/                      # ʐݒEftHgev[g
    defaults.psd1                # lXibvVbg
 Instances/                   # ʐMCX^XtH_QiœIFj
    WebServer-Sim/               # Cӂ̃tH_iuʖj
       instance.psd1            # CX^XݒiIDA\Aڑp[^j
       scenarios/               # ̃CX^XpViI
          startup.csv
          auto_response.csv
       templates/               # ̃CX^Xpdev[g
          messages.csv
       logs/                    # MOij
       reports/                 # \v|[gij
    PLC-Controller/              # ʂ̃CX^X
       instance.psd1
       scenarios/
          periodic_poll.csv
       templates/
           plc_commands.csv
    LoadTest-Client01/           # ׎pCX^X
        instance.psd1
        scenarios/
            burst_send.csv
 Scripts/                     # JX^XNvg
    custom_handlers.ps1
 UI/                          # UI`
     MainForm.ps1                # WinFormstH[`iKvɉC#R[hAdd-TypeŖߍ݁j
```

#### 3.1.3 CX^XoEǗ[
- **ŏ\**: `Instances/<CӃtH_>/instance.psd1` ݂΃CX^XƂĔFB
- **CX^XID**: `instance.psd1`  `Id` vpeBňӎʁiw莞̓tH_玩jB
- **\**: `DisplayName` vpeBUI\p̖̂ݒ\iw莞̓tH_gpjB
- **tH_Ď**: FileSystemWatcher `Instances/` z̒ǉE폜El[mAUIփA^CfB
- **ݒ̗D揇**: 
  1. CX^XtH_̐ݒt@Ci`scenarios/`, `templates/`j
  2. `Config/defaults.psd1` ̃VXeftHg
- **Ɨۏ**: eCX^X͓Ǝ̃XbhEϐXR[vEԊǗACX^X̓ɉe^ȂB
- **OE|[g**: eCX^XtH_ɎۑAtH_ƃRs[邱ƂŊڍsEobNAbv\B

### 3.2 W[\

#### 3.2.1 ConnectionManageriڑǗj
- ڑ̈ꌳǗ
- ڑCX^X̐Ej
- Xe[^XĎ

#### 3.2.2 TcpClient/TcpServer
- TCPڑ̊mEؒf
- 񓯊M
- Cxgʒmiڑ/ؒf/Mj

#### 3.2.3 UdpCommunication
- UDP\Pbg̊Ǘ
- M

#### 3.2.4 ScenarioEngine
- CSVViI̓ǂݍ݁E
- ViIs
- ϐǗEu

#### 3.2.5 MessageHandler
- d̃GR[h/fR[h
- tH[}bgϊiHEX, ASCII, etc.j
- of[V

#### 3.2.6 AutoResponse
- Mp^[}b`O
- [Ǘ
- ev[gKp

#### 3.2.7 QuickSender
- f[^oNiev[g^t@C^f[^j[hAQuickPadL[giXbgԍjփoCh
- NbNMAŌ̑MĎsAO[vM
- M̕ێƍđ

#### 3.2.8 InstanceManager
- ڑ_O[vE^Oŕ
- ꊇiڑJn/~AMAViIsj
- _r[pf[^f̒

#### 3.2.9 NetworkAnalyzer
- ڑOffiPingA|[gaʁA[eBOmFj
- ݒ`FbNXg
- G[̃Rh

### 3.3 WJA[LeN`
```

 Presentation Layer                          
  - WinForms MainForm (Quick Send, Logical View) 
  - UserControls / Shared Styles (Panel/ControlCu) 

           (Data binding / Commands)

 Orchestration Layer                         
  - ConnectionManager                        
  - ScenarioEngine                           
  - InstanceManager                          

           (Events / Pipelines)

 Service Layer                               
  - TcpClient / TcpServer / UdpCommunication 
  - QuickSender / AutoResponse               
  - NetworkAnalyzer                          

           (I/O, OS API, Files)

 Infrastructure Layer                        
  - Config & DataBank Loader                 
  - Logging                                  
  - Resource Monitors                        

```

- **Ӗ**: UI̓f[^oCfBÔ݂SAsOrchestrationwֈϏBʐM^ffƂ又ServicewSAt@CǂݏiInfrastructurewŋʉB
- **Cxg쓮**: OrchestrationwPowerShellCxgUI֏ԂʒmBServicew̓Cxg΂݂̂sAUIXbhɒڐGȂB
- **g**: VvgR͋@\Servicew̃W[ǉŎAUI/Orchestration͍ŏCōςށB

### 3.4 Xbh\iThread Topologyj
- **UI Thread**: WinForms̃bZ[W[vi`System.Windows.Forms.Application.Run`jB[U[ƕ\XVSB
- **Connection Threads**: ڑƂ1XbhmۂA񓯊MƑMsBeCX^X͓Ɨ\[X̂ݑ삷邽߁AbNsvB
- **Scenario Threads**: ViIPʂŃXbhNAXebvsҋ@𐧌BLZ̓tOŊǗB
- **Diagnostics Thread**: NetworkAnalyzerpBPing/Port`FbN񓯊ŎsAʂOrchestrationw֒ʒmB
- **Shared Data Structures**: `Hashtable`isynchronizedjŐڑԂLBUIXV`Control.Invoke`fBXpb`ňѐmہB

**Xbh**: eʐMCX^X͐pXbhœ삵AƎ̃obt@EϐEԂ݂̂𑀍BCX^X̃\[Xɂ͈ؐGȂ߁AbN~[ebNX͕svB

### 3.5 Cxg^bZ[Wt[
| Cxg | Ό | M | e |
| --- | --- | --- | --- |
| `Connection.StatusChanged` | Connection Thread | InstanceManager, UI | ڑԁEG[R[h |
| `Scenario.StepProgress` | ScenarioEngine | UI, Logging | ݃XebvAiAϐXibvVbg |
| `QuickSend.Requested` | UI{^ | QuickSender | DataID, Ώېڑ/O[v |
| `Diagnostics.Result` | NetworkAnalyzer | UI | 茋ʁAANV |

- **bZ[WoX**: PowerShell`Register-EngineEvent`{JX^Cxg𗘗pAXbhԂőaɒʐMB

### 3.6 ԁEݒǗ
- **Immutable Config**: N`instance.psd1`ǂݍ݁A`ConfigSnapshot`ƂĕێBύX́uēǂݍ݁vŃo[WAbvACxgŊeW[֓`dB
- **Runtime State Store**: ڑԁAViIs󋵂`StateStore`isynchronized HashtablejɏWBUIStoreɃoChAOOAPI\[XQƂB
- **Data Persistence**: DataBankDiagnostics͊eCX^XtH_ɕۑB
- **Oۑ**: [U[IɁuOۑvsꍇ̂݃t@Cóit@C̓[U[wj

### 3.7 g|Cg
- **Plug-in Loader**: `Scripts/`zPS1[hA`ExportedFunctions.psd1`ɏ֐ScenarioEngineQuickSenderĂяo\B
- **Protocol Adapter**: VʐMi`Modules/Adapters/<Protocol>.ps1`ǉAConnectionManager̃t@Ngɓo^邾ŗp\B
- **Data Transformer**: MessageHandler`IMessageTransformer`̃C^[tF[X`ABase64AkȂǂ`F[\B
- **UI Custom Pane**: MainForm`Panel`v[Xz_pӂAUserControlǉtH[ւ\ɂB

### 3.8 fvC^^pf
- **Pzz**: `TcpDebugger.ps1``Modules/`z𓯃fBNgɔzu邾œBPowerShell 5.1ȏオΒǉCXg[svB
- **CX^XǗ**: `Instances/`zɃtH_ǉ邾ŐVKCX^X쐬B
- ****: ʏ̓[UŎsB|[gJt@CAEH[ݒ̂ݏiPowerShellʓrNB
- **Oo**: [U[KvɁuOGNX|[gv{^ŖIɕۑiۑȂj

### 3.9 ICX^XǗ

#### 3.9.1 CX^XCtTCN
```
쐬    ڑ  ANeBu  ؒf  j
                               
   ėpv[           Đڑ
```

#### 3.9.2 \[XǗ헪
- **Runspacev[**: ő50 Runspacev[A쐬/j̃I[o[wbh팸
- **ConcurrentDictionary**: XbhZ[tȐڑǗŋԂ
- **I폜**: [U[UI܂API폜s܂ŕێi폜Ȃj

#### 3.9.3 ob`
|  |  | j |
|------|------|-------------------|
| ꊇǉ | CSVC|[gAtH_Rs[ | tH_ǉŎF |
| ꊇڑ | Iڑ𓯎Jn | eCX^X̃XbhN |
| ꊇ폜 | O[v/^OPʂł̍폜 | tH_폜őɔf |
| ꊇM | ڑւ̓f[^M | eXbh֑MCxg𔭉 |

#### 3.9.4 UI
- **zXg**: DataGridzɂ葽̐ڑłX[YXN[
- **f[^oCfBO**: `BindingList`{`BindingSource`gWinFormsWoCfBO
- **vOX\**: ڑ̑쎞͐io[\
- **obNOEh**: ڑ͕ʃXbhŎsAUIubNȂ

#### 3.9.5 IڑǉAPI
```powershell
# Pڑǉ
$conn = $Global:ConnectionManager.AddConnection(@{
    Name = "web-server-01"
    Protocol = "TCP"
    RemoteIP = "192.168.1.100"
    RemotePort = 8080
    Group = "WebServers"
})

# ob`ǉiev[g20j
$template = @{
    BaseName = "load-test"
    Protocol = "TCP"
    RemoteIP = "192.168.1.200"
    RemotePort = 9000
    Group = "LoadTest"
}
$connections = $Global:ConnectionManager.AddConnectionBatch($template, 20)
#  load-test_1 ~ load-test_20 

# CSVC|[g
Import-Csv "new_connections.csv" | ForEach-Object {
    $Global:ConnectionManager.AddConnection(@{
        Name = $_.Name
        Protocol = $_.Protocol
        RemoteIP = $_.RemoteIP
        RemotePort = $_.RemotePort
        Group = $_.Group
    })
}

# ڑ̍폜
$Global:ConnectionManager.RemoveConnection("web-server-01")

# O[vPʂō폜
$removed = $Global:ConnectionManager.RemoveConnectionsByGroup("LoadTest")
Write-Host "$removed connections removed"
```

---



### 3.10 MCxgpCvC

- TcpClient/TcpServer/UdpCommunication ̎M[vł́AMς݃oCg ConnectionContext.RecvBuffer ɒǋLAڑƂ Invoke-ConnectionAutoResponse ĂяoƂőɉ݂B

- AutoResponse.ps1  ReceivedRuleEngine.ps1  CSV  AutoResponse/OnReceived/Unified/Legacy ʂAResponseMessageFile (templates/)  ScriptFile (scenarios/onreceived/) KvɉēWJB


- OnReceivedHandler.ps1  OnReceivedLibrary.ps1  PowerShell XNvgMf[^H₷悤ɁAev[gǂݍ݁EoCg؂oEϐǗESend-MessageData Ȃǂ̃wp[񋟂ĂB

- WinForms UI  DataGridView  AutoResponse/OnReceived/Periodic Send  Set-ConnectionAutoResponseProfile / Set-ConnectionOnReceivedProfile / Set-ConnectionPeriodicSendProfile ĂяoAMpCvC̐ݒsxXVłB



## 4. f[^tH[}bg

### 4.1 CX^Xݒt@Ciinstance.psd1j
eCX^XtH_ɔzuݒt@CB̃t@C݂̑ɂAvCX^XƂĔFB

**: Instances/WebServer-Sim/instance.psd1**
```powershell
@{
    # CX^Xʎqiȗ̓tH_玩j
    Id = "web-srv-01"
    
    # UI\iȗ̓tH_gpj
    DisplayName = "WebT[o[͋[u"
    
    # Epr
    Description = "HTTPʐMp̃T[o[͋["
    
    # ڑݒ
    Connection = @{
        Protocol = "TCP"           # TCP/UDP
        Mode = "Server"           # Client/Server/Sender/Receiver
        LocalIP = "0.0.0.0"
        LocalPort = 8080
        RemoteIP = ""             # Server[hł͕sv
        RemotePort = 0
    }
    
    # Nݒ
    AutoStart = $true            # AvNɎڑ
    AutoScenario = "startup.csv" # ڑɎsViI
    
    # ^OEO[vi_r[ł̕ށj
    Tags = @("WebServer", "HTTP", "Test")
    Group = "WebServers"
    
    # GR[fBOݒ
    DefaultEncoding = "UTF-8"
    
    # \ݒ
    Performance = @{
        EnableMetrics = $true
        SampleInterval = 1000    # ms
    }
}
```

**: Instances/PLC-Controller/instance.psd1**
```powershell
@{
    Id = "plc-ctrl-01"
    DisplayName = "PLC䑕u"
    Description = "FAVXePLC͋["
    
    Connection = @{
        Protocol = "TCP"
        Mode = "Client"
        LocalIP = "0.0.0.0"
        LocalPort = 0
        RemoteIP = "192.168.10.50"
        RemotePort = 502         # Modbus TCP
    }
    
    AutoStart = $false
    AutoScenario = "periodic_poll.csv"
    
    Tags = @("PLC", "Modbus", "FA")
    Group = "FactoryAutomation"
    
    DefaultEncoding = "ASCII"
}
```

1,LOOP,BEGIN,COUNT=3,LABEL=main,${MSG_HELLO}Ɖ3JԂ
2,SEND,${MSG_HELLO},,,HelloM
3,WAIT_RECV,TIMEOUT=5000,PATTERN=OK,,?@
4,SAVE_RECV,VAR_NAME=response,,,Mf[^???
5,SLEEP,1000,,,1b?@
6,SEND_HEX,48656C6C6F,,,HEXf[^M
7,SEND,${response},,,Mf[^??
8,CALL_SCRIPT,custom_check.ps1,,,JX^s
9,LOOP,END,LABEL=main,,[vI[

- `LOOP`: LOOPubN (BEGIN/END, COUNT, LABEL Ή)
- `Name`: ڑʖ
- `Protocol`: TCP/UDP
- `Mode`: Client/Server/Sender/Receiver
- `LocalIP`, `LocalPort`: [JoChݒ
- `RemoteIP`, `RemotePort`: [gڑ
- `AutoStart`: NڑtO
- `ScenarioFile`: ֘AtViIt@C

### 4.2 ViIt@Ciscenarios/*.csvj
CX^XtH_ɔzuBeCX^Xp̃ViI`B
```csv
Step,Action,Parameter1,Parameter2,Parameter3,Description
1,SEND,${MSG_HELLO},,,HelloM
2,WAIT_RECV,TIMEOUT=5000,PATTERN=OK,,ҋ@
3,SAVE_RECV,VAR_NAME=response,,,Mf[^ϐɕۑ
4,SLEEP,1000,,,1bҋ@
5,SEND_HEX,48656C6C6F,,,HEXf[^M
6,SEND,${response},,,Mf[^𑗂Ԃ
7,CALL_SCRIPT,custom_check.ps1,,,JX^s
8,LOOP,1,7,,,Xebv1-7[v
```

**ANV:**
- `SEND`: eLXgMiϐWJj
- `SEND_HEX`: HEX񑗐M
- `SEND_FILE`: t@CeM
- `WAIT_RECV`: Mҋ@i^CAEgAp^[}b`j
- `SAVE_RECV`: Mf[^ϐɕۑi񑗐Mŗp\j
- `SLEEP`: ԑҋ@
- `CALL_SCRIPT`: OXNvgs
- `SET_VAR`: ϐݒ
- `IF`: 
- `LOOP`: [v
- `DISCONNECT`: ؒf
- `RECONNECT`: Đڑ

### 4.3 dev[gitemplates/message_templates.csvj
CX^XtH_ɔzuBeCX^Xp̓dev[g`B
```csv
TemplateName,MessageFormat,Encoding
MSG_HELLO,Hello from ${HOSTNAME} at ${TIMESTAMP},ASCII
MSG_STATUS,STATUS ${SEQ}\n,UTF-8
MSG_BINARY,${HEX:AABBCCDD}${VAR:sequence},HEX
MSG_ECHO,${response},UTF-8
```

**ϐ^Cv:**
- `${ϐ}`: ʏϐiSAVE_RECVŕۑMf[^j
- `${TIMESTAMP}`: ^CX^viyyyyMMddHHmmssj
- `${DATETIME:format}`: w
- `${RANDOM:min-max}`: _l
- `${SEQ:name}`: V[PXԍiCNgj
- `${HEX:value}`: HEXϊ
- `${CALC:expression}`: vZ

### 4.4 [iscenarios/auto_response.csvj
```csv
TriggerPattern,ResponseTemplate,Encoding,Delay,MatchType
^PING,PONG,ASCII,0,Regex
STATUS,OK ${TIMESTAMP},UTF-8,100,Exact
0x01020304,${MSG_ACK},HEX,0,Exact
```

**tB[h:**
- `TriggerPattern`: Mf[^̃}b`p^[
- `ResponseTemplate`: ev[giϐgpj
- `Encoding`: GR[fBO
- `Delay`: xi~bj
- `MatchType`: Regex/Exact/Contains
### 4.5 Mf[^oNidatabank.csvj
CX^XtH_ɔzuBNCbNMp̓dev[gꗗ`B
```csv
DataID,Category,Description,Type,Content
STATUS,Basic,Xe[^XmF,TEXT,"STATUS\n"
QUERY,Basic,f[^v,TEXT,"QUERY\n"
PING,Health,aʊmF,HEX,50494E470D0A
SEQ_STATUS,Sequence,V[PXt^,TEMPLATE,SEQ=${SEQ:main}|TIME=${TIMESTAMP}
ECHO_BACK,Dynamic,Mf[^ԑ,TEXT,${response}
```

**tB[h:**
- `DataID`: ev[gʎqiUI{^Ahbv_E\j
- `Category`: priBasic/Health/DynamicȂǁj
- `Description`: Iy[^
- `Type`: TEXT/HEX/FILE/TEMPLATE Ȃ
- `Content`: f[^܂̓ev[giϐgpj

### 4.6 ff[ݒidiagnostics.psd1j
CX^XtH_ɔzuBCX^XŗL̐ff[`\B
```powershell
@{
   checks = @(
      @{type = "ping"; target = '${REMOTE_IP}'; thresholdMs = 100}
      @{type = "port"; target = '${REMOTE_IP}'; port = 8080}
      @{type = "route"; destination = '${REMOTE_IP}'}
   )
   recommendations = @(
      @{code = "PING_FAIL"; message = "Ώۑu̓d/lbg[NԂmFĂ"}
      @{code = "PORT_CLOSED"; message = "|[g8080Ă܂BΏۑũT[rXNmFĂ"}
   )
}
```

**L[:**
- `checks`: sffXebviPing/Port/Routej
- `recommendations`: R[hɕRÂAhoCXev[g
- ϐ `${REMOTE_IP}` Ȃǂ͐ڑݒ肩玩WJ

---

## 5. GUI݌v

### 5.1 fUCRZvg
- **pd**: WinForms̕WRg[pVvŌSUI
- **Fd**: 邢wiɓKxȃRgXgAdv͐FETCYŋ
- **Iȑ**: hbv_EI{M{^̃VvȃANVM
- **XP[u**: ̐ڑKwIɊǗAplTCY\
- **OCAEg**: iCX^XꗗjEipljEEiO/ffj̍\

### 5.2 CEBhE\

#### p^[A: CX^Xꗗx[Xij
```

 TCP Test Controller                  [Refresh][Connect All]  [][][~] 

 Instance List                                                           
 
   Name         Protocol Endpoint  Scenario     Status Action  
 
  WebServer-Sim TCP Svr :8080     [startup.csv] RUN  [Stop]   
  PLC-Ctrl-01   TCP Cli 192....:502[poll.csv  ] IDLE [Start]  
  LoadTest-01   TCP Cli 192....:9000[burst.csv ] ---- [Conn]   
  WebServer-02  TCP Svr :8081     [None      ] IDLE [Start]  
 
                                                                         
 Selected: WebServer-Sim                                    [Details]  

  Manual Send   Scenario Control   Diagnostics                      

 Scenario: startup.csv      Instance Log: WebServer-Sim                
 ? Step 3/12              
 Sending STATUS_OK         14:30:25  SEND STATUS_OK                
 ???????????? 67%         14:30:26  RECV ACK (64 bytes)           
                           14:30:27  SEND QUERY                    
 [? Run] [? Pause]                                                  
 [? Stop] [? Next Step]                                             
                                                                     
 Variables:                                                          
  response = "ACK"         
  seq = 3                                                              
                            [Clear Log] [Export Log]                   

 Ready | 3/4 connected | Selected: WebServer-Sim           v1.0.0      

```

**:**
- **CX^Xꗗe[u**: ׂẴCX^X1ʂŔcBԁi=ڑA=ؒfjAViIAsԂꗗ\B
- **CCViII**: esɃhbv_EzuAViI𑦍ɐ؂ւ\B
- **sIŏڍב**: CX^XIƁAɏڍבpliManual/Scenario/Diagnosticsj\B
- **ViIsԂ̉**: StatusIDLE/RUN/ERROR\ACX^X̓s󋵂c₷B

#### p^[B: ^u؂ւiֈāj
```

 TCP Test Controller                                        [][][~]   
           
WebServer-Sim  PLC-Ctrl-01   LoadTest-01   WebServer-02  [+]       
           

 Instance: WebServer-Sim (Connected)                      [Disconnect]  
 Protocol: TCP Server | Endpoint: 0.0.0.0:8080                          

  Manual   Scenario   Diag Instance Log                            

 Scenario: [startup.csv ] 14:30:25  SEND STATUS_OK                
                           14:30:26  RECV ACK (64 bytes)           
 ? Step 3/12              14:30:27  SEND QUERY                    
 Sending STATUS_OK                                                   
 ???????????? 67%         
                                                                       
 [? Run] [? Pause]         Global Log (All Instances)                 
 [? Stop] [? Next Step]   
                           14:30:25 [WebServer-Sim]  SEND STATUS   
 Variables:                14:30:26 [PLC-Ctrl-01]  RECV 0x0102     
  response = "ACK"         14:30:27 [WebServer-Sim]  RECV ACK      
  seq = 3                  

 3/4 connected | Active: 2 scenarios running                v1.0.0      

```

**:**
- **^u؂ւ**: eCX^Xʃ^uŕ\BW1CX^X𑀍łB
- **CX^XƂ̃O**: I𒆃CX^X̃Oʕ\B
- **O[oO**: SCX^X̃Onŕ\AŜ̓cB

---

### 5.3 fUC: p^[AiCX^Xꗗx[Xj

**̗pR:**
1. **󋵔ce**: CX^X̏ԁEViIs󋵂1ʂŔc
2. **ViI؂ւv**: es̃hbv_Eőɐ؂ւAStart/Stop{^Ő
3. **rȒP**: s̕ViIׂĊmF\
4. **XP[u**: 10?20CX^XłXN[őΉ\

**ڍ:**
- **DataGridView**: WinFormsDataGridViewgpAe`
  - 1: ԃACRi/ACellPaintingCxgŕ`j
  - 2: NameiTextBoxColumnj
  - 3: ProtocoliTextBoxColumnj
  - 4: EndpointiTextBoxColumnj
  - 5: ScenarioiComboBoxColumnAICxgŃViI؂ւj
  - 6: StatusiTextBoxColumnAF\j
  - 7: ActioniButtonColumnAStart/Stop/Connj
- **sICxg**: SelectionChangedCxgŉ̏ڍ׃plXV
- **CCANV**: ButtonColumnClickCxgŐڑ/ؒf/ViIJn/~𐧌

### 5.3 UIvfڍ

#### CX^Xꗗe[uiDataGridViewj
- **ԗi/j**: CellPaintingCxgŐFt~`
  - ΁: ڑViIs
  - : ڑŃACh
  - O[: ؒf
  - ԁ: G[
- **Name**: CX^X\iinstance.psd1DisplayNamej
- **Protocol**: TCP/UDPAClient/Server/Sender/Receiver\
- **Endpoint**: [gIP܂̓[JoCh|[g\
- **ScenarioiComboBoxColumnj**: 
  - CX^XtH_scenarios/*.csv
  - [None]A[startup.csv]A[poll.csv]hbv_E\
  - IύXScenarioEngineփ[hwiɔfAJn͂Ȃj
- **Status**: IDLE / RUN / PAUSE / ERROR / ----iڑj
  - wiFŎoIɋʁiRUN=΁AERROR=ԁj
- **ActioniButtonColumnj**: 
  - ڑ: [Connect]
  - ڑŃViIs: [Start]iViIJnj
  - ViIs: [Stop]
  - G[: [Retry]

#### ڍבpli^uj

**Manual^ui蓮Mj:**
- **TemplateI**: ComboBoxDataBankꗗ\AJeSʂɃO[v
- **Preview**: ϐWJς݂̑Mf[^TextBoxŕ\EҏW\
- **EncodingI**: ASCII/UTF-8/Shift-JIS/HEXComboBoxőI
- **M{^**: 
  - [Send]: I𒆃CX^X֑M
  - [Burst 10x]: 10AM
  - [Send to Group]: GroupɑSCX^X֑M

**Scenario^uiViIsj:**
- **sԕ\**: 
  - ݂̃Xebvԍ/Xebv
  - iiProgressBarj
  - oߎ
  - s̃ANVeiTextBoxj
- **{^**: 
  - [? Run]: ViIJn
  - [? Pause]: ꎞ~
  - [? Stop]: ~
  - [? Next Step]: 1Xebvs
- **Variables\**: ݂̕ϐXR[vListViewŕ\iǂݎpj

**Diagnostics^uiffj:**
- **ffs**: [Run Check]{^ŐffJn
- **ʕ\**: ListViewŃ`FbNڂƃXe[^Xi?OK/?NGj\
- **ANV**: TextBoxŐĂ\

#### CX^XOpliEj
- **ListView\**: I𒆃CX^X̑M
  - 1: 
  - 2: iM/Mj
  - 3: f[^T}iŏ50j
  - 4: TCYibytesj
- **wiF**: Ms=AMs=΁AG[s=
- **ő100**: Â̂玩폜
- **{^**: 
  - [Clear Log]: ݂̃ONA
  - [Export Log]: t@CɕۑiSaveFileDialogŕۑwj

#### O[vic[o[j
- **Group Filter**: ComboBoxŕ\O[vIiAll/WebServers/LoadTestj
- **ꊇ{^**: 
  - [Refresh]: CX^Xꗗēǂݍ
  - [Connect All]: tB^̑SCX^Xڑ
  - [Disconnect All]: tB^̑SCX^Xؒf
  - [Start All Scenarios]: tB^̑SCX^X̃ViIJn

### 5.4 WinFormsj
- **tH[**: `UI/MainForm.ps1``System.Windows.Forms`pA`SplitContainer`ŃCAEgB
- **f[^oCfBO**: `BindingSource`{`BindingList`̗pAobNGh`StateStore`UIRg[𓯊B
- **񓯊**: Xbh̒ʒm`Control.Invoke/BeginInvoke`UIXbhփ}[VOB
- **Cxg쓮**: WinFormsCxgŊeRg[̑B
- **WRg[**: TreeView, ComboBox, TextBox, Button, ListView, ProgressBar̕WRg[pB
- **CAEg**: `SplitContainer``TableLayoutPanel`3CAEgB`Dock`vpeBŉσTCYΉB

### 5.5 fUCVXe

#### J[pbg
```
vC}:     #0078D4 (Microsoft Blue)
:           #107C10 (Success Green)
x:           #FFB900 (Warning Yellow)
G[:         #E81123 (Error Red)
wi:           #FFFFFF (White)
plwi:     #F3F3F3 (Light Gray)
{[_[:       #E1E1E1 (Border Gray)
eLXg:       #323130 (Dark Gray)
```

#### ^C|OtB
```
o:         Segoe UI Semibold 14pt
{^:         Segoe UI 10pt
{:           Segoe UI 9pt
R[h:         Consolas 9pt
```

#### ԊuETCY
```
{P:       8px Obh
pfBO:     8px / 16px
{^:     28px
ACRTCY: 16~16px
```

### 5.6 ANZVreB
- **L[{[hirQ[V**: Tab_Iɐݒ肵AEnter/Spaceő\B
- **V[gJbg**: Ctrl+SiۑjACtrl+OiJjAF5itbVj̈ʃV[gJbgT|[gB
- **tH[JX\**: L[{[htH[JXɘgŖ

---

## 6. t[

### 6.1 Nt[
```
1. TcpDebugger.ps1 s
2. W[ǂݍ
3. WinFormstH[i`System.Windows.Forms.Application.Run`j
4. Instances/ tH_XLAinstance.psd1 ǂݍ
5. AutoStart=true̐ڑJn
6. CCxg[vJn
```

### 6.2 ڑmt[iTCP Clientj
```
1. ConnectionManagerڑݒ擾AConnectionContext𐶐
2. TcpClient XbhNA[gzXg֐ڑs
3. ڑ
    ԍXVCxgUI֔
    M[vJnAMf[^MessageHandlerֈϏ
    AutoStartViIScenarioEngineN
4. ڑs
    G[InstanceManager֒ʒm
    Đڑ|Vɏ]gC or [U[փG[
```

### 6.3 ViIst[
```
1. ScenarioEngineCSVǂݍ݁AActionpCvC\z
2. sJnƁAeXebvXbhŏ
3. SEND/SEND_HEXQuickSender APIoRđΏېڑ֑M
4. WAIT_RECVIF͎Mobt@^ϐXgAQƂĔ
5. SAVE_RECVŎMf[^ϐɕۑA񑗐Mŗp\
6. CALL_SCRIPTSET_VARŊOWbNԍXV{
7. iStepProgressCxgƂUIƃO֒ʒm
8. EfEG[ScenarioResultƂInstanceManagerɕԋp
```

### 6.4 t[
```
1. Connection XbhMf[^MessageHandler֓n
2. AutoResponseW[[e[u𑖍
3. }b`ꍇ̓ev[gWJDelayM
4. ʂ𗚗֋L^AKvɉScenarioEngineփgK[ԑ
5. }b`Ȃꍇ̓ViIҋ@ֈϏ
```

### 6.5 NbNMt[iSend-Firstj
```
1. [U[hbv_EŃev[gIAM{^NbN
2. QuickSenderDataBankev[gƑMݒ擾
3. MessageHandlerŕϐWJEGR[hE`
4. Ώېڑ܂͘_O[v̑ML[֓
5. Connection XbhMmFAXgA֋L^
```

### 6.6 CX^Xꊇt[
```
1. [U[_r[ŃO[v/^OI
2. InstanceManagerΏېڑꗗ𒊏o
3. viڑ/ؒf/M/ViIJnjeڑ̃XbhփfBXpb`
4. eڑ̌ʃCxgW񂵁AUIɏWԁi/sj\
```

### 6.7 lbg[Nfft[
```
1. ffplŁuRun Checkv{^NbN
2. NetworkAnalyzer XbhPing/Port/Route`FbNs
3. ʂXRAOAdiagnostics.psd1̐ANVKp
4. UI֌ʕ\AKvɉđΏ菇
5. Ώ́uĐffvœ`FbNĎs
```

---

## 7. Zpdl

### 7.1 ʐM
- **TCP**: `System.Net.Sockets.TcpClient`, `TcpListener`
- **UDP**: `System.Net.Sockets.UdpClient`
- **񓯊**: `BeginReceive`/`EndReceive` ܂ `ReceiveAsync`
- **obt@TCY**: 8192oCgiϐݒj

### 7.2 XbhǗ
- **CXbh**: WinForms UIXbhiApplication.Runj
- **ڑXbh**: eڑƂɃXbhiSystem.Threading.Threadj
- **ViIXbh**: ViIspXbh
- ****: `Hashtable.Synchronized()`Ńf[^L
- **ffXbh**: NetworkAnalyzerobNOEhPing/Port`FbNs

**dv**: eCX^X͓Ɨ\[X̂ݑ삷邽߁AbN@\͕svB

### 7.3 G[nhO
- ׂĂ̒ʐMtry-catchubN
- G[OGUIɕ\
- ĐڑWbNigC񐔁AԊuݒj

### 7.4 f[^i
- ݒt@C: PSD1`iPowerShellnbVe[uj
- O: [U[IɁuOۑv{^ŏo
- DataBank: eCX^XtH_CSVt@CƂĊǗ

### 7.5 QuickSender
- DataBankt@C[hA`BindingList`UIɃoCh
- ev[gIDƑMf[^̃}bsOǗ

### 7.6 InstanceManager
- eڑPSCustomObjectŃbvAGroup/Tagǉ
- O[voAꊇAPI
- GUI`BindingSource`ŏԔzM

### 7.7 NetworkAnalyzer
- `Test-Connection`, `Test-NetConnection`, `Find-NetRoute`gݍ킹ff
- ff[PSD1ŋLqAANVev[g

### 7.8 OǗ
- **Ox**: INFO/WARN/ERRORp
- **Oo**: [U[uOGNX|[gv{^ŖIɕۑit@CEۑ[U[wj
- **ۑȂ**: ڍ׃g[XKvȏꍇ͊Oc[gp

---



### 7.9 m̋ZpIۑ

- TcpClient.ps1  UdpCommunication.ps1 ł Invoke-ConnectionAutoResponse ̌ĂяoʒuMOɂAreceivedData ϐ`̂܂܎s鋰ꂪ (TcpServer.ps1 ͐ʒuɔzuς)B


- UI/MainForm.ps1  Periodic Send ݒł͖ Get-InstancePath QƂĂAsɗOBConnection.Variables[InstancePath] ėpŉCKvB

- ScenarioEngine.ps1  IF ANV (Invoke-IfAction) ͌xõX^uŁA𔺂ViI܂słȂB

- OnReceived vt@C GUI ؂ւĂstbN݂Ȃ߁AUnified [oR Invoke-OnReceivedScript Ă΂P[XȊOł͌ʂoȂB



## 8. g

### 8.1 JX^XNvg
```powershell
# Scripts/custom_handlers.ps1
function CustomValidation {
    param($ReceivedData, $Connection)
    # JX^؃WbN
    if ($ReceivedData -match "ERROR") {
        # G[
        return $false
    }
    return $true
}
```

ViIĂяo:
```csv
Step,Action,Parameter1,Parameter2,Parameter3
10,CALL_SCRIPT,CustomValidation,$RECV_DATA,$CONN_NAME
```

### 8.2 vOC@\
- `Scripts/`zPS1t@Cǂݍ
- `ς݊֐ViIĂяo\
- vOCAPIKɏ]

### 8.3 ϐVXeg
Vϐ^Cv̒ǉ:
```powershell
# Modules/MessageHandler.ps1 
function Expand-Variables {
    # ${CUSTOM:xxx} p^[̏ǉ
}
```

---

## 9. ZLeBl

### 9.1 s
- PowerShells|V[: RemoteSigned
- lbg[NANZXKv

> **pr**: {c[TCP/IPʐMp̎łAMꂽlbg[Nł̎gpzBiȃZLeBvKvȊł́AK؂ȃANZXƊĎ{邱ƁB

---

## 10. ptH[}X

### 10.1 œK|Cg
- ʃf[^M̃obt@O
- UIXV̊ԈipxXVj
- Oێ̐i100j
- NbNM̃foEX

### 10.2 XP[reB
- ڑ: 20?30ڑxz
- gp: ڑ萔MB
- CPU: ʏ펞 < 5%
- ꊇ䎞UIubNȂ悤񓯊

---

## 11. eXgj

### 11.1 P̃eXg
- eW[̓ƗeXg
- QuickSender: ev[gWJAϐu
- InstanceManager: O[v쐬A^OtB^
- NetworkAnalyzer: Ping/Portʂ̔胍WbN

### 11.2 eXg
- [J[vobNʐMeXg
- ڑeXg
- ViIseXgiSAVE_RECVϐߍݑMj
- DataBankQuickSenderڑւ̈ꊇM

### 11.3 eXg
- @Ƃ̐ڑeXg
- ԉғeXg
- G[JoeXg
- 10?20ڑK͂̃O[v䎎

---

## 12. zzƉ^p

### 12.1 zz헪
- **|[^upbP[W**: PZIPt@CŊSȎszz
- **ˑ֌W**: PowerShell 5.1ȏiWindowsWĵ
- **USBsΉ**: Cӂ̃hCus\AWXgˑ

### 12.2 pbP[W\
```
TcpDebugger/
 TcpDebugger.ps1              # CXNvg
 Modules/                     # W[Q
 Config/
    defaults.psd1            # ftHgݒ
 Instances/                   # ʐMCX^XtH_Q
    Example/                 # TvCX^X
        instance.psd1
        scenarios/
        templates/
 README.md
```

### 12.3 N@
```powershell
# {N
.\TcpDebugger.ps1

# ܂́APowerShell 璼ڋN
powershell.exe -ExecutionPolicy Bypass -File ".\TcpDebugger.ps1"
```

### 12.4 zz@

#### X^hAzz
```powershell
# ZIPzz
#  TcpDebugger.zip

# WJƎs
Expand-Archive -Path "TcpDebugger.zip" -DestinationPath "C:\Tools\TcpDebugger"
cd "C:\Tools\TcpDebugger"
.\TcpDebugger.ps1
```

#### lbg[NLzz
```powershell
# T[o[: LtH_ɔzu
Copy-Item -Path "TcpDebugger" -Destination "\\server\tools\TcpDebugger" -Recurse

# NCAg: ڎs
\\server\tools\TcpDebugger\TcpDebugger.ps1
```

---

## 13. ̊g\

### 13.1 tF[Y1i{j- ݂̐݌v͈
- TCP/UDP{ʐM
- 蓮M
- ViIGWiMf[^p܂ށj
- WinFormsx[XGUI
- 1tH_=1CX^XǗ
- ffx@\

### 13.2 tF[Y2i@\gj- 
- vgR̓vOC
- \@\iiperf݊j
- 荂xȃViIDSL

---

## 14. Ql

### 14.1 ZpQl
- [PowerShell WinForms GUI Tutorial](https://learn.microsoft.com/powershell/scripting/samples/sample-gui)
- [.NET Socket Programming](https://docs.microsoft.com/dotnet/api/system.net.sockets)

### 14.2 ֘Ac[
- VSCode: XNvgҏW
- Excel/LibreOffice: CSVҏW

---

## t^A: Tvݒt@C

ڍׂȃTv͎ɕʓr쐬\B

---

****
- Version 1.0 (2025-11-15): ō쐬
- Version 1.1 (2025-11-15): vƊȑf
  - 1tH_=1CX^XɌ
  - WinFormsŌIGUIɕύX
  - Xbh\𖾊mibNsvj
  - iperf폜Aff@\͈ێ
  - ͌؂͕svƖL
  - Mf[^p@\iSAVE_RECVjǉ
  - PowerShellP̂ł̎sɌ


****
- Version 1.0 (2025-11-15): ō쐬
---

**文書履歴**
- Version 1.0 (2025-11-15): 初版作成
- Version 1.1 (2025-11-15): 要件整理と簡素化
  - 1フォルダ=1インスタンスに厳密統一
  - WinFormsで現実的なGUIに変更
  - スレッド構成を明確化（ロック不要）
  - iperf削除、診断機能は維持
  - 入力検証は不要と明記
  - 受信データ活用機能（SAVE_RECV）を追加
  - PowerShell単体での実行に限定


**文書履歴**
- Version 1.0 (2025-11-15): 初版作成
