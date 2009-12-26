module TMail
  class Decoder
    def self.decode( str, encoding = nil )
      # 何もしない。実際のデコードはUnquoter#convert_toで行われるため。
      # thanks to ode.
      return str
    end
  end
end
