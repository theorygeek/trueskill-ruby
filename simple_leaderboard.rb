require 'pry'
require 'set'

class Game
  attr_accessor :team1, :team2, :winner
  def initialize(team1:, team2:, winner:)
    raise ArgumentError, "team1 must be Array" unless team1.is_a?(Array)
    raise ArgumentError, "team2 must be Array" unless team2.is_a?(Array)
    raise ArgumentError, "winner must be :team1 or :team2" unless [:team1, :team2].include?(winner)

    @team1 = team1.freeze
    @team2 = team2.freeze
    @winner = winner
    freeze
  end
end

class PossibleGame
  attr_accessor :high_team, :low_team, :quality, :probability

  # @param high_team Team that is most likely to win
  # @param low_team Team that is least likely to win
  # @param quality Quality score of the match
  # @param probability Probability that the high team wins
  def initialize(high_team:, low_team:, quality:, probability:)
    raise ArgumentError, "high_team must be Array" unless high_team.is_a?(Array)
    raise ArgumentError, "low_team must be Array" unless low_team.is_a?(Array)
    raise ArgumentError, "quality must be Float" unless quality.is_a?(Float)
    raise ArgumentError, "probability must be Float" unless probability.is_a?(Float)

    @high_team = high_team
    @low_team = low_team
    @quality = quality
    @probability = probability
    freeze
  end
end

class Player
  attr_accessor :name, :rating, :games_played, :games_won

  def initialize(name)
    @name = name
    @rating = TrueSkill::Rating.new(25.0, 25.0 / 3.0)
    @games_played = 0
    @games_won = 0
  end

  LOW = 25.0 / 3.0
  MEDIUM = LOW / 2.0
  HIGH = LOW / 3.0

  def confidence
    if rating.standard_deviation <= HIGH
      'high'
    elsif rating.standard_deviation <= MEDIUM
      'medium'
    else
      'low'
    end
  end

  def winrate
    (games_won.to_f / games_played.to_f) * 100.0
  end
end

class Leaderboard
  def self.show(*args)
    new(*args).show
  end

  def <<(game)
    calculate_new_ratings(game)
  end

  HEADLINE = ['#', 'Player', 'Mean', 'Confidence', 'Games Won', 'Games Played', 'Win Rate']
  SPACER = '  '

  def show
    sorted = player_rating.sort_by { |player_name, player| [-player.rating.mean, player.rating.standard_deviation] }


    output = [HEADLINE]
    sorted.each_with_index do |(player_name, player), index|
      output << [
        index + 1,
        player_name,
        player.rating.mean.round(1),
        "#{player.confidence} (#{player.rating.standard_deviation.round(1)})",
        player.games_won,
        player.games_played,
        player.winrate
      ]
    end

    display(output)
  end

  def match_qualities
    result = []
    player_rating.keys.combination(4).each do |game_players|
      ignore = Set.new
      game_players.combination(2).each do |team1_players|
        team1 = team1_players
          .map { |player_name| [player_name, player_rating[player_name].rating] }
          .to_h

        team2_players = game_players - team1_players
        team2 = team2_players
          .map { |player_name| [player_name, player_rating[player_name].rating] }
          .to_h

        next unless ignore.add?(team1_players)
        next unless ignore.add?(team2_players)

        quality = TrueSkill::TwoTeamCalculator.match_quality(game_info, [team1, team2])
        probability = TrueSkill::FactorGraphTrueSkillCalculator.outcome_probability(
          game_info,
          [team1, team2],
          [1, 2]
        )

        if probability < 0.5
          # Swap so that team 1 is most likely to win
          team1, team2 = team2, team1
          probability = 1.0 - probability
        end

        result << PossibleGame.new(
          high_team: team1.keys.sort,
          low_team: team2.keys.sort,
          quality: quality,
          probability: probability
        )
      end
    end

    result.sort_by { |pg| -pg.quality }
  end

  private def format(value)
    if value.is_a?(Numeric) && value.finite?
      value.to_s
    elsif value.is_a?(Numeric)
      "N/A"
    else
      value.to_s
    end
  end

  private def display(output, header: true)
    columns = output.map(&:size).max
    column_sizes = (0...columns).map do |column|
      biggest = output.max_by { |row| row[column].to_s.size }
      [column, format(biggest[column]).size]
    end

    column_sizes = column_sizes.to_h

    output.each_with_index do |row, row_index|
      row.each_with_index do |value, col_index|
        value = if value.is_a?(Numeric) && value.finite?
          format(value).rjust(column_sizes[col_index])
        elsif value.is_a?(Numeric)
          format(value).rjust(column_sizes[col_index])
        else
          format(value).ljust(column_sizes[col_index])
        end

        print(value)
        print(SPACER)
      end
      print("\n")

      if header && row_index == 0
        columns.times do |col_index|
          print('-' * column_sizes[col_index])
          print(SPACER)
        end
        print("\n")
      end
    end
  end

  private def game_info
    @game_info ||= TrueSkill::GameInfo.new(draw_probability: 0.1).freeze
  end

  private def calculate_new_ratings(game)
    team1 = build_team(game.team1)
    team2 = build_team(game.team2)
    if game.winner == :team1
      winners = game.team1
      rankings = [1, 2]
    else
      winners = game.team2
      rankings = [2, 1]
    end

    results = TrueSkill::TwoTeamCalculator.calculate_new_ratings(
      game_info, 
      [team1, team2], 
      rankings
    )

    results.each do |player_name, rating|
      player_rating[player_name].rating = rating
      player_rating[player_name].games_played += 1

      if winners.include?(player_name)
        player_rating[player_name].games_won += 1
      end
    end
  end

  private def build_team(players)
    ratings = players.map do |player_name|
      rating = player_rating[player_name].rating
      [player_name, rating]
    end

    ratings.to_h
  end

  private def player_rating
    @player_rating ||= Hash.new do |hash, player_name|
      hash[player_name] = Player.new(player_name)
    end
  end
end