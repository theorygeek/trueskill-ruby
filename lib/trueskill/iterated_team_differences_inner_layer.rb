module TrueSkill
  class IteratedTeamDifferencesInnerLayer < FactorGraphLayer
    attr_accessor :team_differences_comparison_layer, :team_performances_to_team_performance_differences_layer

    def initialize(parent_graph, diff_layer, comparison_layer)
      super(parent_graph)
      self.team_performances_to_team_performance_differences_layer = diff_layer
      self.team_differences_comparison_layer = comparison_layer
    end

    def untyped_factors
      team_performances_to_team_performance_differences_layer.untyped_factors + team_differences_comparison_layer.untyped_factors
    end

    def build_layer!
      team_performances_to_team_performance_differences_layer.input_variables_groups = input_variables_groups;
      team_performances_to_team_performance_differences_layer.build_layer!

      team_differences_comparison_layer.input_variables_groups = team_performances_to_team_performance_differences_layer.output_variables_groups
      team_differences_comparison_layer.build_layer!
    end

    def create_prior_schedule
      loop = nil
      
      case input_variables_groups.count
      when 0, 1
        raise "InvalidOperationException"
      when 2
        loop = create_two_team_inner_prior_loop_schedule
      else
        loop = create_multiple_team_inner_prior_loop_schedule
      end

      # When dealing with differences, there are always (n-1) differences, so add in the 1
      total_team_differences = team_performances_to_team_performance_differences_layer.local_factors.count;

      Schedule::Sequence.new(
        "inner schedule",
        [
          loop,
          Schedule::Step.new(
            "team_performance_to_performance_difference_factors[0] @ 1", 
            team_performances_to_team_performance_differences_layer.local_factors[0], 
            1
          ),
          Schedule::Step.new(
            "team_performance_to_performance_difference_factors[team_team_differences = #{total_team_differences} - 1] @ 2",
            team_performances_to_team_performance_differences_layer.local_factors[total_team_differences - 1],
            2
          )
        ]
      )
    end

    def create_two_team_inner_prior_loop_schedule
      Schedule::Sequence.new(
        "loop of just two teams inner sequence",
          [
              Schedule::Step.new(
                "send team perf to perf differences",
                team_performances_to_team_performance_differences_layer.local_factors[0],
                0
              ),
              Schedule::Step.new(
                "send to greater than or within factor",
                team_differences_comparison_layer.local_factors[0],
                0
              )
          ]
      )
    end

    def create_multiple_team_inner_prior_loop_schedule
      total_team_differences = team_performances_to_team_performance_differences_layer.local_factors.count;
      forward_schedule_list = []
      
      (0...total_team_differences).each do |i|
        current_forward_schedule_piece = Schedule::Sequence.new(
          "current forward schedule piece #{i}",
          [
            Schedule::Step.new(
              "team perf to perf diff #{i}",
              team_performances_to_team_performance_differences_layer.local_factors[i],
              0
            ),
            Schedule::Step.new(
              "greater than or within result factor #{i}",
              team_differences_comparison_layer.local_factors[i],
              0
            ),
            Schedule::Step.new(
              "team perf to perf diff factors [#{i}], 2",
              team_performances_to_team_performance_differences_layer.local_factors[i],
              2
            )
          ]
        )

        forward_schedule_list << current_forward_schedule_piece
      end

      forward_schedule = Schedule::Sequence.new("forward schedule", forward_schedule_list)
      backward_schedule_list = []

      (0...total_team_differences).each do |i|
        current_backward_schedule_piece = Schedule::Sequence.new(
          "current backward schedule piece",
          [
              Schedule::Step.new(
                "teamPerformanceToPerformanceDifferenceFactors[total_team_differences - 1 - #{i}] @ 0",
                team_performances_to_team_performance_differences_layer.local_factors[total_team_differences - 1 - i], 
                0
              ),
              Schedule::Step.new(
                "greaterThanOrWithinResultFactors[total_team_differences - 1 - #{i}] @ 0",
                team_differences_comparison_layer.local_factors[total_team_differences - 1 - i], 
                0
              ),
              Schedule::Step.new(
                "teamPerformanceToPerformanceDifferenceFactors[total_team_differences - 1 - #{i}] @ 1",
                team_performances_to_team_performance_differences_layer.local_factors[total_team_differences - 1 - i], 
                1
              )
          ]
        )

        backward_schedule_list << current_backward_schedule_piece
      end

      backward_schedule = Schedule::Sequence.new("backward schedule", backward_schedule_list);
      forward_backward_schedule_to_loop = Schedule::Sequence.new("forward Backward Schedule To Loop", [forward_schedule, backward_schedule]);

      initial_max_delta = 0.0001;
      Schedule::Loop.new("loop with max delta of #{initial_max_delta}", forward_backward_schedule_to_loop, initial_max_delta)
    end
  end
end