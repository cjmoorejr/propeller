{{

┌──────────────────────────────────────────┐
│ DTMF_DEMO.spin                           │
│ Author: Thomas E. McInnes                │               
│ See end of file for terms of use.        │                
└──────────────────────────────────────────┘

Circuit diagram:

all caps are 10µf 
prop pin 0 ─┬────┬──┐
prop pin 1 ──┘      ←speaker                          
           ┌────────┴──┘   
                 
          VSS    
}}

CON

  _clkmode = xtal1 + pll16x     'Low speed crystal * 16
  _xinfreq = 6_250_000          '6.25Mhz crystal

  laudio = 1                    'First audio pin
  raudio = 0                    'Second audio pin 

VAR

  Long stack[200]               'Stack variable (do not change)

OBJ

  d     :       "DTMF"          'Phone Dialer

PUB start_up

  cognew(program_code, @stack)  'Run program in new cog

PUB program_code

  d.start_up(laudio, raudio)    'Start up object
  d.tech_support                'tech_support

DAT
    
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