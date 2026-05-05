DefinitionBlock ("", "SSDT", 2, "DRTNIA", "AWAC", 0x00000000)
{
    External (STAS, FieldUnitObj)

    Scope (\_SB)
    {
        Method (_INI, 0, NotSerialized)  // _INI: Initialize
        {
            If (_OSI ("Darwin"))
            {
                STAS = One
            }
        }
    }
}
