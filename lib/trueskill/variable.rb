module TrueSkill
  class Variable
    attr_accessor :name, :prior, :value

    def initialize(name, prior = nil)
      self.name = "Variable[#{name}]"
      self.prior = prior || GaussianDistribution.from_precision_mean(0, 0)
      reset_to_prior!
    end

    def reset_to_prior!
      self.value = prior
    end

    def inspect
      "name=#{name} prior=#{prior} value=#{value}>"
    end

    def to_s
      inspect
    end

    class Default < Variable
      def initialize(default_value)
        super("Default", default_value)
        freeze
      end
    end

    class Keyed < Variable
      attr_accessor :key

      def initialize(name, key, prior = nil)
        super(name, prior)
        self.key = key
      end

      def inspect
        "key=#{key} name=#{name} prior=#{prior} value=#{value}>"
      end
    end
  end
end
