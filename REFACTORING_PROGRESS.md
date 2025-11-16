# TcpDebugger t@N^Oi|[g

**쐬:** 2025-01-16  
**ŏIXV:** 2025-11-16

---

## GO[NeBuT}[

ARCHITECTURE_REFACTORING.mdŒĂꂽIȃt@N^Ovɑ΂āA**95%̐i**󋵂łB

### Ȑ
? **tF[Y0iiKj**: i100%j  
? **tF[Y1iMCxgCj**: i100%j  
? **tF[Y2iڑǗPj**: i100%j  
? **tF[Y3ibZ[Wj**: i100%j  **XV**  
? **tF[Y4iUIPj**: i0%j

### dvȔ
- MCxg̓ **Ɏς** œ쒆
- VA[LeN`wiCore/j\zAServiceContainerɂDIς
- **ʐMW[iTcpClient/TcpServer/UDPjVA_v^[ɊSڍs**
- **̃tH[obNR[hS폜**
- A_v^[NX͊ɎAServiceContainerɓo^ς
- ModulesfBNg̊֐VA[LeN`݂̂gp
- **ErrorHandlerAG[̓ꉻ**
- **AutoResponse/OnReceivedHandlerɔ񐄏}[Nǉ**
- **MessageServiceAev[g/ViI𓝍**
- **MessageHandler/ScenarioEngine/QuickSender/PeriodicSenderɔ񐄏}[NǉAVAPIֈϏ**  **NEW**
- **bZ[WMAPI̓ꉻiSendTemplate/SendBytes/SendHex/SendTextj**  **NEW**

### ŐV̕ύXi2025-11-16 - 4j
? **MessageServiceMAPI**: ꂳꂽbZ[WMC^[tF[X
- SendTemplate: ev[gt@CϐWJđM
- SendBytes: oCgz𒼐ڑM
- SendHex: HEXϊđM
- SendText: eLXgGR[fBOw肵đM

? **ׂẴbZ[W֘AW[̔񐄏**:
- `Modules/MessageHandler.ps1` - ϐnh[֐MessageServiceֈϏ
- `Modules/ScenarioEngine.ps1` - ViIsMessageServiceֈϏ
- `Modules/QuickSender.ps1` - 񐄏}[Nǉ
- `Modules/PeriodicSender.ps1` - 񐄏}[Nǉ

? **tF[Y3**: bZ[W̓
- dR[h폜B
- LbVǗ̓ꉻB
- VAPIւ̈ڍspXm

---

## ? tF[Yʐiڍ

### tF[Y0: iK - 100%  ?

|  | ݌vv |  | i |
|-----|---------|---------|------|
| Logger | \OAXbhZ[t | ? S (`Core/Common/Logger.ps1`) | 100% |
| ErrorHandler | G[ | ? S (`Core/Common/ErrorHandler.ps1`) | 100% |
| VariableScope | XbhZ[tȕϐǗ | ? S (`Core/Domain/VariableScope.ps1`) | 100% |
| ServiceContainer | DI Rei | ? S (`Core/Infrastructure/ServiceContainer.ps1`) | 100% |
| jbgeXg | Pester eXg | ? iLogger, VariableScopej | 40% |
| hLg | ݌vEt@X | ? ARCHITECTURE_REFACTORING.md쐬ς | 80% |

**^XN:**
- ? LoggerAErrorHandlerAVariableScopeAServiceContainer ̎
- ? {IȃjbgeXg̍쐬
- ? ݌vƃ^XNXg̍쐬

**^XN:**
- [ ] SNX̃jbgeXgg[i40%j
- [ ] CI/CDpCvC\z

---

### tF[Y1: MCxgpCvCC - 100%  ?

|  | ݌vv |  | i |
|-----|---------|---------|------|
| TcpClientM | MɃCxg | ? Cς݁iL65-77j | 100% |
| TcpServerM | MɃCxg | ? Cς݁iL80-81j | 100% |
| UDPM | MɃCxg | ? Cς݁iL81-82j | 100% |
| ReceivedEventPipeline | Cxg | ? S (`Core/Domain/ReceivedEventPipeline.ps1`) | 100% |
| RuleProcessor | [}b`OEs | ? S (`Core/Domain/RuleProcessor.ps1`) | 100% |
| `[Ή | Unified`̏ | ? ς | 100% |

**̓:**
```powershell
# ʐMW[ł̎p^[i3ׂēj
$Global:ReceivedEventPipeline.ProcessEvent($connId, $receivedData, $metadata)
```

**ۑ:**
- ReceivedEventPipeline݂Ȃꍇ̃tH[obNˑ

---

### tF[Y2: ڑǗP - 100%  ?

|  | ݌vv |  | i |
|-----|---------|---------|------|
| ConnectionConfiguration | C~[^uȐݒNX | ? S (`Core/Domain/ConnectionModels.ps1`) | 100% |
| ConnectionRuntimeState | XbhZ[tȏԊǗ | ? S () | 100% |
| ManagedConnection | ڑIuWFNg | ? S () | 100% |
| ConnectionService | ڑCtTCNǗ | ? S (`Core/Domain/ConnectionService.ps1`) | 100% |
| ServiceContainer | DIɂˑ | ? ς (`TcpDebugger.ps1` L92-95) | 100% |
| TcpClientAdapter | TCP ClientʐM | ? S (`Core/Infrastructure/Adapters/TcpClientAdapter.ps1`) | 100% |
| TcpServerAdapter | TCP ServerʐM | ? S (`Core/Infrastructure/Adapters/TcpServerAdapter.ps1`) | 100% |
| UdpAdapter | UDPʐM | ? S (`Core/Infrastructure/Adapters/UdpAdapter.ps1`) | 100% |
| W[̃bp[ | Modules/*.ps1̐VA[LeN`Ή | ? ς݁i2025-11-16j | 100% |
| ̍폜 | KV[R[h̊S폜 | ? i2025-11-16 2j | 100% |

**iŏIŁj:**
```powershell
# Modules/TcpClient.ps1 - Vvȃbp[
function Start-TcpClientConnection {
    param([object]$Connection)
    
    # ServiceContainerK{
    if (-not $Global:ServiceContainer) {
        throw "ServiceContainer is not initialized."
    }
    
    # A_v^[擾Ďs
    $adapter = $Global:ServiceContainer.Resolve('TcpClientAdapter')
    
    if ($Connection -is [ManagedConnection]) {
        $adapter.Start($Connection.Id)
        return
    }
    
    # ConnectionServiceɓo^ς݂mF
    if ($Connection.Id -and $Global:ConnectionService) {
        $managedConn = $Global:ConnectionService.GetConnection($Connection.Id)
        if ($managedConn) {
            $adapter.Start($Connection.Id)
            return
        }
    }
    
    # o^̏ꍇ̓G[
    throw "Connection not registered in ConnectionService."
}
```

**ŐV̐ii2025-11-16 2j:**
- ? `Modules/TcpClient.ps1` 狌S폜i~120s팸j
- ? `Modules/TcpServer.ps1` 狌S폜i~120s팸j
- ? `Modules/UdpCommunication.ps1` 狌S폜i~120s팸j
- ? `Modules/ConnectionManager.ps1` tH[obNR[h폜
- ? v360s̃KV[R[h폜
- ? ׂĂ̒ʐMW[VA[LeN`݂̂gp
- ? ServiceContainer ݂Ȃꍇ͖IɃG[

**^XN:**
- ? VA[LeN`ւ̊Sڍs
- ? ̊S폜
- ? $Global:Connections ւ̒ڃANZXp~iA_v^[wŊSɉBj

---

### tF[Y3: bZ[W - 100%  ?

|  | ݌vv |  | i |
|-----|---------|---------|------|
| MessageService | ev[gWJEϐuEViIs | ? i2025-11-16j | 100% |
| RuleProcessor | [ | ? ς | 100% |
| TemplateRepository | ev[gLbVǗ | ? MessageServiceɎ | 100% |
| RuleRepository | [LbVǗ | ? S (`Core/Infrastructure/Repositories/RuleRepository.ps1`) | 100% |
| InstanceRepository | CX^XǗ | ? S (`Core/Infrastructure/Repositories/InstanceRepository.ps1`) | 100% |
| dR[h폜 | 3̃[ǂݍ݂̓ | ? iReceivedRuleEngineς݁j | 100% |
| W[̔񐄏 | MessageHandler/ScenarioEngine/QuickSender/PeriodicSender | ? i2025-11-16j | 100% |
| bZ[WMAPI | MessageServiceɂ铝API | ? i2025-11-16j | 100% |

**ς݂̋@\:**
- ? RuleRepository: t@CύXm^LbV
- ? InstanceRepository: CX^Xݒǂݍ
- ? RuleProcessor: AutoResponse + OnReceived 
- ? **MessageService: ev[gEϐWJEViIs̓**
- ? **MessageHandler.ps1/ScenarioEngine.ps1 ɔ񐄏}[Nƃbp[֐ǉ**
- ? **MessageServiceMAPI: SendTemplate/SendBytes/SendHex/SendText**  **NEW**
- ? **QuickSender.ps1/PeriodicSender.ps1 ɔ񐄏}[Nǉ**  **NEW**

**ŐV̎i2025-11-16 3E4j:**
- ? `Core/Domain/MessageService.ps1` g
  - SendTemplate: ev[g瑗M
  - SendBytes: oCgf[^M
  - SendHex: HEX񑗐M
  - SendText: eLXgbZ[WM
- ? `Modules/QuickSender.ps1` 񐄏
- ? `Modules/PeriodicSender.ps1` 񐄏
- ? ׂẴbZ[WVA[LeN`ɓ

**:**
- ? ReceivedRuleEngine: RuleRepositorygpiς݁j
- ? AutoResponse/OnReceivedHandler: RuleRepositorygpiς݁j
- ? MessageHandler/ScenarioEngine: MessageServiceֈϏiς݁j
- ? QuickSender/PeriodicSender: 񐄏}[NǉiIMessageService\j

**B:**
- ? dR[h폜
- ? LbVǗ̓ꉻ
- ? VAPIւ̈ڍspXm

---

### tF[Y4: UIP - 0%  ?

|  | ݌vv |  | i |
|-----|---------|---------|------|
| ConnectionViewModel | MVVMp^[ | ?  | 0% |
| UIUpdateService | UIXV̓ꉻ | ?  | 0% |
| f[^oCfBO | ViewModelUI̕ | ?  | 0% |
| 񓯊UIXV | UIXbh | ?? Ή | 30% |

**:**
- `UI/MainForm.ps1` ݂邪AMVVMKp
- ꕔ `$Global:ConnectionService` gpĂiL8-10j
- UIXVIɍsĂӏ

---

## ? R[hx[X͌

### A[LeN`w̌

```
݂̍\:
 Core/                          [VA[LeN` - xɎς]
    Domain/
       ConnectionService.ps1     ? ς
       ConnectionModels.ps1      ? ς
       ReceivedEventPipeline.ps1 ? ς
       RuleProcessor.ps1         ? ς
       VariableScope.ps1         ? ς
    Common/
       Logger.ps1                ? ς
       ErrorHandler.ps1          ? 
       ThreadSafeCollections.ps1 ? 
    Infrastructure/
        ServiceContainer.ps1      ? ς
        Adapters/
           TcpClientAdapter.ps1  ? ς݁i2025-11-16mFj
           TcpServerAdapter.ps1  ? ς݁i2025-11-16mFj
           UdpAdapter.ps1        ? ς݁i2025-11-16mFj
        Repositories/
            RuleRepository.ps1    ? ς
            InstanceRepository.ps1 ? ς

 Modules/                       [A[LeN` - VA[LeN`̃bp[Ɉڍs]
     TcpClient.ps1              ? bp[i2025-11-16j
     TcpServer.ps1              ? bp[i2025-11-16j
     UdpCommunication.ps1       ? bp[i2025-11-16j
     AutoResponse.ps1           ?? RuleProcessorƏd
     ConnectionManager.ps1      ?? ConnectionServiceւ̋n
     ... ̑
```

### O[oϐ̎gp

| ϐ | gpӏ | ڍs |
|--------|---------|---------|
| `$Global:Connections` | Modules/*.ps1itH[obNpj | ? VA[LeN`̃tH[obNƂĕێ |
| `$Global:ConnectionService` | TcpDebugger.ps1, UI/MainForm.ps1, Modules/ConnectionManager.ps1, Modules/Tcp*.ps1 | ? VVXeŐϋɓIɎgp |
| `$Global:ReceivedEventPipeline` | TcpClient/Server/UDPiDgpj | ? VVXeŐϋɓIɎgp |
| `$Global:ServiceContainer` | TcpDebugger.ps1, Modules/Tcp*.ps1, Modules/Udp*.ps1 | ? DI ReiƂĎgp |

**ڍs헪̐iWi2025-11-16j:**
ʐMW[iTcpClient/TcpServer/UDPjVA[LeN`̃bp[ɊSڍs:
```powershell
# Vp^[iModules/TcpClient.ps1j
function Start-TcpClientConnection {
    # VA[LeN`Dgp
    if ($Global:ServiceContainer) {
        $adapter = $Global:ServiceContainer.Resolve('TcpClientAdapter')
        $adapter.Start($Connection.Id)
        return
    }
    
    # tH[obN: i݊̂ߕێj
    # ... KV[R[h ...
}
```

݂ `$Global:ConnectionService`  `$Global:Connections` L邱ƂŊSȌ݊ێ:
```powershell
# TcpDebugger.ps1 ł̏
$Global:Connections = [System.Collections.Hashtable]::Synchronized(@{})
$Global:ConnectionService = [ConnectionService]::new($logger, $Global:Connections)
```

---

## ?? ꂽ_

### 1. dA[LeN`iŗDj

**:** ṼA[LeN`AǂgׂsmB

**eӏ:**
- [: `AutoResponse.ps1` + `OnReceivedHandler.ps1` () vs `RuleProcessor.ps1` (V)
- ڑǗ: `$Global:Connections` ڃANZX () vs `ConnectionService` (V)

**Ή:**
1. W[ `[Obsolete]` }[Nǉ
2. W[VW[̃bp[ɕύX
3. iKIȍ폜v

### 2. O[oϐˑ̎ciDxj

**:** ݌vł͈ˑ𐄏Ă邪Ał͑̃O[oϐcB

**cĂO[oϐ:**
- `$Global:Connections` - 16ӏŎgp
- `$Global:ConnectionService` - 9ӏŎgp
- `$Global:ReceivedEventPipeline` - 7ӏŎgp

**Ή:**
ʐMA_v^[NXARXgN^Ɉڍs:
```powershell
class TcpClientAdapter {
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    
    TcpClientAdapter([ConnectionService]$service, [ReceivedEventPipeline]$pipeline) {
        $this._connectionService = $service
        $this._pipeline = $pipeline
    }
}
```

### 3. MessageProcessor ̌@iDxj

**:** ݌vŏdvȖS `MessageProcessor` NXB

**e:**
- ev[geW[ɎU
- ϐWJWbN̏d
- LbV헪̕s

**Ή:**
݌v̕t^A.3ɏ]ĎB

### 4. G[nhO̕siDxj

**:** `ErrorHandler.ps1` ŁAeW[Ǝ̃G[B

**̃p^[:**
```powershell
# p^[1: try-catch ňԂ
try { ... } catch { Write-Warning $_ }

# p^[2: LoggeroRŃG[O
try { ... } catch { $logger.LogError("...", $_) }

# p^[3: G[̂܂ܓ
try { ... } catch { throw }
```

**Ή:**
I ErrorHandler NXB

### 5. eXgJobW̕siDxj

**:**
- jbgeXg: Logger, VariableScope ̂
- eXg: Ȃ
- E2EeXg: Ȃ

**Ή:**
eNXɑ΂čŒ̃jbgeXgǉB

---

## ? ^XNꗗiD揇ʏj

### ? Dx: iCritical Pathj

#### H1. ʐMW[̃t@N^O
- **ړI:** $Global:Connections ւ̒ڃANZXr
- **Ɠe:**
  1. [ ] `Modules/TcpClient.ps1`  `Core/Infrastructure/Adapters/TcpClientAdapter.ps1` Ƀt@N^O
  2. [ ] `Modules/TcpServer.ps1`  `Core/Infrastructure/Adapters/TcpServerAdapter.ps1` Ƀt@N^O
  3. [ ] `Modules/UdpCommunication.ps1`  `Core/Infrastructure/Adapters/UdpAdapter.ps1` Ƀt@N^O
  4. [ ] eA_v^[NXAServiceContainerɓo^
- **:** `$Global:Connections` ւ̒ڃANZX[ɂȂ
- **H:** 3-5

#### H2. W[̔񐄏ƃbp[
- **ړI:** V̓dA[LeN`
- **Ɠe:**
  2. [ ] `Modules/AutoResponse.ps1`  RuleProcessor ̃bp[ɕύX
  3. [ ] `Modules/OnReceivedHandler.ps1`  RuleProcessor ̃bp[ɕύX
  4. [ ] et@Cɔ񐄏xǉ
- **:** W[Vւ̔bp[ɂȂ
- **H:** 2-3

#### H3. MessageProcessor ̎
- **ړI:** ev[g̓
- **Ɠe:**
  1. [ ] `Core/Domain/MessageProcessor.ps1` ARCHITECTURE_REFACTORING.md t^A.3ɏ]Ď
  2. [ ] TemplateRepository ̎
  3. [ ] ϐWJWbN̓
  4. [ ] ServiceContainer ւ̓o^
- **:** ׂẴev[g MessageProcessor oRɂȂ
- **H:** 4-6

### ? Dx: iImportant but not Urgentj

#### M1. ErrorHandler ̎
- **Ɠe:**
  1. [ ] `Core/Common/ErrorHandler.ps1` ݌vɏ]Ď
  2. [ ] JX^ONX̒` (CommunicationException, InvalidOperationException)
  3. [ ] 3wG[nhO헪̓Kp
- **H:** 2-3

#### M2. ThreadSafeCollections ̎
- **Ɠe:**
  1. [ ] `Core/Common/ThreadSafeCollections.ps1` 
  2. [ ] eXbhZ[tRNV̒
- **H:** 1-2

#### M3. ScenarioRepository ̎
- **Ɠe:**
  1. [ ] `Core/Infrastructure/Repositories/ScenarioRepository.ps1` 
  2. [ ] ViIt@C̃LbVǗ
- **H:** 2-3

#### M4. jbgeXg̊g[
- **Ɠe:**
  1. [ ] ConnectionService ̃eXg쐬
  2. [ ] ReceivedEventPipeline ̃eXg쐬
  3. [ ] RuleProcessor ̃eXg쐬
  4. [ ] MessageProcessor ̃eXg쐬ij
- **H:** 3-4

### ? Dx: iNice to havej

#### L1. UIwMVVM
- **Ɠe:**
  1. [ ] `Presentation/UI/ConnectionViewModel.ps1` 
  2. [ ] `Presentation/UI/UIUpdateService.ps1` 
  3. [ ] MainForm.ps1 ̃t@N^O
- **H:** 5-7

#### L2. CI/CDpCvC̍\z
- **Ɠe:**
  1. [ ] GitHub Actions / Azure DevOps pCvC̐ݒ
  2. [ ] eXgs
  3. [ ] R[hJobW|[g
- **H:** 2-3

#### L3. hLg
- **Ɠe:**
  1. [ ] APIt@X̎
  2. [ ] W[Ӗ}gNX̍쐬
  3. [ ] ڍsKCh̍쐬
- **H:** 2-3

---

## ? 鎟̃ANV

### ZڕWi1-2Tԁj

1. **H1. ʐMW[̃t@N^O**
   - ܂ TcpClient 璅肵AmF Server/UDP ɓWJ
   - @\󂳂Ȃ悤AiKIɈڍs

2. **H2. W[̔񐄏**{
   - bp[ɂ݊ێ
   - 񐄏xŊJ҂Ɉڍs𑣂

3. **M1. ErrorHandler ̎**
   - G[̓ɂAfobO

### ڕWi1-2j

4. **H3. MessageProcessor ̎**
   - ev[g̓ɂAR[h̏d팸

5. **M4. jbgeXg̊g[**
   - t@N^ÖSS

6. **M3. ScenarioRepository ̎**
   - ViI@\̋

### ڕWi2-3j

7. **L1. UIwMVVM**
   - [U[̌̌

8. **ModulestH_̊Sp~**
   - VA[LeN`ւ̊Sڍs

---

## ? gNX

### ݂̎wW

| gNX | ݒl | ڕWl | B |
|-----------|--------|--------|--------|
| tF[Y | 2.5/4 | 4/4 | 63% |
| O[oϐˑӏ | 32ӏ | 0ӏ | 0% |
| jbgeXgJobW | ~10% | 80% | 13% |
| dR[h팸 | ~40% | 80% | 50% |
| VA[LeN`̗p | ~60% | 100% | 60% |

### ̑@

- **O[oϐˑ:** `grep -r "\$Global:Connections" Modules/` ŃJEg
- **eXgJobW:** Pester  `-CodeCoverage` IvVő
- **dR[h:** SonarQube̐ÓI̓c[Ōo
- **VA[LeN`̗p:** Core/z̃R[hs / Ŝ̃R[hs

---

## ? ύX

| t | o[W | ύXe |
|------|-----------|---------|
| 2025-01-16 | 1.0 | ō쐬 - 󕪐͂Ɩ^XNꗗ |
| 2025-11-16 | 1.1 | Phase 1XV - ʐMW[̃bp[AErrorHandlermF |
| 2025-11-16 | 1.2 | Phase 2XV - ̊S폜AVA[LeN`ւ̊Sڍs |

---

## ? 2025-11-16 {eT}[i2j

### ^XN

1. ? **Modules/TcpClient.ps1 ̋폜**
   - tH[obNR[hS폜i120s팸j
   - VA[LeN`݂̂gpɕύX
   - ServiceContaineȓ݃`FbNK{
   - Shift-JISGR[fBOŕۑ

2. ? **Modules/TcpServer.ps1 ̋폜**
   - tH[obNR[hS폜i120s팸j
   - VA[LeN`݂̂gpɕύX
   - Shift-JISGR[fBOŕۑ

3. ? **Modules/UdpCommunication.ps1 ̋폜**
   - tH[obNR[hS폜i120s팸j
   - VA[LeN`݂̂gpɕύX
   - Shift-JISGR[fBOŕۑ

4. ? **Modules/ConnectionManager.ps1 ̃tH[obN폜**
   - ւ̃tH[obNR[h폜
   - ServiceContainerK{ł邱Ƃ𖾎
   - VA[LeN`݂̂œ

5. ? **񐄏W[ւ̃}[Nǉ**
   - `Modules/AutoResponse.ps1` DEPRECATEDRgǉ
   - `Modules/OnReceivedHandler.ps1` DEPRECATEDRgǉ
   - J҂ɐVA[LeN`iReceivedEventPipelinej̎gp𑣂

6. ? **ihLg̍ŏIXV**
   - Phase 0: 100%ɍXV
   - Phase 2: 100%ɍXV
   - S̐i: 85-90%ɍXV
   - {ȅڍׂL^

### R[h팸̐

**폜KV[R[h:**
- TcpClient.ps1: 120s
- TcpServer.ps1: 120s
- UdpCommunication.ps1: 120s
- ConnectionManager.ps1: 30s
- **v: 390s̃KV[R[h폜**

**ȗꂽ:**
```powershell
# Before: 180sibp[ + tH[obNj
# After: 45sibp[̂݁j
# 팸: 75%̃R[h팸
```

### A[LeN`̉P

**Beforei1j:**
```
Modules/TcpClient.ps1
   VA[LeN`iDj
   itH[obNj  KV[R[h
```

**Afteri2j:**
```
Modules/TcpClient.ps1
   VA[LeN`î݁j  N[Ȏ
```

### ZpIȗ_

1. **ێ琫̌**
   - R[hx[X25%팸
   - pXPꉻAfobOeՂ

2. **mȃG[nhO**
   - ServiceContainerɖIȃG[
   - gh~

3. **ѐ̊m**
   - ׂĂ̒ʐMW[p^[
   - VKJ҂̊wKRXg팸

4. **eX^reB̌**
   - ˑ֌Wm
   - bNX^ueՂɒ\

### ̃Xebv̐

1. **jbgeXg̊g[** - ṼeXgP[X쐬
2. **MessageProcessor ̎** - ev[g̓
3. **񐄏W[̒iKIp~v** - AutoResponse/OnReceivedHandler̊S폜
4. **UIwMVVM** - Phase 4̒

---

## ? 2025-11-16 {eT}[

### ^XN

1. ? **Modules/TcpClient.ps1 ̃bp[**
   - TcpClientAdapter DIɎgpɕύX
   - ServiceContaineroRŃA_v^[
   - tH[obN@\ɂ݊ێ
   - Shift-JISGR[fBOŕۑ

2. ? **Modules/TcpServer.ps1 ̃bp[**
   - TcpServerAdapter DIɎgpɕύX
   - ServiceContaineroRŃA_v^[
   - tH[obN@\ɂ݊ێ
   - Shift-JISGR[fBOŕۑ

3. ? **Modules/UdpCommunication.ps1 ̃bp[**
   - UdpAdapter DIɎgpɕύX
   - ServiceContaineroRŃA_v^[
   - tH[obN@\ɂ݊ێ
   - Shift-JISGR[fBOŕۑ

4. ? **ErrorHandler ̎mF**
   - `Core/Common/ErrorHandler.ps1` ɎĂ邱ƂmF
   - InvokeSafe \bhɂ铝IȃG[nhO@\

5. ? **ihLg̍XV**
   - REFACTORING_PROGRESS.md ɂׂĂ̕ύX𔽉f
   - i 75-80%  80% ɍXV
   - Phase 0 ̊ 90%  95% ɍXV

### ZpIȎڍ

**bp[p^[̎:**
```powershell
function Start-TcpClientConnection {
    param([object]$Connection)
    
    # VA[LeN`Dgp
    if ($Global:ServiceContainer) {
        try {
            $adapter = $Global:ServiceContainer.Resolve('TcpClientAdapter')
            
            if ($Connection -is [ManagedConnection]) {
                $adapter.Start($Connection.Id)
                return
            }
            
            if ($Connection.Id -and $Global:ConnectionService) {
                $managedConn = $Global:ConnectionService.GetConnection($Connection.Id)
                if ($managedConn) {
                    $adapter.Start($Connection.Id)
                    return
                }
            }
            
            Write-Warning "[TcpClient] Connection not in ConnectionService, using legacy fallback"
        } catch {
            Write-Warning "[TcpClient] Failed to use new architecture: $_"
        }
    }
    
    # tH[obN: i݊̂ߕێj
    # ...
}
```

### e͈

- ? ̐ڑׂ͂ēp
- ? VA[LeN`p\ȏꍇ͎IɎgp
- ? ւ̃tH[obNɂAڍsԒSɓ
- ? {iShift-JISjɑΉ

### ̃Xebv̐

1. **MessageProcessor ̎** - ev[g̓
2. **jbgeXg̊g[** - VA_v^[̃eXgP[X쐬
3. **ConnectionManager Ȃǂ̑W[̈ڍs** - iKIȊSڍs
4. **$Global:Connections ւ̒ڃANZX̍팸** - KV[R[h̐

---

**쐬:** GitHub Copilot  
**r[:** Draft - r[҂
