require 'nkf'
# convert_to で機種依存文字や絵文字に対応するために
# Unquoter 内で NKF を使用するようにしたもの
module TMail
  class Unquoter
    class << self

      def unquote_and_convert_to(text, to_charset, from_charset = "iso-8859-1", preserve_underscores=false)
        return "" if text.nil?
        text.gsub(/(.*?)(?:(?:=\?(.*?)\?(.)\?(.*?)\?=)|$)/) do
          before = $1
          from_charset = $2
          quoting_method = $3
          text = $4

          before = convert_to(before, to_charset, from_charset) if before.length > 0
          before + case quoting_method
            when "q", "Q" then
            unquote_quoted_printable_and_convert_to(text, to_charset, from_charset, preserve_underscores)
            when "b", "B" then
            unquote_base64_and_convert_to(text, to_charset, from_charset)
            when nil then
            # will be nil at the end of the string, due to the nature of
            # the regex used.
                ""
          else
            raise "unknown quoting method #{quoting_method.inspect}"
          end
        end
      end

      # http://www.kbmj.com/~shinya/rails_seminar/slides/#(30)
      def convert_to_with_nkf(text, to, from)
        if text && to =~ /^utf-8$/i && from =~ /^iso-2022-jp$/i
          NKF.nkf("-w", text)
        elsif text && from =~ /^utf-8$/i && to =~ /^iso-2022-jp$/i
          NKF.nkf("-Wj", text)
        else
          convert_to_without_nkf(text, to, from)
        end
      end

      alias_method_chain :convert_to, :nkf
    end
  end
end
