defmodule Acceptor do
  def start(config) do
    # Note: Due to interesting elixir overloading, INTEGER > TUPLE is always false,
    #       therefore an integer (like 0) acts as "bottom" for our purposes.
    state = %{bn: 0, accepted: []}
    loop(state)
  end

  def loop(state) do
    receive do
      { :accept_req, l, b } ->
        if b > state[:bn] do
          state = Map.put(state, :bn, b)
        end
        send l, { :accept_rsp, self(), state[:bn], state[:accepted] }
        loop(state)
      { :accepted_req, l, { b, slot, cmd }} ->
        if b == bn do
          state = Map.update!(state, :accepted, &([{b, slot, cmd} | &1]))
        end
        send l, { :accepted_rsp, self(), state[:bn] }
        loop(state)
    end
  end
end
