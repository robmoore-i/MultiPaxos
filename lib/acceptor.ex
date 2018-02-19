defmodule Acceptor do
  def log(msg) do
    IO.puts ["ACCEPTOR (", Kernel.inspect(self()), "): ", msg]
  end

  def start(config) do
    # Note: Due to interesting elixir overloading, INTEGER > TUPLE is always false,
    #       therefore an integer (like 0) acts as "bottom" for our purposes.
    state = %{bn: 0, accepted: []}
    loop(state)
  end

  def loop(state) do
    new_state = receive do
      { :accept_req, l, b } ->
        log "received phase-1 request"
        max_ballot = max_int(b, state[:bn])
        send l, { :accept_rsp, self(), max_ballot, state[:accepted] }
        Map.put(state, :bn, max_ballot)
      { :accepted_req, l, { b, slot, cmd }} ->
        log "received phase-2 request"
        send l, { :accepted_rsp, self(), state[:bn] }
        if b == state[:bn] do
          Map.update!(state, :accepted, &([{b, slot, cmd} | &1]))
        else
          state
        end
    end
    loop(new_state)
  end

  def max_int(a, b) do
    if a > b do
      a
    else
      b
    end
  end
end
