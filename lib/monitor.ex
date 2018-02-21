
# distributed algorithms, n.dulay 2 feb 18
# coursework 2, paxos made moderately complex

defmodule Monitor do

def start config do
  Process.send_after self(), :print, config.print_after
  next Map.merge(config, %{start_time: :os.system_time(:millisecond), remaining_dbs: config.n_servers}), 0, Map.new, Map.new, Map.new
end # start

defp next config, clock, requests, updates, transactions do
  receive do
  { :db_update, db, seqnum, transaction, db_pid } ->
    { :move, amount, from, to } = transaction

    done = Map.get updates, db, 0

    if seqnum != done + 1  do
      IO.puts "  ** error db #{db}: seq #{seqnum} expecting #{done+1}"
      System.halt
    end

    transactions =
      case Map.get transactions, seqnum do
      nil ->
        # IO.puts "db #{db} seq #{seqnum} #{done}"
        Map.put transactions, seqnum, %{ amount: amount, from: from, to: to }

      t -> # already logged - check transaction
        if amount != t.amount or from != t.from or to != t.to do
	         IO.puts " ** error db #{db}.#{done} [#{amount},#{from},#{to}] = log #{done}/#{Map.size transactions} [#{t.amount},#{t.from},#{t.to}]"
          System.halt
        end
        transactions
      end # case

    updates = Map.put updates, db, seqnum

    if seqnum >= config.max_requests * config.n_clients do
      IO.puts "DB-#{db}.DONE(#{:os.system_time(:millisecond) - config.start_time})"
      send db_pid, { :account_summary }
      receive do
        { :account_summary, ^db_pid, balances } -> IO.puts ["Balances in ", inspect(db), ": ", inspect balances]
      end
      new_remaining_dbs = config.remaining_dbs - 1
      if new_remaining_dbs == 0 do
        System.halt
      else
        next %{config | remaining_dbs: new_remaining_dbs}, clock, requests, updates, transactions
      end
    else
      next config, clock, requests, updates, transactions
    end

  { :client_request, server_num } ->  # requests by replica
    seen = Map.get requests, server_num, 0
    requests = Map.put requests, server_num, seen + 1
    next config, clock, requests, updates, transactions

  :print ->
    clock = clock + config.print_after
    sorted = updates |> Map.to_list |> List.keysort(0)
    IO.puts "TICK(#{clock}):#{inspect sorted}"
    Process.send_after self(), :print, config.print_after
    next config, clock, requests, updates, transactions

  # ** ADD ADDITIONAL MESSAGES HERE

  _ ->
    IO.puts "monitor: unexpected message"
    System.halt
  end # receive
end # next

end # Monitor
