# SolarWinds Orion Modern Dashboards

Thirty import-ready JSON dashboard exports for Windows and Linux server infrastructure (virtual and physical).

## Contents

- `dashboards/catalog.json` - index of all 30 dashboards with titles and filenames
- `dashboards/dashboard-*.json` - individual dashboard exports
- `New-SolarWindsDashboards.ps1` - regenerate all JSON files

## Dashboard titles

1. Windows Server Fleet Health Overview
2. Linux Server Fleet Health Overview
3. Virtual Windows Server Performance
4. Virtual Linux Server Performance
5. Physical Server Hardware Health
6. Critical Windows Services Availability
7. Critical Linux Daemon Availability
8. Cross-Platform CPU Hotspots
9. Memory Pressure Alert Board
10. Windows Disk Capacity and Forecast
11. Linux Filesystem Capacity and Forecast
12. WSUS Patch Compliance Summary
13. SCCM Patch Compliance Dashboard
14. Linux Package Patch Status
15. Certificate Expiration Radar
16. Internal PKI Cert 30-60-90 Day View
17. Web Server SSL TLS Certificate Monitor
18. Windows Critical Event Log Errors
19. Linux Syslog Severity Dashboard
20. Active Directory Domain Controller Health
21. DNS Resolution Performance
22. Server-to-Server Network Latency
23. VMware Cluster Capacity and Oversubscription
24. Hyper-V Host Capacity Overview
25. SQL Server Instance Health
26. IIS Web Server Availability and Response
27. RDS Session Host Load and Sessions
28. Backup Job Success Rate
29. EDR and Antivirus Agent Status
30. Change Window Infrastructure Readiness

## Import

1. Open SolarWinds Orion Web Console
2. Go to **Dashboards** and choose **Manage Dashboards** (or **Import**, depending on version)
3. Import each JSON file or use your org's dashboard deployment process
4. Edit SWQL queries inside widgets to match your node naming and licensed modules

Patterns are inspired by Thwack community boards; adjust tables and chart types for your Orion version.

## Regenerate

```powershell
.\New-SolarWindsDashboards.ps1
```
