// Experiment utility for quickly characterising results.

parseConfig:{[fh]("JJJJJFJ"; enlist ",") 0: 2#read0 fh}
parseTotalTime:{[fh]"J"$first "." vs first -2#read0 fh}
parseTimes:{[fh]"J"$-2_3_read0 fh}
parseNote:{[fh]raze last read0 fh}

avgUpdatesPerTick:{[ts]avg deltas ts}
tickDurationSeconds:{[cfg]0.001*cfg `printAfter}
avgUpdatesPerSecond:{[ts;cfg]avgUpdatesPerTick[ts]%tickDurationSeconds cfg}

go:{[fh]
  c:parseConfig fh;
  t:parseTimes fh;
  tt: parseTotalTime fh;
  -1 "";
  -1 "Experiment: ",parseNote fh;
  -1 "Total time: ",string tt;
  -1 "Avg upds/s: ",raze string avgUpdatesPerSecond[t;c];
  -1 "T deltas  : "," " sv string deltas t;
  -1 "";}
