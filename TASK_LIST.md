# TcpDebugger t@N^Oƃ^XNꗗ

**ŏIXV:** 2025-01-16

̃hLǵAARCHITECTURE_REFACTORING.mdŒĂꂽt@N^Ov̋̓Iȍƃ^XNAiǗ\Ȍ`Ő̂łB

---

## ^XNǗ̖}

- ? **** - EeXg
- ? **is** - ƒ
- ?? **ۗ** - ^XN̊҂
- ? **** - ܂JnĂȂ
- ?? **ubN** - ɂiss

---

## ? Phase 1: ً}ΉiCritical Pathj

### ? Epic 1.1: ʐMW[̃A[LeN`ڍs

**ړI:** $Global:Connectionsւ̒ڃANZXrAVA[LeN`ɊSڍs

#### Task 1.1.1: TcpClient ̃A_v^[ ?

**Dx:** P0 (ŗD)  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] `Core/Infrastructure/Adapters/TcpClientAdapter.ps1` VK쐬
2. [ ] `Modules/TcpClient.ps1` ̃WbNNXĈڐA
3. [ ] RXgN^ ConnectionService  ReceivedEventPipeline 𒍓
4. [ ] ServiceContainer ւ̓o^ǉ
5. [ ]  Start-TcpClient ֐VA_v^[̃bp[ɕύX

**:**
```powershell
# Core/Infrastructure/Adapters/TcpClientAdapter.ps1
class TcpClientAdapter {
    hidden [ConnectionService]$_connectionService
    hidden [ReceivedEventPipeline]$_pipeline
    hidden [Logger]$_logger
    
    TcpClientAdapter(
        [ConnectionService]$connectionService,
        [ReceivedEventPipeline]$pipeline,
        [Logger]$logger
    ) {
        $this._connectionService = $connectionService
        $this._pipeline = $pipeline
        $this._logger = $logger
    }
    
    [void] Start([string]$connectionId) {
        $conn = $this._connectionService.GetConnection($connectionId)
        # ... ڑ ...
        
        # M
        $this._pipeline.ProcessEvent($connectionId, $receivedData, $metadata)
    }
}
```

**:**
- [ ] TcpClientAdapter NXɓ
- [ ] $Global:Connections ւ̎QƂ[
- [ ] ̃ViIeXgSĒʉ

**ˑ֌W:** Ȃ

---

#### Task 1.1.2: TcpServer ̃A_v^[ ?

**Dx:** P0 (ŗD)  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] `Core/Infrastructure/Adapters/TcpServerAdapter.ps1` VK쐬
2. [ ] `Modules/TcpServer.ps1` ̃WbNNXĈڐA
3. [ ] Task 1.1.1 Ɠl̃p^[Ŏ
4. [ ] ServiceContainer ւ̓o^ǉ
5. [ ]  Start-TcpServer ֐VA_v^[̃bp[ɕύX

**:**
- [ ] TcpServerAdapter NXɓ
- [ ] $Global:Connections ւ̎QƂ[
- [ ] ̃ViIeXgSĒʉ

**ˑ֌W:** Task 1.1.1 (p^[mɒ萄)

---

#### Task 1.1.3: UDP ̃A_v^[ ?

**Dx:** P0 (ŗD)  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] `Core/Infrastructure/Adapters/UdpAdapter.ps1` VK쐬
2. [ ] `Modules/UdpCommunication.ps1` ̃WbNNXĈڐA
3. [ ] Task 1.1.1 Ɠl̃p^[Ŏ
4. [ ] ServiceContainer ւ̓o^ǉ
5. [ ]  Start-UdpCommunication ֐VA_v^[̃bp[ɕύX

**:**
- [ ] UdpAdapter NXɓ
- [ ] $Global:Connections ւ̎QƂ[
- [ ] ̃ViIeXgSĒʉ

**ˑ֌W:** Task 1.1.1 (p^[mɒ萄)

---

#### Task 1.1.4: ServiceContainer ւ̒ʐMA_v^[o^ ?

**Dx:** P0 (ŗD)  
**H:** 2-4  
**S:** _蓖_

**e:**
1. [ ] TcpDebugger.ps1  ServiceContainer XV
2. [ ] eA_v^[ Transient ܂ Singleton œo^
3. [ ] t@Ng֐ł̈ˑ

**:**
```powershell
# TcpDebugger.ps1
$container.RegisterTransient('TcpClientAdapter', {
    param($c)
    $connectionService = $c.Resolve('ConnectionService')
    $pipeline = $c.Resolve('ReceivedEventPipeline')
    $logger = $c.Resolve('Logger')
    [TcpClientAdapter]::new($connectionService, $pipeline, $logger)
})
```

**:**
- [ ] ׂĂ̒ʐMA_v^[ ServiceContainer 擾\
- [ ] ˑĂ

**ˑ֌W:** Task 1.1.1, 1.1.2, 1.1.3

---

### ? Epic 1.2: W[̔񐄏ƃbp[

**ړI:** V̓dA[LeN`AiKIȈڍs𑣐i

**Status:** ReceivedEventPipeline ɂlĂ旧ハンドラーを削除済み。

---

#### Task 1.2.2: AutoResponse ̃bp[ ?

**Dx:** P1 ()  
**H:** 4-6  
**S:** _蓖_

**e:**
1. [ ] `Modules/AutoResponse.ps1` ̊e֐ RuleProcessor ̃bp[ɕύX
2. [ ] 񐄏xbZ[Wǉ
3. [ ] Read-AutoResponseRules  RuleRepository ̃bp[ɕύX

**:**
```powershell
function Invoke-ConnectionAutoResponse {
    [Obsolete("Use RuleProcessor via ReceivedEventPipeline instead.")]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionId,
        [Parameter(Mandatory=$true)]
        [byte[]]$ReceivedData
    )
    
    Write-Warning "[DEPRECATED] Invoke-ConnectionAutoResponse is deprecated. Use RuleProcessor."
    
    # RuleRepository oRŃ[擾
    $repository = Get-RuleRepository
    $conn = Get-ManagedConnection -ConnectionId $ConnectionId
    # ... ȉARuleProcessor ĂяoɃ_CNg
}
```

**:**
- [ ] ֐ RuleProcessor ւ̔bp[ɂȂĂ
- [ ] 񐄏x\
- [ ] ̌Ăяo삷

**ˑ֌W:** Ȃ

---

#### Task 1.2.3: OnReceivedHandler ̃bp[ ?

**Dx:** P1 ()  
**H:** 4-6  
**S:** _蓖_

**e:**
1. [ ] `Modules/OnReceivedHandler.ps1` ̊e֐ RuleProcessor ̃bp[ɕύX
2. [ ] 񐄏xbZ[Wǉ
3. [ ] Read-OnReceivedRules  RuleRepository ̃bp[ɕύX

**:**
- [ ] ֐ RuleProcessor ւ̔bp[ɂȂĂ
- [ ] 񐄏x\
- [ ] ̌Ăяo삷

**ˑ֌W:** Ȃ

---

### ? Epic 1.3: MessageProcessor ̎

**ړI:** ev[g̓ƏdR[h̍팸

#### Task 1.3.1: MessageProcessor NX̎ ?

**Dx:** P0 (ŗD)  
**H:** 12-16  
**S:** _蓖_

**e:**
1. [ ] `Core/Domain/MessageProcessor.ps1` 쐬
2. [ ] ARCHITECTURE_REFACTORING.md t^A.3 ̎dlɏ]Ď
3. [ ] ϐWJWbN̎
4. [ ] GR[fBOϊ̎
5. [ ] jbgeXg̍쐬

**ׂ\bh:**
```powershell
class MessageProcessor {
    [byte[]] ProcessTemplate([string]$templatePath, [hashtable]$variables)
    hidden [string] ExpandVariables([string]$format, [hashtable]$variables)
    hidden [byte[]] ConvertToBytes([string]$data, [string]$encoding)
    [string] FormatMessage([byte[]]$data, [string]$encoding)
}
```

**:**
- [ ] MessageProcessor NX݌vʂɓ
- [ ] jbgeXgׂĒʉ
- [ ] ̃ev[gƓ̋@\

**ˑ֌W:** Task 1.3.2 (sƉ\)

---

#### Task 1.3.2: TemplateRepository ̎ ?

**Dx:** P0 (ŗD)  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] `Core/Infrastructure/Repositories/TemplateRepository.ps1` 쐬
2. [ ] RuleRepository Ɠl̃LbV@\
3. [ ] CSV`̃ev[gǂݍ
4. [ ] t@CύXmƃLbV

**ׂ\bh:**
```powershell
class TemplateRepository {
    [TemplateDefinition] GetTemplate([string]$filePath)
    [void] ClearCache([string]$filePath)
    hidden [TemplateDefinition] TryGetCached([string]$key, [datetime]$lastWrite)
    hidden [void] SetCache([string]$key, [datetime]$lastWrite, [TemplateDefinition]$template)
}

class TemplateDefinition {
    [string]$Format
    [string]$Encoding
    [hashtable]$Metadata
}
```

**:**
- [ ] TemplateRepository  RuleRepository Ɠlɓ
- [ ] LbV@\
- [ ] jbgeXgׂĒʉ

**ˑ֌W:** Ȃ

---

#### Task 1.3.3: MessageProcessor  ServiceContainer o^ ?

**Dx:** P1 ()  
**H:** 2-4  
**S:** _蓖_

**e:**
1. [ ] TcpDebugger.ps1  ServiceContainer XV
2. [ ] MessageProcessor  Singleton œo^
3. [ ] TemplateRepository  Singleton œo^

**:**
```powershell
$container.RegisterSingleton('TemplateRepository', {
    param($c)
    $logger = $c.Resolve('Logger')
    [TemplateRepository]::new($logger)
})

$container.RegisterSingleton('MessageProcessor', {
    param($c)
    $templateRepo = $c.Resolve('TemplateRepository')
    $logger = $c.Resolve('Logger')
    [MessageProcessor]::new($templateRepo, $logger)
})
```

**:**
- [ ] MessageProcessor  ServiceContainer 擾\
- [ ] ˑĂ

**ˑ֌W:** Task 1.3.1, 1.3.2

---

#### Task 1.3.4: ̃ev[g MessageProcessor Ɉڍs ?

**Dx:** P1 ()  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] `Modules/MessageHandler.ps1` ̃ev[g MessageProcessor ĂяoɕύX
2. [ ] `Modules/QuickSender.ps1` ̃ev[g MessageProcessor ĂяoɕύX
3. [ ] `Modules/ScenarioEngine.ps1` ̃ev[g MessageProcessor ĂяoɕύX
4. [ ] eW[ŏdĂWbN폜

**:**
- [ ] ׂẴev[g MessageProcessor oRɂȂĂ
- [ ] dR[h폜Ă
- [ ] ̃ViIeXgSĒʉ

**ˑ֌W:** Task 1.3.1, 1.3.2, 1.3.3

---

## ? Phase 2: dvPiImportant but not Urgentj

### ? Epic 2.1: G[nhO̓

#### Task 2.1.1: ErrorHandler NX̎ ?

**Dx:** P2 ()  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] `Core/Common/ErrorHandler.ps1` 쐬
2. [ ] JX^ONX̒`
   - CommunicationException
   - InvalidOperationException
   - ConfigurationException
3. [ ] 3wG[nhO헪̎
4. [ ] G[O̍\

**:**
```powershell
# JX^O
class CommunicationException : System.Exception {
    CommunicationException([string]$message) : base($message) {}
    CommunicationException([string]$message, [Exception]$inner) : base($message, $inner) {}
}

# ErrorHandler
class ErrorHandler {
    hidden [Logger]$_logger
    
    [void] HandleInfrastructureError([Exception]$ex, [hashtable]$context)
    [void] HandleDomainError([Exception]$ex, [hashtable]$context)
    [void] HandleApplicationError([Exception]$ex, [hashtable]$context)
}
```

**:**
- [ ] ErrorHandler NXɓ
- [ ] JX^O`Ă
- [ ] jbgeXgׂĒʉ

**ˑ֌W:** Ȃ

---

#### Task 2.1.2: ̃G[ ErrorHandler Ɉڍs ?

**Dx:** P2 ()  
**H:** 12-16  
**S:** _蓖_

**e:**
1. [ ] eʐMA_v^[̃G[ ErrorHandler oRɕύX
2. [ ] Domainw̃G[ ErrorHandler oRɕύX
3. [ ] Applicationw̃G[ ErrorHandler oRɕύX
4. [ ] IȃG[nhOp^[Kp

**:**
- [ ] ׂẴG[ ErrorHandler oRɂȂĂ
- [ ] G[O\Ă
- [ ] try-catch ̃p^[ꂳĂ

**ˑ֌W:** Task 2.1.1

---

### ? Epic 2.2: Repository ̊g[

#### Task 2.2.1: ScenarioRepository ̎ ?

**Dx:** P2 ()  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] `Core/Infrastructure/Repositories/ScenarioRepository.ps1` 쐬
2. [ ] ViICSVt@C̓ǂݍ
3. [ ] LbV@\̎
4. [ ] t@CύXm

**ׂ\bh:**
```powershell
class ScenarioRepository {
    [ScenarioStep[]] GetScenario([string]$filePath)
    [void] ClearCache([string]$filePath)
}
```

**:**
- [ ] ScenarioRepository ɓ
- [ ] LbV@\
- [ ] jbgeXgׂĒʉ

**ˑ֌W:** Ȃ

---

#### Task 2.2.2: ConfigurationRepository ̎ ?

**Dx:** P3 ()  
**H:** 6-8  
**S:** _蓖_

**e:**
1. [ ] `Core/Infrastructure/Repositories/ConfigurationRepository.ps1` 쐬
2. [ ] .psd1 `̐ݒt@Cǂݍ
3. [ ] ݒ̃of[V

**:**
- [ ] ConfigurationRepository ɓ
- [ ] ݒ̃of[V@\

**ˑ֌W:** Ȃ

---

### ? Epic 2.3: jbgeXg̊g[

#### Task 2.3.1: ConnectionService ̃eXg쐬 ?

**Dx:** P2 ()  
**H:** 6-8  
**S:** _蓖_

**e:**
1. [ ] `Tests/Unit/Core/Domain/ConnectionService.Tests.ps1` 쐬
2. [ ] ڑ̒ǉE擾E폜̃eXg
3. [ ] XbhS̃eXg
4. [ ] G[P[X̃eXg

**:**
- [ ] R[hJobW 80% ȏ
- [ ] ׂẴeXgʉ

**ˑ֌W:** Ȃ

---

#### Task 2.3.2: ReceivedEventPipeline ̃eXg쐬 ?

**Dx:** P2 ()  
**H:** 6-8  
**S:** _蓖_

**e:**
1. [ ] `Tests/Unit/Core/Domain/ReceivedEventPipeline.Tests.ps1` 쐬
2. [ ] Cxgt[̃eXg
3. [ ] RuleProcessor Ag̃eXg
4. [ ] G[P[X̃eXg

**:**
- [ ] R[hJobW 80% ȏ
- [ ] ׂẴeXgʉ

**ˑ֌W:** Ȃ

---

#### Task 2.3.3: RuleProcessor ̃eXg쐬 ?

**Dx:** P2 ()  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] `Tests/Unit/Core/Domain/RuleProcessor.Tests.ps1` 쐬
2. [ ] [}b`ÕeXg
3. [ ] AutoResponse / OnReceived ̃eXg
4. [ ] Unified`̃eXg
5. [ ] G[P[X̃eXg

**:**
- [ ] R[hJobW 80% ȏ
- [ ] ׂẴeXgʉ

**ˑ֌W:** Ȃ

---

#### Task 2.3.4: MessageProcessor ̃eXg쐬 ?

**Dx:** P2 ()  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] `Tests/Unit/Core/Domain/MessageProcessor.Tests.ps1` 쐬
2. [ ] ev[gWJ̃eXg
3. [ ] ϐũeXg
4. [ ] GR[fBOϊ̃eXg
5. [ ] G[P[X̃eXg

**:**
- [ ] R[hJobW 80% ȏ
- [ ] ׂẴeXgʉ

**ˑ֌W:** Task 1.3.1 (MessageProcessor )

---

#### Task 2.3.5: eXg̍쐬 ?

**Dx:** P2 ()  
**H:** 12-16  
**S:** _蓖_

**e:**
1. [ ] `Tests/Integration/` tH_쐬
2. [ ] ʐMt[̓eXgiTCP Client/Server, UDPj
3. [ ] ViIs̓eXg
4. [ ] MCxg̓eXg

**:**
- [ ] vȃ[XP[XeXgŃJo[Ă
- [ ] ׂẴeXgʉ

**ˑ֌W:** Task 1.1.1, 1.1.2, 1.1.3

---

## ? Phase 3: PiNice to havej

### ? Epic 3.1: UIwMVVM

#### Task 3.1.1: ConnectionViewModel ̎ ?

**Dx:** P3 ()  
**H:** 12-16  
**S:** _蓖_

**e:**
1. [ ] `Presentation/UI/ConnectionViewModel.ps1` 쐬
2. [ ] INotifyPropertyChanged ̎
3. [ ] f[^oCfBOpvpeB̒`
4. [ ] R}hnh[̎

**:**
- [ ] ConnectionViewModel ɓ
- [ ] f[^oCfBO@\

**ˑ֌W:** Ȃ

---

#### Task 3.1.2: UIUpdateService ̎ ?

**Dx:** P3 ()  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] `Presentation/UI/UIUpdateService.ps1` 쐬
2. [ ] UIXbhł̈SȍXV
3. [ ] Invoke p^[̓ꉻ

**:**
- [ ] UIXV񓯊ňSɍs
- [ ] UIt[YȂ

**ˑ֌W:** Ȃ

---

#### Task 3.1.3: MainForm ̃t@N^O ?

**Dx:** P3 ()  
**H:** 16-24  
**S:** _蓖_

**e:**
1. [ ] `UI/MainForm.ps1` MVVMp^[Ɉڍs
2. [ ] ViewModel Ƃ̃f[^oCfBO
3. [ ] Cxgnh[̐
4. [ ] UIXVWbN UIUpdateService ւ̈ڍs

**:**
- [ ] MainForm  MVVM p^[ɏ]Ă
- [ ] rWlXWbN ViewModel ɈړĂ
- [ ] UI ̉サĂ

**ˑ֌W:** Task 3.1.1, 3.1.2

---

### ? Epic 3.2: CtXgN`̐

#### Task 3.2.1: CI/CDpCvC̍\z ?

**Dx:** P3 ()  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] GitHub Actions ܂ Azure DevOps pCvC̐ݒ
2. [ ] eXgs̐ݒ
3. [ ] R[hJobW|[g̐
4. [ ] ÓI̓c[̓

**:**
- [ ] R~bgɎeXgs
- [ ] JobW|[g
- [ ] ÓI͌ʂ\

**ˑ֌W:** Task 2.3.x (eXg쐬)

---

#### Task 3.2.2: hLg ?

**Dx:** P3 ()  
**H:** 6-8  
**S:** _蓖_

**e:**
1. [ ] platyPS gp API t@X
2. [ ] W[Ӗ}gNX̍쐬
3. [ ] ڍsKCh̍쐬

**:**
- [ ] APIt@X
- [ ] hLgŐV̏Ԃɕۂ

**ˑ֌W:** Ȃ

---

### ? Epic 3.3: W[̍폜

#### Task 3.3.1: 񐄏W[̍폜v ?

**Dx:** P3 ()  
**H:** 4-6  
**S:** _蓖_

**e:**
1. [ ] 폜ΏۃW[̃XgAbv
2. [ ] ˑ֌W̊mF
3. [ ] 폜XPW[̍
4. [ ] [U[ւ̍m

**:**
- [ ] 폜v悪Ă
- [ ] ֌W҂ɎmĂ

**ˑ֌W:** Task 1.2.x (bp[)

---

#### Task 3.3.2: ModulestH_̒iKI폜 ?

**Dx:** P3 ()  
**H:** 8-12  
**S:** _蓖_

**e:**
1. [ ] gpĂȂW[珇폜
2. [ ] e폜̓mF
3. [ ] ŏII Modules/ tH_ Core/ ɓ

**:**
- [ ] ׂĂ̋W[폜Ă
- [ ] VA[LeN`݂̂gpĂ
- [ ] ׂẴeXgʉ߂Ă

**ˑ֌W:** Task 3.3.1,  Phase 1, 2 ׂ̂Ẵ^XN

---

## ? igbLO

### S̐i

| Phase | ^XN |  | is |  | i |
|-------|-----------|------|--------|--------|--------|
| Phase 1 (ً}) | 13 | 0 | 0 | 13 | 0% |
| Phase 2 (dv) | 12 | 0 | 0 | 12 | 0% |
| Phase 3 () | 7 | 0 | 0 | 7 | 0% |
| **v** | **32** | **0** | **0** | **32** | **0%** |

### Epicʐi

| Epic | ^XN |  | is |  | i |
|------|-----------|------|--------|--------|--------|
| 1.1 ʐMW[ڍs | 4 | 0 | 0 | 4 | 0% |
| 1.2 W[񐄏 | 3 | 0 | 0 | 3 | 0% |
| 1.3 MessageProcessor | 4 | 0 | 0 | 4 | 0% |
| 2.1 G[nhO | 2 | 0 | 0 | 2 | 0% |
| 2.2 Repositoryg[ | 2 | 0 | 0 | 2 | 0% |
| 2.3 jbgeXgg[ | 5 | 0 | 0 | 5 | 0% |
| 3.1 UIwMVVM | 3 | 0 | 0 | 3 | 0% |
| 3.2 Ct | 2 | 0 | 0 | 2 | 0% |
| 3.3 W[폜 | 2 | 0 | 0 | 2 | 0% |

---

## ? 钅菇

### Week 1-2
1. Task 1.1.1: TcpClient ̃A_v^[
2. Task 1.3.1: MessageProcessor NX̎
3. Task 1.3.2: TemplateRepository ̎

### Week 3-4
4. Task 1.1.2: TcpServer ̃A_v^[
5. Task 1.1.3: UDP ̃A_v^[
6. Task 1.1.4: ServiceContainer ւ̒ʐMA_v^[o^
7. Task 1.3.3: MessageProcessor  ServiceContainer o^

### Week 5-6
8. Task 1.3.4: ̃ev[g MessageProcessor Ɉڍs
9. Task 1.2.1, 1.2.2, 1.2.3: W[̃bp[
10. Task 2.1.1: ErrorHandler NX̎

### Week 7-8
11. Task 2.3.1-2.3.4: jbgeXg̊g[
12. Task 2.1.2: ̃G[ ErrorHandler Ɉڍs
13. Task 2.2.1: ScenarioRepository ̎

### Week 9 ȍ~
14. Phase 3 ̃^XNɒ

---

## ? ^XNǗ̃xXgvNeBX

### ^XN̊Jn
- [ ] ^XN̎eƊĊmF
- [ ] ˑ֌W^XNĂ邩mF
- [ ] u`쐬i: `feature/task-1.1.1-tcpclient-adapter`j
- [ ] ^XNXe[^Xuis?vɍXV

### ^XN̊
- [ ] ׂĖĂ邩mF
- [ ] jbgeXg쐬Es
- [ ] R[hr[˗
- [ ] }[WA^XNXe[^Xu?vɍXV
- [ ] igbLOe[uXV

### Tr[
- [ ] ^XN̐UԂ
- [ ] ubNĂ^XN̊mF
- [ ] Ťv旧
- [ ] i̍XV

---

## ? ֘AhLg

- [ARCHITECTURE_REFACTORING.md](./ARCHITECTURE_REFACTORING.md) - t@N^O݌v
- [REFACTORING_PROGRESS.md](./REFACTORING_PROGRESS.md) - i|[g
- [DESIGN.md](./DESIGN.md) - S̐݌v
- [README.md](./README.md) - vWFNgTv

---

**ŏIXV:** GitHub Copilot  
**r[:** Draft - r[҂
