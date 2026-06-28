# ServerOps Toolkit - Tools

Standalone PowerShell tools for Windows infrastructure teams. Built following `.cursor/rules/powershell-wpf.mdc`:

- **GUI tools** use WPF (XAML + launcher + `.psm1` logic)
- **Remote ops** prefer CIM / `Invoke-Command`
- **ASCII-only** strings in scripts (Mac share / Windows PowerShell safe)

Run these on a **Windows admin workstation** with PowerShell 5.1+ unless noted.

## Quick reference

| # | Tool | Entry point | Purpose |
|---|------|-------------|---------|
| 1 | Command Vault | `CommandVault\CommandVault.ps1` | Searchable command library with tags, favorites, copy/execute, JSON import/export |
| 2 | Windows Server Build Wizard | `New-WindowsServer\New-WindowsServer.ps1` | Interactive wizard -> deploy script, unattend.xml, post-config checklist (vCenter content library) |
| 3 | Server Hardening | `Invoke-ServerHardening\Invoke-ServerHardening.ps1` | CIS Level 1/2 apply + compliance check + HTML report (idempotent) |
| 4 | Release / Handover Doc | `New-ServerReleaseDoc\New-ServerReleaseDoc.ps1` | Markdown + Word/PDF handover document for ops teams |
| 5 | Infra Quick Launcher | `Infra-Launcher\Infra-Launcher.ps1` | Console menu or `-TrayMode` system tray for infra links |
| 6 | Snippet Manager | `SnippetManager\SnippetManager.ps1` | Pick/copy templates: logging, errors, Secret Server creds, scheduled tasks, DSC |
| 7 | Infra Snapshot | `Get-InfrastructureSnapshot\Get-InfrastructureSnapshot.ps1` | Living Markdown doc from vCenter, Infoblox, Orion, CIM |
| 8 | Batch Server Builder | `New-BatchServerBuild\New-BatchServerBuild.ps1` | CSV-driven build script generator + optional remoting |
| 9 | Cert / Patch Dashboard | `Get-CertPatchDashboard\Get-CertPatchDashboard.ps1` | SharePoint cert expiry + WSUS/SCCM patch summary HTML |
| 10 | Troubleshoot Kit | `Start-TroubleshootKit\Start-TroubleshootKit.ps1` | One-click diagnostics zip for tickets |
| 11 | SolarWinds Dashboards | `SolarWinds-Dashboards\dashboards\` | 30 modern Orion JSON dashboards + `catalog.json` |

## Examples

```powershell
cd C:\path\to\ServerOpsToolkit\Tools

# 1 - Command vault GUI
.\CommandVault\CommandVault.ps1

# 2 - Build wizard
.\New-WindowsServer\New-WindowsServer.ps1

# 3 - Hardening (local)
.\Invoke-ServerHardening\Invoke-ServerHardening.ps1 -Level Level1

# 4 - Handover doc
.\New-ServerReleaseDoc\New-ServerReleaseDoc.ps1 -ServerName srv-web-01 `
    -Applications 'IIS','.NET 4.8' -Ports '443/tcp','80/tcp' -Dependencies 'SQL-PROD-01'

# 5 - Infra launcher (tray)
.\Infra-Launcher\Infra-Launcher.ps1 -TrayMode

# 6 - Snippets
.\SnippetManager\SnippetManager.ps1

# 7 - Infrastructure snapshot
.\Get-InfrastructureSnapshot\Get-InfrastructureSnapshot.ps1 -ServerName srv-web-01

# 8 - Batch builds from CSV
.\New-BatchServerBuild\New-BatchServerBuild.ps1 -InputCsv .\New-BatchServerBuild\sample-servers.csv

# 9 - Cert and patch dashboard
.\Get-CertPatchDashboard\Get-CertPatchDashboard.ps1 -SharePointSiteUrl https://sharepoint.example.com/sites/Infra

# 10 - Troubleshoot pack
.\Start-TroubleshootKit\Start-TroubleshootKit.ps1 -ComputerName srv-web-01 -TicketNumber INC123456

# 11 - Regenerate SolarWinds dashboard JSON (optional)
.\SolarWinds-Dashboards\New-SolarWindsDashboards.ps1
```

## Configuration

| Tool | Config location |
|------|-----------------|
| Command Vault | `%APPDATA%\CommandVault\commands.json` |
| Infra Launcher | `Infra-Launcher\config\links.json` |
| Infra Snapshot | `%APPDATA%\InfraSnapshot\settings.json` (auto-created) |

Edit `links.json` and snapshot settings with your org URLs before first use.

## SolarWinds dashboards (Tool 11)

Thirty import-ready JSON files live in `SolarWinds-Dashboards\dashboards\`. Open `catalog.json` for titles and filenames. Categories include Windows/Linux (virtual and physical), patching, certificates, AD, VMware, Hyper-V, SQL, IIS, RDS, backup, and EDR.

Import via Orion **Dashboards > Manage > Import** (exact menu varies by Orion version). Review SWQL queries and adjust object names for your environment.

## Prerequisites by tool

- **VMware tools (2, 7, 8)**: `Install-Module VMware.PowerCLI -Scope CurrentUser`
- **Orion snapshot (7)**: `Install-Module SwisPowerShell`
- **SharePoint certs (9)**: `Install-Module PnP.PowerShell`
- **Handover Word/PDF (4)**: Microsoft Word (COM) on the workstation
- **AD snippets / snapshot**: RSAT Active Directory tools

## Project layout

```
Tools/
├── README.md
├── CommandVault/          # WPF: ui/, src/, data/
├── New-WindowsServer/
├── Invoke-ServerHardening/  # src/HardeningBaseline.psm1
├── New-ServerReleaseDoc/
├── Infra-Launcher/        # config/links.json
├── SnippetManager/        # snippets/*.ps1
├── Get-InfrastructureSnapshot/
├── New-BatchServerBuild/
├── Get-CertPatchDashboard/
├── Start-TroubleshootKit/
└── SolarWinds-Dashboards/ # dashboards/*.json, catalog.json
```
