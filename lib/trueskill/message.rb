module TrueSkill
  class Message
    attr_accessor :name, :value
    
    def initialize(value, name)
      self.name = name
      self.value = value;
    end
    
    def to_s
      name
    end

    def inspect
      "#<Message: name=#{name} value=#{value}>"
    end
  end
end