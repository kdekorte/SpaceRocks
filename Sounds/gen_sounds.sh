sox -n thrust.caf synth 0.8 noise gain -9 lowpass 900 highpass 120 fade h 0.02 0.8 0.02
sox -n shield_on.caf synth 0.5 sine 200-1000 gain -6 fade q 0.01 0.5 0.1
sox -n shield_off.caf synth 0.4 sine 1000-200 gain -6 fade q 0.01 0.4 0.1
sox -n shield_off.caf synth 0.4 sine 1000-200 gain -6 fade q 0.01 0.4 0.1
sox -n shield_on.caf synth 0.5 sine 200-1000 gain -6 fade q 0.01 0.5 0.1
sox -n thrust.caf synth 0.8 noise gain -9 lowpass 900 highpass 120 fade h 0.02 0.8 0.02
sox -m -n -n explode.caf synth 0.4 noise synth 0.4 square 120-40 gain -5 lowpass 1200 fade q 0 0.4 0.2
sox -n fire.caf synth 0.15 sine 1200-200 gain -10 fade q 0 0.15 0.05
sox -n bg_heartbeat.caf synth 0.06 square 70 gain -10 lowpass 1200 pad 0 1.5
