'' test proximity "touch" sensor
''
''    Vcc
''     
''     1M
'' µC─┴──Metal Plate
''
'' Above is a simple setup for a proximity touch sensor using RCTime to detect
'' capacitance between a metal plate and a human.
''
CON

  { ==[ CLOCK SET ]== }       
  _CLKMODE      = XTAL1' + PLL2X
  _XINFREQ      = 5_000_000                             ' 5MHz Crystal

  samples = 64                                          ' samples for average, and samples of samples average for overall average (I know it's confusing)       
  shifts = 6                                            ' this needs to be 2^shifts == samples -- used for fast average making
  threshold = 2                                         ' if current "average" is this far above overall average, then proximity!

OBJ

  DEBUG  : "FullDuplexSerial"
  RC     : "RCTIME3" 

VAR

  WORD avg1[samples]                                    ' array of current samlpes
  WORD avg2[samples]                                    ' short term storage of average samples
  WORD avg                                              ' average to compare to for proximity sense

PUB Main | rtime, i, j, k, nmbr

  DEBUG.start(31, 30, 0, 57600)
  waitcnt(clkfreq + cnt)  
  DEBUG.tx($0D)

  rtime~
  avg := RC.RCTIME(3, 5, 0, 5)                          ' get one-time RCTIME to fill in current blanks
  wordfill(@avg2, avg, samples)
  
  RC.RCTIME_forever(3, 5, 0, @rtime)                    ' set RCTIME to run for forever
  REPEAT
    REPEAT i FROM 0 TO samples - 1
      REPEAT j FROM 0 TO samples - 1
        avg1[j] := rtime                                ' get samples

      nmbr~
      REPEAT k FROM 0 TO samples - 1
        nmbr += avg1[k]                                 ' average samples for proximity detect
      avg2[i] := nmbr >> shifts
       
      IF (avg2[i] > avg + threshold)                    ' if samples are threshold above avg, then finger is close
        DEBUG.str(string("Click!",13))

    nmbr~
    REPEAT k FROM 0 TO samples - 1
      nmbr += avg2[k]                                   ' get an average of the average of the samples
    avg := nmbr >> shifts
      
    DEBUG.dec(avg)                                      ' display new average value
    DEBUG.tx($0D)
    