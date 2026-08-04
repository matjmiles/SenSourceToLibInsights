# Archived Documentation

These documents are **historical** and describe workflows, scripts, and open
questions that no longer reflect how the pipeline works. They are kept for context
on how the project got here.

**Do not follow instructions in these files.** For current documentation see
[../../README.md](../../README.md), [../SCRIPTS.md](../SCRIPTS.md), and
[../SERVER-DEPLOYMENT.md](../SERVER-DEPLOYMENT.md).

| File | Why it's archived |
|------|-------------------|
| `CLEANUP_SUMMARY.md` | Point-in-time record of the December 2025 reorganization. Describes scripts that no longer exist (`VEA-Zone-CSV-Processor.ps1`, `VEA-Generate-All-Individual-CSVs.ps1`) and an `INSTALLATION.md` that has since been folded into the README and SERVER-DEPLOYMENT guide. |
| `Springshare-Import-Analysis.md` | Research notes from when the LibInsights import format was unknown. The question it poses — "does LibInsights support bulk import?" — was answered: yes, via `POST /gate-count/{id}/save`. |
| `SPRINGSHARE-IMPORT-READY.md` | Documented the original **manual CSV upload** workflow with daily-aggregated data. Superseded by the automated API import, and the data is now hourly rather than daily. |
| `LibInsights API.txt` | Early notes on the LibApps v1.2 API at `lgapi-us.libapps.com`. The pipeline uses the LibInsights API at `byui.libinsight.com/v1.0` instead — see [../LibInsights-API.md](../LibInsights-API.md). |
