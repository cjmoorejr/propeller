{
File: ADS1252.spin
This object is for the Texas Instruments ADS1252, a 24-bit 40kHZ Analog-to-Digital Converter.

Version 1.0
Author: Steve Skalko
email: stevenskalko@gmail.com

By swapping the "slow" delay and CtraFreq constants in the DAT section, data rates can be
reduced to about 3 kHz. 

}
VAR

long    cog, cPin

long    Pout
long    CLK
long    dPin
long    sPin
long    Output

Pub Start( cPinx, dPinx, sPinx) : okay

' cPin connected to CLK pin on ADS1252 
' dPin connected to DOUT/DRDY pin on ADS1252
' sPin connected to SCLK pin on ADS1252
longfill(@Pout, 0, 4)
cPin := |< cPinx
sPin := |< sPinx
dPin := |< dPinx
Pout := cPin | sPin
CLK := %00100 << 26 + cPinx 


okay := cog := cognew(@entry, @Pout)

Pub Stop

cogstop(cog)

Pub sample

return output.long
DAT
        org
entry   mov             t1,                     par
        rdlong          Pinout,                 t1
        or              dira,                   PinOut

        add             t1,                     #4
        rdlong          aCLK,                   t1
        mov             CTRa,                   aCLK

        mov             frqa,                   CtraFreq
        add             t1,                     #4
        rdlong          aDAT,                   t1

        add             t1,                     #4
        rdlong          aSER,                   t1

        add             t1,                     #4
        
        
:loopa  mov             bitcount,               #25
        mov             data,                   #0
        mov             waittimer,              delay                                    
        waitpeq         aDAT,                   aDAT
        waitpne         aDAT,                   aDAT
        waitpeq         aDAT,                   aDAT
        waitpne         aDAT,                   aDAT
        add             waittimer,              cnt
:loopb  or              outa,                   aSER
        
        waitcnt         waittimer,              delay
        test            aDAT,                   ina     wc
        rcl             data,                   #1
        xor             outa,                   aSER
        waitcnt         waittimer,              delay
        djnz            bitcount,               #:loopb
        mov             adc_data,               data
        wrlong          adc_data,               t1

        jmp             #:loopa
                                                          
        waitpeq         $,                      #0
        



'----------------------------------------------------------------


'CtraFreq                long    054_100_000     'slow mode
CtraFreq                long    858_993_459      'fast mode        

delay                   long    18               'fast mode
'delay                   long    200             'slow mode


t1            res       1
aCLK          res       1
Pinout        res       1
aDAT          res       1
aSER          res       1   

bitcount      res       1
data          res       1
adc_data      res       1
waittimer     res       1



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