module TrueSkill
  class FactorGraphLayer

    attr_accessor :parent_factor_graph
    attr_accessor :local_factors, :output_variables_groups, :input_variables_groups

    def initialize(parent_graph)
      self.parent_factor_graph = parent_graph
      self.local_factors = []
      self.output_variables_groups = []
      self.input_variables_groups = []
    end

    def create_prior_schedule
      nil
    end

    def create_posterior_schedule
      nil
    end

    alias untyped_factors local_factors
  end
end