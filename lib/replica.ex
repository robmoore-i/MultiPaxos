# Robert Moore (rrm115) Inusha Hapuarachchi (ih1115)

defmodule Replica do
  def log(msg) do
    IO.puts ["REPLICA  (", Kernel.inspect(self()), "): ", msg]
  end

  def start(config, db, _monitor) do
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
        Map.update!(state , :requests, &([cmd | &1]))
      { :decision, decision } ->
        process_decision(state, decision)
    end
    state = propose(state)
    loop(state)
  end

  def process_decision(state, {slot, cmd}) do
    unify Map.update!(state, :decisions, &Map.put(&1, slot, cmd))
  end

  def unify(state) do
    sn = state.sn
    if Map.has_key?(state.decisions, sn) do
    state =
        if Map.has_key?(state.proposals, sn) do
          del_proposal = fn s, n -> Map.update!(s, :proposals, &Map.delete(&1, n)) end
          if state.decisions[sn] != state.proposals[sn] do
            del_proposal.(Map.update!(state, :requests, &([state.proposals[sn] | &1])), sn)
          else
            del_proposal.(state, sn)
          end
        else
          state
        end
      unify(perform(state, state.decisions[sn])) # Loop
    else
      state
    end
  end

  def perform(state, cmd) do
    decisions = state.decisions
    if Enum.empty? Enum.filter(Map.keys(decisions), &(state[:sn] > &1 and decisions[&1] == cmd and Cmd.is_reconfigure cmd)) do
      _result = Cmd.execute(cmd, state.db)
      # To send response back to client: ((( send Cmd.client(cmd), { :client_response, Cmd.id cmd, result } )))
    else
      log "Reconfiguration branch entered erroneously in Replica.perform"
      System.halt
    end
    Map.update!(state, :sn, &(&1 + 1))
  end

  def propose(state) do
    pn = state.pn
    if pn < state.sn + state.window and not Enum.empty?(state.requests) do
      if Cmd.is_reconfigure(state.decisions[pn - state.window]) do
        # Add leaders using reconfiguration:
        #   state = Map.put(state, :leaders, Cmd.pull_new_leaders state.decisions[pn - state.window])
        log "Reconfiguration branch entered erroneously in Replica.propose"
        System.halt
      end
      state =
        if not Map.has_key?(state.decisions, pn) do
          proposed = List.first state.requests
          for l <- state.leaders do
            send l, { :propose, pn, proposed }
          end
          state = Map.update!(state, :proposals, &Map.put(&1, pn, proposed))
          state = Map.update!(state, :requests,  &List.delete_at(&1, 0))
          state
        else
          state
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
