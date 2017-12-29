module TrueSkill
  class Schedule
    attr_accessor :name

    def initialize(name)
      self.name = name
    end

    def to_s
      name
    end

    def inspect
      "#<#{self.class.name} #{to_s}>"
    end

    class Step < Schedule
      attr_accessor :factor, :index

      def initialize(name, factor, index)
        super(name)
        self.factor = factor
        self.index = index
      end

      def visit!(depth = -1, max_depth = 0)
        factor.update_message!(index)
      end
    end

    class Sequence < Schedule
      attr_accessor :schedules

      def initialize(name, schedules)
        super(name)
        self.schedules = schedules
      end

      def visit!(depth = -1, max_depth = 0)
        max_delta = 0

        schedules.each do |current_schedule|
          max_delta = [max_delta, current_schedule.visit!(depth + 1, max_depth)].max
        end

        max_delta
      end
    end

    class Loop < Schedule
      attr_accessor :max_delta, :schedule_to_loop

      def initialize(name, schedule_to_loop, max_delta)
        super(name)
        self.schedule_to_loop = schedule_to_loop
        self.max_delta = max_delta
      end

      def visit!(depth = -1, max_depth = 0)
        delta = schedule_to_loop.visit!(depth + 1, max_depth)
        delta = schedule_to_loop.visit!(depth + 1, max_depth) while delta > max_delta
        delta
      end
    end
  end
end