<#PSScriptInfo

.VERSION 1.0

.GUID 3f0ca459-2ac4-418f-8ef3-ff614f379092

.AUTHOR José Ramón Fernández Peralta [joseramon.fernandez@empresas.justicia.es]

. DATE 21/05/2024

.COMPANYNAME AYESA S.A.

.COPYRIGHT 2024 AYESA S.A.

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Remediación para activación y verificación de BitLocker en los dispositivos portátiles 

#> 
Param()

# Remediación para activación y verificación de BitLocker en los dispositivos portátiles.
## Casuísticas

### 1. WMI corrupto
### Solución: Reparar WMI

### 2. Cifrado de Disco duro por TPMPin
### Solución: Cambiar keyprotector de TPMPin a TPM

### 3. BitLocker suspendido. 
### Solución: Reanudación de encriptación

### 4. Cifrado de BitLocker no completado.
### Solución: Esperar a la finalización del cifrado completo de la unidad C:

### Log de ejecución almacenado en C:\temp\[yyyyMMddHHmmss]-BL_remedation.log

$count = 0
$MountPoint = "d"
$date = Get-Date
$computerSystem = Get-CimInstance Win32_ComputerSystem
$logFile = Join-Path -Path "C:\temp\" -ChildPath "$($date.ToString("yyyyMMddHHmmss"))-BL_remedation.log"

if (Test-Path -Path $logFile) {
    Remove-Item $logFile | Out-Null
}
New-Item -Path $logFile -ItemType File -Force | Out-Null
$counterFlag = $false

Function Write-Log {
    Param
    (
        [string]$message,
        [string]$ForegroundColor = "White",
        [switch]$noNewLine
    )
    if ($noNewLine) {
        Add-Content -Path $logFile -Value $message -NoNewLine
        Write-Host -NoNewline -ForegroundColor $ForegroundColor $message
    }
    else {
        Add-Content -Path $logFile -Value $message
        Write-Host -ForegroundColor $ForegroundColor $message
    }
    
}
$id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$wp = New-Object System.Security.Principal.WindowsPrincipal($id)
if ($computerSystem.PCSystemTypeEx -eq 2) {
    if (($wp.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))) {
        while (($count -le 2) -or ($counterFlag)) {
            Clear-Host
            Write-Log "=========== Comprobación de estado de BitLocker ===========`n"
            Write-Log "Fecha y hora de inicio:    $($date.ToString("dd/MM/yyyy - HH:mm:ss"))"
            Write-Log "Hostname:                  $($env:computername)"
            Write-Log -NoNewline "Número de serie:           "
            Write-Log "$((Get-CimInstance -ClassName Win32_Bios).SerialNumber)`n"
            Write-Log "===========================================================`n"

            try {
                # Obtiene informacion de BL.
                # Si el proceso WMI falla, lanza su restauración.
                Write-Log -NoNewline "- Obteniendo información BL en unidad C: "
                $bl_status = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
                Write-Log -ForegroundColor Green "Cumple"

                # Comprobación de tipos de protectores de BitLocker.
                Write-Log -NoNewline "- Claves de protección de BL:            "
                if ("TpmPin" -in $bl_status.KeyProtector.KeyProtectorType) {
                    Write-Log -ForegroundColor Red "No cumple"
                    Write-Log "`nRestaurando protectores de BitLocker correctos..."
                    Start-Process "manage-bde" -ArgumentList "-protectors", "-delete", $MountPoint, "-type", "tpmandpin" -NoNewWindow -Wait | Out-Null
                    Start-Process "manage-bde" -ArgumentList "-protectors", "-add", $MountPoint, "-tpm" -NoNewWindow -Wait  | Out-Null
                }
                else {
                    Write-Log -ForegroundColor Green "Cumple"

                    # Comprobación de activación de BitLocker.
                    Write-Log -NoNewline "- BitLocker Activo:                      "
                    if ($bl_status.ProtectionStatus -eq "Off") {
                        Write-Log -ForegroundColor Red "No cumple"
                        Write-Log "`nActivando protección de BitLocker..."
                        Start-Process manage-bde -ArgumentList "-protectors -enable $($MountPoint):" -Wait -NoNewWindow | Out-Null
                
                    }
                    else {
                        Write-Log -ForegroundColor Green "Cumple"

                        # Comprobación de cifrado completado de BitLocker.
                        Write-Log -NoNewline "- Porcentaje de cifrado:                 "
                        if ($bl_status.EncryptionPercentage -lt 100) {
                            Write-Log -ForegroundColor Red "No cumple - $($bl_status.EncryptionPercentage)%"
                            $counterFlag = $true
                            Start-Sleep -Seconds 10
                        }
                        else {
                            Write-Log -ForegroundColor Green "Cumple - $($bl_status.EncryptionPercentage)%"
                            Write-Log -NoNewline "`nEstado final de BitLocker en unidad C:   "
                            Write-Log -ForegroundColor Green "OK`n"
                            Write-Log "===========================================================`n"
                            Write-Log "Fecha y hora de fin:      $((Get-Date).ToString("dd/MM/yyyy - HH:mm:ss"))`n"
                            Write-Log "===========================================================`n"
                            Write-Host -BackGroundColor Red "`n¡¡Pendiente de realizar sincronización final con Intune!!`n`n"
                            exit
                        }
                    }
                }
        
            }
            catch [Microsoft.Management.Infrastructure.CimException] {
                # Comienza proceso de restauración de WMI
                Write-Log -ForegroundColor Red "No Cumple"
                Write-Log "Restaurando Proceso WMI..."
                Set-Service -Name winmgmt -StartupType Disabled
                Stop-Service -Name winmgmt -Force -Confirm:$false
                Start-Process winmgmt -ArgumentList "/salvagerepository"  -NoNewWindow -Wait
                Start-Process winmgmt -ArgumentList "/resetrepository" -NoNewWindow -Wait
                Set-Service -Name winmgmt -StartupType Automatic
                Start-Service -Name winmgmt
            }
            Write-Log "`nVolviendo a escanear estado de BitLocker..."
            Start-Sleep -Seconds 2
        }
        Write-Log -ForegroundColor Red "`nAlgo salió mal. Es necesario revisar el estado de BitLocker manualmente`n`n"
        exit
    }
    else {
        Write-Host -BackGroundColor Red "`n¡¡Es necesario iniciar sesión con privilegios de administración!!`n`n"
    }
}else {
    Write-Host -BackGroundColor Green -ForegroundColor Black "`nEste equipo no es un portátil/tablet y no necesita comprobación de BitLocker.`n"
}
