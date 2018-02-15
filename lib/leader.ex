defmodule Leader do
  def start(config) do

  end

  def loop(state) do

  end
end

defmodule Scout do
  def start(lid, acceptors, bn) do
    state = %{leader: lid, acceptors: acceptors, bn: bn, waiting_for: acceptors, votes: []}
    for a in acceptors do
      send a, { :accept_req, self(), bn }
    end
    loop(state)
  end

  def loop(state) do
    state = receive do
      { :accept_rsp, aid, b, votes } ->
        if b == bn do
          # halal
        else
          # Preempted
        end
    end
    loop(state)
  end
end

defmodule Commander do
  def start(lid, acceptors, replicas, {bn, slot, cmd}) do
    state = %{leader: lid, acceptors: acceptors, bn: bn, waiting_for: acceptors, votes: []}
    for a in acceptors do
      send a, { :accepted_req, self(), bn }
    end
    loop(state)
  end

  def loop(state) do
    state = receive do
      { :accepted_rsp, aid, b, votes } ->
        if b == bn do
          # halal
        else
          # Preempted
        end
    end
    loop(state)
  end
end
