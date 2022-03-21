ContainerAppConsoleLogs_CL 
| order by TimeGenerated desc 
| project  TimeGenerated, ContainerName_s,  Log_s