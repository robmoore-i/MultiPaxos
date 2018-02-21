
# distributed algorithms, n.dulay, 2 feb 18
# multi-paxos, configuration parameters v1

defmodule Configuration do

def version 1 do	# configuration 1
  %{
  debug_level:  0, 	# debug level
  docker_delay: 5_000,	# time (ms) to wait for containers to start up

  max_requests: 500,   	# max requests each client will make
  client_sleep: 5,	# time (ms) to sleep before sending new request
  client_stop:  10_000,	# time (ms) to stop sending further requests
  n_accounts:   100,	# number of active bank accounts
  max_amount:   1000,	# max amount moved between accounts

  print_after:  1_000,	# print transaction log summary every print_after msecs

  # Liveness parameters
  backoff_inc: fn b -> b + 1 end,
  backoff_dec: fn b -> round b / 2 end,
  window: 5
  }
end

def version 2 do	# higher debug level
 config = version 1
 Map.put config, :debug_level, 1
end

end # module -----------------------
