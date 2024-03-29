# Robert Moore (rrm115) Inusha Hapuarachchi (ih1115)

defmodule Acceptor do
  def log(msg) do
    IO.puts ["ACCEPTOR (", Kernel.inspect(self()), "): ", msg]
  end

  def start(_config) do
    # Note: Due to interesting elixir overloading, TUPLE > INTEGER is always true,
    #       therefore an integer (like 0) can act as "bottom" for our purposes.
    state = %{bn: 0, accepted: []}
    loop(state)
  end

  def loop(state) do
    new_state = receive do
      { :accept_req, l, b } ->
        max_ballot = max(b, state.bn)
        send l, { :accept_rsp, self(), max_ballot, state.accepted }
        Map.put(state, :bn, max_ballot)
      { :accepted_req, l, { b, slot, cmd }} ->
        send l, { :accepted_rsp, self(), state.bn }
        if b == state.bn do
          Map.update!(state, :accepted, &([{b, slot, cmd} | &1]))
        else
          state
        end
    end
    loop(new_state)
  end
end
