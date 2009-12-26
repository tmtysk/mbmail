module MbMail
  class MbMailer < ActionMailer::Base

    Dir[File.join(File.dirname(__FILE__), '../tmail/**/*.rb')].sort.each { |f| require f }

    private

    def create_mail_with_encode_body
      carrier = MbMailer.target_carrier(@recipients.first)
      character_set = "UTF-8"
      nkf_option = "-w -m0"
      if carrier == :docomo or carrier == :au then
        character_set = "Shift-JIS"
        nkf_option = "-s -m0"
      end
      charset character_set
      # 文字コードを変換
      @subject = NKF.nkf(nkf_option, @subject)
      @body = NKF.nkf(nkf_option, @body) if @parts.empty?
      # subjectとbodyの絵文字を置換
      @body = MbMailer.to_external(@body, carrier)
      @subject = MbMailer.to_external(@subject, carrier)
      # subjectは文字コードがShift-JISのときはbase64しない
      if character_set != "Shift-JIS" then
        @subject = base64(@subject, character_set) 
      end
      # bodyは文字コード変換後、全キャリア共通でbase64エンコード
      if @parts.empty? then
        @body = [@body].pack('m')
      end
      create_mail_without_encode_body
      @mail.transfer_encoding = "base64"
      @mail
    end

    alias_method_chain :create_mail, :encode_body

    public

    def self.receive(raw_email)
      logger.info "Received mail:\n #{raw_email}" unless logger.nil?
      mail = TMail::Mail.parse(raw_email)
      carrier = MbMailer.target_carrier(mail.from.first)
      # utf-8で取得
      subject = mail.subject
      body = mail.body
      if carrier == :au then
        # auではiso-2022-jpにsjisで絵文字が埋め込まれてくるので、
        # Unquoterのデコードは使わずNKFでいったんsjisにしてから
        # 絵文字部分を変換する
        subject = mail.subject('iso-2022-jp')
        body = mail.body('iso-2022-jp')
        subject = NKF.nkf('-x -s', subject)
        body = NKF.nkf('-x -s', body)
        # 絵文字を変換してUTF-8へ
        subject = Jpmobile::Emoticon.external_to_unicodecr_au_mail(subject)
        body = Jpmobile::Emoticon.external_to_unicodecr_au_mail(body)
        subject = NKF.nkf('-x -w', subject)
        body = NKF.nkf('-x -w', body)
      elsif carrier == :softbank then
        # SoftBankはSJIS絵文字が入ってくる？
        # 他のケースもあるかもしれないけど。
        subject = mail.subject('Shift_JIS')
        body = mail.body('Shift_JIS')
        subject = Jpmobile::Emoticon.external_sjis_to_unicodecr_softbank(subject)
        body = Jpmobile::Emoticon.external_sjis_to_unicodecr_softbank(body)
        subject = NKF.nkf('-x -w', subject)
        body = NKF.nkf('-x -w', body)
      end
      # UTF-8の絵文字を数値文字参照へ
      subject = Jpmobile::Emoticon.utf8_to_unicodecr(subject)
      body = Jpmobile::Emoticon.utf8_to_unicodecr(body)
      mail.content_type = "text/plain; charset=UTF-8"
      mail.transfer_encoding = "8bit"
      mail.subject = subject
      mail.body = body
      new.receive(mail)
    end

    def base64(text, charset="iso-2022-jp")
#      case charset.downcase
#      when "utf-8"
#        text = NKF.nkf('-w8 -m0', text)
#      when "sjis", "shift-jis"
#        text = NKF.nkf('-s -m0', text)
#      else
#        # デフォルトで iso-2022-jp
#        text = NKF.nkf('-j -m0', text)
#      end
      text = [text].pack('m').delete("\r\n")
      "=?#{charset}?B?#{text}?="
    end

    def self.target_carrier(to)
      carrier = :unknown
      if to =~ /([^@\.]+\.ne\.jp)$/ then
        case $1
        when "docomo.ne.jp"
          carrier = :docomo
        when "ezweb.ne.jp"
          carrier = :au
        when "jphone.ne.jp", "vodafone.ne.jp", "softbank.ne.jp"
          carrier = :softbank
        end
      end
      carrier
    end

    def self.to_internal(str, target_carrier)
      case target_carrier
      when :docomo
        str = Jpmobile::Emoticon.external_to_unicodecr_docomo(str)
      when :au
        str = Jpmobile::Emoticon.external_to_unicodecr_au_mail(str)
      when :softbank
        str = Jpmobile::Emoticon.external_to_unicodecr_softbank(str)
      end
      str
    end

    def self.to_external(str, target_carrier)
      conv_table = nil
      sjis_table = {}
      to_sjis = false
      case target_carrier
      when :docomo
        conv_table = Jpmobile::Emoticon::CONVERSION_TABLE_TO_DOCOMO
        sjis_table = Jpmobile::Emoticon::DOCOMO_UNICODE_TO_SJIS
      when :au
        conv_table = Jpmobile::Emoticon::CONVERSION_TABLE_TO_AU
        sjis_table = Jpmobile::Emoticon::AU_UNICODE_TO_SJIS
      when :softbank
        conv_table = Jpmobile::Emoticon::CONVERSION_TABLE_TO_SOFTBANK
      end

      str.gsub(/&#x([0-9a-f]{4});/i) do |match|
        unicode = $1.scanf("%x").first
        if conv_table then
          converted = conv_table[unicode] # キャリア間変換
        else
          converted = unicode # 変換しない
        end

        # 携帯側エンコーディングに変換する
        case converted
        when Integer
          if target_carrier != :softbank and sjis = sjis_table[converted]
            [sjis].pack('n')
          else
            [converted-0x1000].pack('U')
          end
        when String
          if target_carrier != :softbank then
            Kconv::kconv(converted, Kconv::SJIS, Kconv::UTF8)
          else
            converted
          end
        when nil
          match
        end
      end
    end

  end
end
