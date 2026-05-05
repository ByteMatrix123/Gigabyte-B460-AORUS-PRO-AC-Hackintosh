DefinitionBlock ("", "SSDT", 2, "DRTNIA", "CpuPlug", 0x00000000)
{
    External (_SB_.PR00, ProcessorObj)

    Scope (\_SB.PR00)
    {
        Method (_DSM, 4, NotSerialized)
        {
            If (!Arg2)
            {
                Return (Buffer (One)
                {
                     0x03
                })
            }

            If (_OSI ("Darwin"))
            {
                Return (Package (0x02)
                {
                    "plugin-type",
                    One
                })
            }

            Return (Buffer (One)
            {
                 0x00
            })
        }
    }
}
