# CheckBitLocker
Confirm that BitLocker is enabled on a device by performing various checks

# Escenario
Detección del aumento de dispositivos portátiles dentro de la organización que reportaban el cifrado de BitLocker como deshabilitado dentro de la herramienta de Intune (Azure).

# Casuísticas
1. El acceso desde la herramienta Intune a través de consultas del Módelo de Información Común (CIM) del Instrumental de Administración de Windows (WMI) está corrupto y devuelve una excepción.
2. Anteriormente, los clientes estaban configurados para ser administrados y supervisados por la herramienta MDOP MBAM.
   Posteriormente, esta interfaz administrativa fue deshabilitada en la organización por lo que cuando se deshabilita el cifrado del BitLocker (Actualizaciones de Windows, actualizaciones de firmware del dispostiivo, etc), no puede volver a habilitarse al estado anterior.
   Finalmente y como medida de remediación, es necesario activar el cifrado únicamente por TPM.
3. Como consecuencia del punto anterior, puede que alguna actualización al suspender BitLocker, utilice el parámetro RebootCount y aún habiendo solucionado el punto anterior, puede seguir desactivado BitLocker en el equipo

# Acciones
El script realiza las siguientes acciones:
- Comprueba que se trata de un dispositivo portátil.
- Comprueba que se puede realizar la consulta CIM al proceso WMI. En caso contrario, restaura el Instrumental de Windows (WMI).
- Comprueba que BitLocker no tiene activado el KeyProtector **TPMandPIN** y si tiene activado el KeyProtector **TPM**.
- Reanuda la protección de BitLocker si está suspendido.
- Finalmente, comprueba que la unidad escaneada está totalmente cifrada

  ** Este script se puede ejecutar en consola de Powershell (con privilegios de administración) o en herramientas de administración de sistemas (Ej: SCCM).

  ** De todo lo realizado queda una traza en el directorio **C:\temp\\[yyyyMMddHHmmss]-BL_remedation.log**

  
