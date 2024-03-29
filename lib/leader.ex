# Robert Moore (rrm115) Inusha Hapuarachchi (ih1115)

defmodule Leader do
  def log(msg) do
    IO.puts ["LEADER   (", Kernel.inspect(self()), "): ", msg]
  end

  def start(config) do
    { acceptors, replicas } = receive do
      { :bind, acceptors, replicas } -> { acceptors, replicas }
    end
    state = %{acceptors: acceptors, replicas: replicas, active: false,
              proposals: %{}, bn: Ballot.init(self()), backoff: :rand.uniform(100),
              backoff_inc: config.backoff_inc, backoff_dec: config.backoff_dec,
              total_sleep_time: 0}
    spawn(Scout, :start, [self(), acceptors, state.bn])
    loop(state)
  end

  def loop(state) do
    state = receive do
      { :propose, slot, cmd } ->
        if not Map.has_key?(state.proposals, slot) do
          if state.active do
            spawn(Commander, :start, [self(), state.acceptors, state.replicas, {state.bn, slot, cmd}])
          end
          Map.update!(state, :proposals, &Map.put_new(&1, slot, cmd))
        else
          state
        end
      { :adopted, bn, votes } ->
        new_proposals = merge_votes(state.proposals, votes)
        for {slot, cmd} <- new_proposals do
          spawn(Commander, :start, [self(), state.acceptors, state.replicas, {bn, slot, cmd}])
        end
        decrease_backoff  %{state | active: true, proposals: new_proposals}
      { :preempted, higher_bn } ->
        Process.sleep(state.backoff)
        incremented_sleep_time = state.total_sleep_time + state.backoff
        if higher_bn > state.bn do
          incremented_bn = Ballot.inc(state.bn)
          spawn(Scout, :start, [self(), state.acceptors, incremented_bn])
          increase_backoff %{state | active: true, bn: incremented_bn, total_sleep_time: incremented_sleep_time}
        else
          %{state | total_sleep_time: incremented_sleep_time}
        end
    end
    loop(state)
  end

  # Returns updates proposals
  def merge_votes(proposals, votes) do
    # Get the (slot, cmd) pairs which have the maximal ballot number within the given votes
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

  ### Backoff management

  def increase_backoff(state) do
    Map.update!(state, :backoff, state.backoff_inc)
  end

  def decrease_backoff(state) do
    Map.update!(state, :backoff, state.backoff_dec)
  end

  ### Some functions used by the subprocesses

  def quorum(state) do
    Enum.count(state.waiting_for) < Enum.count(state.acceptors) / 2
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
    state = %{leader: lid, acceptors: acceptors, bn: bn, waiting_for: acceptors,
              votes: [], quorum: Enum.count(acceptors) / 2}
    for a <- acceptors, do: send a, { :accept_req, self(), bn }
    loop(state)
  end

  def loop(state) do
    state = receive do
      { :accept_rsp, aid, b, votes } ->
        if b == state.bn do
          state = Map.update!(state, :votes,       &(&1 ++ votes))
          state = Map.update!(state, :waiting_for, &List.delete(&1, aid))
          if Leader.quorum(state) do
            send state.leader, { :adopted, state.bn, state.votes }
            Process.exit(self(), :adopted)
          end
          state
        else
          Leader.preempt(self(), state.leader, b)
        end
    end
    loop(state)
  end
end

defmodule Commander do
  def log(msg) do
    IO.puts ["COMMANDER(", Kernel.inspect(self()), "): ", msg]
  end

  def start(lid, acceptors, replicas, {bn, slot, cmd} = proposal) do
    state = %{leader: lid, acceptors: acceptors, replicas: replicas,
              bn: bn, slot: slot, cmd: cmd, waiting_for: acceptors, votes: [],
              proposal: proposal}
    for a <- acceptors, do: send a, { :accepted_req, self(),  proposal }
    loop(state)
  end

  def loop(state) do
    state = receive do
      { :accepted_rsp, aid, b } ->
        if b == state.bn do
          state = Map.update!(state, :waiting_for, &List.delete(&1, aid))
          if Leader.quorum(state) do
            for r <- state.replicas, do: send r, { :decision, {state.slot, state.cmd}}
            Process.exit(self(), :decision)
          end
          state
        else
          Leader.preempt(self(), state.leader, b)
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
