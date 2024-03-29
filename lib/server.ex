# Robert Moore (rrm115) Inusha Hapuarachchi (ih1115)

# distributed algorithms, n.dulay 2 feb 18
# coursework 2, paxos made moderately complex

defmodule Server do

def start config, server_num, paxos, monitor do
  config   = Map.put config, :server_num, server_num

  database = spawn Database, :start, [config, monitor]
  replica  = spawn Replica,  :start, [config, database, monitor]
  leader   = spawn Leader,   :start, [config]
  acceptor = spawn Acceptor, :start, [config]

  send paxos, { :config, replica, acceptor, leader }
end # start

end # Server
