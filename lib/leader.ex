defmodule Leader do
  def log(msg) do
    IO.puts ["LEADER   (", Kernel.inspect(self()), "): ", msg]
  end

  def start(config) do
    { acceptors, replicas } = receive do
      { :bind, acceptors, replicas } -> { acceptors, replicas }
    end
    state = %{acceptors: acceptors, replicas: replicas, active: false, proposals: %{}, bn: Ballot.init(self())}
    log ["replicas : ", Kernel.inspect replicas]
    log ["acceptors: ", Kernel.inspect acceptors]
    loop(state)
  end

  def loop(state) do
    state = receive do
      { :propose, slot, cmd } ->
        log "Received proposal"
        if state[:active] do
          spawn(Commander, :start, [self(), state[:acceptors], state[:replicas], {state[:bn], slot, cmd}])
        end
        Map.put(state, :proposals, Map.put_new(state[:proposals], slot, cmd))
      { :adopted, bn, votes } ->
        log "Adoption confirmed, moving to stage 2"
        new_proposals = merge_votes(state[:proposals], votes)
        for {slot, cmd} <- new_proposals do
          spawn(Commander, :start, [self(), state[:acceptors], state[:replicas], {state[:bn], slot, cmd}])
        end
        Map.put(Map.put(state, :active, true), :proposals, new_proposals)
      { :preempted, higher_bn } ->
        log "Preempted, incrementing ballot number"
        if higher_bn > state[:bn] do
          new_state = %{state | active: true, bn: Ballot.inc(state[:bn])}
          spawn(Scout, :start, [self(), state[:acceptors], new_state[:bn]])
          new_state
        else
          state
        end
    end
    loop(state)
  end

  # Returns updates proposals
  def merge_votes(proposals, votes) do
    # Get the (slot, cmd) pairs which have the maximal ballot number within the given votes
    acc = %{}
    max_slot_votes = Enum.reduce(votes, %{},
      fn {bn, slot, cmd}, acc ->
        if Map.has_key?(acc, slot) do
          {cur_bn, _cur_cmd} = Map.get(acc, slot)
          if bn > cur_bn do
            Map.put(acc, slot, {bn, cmd})
          else
            acc
          end
        else
          Map.put(acc, slot, {bn, cmd})
        end
      end)

    # Inductiuvely enforce prior-ballot consistency by assigning the slot values
    # accordingly from the votes into the current proposals.
    Enum.reduce(max_slot_votes, proposals,
      fn {slot, {_bn, cmd}}, acc ->
        Map.put(acc, slot, cmd)
      end)
  end

  def quorum(state) do
    Enum.count(state[:waiting_for]) < Enum.count(state[:acceptors]) / 2
  end

  def preempt(pid, lid, higher_bn) do
    send lid, { :preempted, higher_bn }
    Process.exit(pid, :preempted)
    %{} # This function does not return
  end
end

defmodule Scout do
  def log(msg) do
    IO.puts ["SCOUT    (", Kernel.inspect(self()), "): ", msg]
  end

  def start(lid, acceptors, bn) do
    state = %{leader: lid, acceptors: acceptors, bn: bn, waiting_for: acceptors, votes: [], quorum: Enum.count(acceptors) / 2}
    log "sending phase-1 requests for slot #{slot}"
    for a <- acceptors, do: send a, { :accept_req, self(), bn }
    loop(state)
  end

  def loop(state) do
    state = receive do
      { :accept_rsp, aid, b, votes } ->
        log "received phase-1 response for slot #{slot}"
        if b == state[:bn] do
          state = Map.update!(state, :votes, &(&1 ++ votes))
          state = Map.update!(state, :acceptors, &List.delete(&1, aid))
          if Leader.quorum(state) do
            send state[:lid], { :adopted, b, votes }
            Process.exit(self(), :adopted)
          end
          state
        else
          Leader.preempt(self(), state[:lid], b)
        end
    end
    loop(state)
  end
end

defmodule Commander do
  def log(msg) do
    IO.puts ["COMMANDER(", Kernel.inspect(self()), "): ", msg]
  end

  def start(lid, acceptors, replicas, {bn, slot, cmd}) do
    state = %{leader: lid, acceptors: acceptors, bn: bn, slot: slot, cmd: cmd, waiting_for: acceptors, votes: []}
    log "sending phase-2 requests for slot #{slot}"
    for a <- acceptors, do: send a, { :accepted_req, self(), bn }
    loop(state)
  end

  def loop(state) do
    state = receive do
      { :accepted_rsp, aid, b } ->
        log "received phase-2 response for slot #{slot}"
        if b == state[:bn] do
          state = Map.update!(state, :acceptors, &List.delete(&1, aid))
          if Leader.quorum(state) do
            for r <- state[:replicas], do: send r, { :decided, {state[:slot], state[:cmd]}}
            Process.exit(self(), :decided)
          end
          state
        else
          Leader.preempt(self(), state[:lid], b)
        end
    end
    loop(state)
  end
end

defmodule Ballot do
  # Ballots are tuples of {seq-num, pid}.
  # They inherit ordering from the total ordering in elixir of integers and of pids.

  def init(pid) do
    {0, pid}
  end

  def inc({i, pid}) do
    {i + 1, pid}
  end
end
