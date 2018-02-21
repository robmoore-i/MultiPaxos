
# distributed algorithms, n.dulay, 2 feb 18
# multi-paxos, configuration parameters v1

defmodule Configuration do

def f_minus(n) do
  fn b -> max(0, b - n) end
end

def f_div(n) do
  fn b -> round(b / n) end
end

def version 1 do	# configuration 1
  %{
  debug_level:  0, 	    # debug level
  docker_delay: 5_000,	# time (ms) to wait for containers to start up
  max_requests: 500,  	# max requests each client will make
  client_sleep: 5,	    # time (ms) to sleep before sending new request
  client_stop:  10_000,	# time (ms) to stop sending further requests
  n_accounts:   100,	  # number of active bank accounts
  max_amount:   1000,	  # max amount moved between accounts
  print_after:  1_000,	# print transaction log summary every print_after msecs

  # Liveness parameters
  backoff_inc: fn b -> b + 1 end,
  backoff_dec: f_minus(1),
  window: 5,

  # So I don't have to change files too often during local testing
  n_servers: 3,
  n_clients: 2
  }
end

def version 2 do	# higher debug level
 config = version 1
 Map.put config, :debug_level, 1
end

end # module -----------------------
