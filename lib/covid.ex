defmodule Covid do

  @edge_list "priv/zachary-edge-list"
  @num_nodes 34

  @num_initial_infecteds 3
  @num_replications 20

  @time_steps 100

  def load_data(graph_file, nodes) do
    nodes = for x <- 1..nodes, do: x
    edges =
      graph_file
      |> File.stream!()
      |> Stream.map(& String.trim(&1))
      |> Stream.map(& String.split(&1, " "))
      |> Stream.map(& List.to_tuple(&1))
      |> Stream.map(fn {x, y} -> {String.to_integer(x), String.to_integer(y)} end)
      |> Stream.map(fn {x, y} -> {x, y} end)
      |> Enum.map(fn {x, y} -> Graph.Edge.new(x, y) end)

    graph =
      Graph.new(type: :undirected)
      |> Graph.add_vertices(nodes)
      |> Graph.add_edges(edges)

    graph
  end

  def remove_edges(graph, edges) do
    edges = MapSet.new(edges)
    edges =
      graph
      |> Graph.edges()
      |> Enum.with_index()
      |> Enum.filter(fn {id, _} -> MapSet.member?(edges, id) end)
      |> Enum.map(fn {_, edge} -> edge end)
    Graph.delete_edges(graph, edges)
  end

  def try_to_infect(targets, susceptibles, current_time, times) do
    exposeds =
      targets
      |> Enum.filter(fn {_, prob} -> :rand.uniform < prob end)
      |> Enum.map(fn {x, _} -> x end)
      |> MapSet.new()

    times =
      times
      |> Enum.with_index()
      |> Enum.map(
          fn {i, time} ->
            if MapSet.member?(exposeds, i) do
              current_time + epsilon(current_time)
            else
              time
            end
          end
        )

    susceptibles =
      susceptibles
      |> MapSet.difference(exposeds)

    {susceptibles, exposeds, times}
  end

  def update_infected(exposeds, infecteds, current_time, times) do
    newly_infecteds =
      exposeds
      |> Enum.map(& {&1, Enum.at(times, &1)})
      |> Enum.filter(fn {_, time} -> time < current_time end)
      |> MapSet.new()

    times =
      times
      |> Enum.with_index()
      |> Enum.map(
          fn {i, time} ->
            if MapSet.member?(newly_infecteds, i) do
              current_time + lambda(current_time)
            else
              time
            end
          end
        )

    infecteds = MapSet.union(newly_infecteds, infecteds)

    exposeds = MapSet.difference(exposeds, newly_infecteds)

    {exposeds, infecteds, times}
  end

  def simulate_infection(network, infecteds, susceptibles, exposeds, times, current_time, time_steps) do
    if current_time >= time_steps do
      MapSet.size(infecteds)
    else
      new_infecteds =
        infecteds
        |> Enum.map(& {&1, Enum.at(times, &1)})
        |> Enum.filter(fn {_, time} -> time < current_time end)
        |> Enum.map(fn {id, _} -> id end)
        |> MapSet.new()

      susceptibles =
        infecteds
        |> Enum.filter(& !MapSet.member?(new_infecteds, &1))
        |> MapSet.new()
        |> MapSet.union(susceptibles)

      targets =
        infecteds
        |> Enum.flat_map(& Graph.neighbors(network, &1))
        |> MapSet.new()
        |> MapSet.intersection(susceptibles)
        |> Enum.map(
            fn x ->
              if Enum.any?(infecteds, fn y -> Covid.cluster?(network, x, y) end) do
                {x, chi(current_time)}
              else
                {x, phi(current_time)}
              end
            end
          )

      {susceptibles, exposeds, times} = try_to_infect(targets, susceptibles, current_time, times)
      {exposeds, infecteds, times} = update_infected(exposeds, infecteds, current_time, times)
      simulate_infection(network, infecteds, susceptibles, exposeds, times, current_time+1, time_steps)
    end
  end

  def min_seis_cluster(chromosome) do
    network =
      @edge_list
      |> Covid.load_data(@num_nodes)
      |> Covid.remove_edges(chromosome)
    time_table = for _ <- 1..@num_nodes, do: 0
    exposeds = MapSet.new()
    trials =
      for r <- 1..@num_replications do
        IO.write("\rRep: #{Integer.to_string(r) |> String.pad_leading(2, "0")}")
        infecteds = MapSet.new(for _ <- 1..@num_initial_infecteds, do: :rand.uniform(@num_nodes))
        susceptibles = MapSet.difference(MapSet.new(1..34), infecteds)
        Covid.simulate_infection(network, infecteds, susceptibles, exposeds, time_table, 0, @time_steps)
      end
    Enum.min(trials)
  end

  def cluster?(network, p1, p2) do
    network
    |> Graph.cliques()
    |> Enum.map(& MapSet.new(&1))
    |> Enum.filter(& MapSet.member?(&1, p1) && MapSet.member?(&1, p2))
    |> Enum.empty?
    |> Kernel.!()
  end

  def chi(_), do: 0.15

  def phi(_), do: 0.05

  def epsilon(_), do: 1

  def lambda(_), do: 1
end
