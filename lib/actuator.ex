defmodule Actuator do
  use GenServer
  defstruct inbound_connections: Map.new(),
    barrier: Map.new(),
    actuator_function: {0, nil},
    has_been_activated: false,
    actuator_id: 0

  def start_link(registry_func, actuator) do
    actuator_name = registry_func.(actuator.actuator_id)
    GenServer.start_link(Actuator, actuator, name: actuator_name)
  end

  def start_link(actuator) do
    GenServer.start_link(Actuator, actuator)
  end

  def calculate_output_value(barrier) do
    get_synapse_value =
    (fn {_, synapse} ->
      synapse.value
    end)

    Enum.map(barrier, get_synapse_value)
    |> Enum.sum
  end

  def handle_cast({:receive_synapse, synapse}, state) do
    updated_barrier =
      Map.put(state.barrier, {synapse.from_node_id, synapse.connection_id}, synapse)
    updated_state =
    #check if barrier is full
    if NeuralNode.is_barrier_full?(updated_barrier, state.inbound_connections) do
      {_actuator_function_id, actuator_function} = state.actuator_function
      calculate_output_value(updated_barrier)
      |> actuator_function.()
      %Actuator{state |
              has_been_activated: true,
              barrier: Map.new()
      }
    else
      %Actuator{state |
              barrier: updated_barrier
      }
    end
    {:noreply, updated_state}
  end

  def handle_cast({:receive_blank_synapse, synapse}, state) do
    updated_barrier =
      Map.put(state.barrier, {synapse.from_node_id, synapse.connection_id}, synapse)
    updated_state =
      %Actuator{state |
                barrier: updated_barrier
               }
    {:noreply, updated_state}
  end

  def handle_call(:has_been_activated, _from, state) do
    updated_state =
      case state.has_been_activated do
        true ->
          %Actuator{state |
                    has_been_activated: false
                   }
        false -> state
      end
    {:reply, state.has_been_activated, updated_state}
  end

end
