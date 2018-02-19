defmodule Replica do
  def log(msg) do
    IO.puts ["REPLICA  (", Kernel.inspect(self()), "): ", msg]
  end

  def start(config, db, monitor) do
    leaders = receive do
      { :bind, leaders } -> leaders
    end
    state = %{db: db, leaders: leaders, window: config[:window], sn: 0, pn: 0, requests: [], proposals: %{}, decisions: %{}}
    # requests is a list of backlogged client requests.
    # proposals maps seq-ns to commands
    # decisions maps slots  to commands
    loop(state)
  end

  def loop(state) do
    state = receive do
      { :client_request, cmd } ->
        # There are lots of these: log "Client request"
        Map.update!(state , :requests, &([cmd | &1]))
      { :decision, decision } ->
        log "Decision recieved"
        process_decision(state, decision)
    end
    state = propose(state)
    loop(state)
  end

  def process_decision(state, {slot, cmd}) do
    unify Map.update!(state, :decisions, &Map.put(&1, slot, cmd))
  end

  def unify(state) do
    sn        = state.sn
    decisions = state.decisions
    proposals = state.proposals
    if sn in Map.keys(decisions) do
      if sn in Map.keys(proposals) do
        if decisions[sn] != proposals[sn] do
          state = Map.update!(state, :requests, &([proposals[sn] | &1]))
        end
        state = Map.put(state, :proposals, Map.delete(proposals, sn))
      end
      state = perform(state, decisions[sn])
      unify(state) # Loop
    else
      state
    end
  end

  def perform(state, cmd) do
    decisions = state[:decisions]
    if Enum.empty? Enum.filter(Map.keys(decisions), &(state[:sn] > &1 and decisions[&1] == cmd and Cmd.is_reconfigure cmd)) do
      log "Executing decision"
      _result = Cmd.execute(cmd, state[:db])
      # To send response back to client: ((( send Cmd.client(cmd), { :client_response, Cmd.id cmd, result } )))
    end
    state = Map.update!(state, :sn, &(&1 + 1))
  end

  def propose(state) do
    pn = state.pn
    if pn < state.sn + state.window and !Enum.empty?(state.requests) do
      earliest_cmd = state.decisions[pn - state.window]
      if Cmd.is_reconfigure(earliest_cmd) do
        log "Reconfiguration received (SHOULDN'T HAPPEN)"
        state = Map.put(state, :leaders, Cmd.pull_new_leaders earliest_cmd)
      end
      if !Map.has_key?(state.decisions, pn) do
        proposed = List.first state.requests
        state = Map.update!(state, :proposals, &Map.put(&1, pn, proposed))
        log ["Proposing #{pn} -> ", Kernel.inspect proposed]
        for l <- state.leaders do
          send l, { :propose, pn, proposed }
        end
        state = Map.update!(state, :requests, &List.delete_at(&1, 0))
      end
      state = Map.update!(state, :pn, &(&1 + 1))
      propose(state)
    else
      state
    end
  end
end

defmodule Cmd do
  # The format of sent commands is a triple of the general form:
  #     { sender_pid, meta_inf, payload}
  # For client requests, meta_inf is the client's sequence number. For leader reconfiguration, it is any negative number.
  # For client requests, payload  is the transaction for the db.   For leader reconfiguration, it is the new set of leaders.

  def pull_new_leaders(cmd) do
    case cmd do
      {_sender_id, _reconfigure_flag, payload} -> payload
      _ -> []
    end
  end

  def id(cmd) do
    case cmd do
      {client_id, client_seq_n, _tx} -> {client_id, client_seq_n}
      _ -> nil
    end
  end

  def is_reconfigure(cmd) do
    case cmd do
      {_sender_id, reconfigure_flag, _payload} -> reconfigure_flag < 0
      _ -> false
    end
  end

  def execute(cmd, db) do
    case cmd do
      {_sender_id, _sequence_number, tx} -> send db, { :execute, tx }
      _ -> raise ["Bad cmd: ", Kernel.inspect cmd]
    end
    True
  end
end
