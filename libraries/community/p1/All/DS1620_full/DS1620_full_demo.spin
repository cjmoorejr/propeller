{{ DS1620_full_demo.spin
┌─────────────────────────────────────┬────────────────┬─────────────────────┬───────────────┐
│ DS1602 demo v1.0                    │ BR             │ (C)2012             │  26Nov2012    │
├─────────────────────────────────────┴────────────────┴─────────────────────┴───────────────┤
│ This demo can be used to program the DS1620 non-volatile memory for                        │
│ a high temperature and a low temperature setting such that it can be                       │
│ used in standalone mode without a uC.                                                      │
│                                                                                            │
│ See end of file for terms of use.                                                          │
└────────────────────────────────────────────────────────────────────────────────────────────┘
FIXME: there's a bug in the demo somewhere that causes the 1st reading after DS1620 powerup
       to be erroneous. Hit return to see second reading...should be correct.
}}
CON
  _clkmode      = xtal1 + pll16x                        ' use crystal x 16
  _xinfreq      = 5_000_000
  data_pin      = 0
  clock_pin     = 1
  rst_pin       = 2
  

OBJ
  pst   : "parallax serial terminal"
  temp  : "ds1620_full"
  

pub go | tmp 

pst.start(115200)
temp.init(data_pin, clock_pin, rst_pin)
waitcnt(cnt+clkfreq*5)                                 'wait 5 sec before starting

pst.clear
pst.str(string("DS1620 Thermostat demo & temperature trigger setup"))
repeat

  pst.newline
  pst.str(string("cmd register contents = "))
  pst.bin(temp.rwreg(temp#RdCfg,0),8)
  pst.newline

  pst.str(string("tmp register contents = "))
  tmp := temp.rwreg(temp#RdTmp,0)
  tmp := tmp << 23 ~> 23                                ' extend sign bit
  pst.dec(tmp*5)
  pst.newline

  pst.str(string("Tlo register contents = "))
  tmp := temp.rwreg(temp#RdLo,0)
  tmp := tmp << 23 ~> 23                                ' extend sign bit
  pst.dec(tmp*5)
  pst.newline

  pst.str(string("Thi register contents = "))
  tmp := temp.rwreg(temp#RdHi,0)
  tmp := tmp << 23 ~> 23                                ' extend sign bit
  pst.dec(tmp*5)
  pst.newline

  pst.str(string("ctr register contents = "))
  tmp := temp.rwreg(temp#RdCntr,0)
  tmp := tmp << 23 ~> 23                                ' extend sign bit
  pst.dec(tmp*5)
  pst.newline

  pst.str(string("slp register contents = "))
  tmp := temp.rwreg(temp#RdSlope,0)
  tmp := tmp << 23 ~> 23                                ' extend sign bit
  pst.dec(tmp*5)
  pst.newline

  pst.str(string("Temperature deg F ="))
  pst.dec(temp.gettempf)
  pst.newline

  pst.str(string("Temperature deg C ="))
  pst.dec(temp.gettempc)
  pst.newline

  pst.str(string("set thermostat? (y/n, or q to quit)?",13))
  tmp := pst.CharIn
  if tmp=="q"
    quit
  elseif tmp=="y"
    pst.str(string("Enter Lo alarm, deg F",13))
    temp.setlo(pst.decin,1)
    pst.str(string("Enter Hi alarm, deg F",13))
    temp.sethigh(pst.decin,1)

temp.stop


DAT
{{
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                     TERMS OF USE: MIT License                                       │                                                            
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and    │
│associated documentation files (the "Software"), to deal in the Software without restriction,        │
│including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,│
│and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,│
│subject to the following conditions:                                                                 │
│                                                                                                     │                        │
│The above copyright notice and this permission notice shall be included in all copies or substantial │
│portions of the Software.                                                                            │
│                                                                                                     │                        │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT│
│LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  │
│IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER         │
│LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION│
│WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                                      │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
}} 