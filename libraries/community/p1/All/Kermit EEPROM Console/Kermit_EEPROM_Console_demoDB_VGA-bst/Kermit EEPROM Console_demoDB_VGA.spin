{{

┌──────────────────────────────────────────────────────────────────────┐
│ Kermit EEPROM Kermit EEPROM Console_demoDB_VGA, program to show use  │
| of command line IO via serial port with Kermit, protocol download of │
│ .EEPROM, has elaborate VGA display of process for debugging, is slow │
│ because of this display                                              │
│ Author: Eric Ratliff                                                 │
│ Copyright (c) 2009, 2010 Eric Ratliff                                │
│ See end of file for terms of use.                                    │
└──────────────────────────────────────────────────────────────────────┘

Kermit EEPROM Console_demoDB_VGA.spin,
2009.5.30 by Eric Ratliff
2010.2.21 Eric Ratliff, eliminated separate public calls to FileReceive and ProcessInput, now just call Process
}}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
  ARRAY_SIZE = Debugger#InputDisplaySizeLong
  null = 0
  TimeTrioBaseIndex = 24        ' where to display execution speed statistics
  DoDebug = true
  SimulateDebugging = false

OBJ
  ConsoleSerialDriver : "Kermit EEPROM Console"
  'KDefs : "KermitConsoleDefs"
  'Monitor :     "MonVarsVGA"
  nums : "Numbers"
  Debugger : "KermitConsoleDebugger"

VAR
  ' console serial port variables
  long rxPin ' where Propeller chip receives data
  long txPin ' where Propeller chip outputs data
  long SerialMode ' bit 0: invert rx, bit 1 invert tx, bit 2 open-drain source tx, ignore tx echo on rx
  ' individual components of mode
  long InvertRx
  long InvertTx
  long OpenDrainSourctTx
  long IgnoreTxEchoOnRx
  long baud ' (bits/second)

  byte CommandBuffer[ConsoleSerialDriver#LineLengthLimit+1+10] ' room for command and null terminator
  long ByteCount ' how many bytes came back in the command
  long UseCommandLines,EchoInput

  long MonArray[ARRAY_SIZE]
  long SpacerLong[100] ' dummy space, for avoiding possible monitor array overrun problems
  long last_loop_end  ' (clocks)
  long this_loop_end
  long this_period    ' execution speed for loop, excluding time to post execution speed (clocks)
  long min_period
  long max_period
  long KECPIcall_start  ' (clocks)
  long KECPIcall_end
  long KECRFcall_start  ' (clocks)
  long KECRFcall_end
  long max_KECPIcall  ' longest time to call console input processing routine (clocks)
  long max_KECRFcall  ' longest time to call kermit file receive routint (clocks)
  long MaxCallClk     ' max of above two (clocks)
  long ClocksPerTms   ' clocks per 1/10 millisecond (clocks)
  long MaxCallTms     ' maximum console call time, later remainder (1/10ths of millisecond)
  long MaxCallMs      ' maximum colsole call time, truncated (milliseconds)
  long ms_divider     ' to change clocks to milliseconds (clocks/ms)
  long pDebug         ' pointer to the debug structure
  long ProcessorResultFlags ' from input or receive file call
  'long DisplayStartSuccess ' flag to show monitor/debugger and possibly tx buffer monitor started
  long pGenVars ' pointer to beginning of monitor array, or zero depending on VGA driver success
  long BeenHere
  long StartTimeUDSim 'debugging timer variables
  long DisplaySimTimeClk

  

PUB main
  if DoDebug
    ' show numbers as unsigned hex with bytes separated by underscores
    ' entire array and following long variable
    pDebug := Debugger.Start(@MonArray)
    if pDebug ' did VGA driver start?
      pGenVars := @MonArray
    else
      pGenVars := 0
  else
    pDebug := 0 ' no full debugging
    pGenVars := 0 ' not even any general debug variables

  DisplaySimTimeClk := DurationClks(4)
    
  nums.Init ' prepare for formatted output

  ' console serial driver parameters
  rxPin := 31 ' 31 is for USB port
  txPin := 30
  
  'rxPin := 7  ' 7 is where I have wired an XBee module on a Propeller Demo board
  'txPin := 6

  InvertRx := FALSE   ' (does not matter, this program only transmits)
  InvertTx := FALSE   ' (must be FALSE)
  OpenDrainSourctTx := TRUE ' I'm guessing this is for half duplex, such as 2 wire RS-485 (does not matter)
  IgnoreTxEchoOnRx := FALSE ' I'm guessing this is for half duplex, such as 2 wire RS-485 ( surprise, must be FALSE for transmit to work)
  SerialMode := (%1 & InvertRx)
  SerialMode |= (%10 & InvertTx)
  SerialMode |= (%100 & OpenDrainSourctTx)
  SerialMode |= (%1000 & IgnoreTxEchoOnRx)

  ' 57600 known to have worked with Kermit XBee 'program'
  'baud := 9600
  'baud := 19200 ' (works with normal 16 byte rx buffer in FullDuplexSerial)
  'baud := 38400  
  baud := 57600 ' (works with 128 byte rx buffer in FullDuplexSerial128)
  'baud := 115200 ' (almost works with 128 bte rx buffer, runs, more retries, fails, sometimes works)
  'baud := 460800 ' (fails)
  'baud := 230400 ' (fails)

  ' start object, letting it know if there are some variables to show and if full debug is happening
  ConsoleSerialDriver.SetupDisplayDebugging(pGenVars,pDebug)
  ConsoleSerialDriver.start(rxpin, txpin, SerialMode, baud)
  UseCommandLines := true
  EchoInput := true
  ConsoleSerialDriver.SetCommandMode(UseCommandLines,EchoInput)

  repeat 5
    waitcnt(clkfreq+cnt)' wait 1 second
    Prompt

  ' prepare for execution time measurement
  ' establish some unreasonable period time records to be overwritten
  SetMaxMinTimes
  ms_divider := clkfreq/1_000
  last_loop_end := cnt          ' record looping start time

  repeat

    ' are we not processing a Kermit receive?
    if not(ProcessorResultFlags & ConsoleSerialDriver#KEC_ISM_KermitPacketDetected)
      KECPIcall_start := cnt
      ProcessorResultFlags := ConsoleSerialDriver.Process
      KECPIcall_end := cnt
      ' is a command ready?
      if ProcessorResultFlags & ConsoleSerialDriver#KEC_ISM_CommandReady
        ConsoleSerialDriver.ReadBytes(@CommandBuffer,@ByteCount)
        if UseCommandLines
          ' describe the command line and show it again
          ConsoleSerialDriver.str(nums.ToStr(ByteCount,nums#DEC))
          ConsoleSerialDriver.str(string(" bytes in "))
          CommandBuffer[ByteCount] := null
          ConsoleSerialDriver.str(string("---"))
          ConsoleSerialDriver.str(@CommandBuffer[0])
          ConsoleSerialDriver.str(string("---"))
          ConsoleSerialDriver.CRLF
          Prompt
        else
      'if ProcessorResultFlags & ConsoleSerialDriver#KEC_ISM_KermitPacketDetected ' did we just get a Kermit start?
      '  JustGotKermitStart := true
    else ' we are processing a Kermit receive
      'if JustGotKermitStart
      '  JustGotKermitStart := false
      '  FileTransferStart := cnt
      KECRFcall_start := cnt
      ProcessorResultFlags := ConsoleSerialDriver.Process
      KECRFcall_end := cnt
      ' did Kermit process end?
      if not ProcessorResultFlags & ConsoleSerialDriver#KEC_ISM_KermitPacketDetected
        ' does file size equal declared or assumed size?
        if ProcessorResultFlags & ConsoleSerialDriver#KEC_ISM_KermitCompleted
          ConsoleSerialDriver.str(string("File Receive Finished"))
        else
          ConsoleSerialDriver.str(string("File Receive Stopped"))
        ConsoleSerialDriver.str(string(" Max call time ="))
        MaxCallClk := max_KECPIcall #> max_KECRFcall
        ClocksPerTms := clkfreq/10000
        MaxCallTms :=  MaxCallClk/ClocksPerTms
        MaxCallMs := MaxCallTms/10
        ConsoleSerialDriver.str(nums.ToStr(MaxCallMs,nums#DEC))
        ConsoleSerialDriver.str(string("."))
        MaxCallTms //= 10 ' get remainder from whole milliseconds
        ConsoleSerialDriver.str(nums.ToStr(MaxCallTms,nums#DEC)+1)
        ConsoleSerialDriver.str(string(" (ms)"))
        ConsoleSerialDriver.CRLF

    ' measure and report execution speed
    this_loop_end := cnt
    if TestButtonState(BUTTON_PIN) ' see if user has pressed button to reset max/min times
      SetMaxMinTimes
    this_period := this_loop_end - last_loop_end
    max_period #>= this_period
    min_period <#= this_period
    max_KECPIcall #>= (KECPIcall_end - KECPIcall_start)
    max_KECRFcall #>= (KECRFcall_end - KECRFcall_start)
    GeneralDebug(TimeTrioBaseIndex + 0,max_period)
    GeneralDebug(TimeTrioBaseIndex + 1,min_period)
    GeneralDebug(TimeTrioBaseIndex + 2,this_period)
    GeneralDebug(TimeTrioBaseIndex + 3,max_period/ms_divider)
    GeneralDebug(TimeTrioBaseIndex + 4,min_period/ms_divider)
    GeneralDebug(TimeTrioBaseIndex + 5,this_period/ms_divider)
    GeneralDebug(TimeTrioBaseIndex + 3 - 8,max_KECRFcall/ms_divider)
    GeneralDebug(TimeTrioBaseIndex + 3 - 16,max_KECPIcall/ms_divider)
    last_loop_end := cnt        ' exclude reporting time

    if pDebug
      if SimulateDebugging
        StartTimeUDSim := cnt
        repeat while not TimeYetDifferential(StartTimeUDSim,DisplaySimTimeClk)
      else
        Debugger.UpdateDisplay
      
    if not BeenHere
      BeenHere := true
      if DoDebug
        if pDebug ' do we have display?
          if SimulateDebugging ' are we calling refresh?
            ConsoleSerialDriver.str(string("start with simulated debug"))
            ConsoleSerialDriver.CRLF
          else
            ConsoleSerialDriver.str(string("start with debug"))
            ConsoleSerialDriver.CRLF
        else
          ConsoleSerialDriver.str(string("could not start debug"))
          ConsoleSerialDriver.CRLF
      else
        ConsoleSerialDriver.str(string("start without debug"))
        ConsoleSerialDriver.CRLF

PRI Prompt
  ConsoleSerialDriver.str(string("Prompt>"))
  ConsoleSerialDriver.CRLF

PRI GeneralDebug(index,the_value)
' place a value in the general variables area
  MonArray[index] := the_value

PRI SetMaxMinTimes
  min_period := 10_000_000
  max_period := 0
  max_KECPIcall := 0
  max_KECRFcall := 0
  
CON
  BUTTON_PIN = 2         ' where 'pull up' button is connected for aborting file receive
PRI TestButtonState(Pin):IsHigh
' returns false if button pin is in low logic state
  IsHigh := ((ina & (1 << Pin)) <> false)

PRI DurationClks(DurationMs):DurationInClocks       
  DurationInClocks := (clkfreq >> 10 + clkfreq >> 16) * DurationMs ' -.8% accurate 
  'DurationInClocks := (clkfreq >> 10 + clkfreq >> 16 + clkfreq >> 17) * DurationMs ' -.05% accurate 
                              
PRI TimeYetDifferential(StartTime,DurationClocks):AtOrPastTheTime      
  AtOrPastTheTime := (cnt - StartTime) => DurationClocks              

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
