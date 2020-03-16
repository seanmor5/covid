defmodule CovidGa do
  @moduledoc """
  Implementation of GA for epidemic mitigation described here: https://arxiv.org/pdf/1707.05377.pdf
  """
  @k 3
  @e 34

  use Genex,
    parent_selection: :tournament,
    tournsize: 2,
    crossover_type: :uniform,
    uniform_crossover_rate: 0.5,
    population_size: 10,
    minimize: true

  def encoding do
    genes = for _ <- 1..@k, do: :rand.uniform(@e)
    encoding(MapSet.new(genes), @k, @e)
  end
  def encoding(genes, k, e) do
    if MapSet.size(genes) >= k do
      genes |> MapSet.to_list()
    else
      encoding(MapSet.put(genes, :rand.uniform(e)), k, e)
    end
  end

  # See Algorithm 1
  def fitness_function(chromosome), do: Covid.min_seis_cluster(chromosome.genes)

  def terminate?(population), do: population.generation == 300

  # Chromosome repairment implemented as mutation function.
  def mutation(chromosome) do
    # Remove repeated chromosome
    chromosome = MapSet.new(chromosome.genes)
    # Loop and return
    mutation(chromosome, @k, @e)
  end
  def mutation(chromosome, k, e) do
    if MapSet.size(chromosome) < k do
      mutation(MapSet.put(chromosome, :rand.uniform(e)), k, e)
    else
      genes = MapSet.to_list(chromosome)
      %Chromosome{genes: genes, size: length(genes)}
    end
  end
end