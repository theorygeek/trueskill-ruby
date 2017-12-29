module TrueSkill
  class FactorGraph
    attr_accessor :layers, :prior_layer, :game_info

    def initialize(game_info, teams, team_ranks)
      raise ArgumentError, "game_info is required" if game_info.nil?
      teams, team_ranks = RankSorter.sort(teams, team_ranks)

      self.prior_layer = PlayerPriorValuesToSkillsLayer.new(self, teams)
      self.game_info = game_info

      self.layers = [
        prior_layer,
        PlayerSkillsToPerformancesLayer.new(self),
        PlayerPerformancesToTeamPerformancesLayer.new(self),
        IteratedTeamDifferencesInnerLayer.new(
          self,
          TeamPerformancesToTeamPerformanceDifferencesLayer.new(self),
          TeamDifferencesComparisonLayer.new(self, team_ranks)
        )
      ]
    end

    def build_graph!
      last_output = nil

      layers.each do |current_layer| 
        current_layer.input_variables_groups = last_output unless last_output.nil?
        current_layer.build_layer!
        last_output = current_layer.output_variables_groups
      end
    end

    def run_schedule!
      full_schedule = create_full_schedule
      full_schedule.visit!
    end

    def updated_ratings
      result = {}
      prior_layer.output_variables_groups.each do |current_team|
        current_team.each do |player|
          result[player.key] = Rating.new(player.value.mean, player.value.standard_deviation)
        end
      end

      result
    end

    def outcome_probability
      factor_list = FactorList.new
      layers.each do |current_layer|
        current_layer.untyped_factors.each do |current_factor|
          factor_list.list << current_factor
        end
      end

      log_z = factor_list.log_normalization
      Math.exp(log_z)
    end

    def create_full_schedule
      full_schedule = []
      layers.each do |current_layer|
        current_prior_schedule = current_layer.create_prior_schedule
        full_schedule << current_prior_schedule unless current_prior_schedule.nil?
      end

      layers.reverse_each do |current_layer|
        current_posterior_schedule = current_layer.create_posterior_schedule
        full_schedule << current_posterior_schedule unless current_posterior_schedule.nil?
      end

      Schedule::Sequence.new("Full schedule", full_schedule)
    end
  end
end