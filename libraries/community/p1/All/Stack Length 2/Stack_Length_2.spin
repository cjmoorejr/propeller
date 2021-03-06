{{
*****************************************
* Stsck Length 2., 033015 ggysbers      *
*   Filename changed as to protect      *
*   original library SPIN code          *
*****************************************
* Stack Length v1.1                     *
* Author: Jeff Martin                   *
* Copyright (c) 2006-2010 Parallax Inc. *
* See end of file for terms of use.     *
*****************************************

Measures utilization of user-defined stack; used to determine actual run-time stack requirements for an object in development.

Any object that manually launches Spin code, via COGINIT or COGNEW commands, must reserve stack space for the new cog to use
at run-time.  Too little stack space results in malfunctioning code, while too much stack space is wasteful.

Run-time stack space is used by the Spin Interpreter to store temporary values (return addresses, return values, intermediate
expression values and operators, etc).  The amount of stack space needed for manually launched Spin code is impossible to
calculate at compile-time; it is a run-time phenomena that grows and shrinks depending on levels of nested calls, complexity
of expressions, and paths code takes in response to stimuli.

See "Theory of Operation" below for more information.

{{--------------------------REVISION HISTORY--------------------------
 v1.1 - Updated 03/19/2010 to enhance GetLength's BaudRate range.
        NOTE: GetLength now returns stack utilization as a long value
              instead of a string pointer. 
──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────}}
DAT{{
 (2) 033015 ggysbers, modified "PUB GetLength(...)" so that the method will no longer initially clear the terminal
                      window while each line now ends with a "NL," New Line.  Useful in testing multiple process
                      flow paths of a cog's work order.
                  Eg.   +------------------------------------+
                        |Parallax Serial Terminal - (COMx)   |
                        +------------------------------------+
                        |                                    |
                        +------------------------------------+
                        |Stack Usage: 8                      |
                        |Stack Usage: 9                      |
                        |Stack Usage: 9                      |
                        |Stack Usage: 13                     |
                        |Stack Usage: 14                     |
                        |Stack Usage: 14                     |
                        |Stack Usage: 15                     |
                        |                                    |
                        +------------------------------------+
                                                                                                                      }}
DAT{{                One's top level SPIN code may look similar to the following:
                                        
   VAR
     long TestStack[32]                    'a stack of longs used by delay routine    
   
   OBJ
     Stk   :       "Stack Length 2"        'Include Stack Length Object
  
   PUB public_method_name

     Stk.Init(@TestStack, 32)              'Initialize reserved Stack space (utilized below)

     cognew(Toggle(16, 3_000_000, 10), @TestStack)
     waitcnt(clkfreq * 6 + cnt)             'Pause 6 seconds
     Stk.GetLength(30, 9600)                'Transmit results serially out P30 at 9600 baud

     cognew(Toggle(2, 19_000_000, 11), @TestStack)
     waitcnt(clkfreq * 10 + cnt)            'Wait ample time for max stack usage, 10 seconds
     Stk.GetLength(30, 9600)                'Transmit results serially out P30 at 9600 baud

     cognew(Toggle(81, 2_000_000, 500), @TestStack)
     waitcnt(clkfreq * 10 + cnt)            'Wait ample time for max stack usage
     Stk.GetLength(30, 9600)                'Transmit results serially out P30 at 9600 baud

   PRI Toggle(x, y, z)
     ...     

-(2) 033015─────────────────────────────────────────────────────────────────────────────────────────────────────────────────}}
VAR
  long  Addr                                                                    'Address of stack
  long  Size                                                                    'Size of stack
  long  Seed                                                                    'Current pseudo-random seed value

OBJ
  pst : "Parallax Serial Terminal"                                              'Interface object for Parallax Serial Terminal
  
PUB Init(StackAddr, Longs) | Idx
{{Initialize stack with pseudo-random values.
  Parameters: StackAddr = address of stack to initialize and measure later.
              Longs = length of reserved stack space, in longs.}}
              
  Addr := StackAddr                                                             'Remember address
  Size := Longs-1                                                               'Remember size
  Seed := cnt                                                                   'Initialize Random Value
  repeat Idx from 0 to Size                                                     'Write pseudo-random values to entire stack
    long[Addr][Idx] := Seed?
  Seed?                                                                         'Set seed in prep for Length method
                                                                                     
PUB GetLength(TxPin, BaudRate): UsedLongs | ISeed
{{Measure the maximum utilization of stack, given to Init, transmit it serially as a friendly string and return long value.
  Call this method only after first calling Init and then fully exercising any code that uses the stack given to Init.
  Parameters: TxPin = pin number (0-31) to use for transmitting result serially, if desired.
              BaudRate = serial baud rate (ex: 115200) of transmission (0 = no transmission).
  Returns:    Long value indicating actual utilization of stack:
              -1 = inconclusive; stack may be too small, increase size and try again.
               0 = stack never utilized.
              >0 = maximum utilization (in longs) of stack up to this moment.
  NOTE: Serial transmission is true-polarity, 8, N, 1}}

  {Determine utilization of stack}
  ISeed := Seed                                                                 'Remember initial seed value 
  UsedLongs := Size                                                             'Start at end of stack
  repeat while (UsedLongs > -1) and (long[Addr][UsedLongs] == ?ISeed)           'Read stack backwards, stop at first unmatched seed
    UsedLongs--
  if ++UsedLongs == Size+1                                                      'If stack is full
    UsedLongs~~                                                                 '  flag as inconclusive
  
  {Transmit as a friendly serial string, if desired}
  if BaudRate                                                                   'If we should serially transmit result
    pst.StartRxTx(TxPin, TxPin, 0, BaudRate)                                    '  Start Parallax Serial Terminal object
'   pst.Str(string(pst#CS, "Stack Usage: "))                                    '  Transmit text
    pst.Str(string("Stack Usage: "))                                            '  Transmit text
    pst.Dec(UsedLongs)                                                          '  Transmit stack utilization value
    pst.Str(string(pst#NL))     
    

DAT
{{
──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
                                                     THEORY OF OPERATION
──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Follow these steps for developing objects that manually launch Spin code:


STEP 1: As you develop your object, provide a large amount of stack space for any Spin code launched via COGINIT or COGNEW.
        Simple code may take around 8 longs, but more complex code may take hundreds of longs. Start with a large value,
        128 longs for example, and increase it as needed to ensure proper operation.

STEP 2: When your object's development is complete, include this object ("Stack Length") within it and call Init before
        launching any Spin code.  NOTE: For the Init's parameters, make sure to specify the proper address and length
        (in longs) of the stack space you actually reserved. 

        Example:

        VAR
          long Stack[128]

        OBJ
          Stk : "Stack Length"

        PUB Start
          Stk.Init(@Stack, 128)                         'Initialize Stack for measuring later

          cognew(MySpinCode, @Stack)                    'Launch code that utilizes Stack
    
Step 3: Fully exercise your object, being sure to affect every feature that will cause the greatest nested method calls and
        most complex set of run-time expressions to be evaluated.  This may have to be a combination of hard-coded tests and
        physical, external stimuli depending on the application.

Step 4: Call GetLength to measure the stack space actually utilized.  GetLength will return the result as a long value and
        will serially transmit the results as a string on the TxPin at the BaudRate specified. Use 0 for BaudRate if no
        transmission is desired.  The value returned will be -1 if the test was inconclusive (try again, but with more stack
        space reserved), 0 if the stack was never used, or some other value indicating the maximum utilization (in longs) of
        your stack up to that moment in time.

        Example:  If the application uses an external 5 MHz resonator and its clock settings are as follows:
        
        CON
          _clkmode = xtal1 + pll16x
          _xinfreq = 5_000_000

        Then the following line will transmit "Stack Usage: #" on I/O pin 30 (the Tx pin normally used for programming) at
        115200 baud; where # is the utilization of your Stack.

          Stk.GetLength(30, 115200)

Step 5: Set your reserved Stack space to the measured size and remove this object, Stack Length, from your finished object.

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