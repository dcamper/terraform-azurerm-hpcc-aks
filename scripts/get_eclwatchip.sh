#!/bin/bash
count = 10
for ((i=1; $i<=$count; i++)); do
  sleep 5;
  eclwatchip = `kubectl get services -A | grep eclwatch | awk '{match(\$6,/[0-9]+/); print \$5}'`
  if ( $eclwatchip =~ /^\d+(?:\.\d+){3}$/ ){
    print "{\"ecl_watch_ip\" : \"$eclwatchip\"}";
    exit 0;
  }
done
print STDERR "FATAL ERROR: Could not get ECL Watch Public IP. eclwatchip=\"$eclwatchip\".\n";
exit 1;
