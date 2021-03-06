''=============================================================================
'' @file     Sensirion.spin
'' @target   Propeller
''
'' Sensirion SHT-11 routines
''
'' @author   Cam Thompson, Micromega Corporation 
''
'' Copyright (c) 2006 Micromega Corporation
'' See end of file for terms of use.
''       
'' @version  V1.0 - July 11, 2006
'' @changes
''  - original version
''=============================================================================

CON
  Cmd_Temperature = %00011                              ' measure temperature
  Cmd_Humidity    = %00101                              ' measure humidity
  Cmd_ReadStatus  = %00111                              ' read status
  Cmd_WriteStatus = %00110                              ' write status
  Cmd_Reset       = %11110                              ' soft rest
           
VAR
  word  dpin, cpin
 
PUB start(data_pin, clock_pin) 
  ' assign SHT-11 clock and data pins and reset device
  dpin := data_pin                                      ' assign data pins                       
  cpin := clock_pin                                     ' assign clock pin
  outa[cpin]~                                           ' set clock low
  dira[cpin]~~
  outa[dpin]~~                                          ' set data high
  dira[dpin]~~                                           
  REPEAT 9                                              ' send 9 clock pulses for reset
    !outa[cpin]                                         
    !outa[cpin]
     
PUB readTemperature | ack
  ' read SHT-11temperature value
  ack := sendCommand(Cmd_Temperature)                   ' measure temperature
  wait                                                  ' wait until done
  return readWord                                       ' return result

PUB readHumidity | ack
  ' read SHT-11 humidity value
  ack := sendCommand(Cmd_Humidity)                      ' measure humidity
  wait                                                  ' wait until done
  return readWord                                       ' return result

PUB readStatus | ack
  ' read SHT-11 status  register
  ack := sendCommand(cmd_ReadStatus)                    ' read status
  return readByte(1)
  
PUB writeStatus(n) | ack
  ' set SHT-11 status register
  ack := sendCommand(cmd_WriteStatus)                   ' write status
  writeByte(n & $47)                                    ' (mask out reserved bits)
  
PUB reset | ack
  ' soft reset the SHT-11
  ack := sendCommand(cmd_Reset)                         ' write status
  waitcnt(cnt+clkfreq*15/1000)                          ' delay for 15 msec
  
PRI sendCommand(cmd)
  ' send transmission start sequence
  ' clock  
  ' data   
  dira[dpin]~                                           ' data high (pull-up)                                '
  outa[cpin]~                                           ' clock low                                   
  outa[cpin]~~                                          ' clock high                                 
  outa[dpin]~                                           ' data low
  dira[dpin]~~
  outa[cpin]~                                           ' clock low
  outa[cpin]~~                                          ' clock high
  dira[dpin]~                                           ' data high (pull-up)                                '
  outa[cpin]~                                           ' clock low

  return writeByte(cmd)                                 ' send command and return ACK

PRI readWord                                            ' read 16-bit value 
  return (readByte(0) << 8) + readByte(1)               
  
PRI readByte(ack)                                       ' read 8-bit value
  ' data is valid before rising edge of clock
  ' clock   
  ' data   

  dira[dpin]~                                           ' data input
  REPEAT 8
    result := (result << 1) | ina[dpin]                 ' get next bit
    !outa[cpin]                                         ' send clock pulse 
    !outa[cpin]

  dira[dpin]~~                                          ' enable data output
  outa[dpin] := ack                                     ' write ACK bit
  !outa[cpin]                                           ' send clock pulse 
  !outa[cpin]
  dira[dpin]~                                           ' enable data input
  
PRI writeByte(value)                                    ' write 8-bit value, return ACK
  ' data must be valid on rising edge of clock and while clock is high
  ' clock   
  ' data   

  dira[dpin]~~                                          ' enable data output   
  REPEAT 8
    outa[dpin] := value >> 7                            ' output next bit
    value := value << 1
    !outa[cpin]                                         ' send clock pulse
    !outa[cpin]

  dira[dpin]~                                           ' enable data input
  result := ina[dpin]                                   ' read ACK bit
  !outa[cpin]                                           ' send clock pulse 
  !outa[cpin]
  
PRI wait | t                                            ' wait for data low (250 msec timeout) 
  t := cnt                                              
  repeat until not ina[dpin] or (cnt - t)/(clkfreq/1000) > 250

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