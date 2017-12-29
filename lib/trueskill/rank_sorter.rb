module TrueSkill
  module RankSorter
    extend self

    def sort(teams, team_ranks)
      last_observed_rank = 0
      need_to_sort = false

      team_ranks.each do |current_rank|
        # We're expecting ranks to go up (1, 2, 2, 3, ...)
        # If it goes down, then we've got to sort it
        if current_rank < last_observed_rank
          need_to_sort = true
          break
        end

        last_observed_rank = current_rank
      end

      return [teams, team_ranks] unless need_to_sort

      items_in_list = teams.to_a
      item_to_rank = {}

      items_in_list.each_with_index do |current_item, i|
        current_item_rank = team_ranks[i]
        item_to_rank[current_item] = current_item_rank
      end

      sorted_items = []
      sorted_ranks = []

      item_to_rank.sort_by { |k, v| v }.each do |key, value|
        sorted_items << key
        sorted_ranks << value
      end

      [sorted_items, sorted_ranks]
    end
  end
end
