require File.dirname(__FILE__) + '/../spec_helper'

describe MbMail::MbMailer, "は" do
  before do
    class TestMbMailer < MbMail::MbMailer
      def testmail(sent_at = Time.now)
        @subject = '日本語subject'
        @recipients = [ INVALID_ADDRESS ]
        @from = "#{base64('日本語from')} <#{INVALID_ADDRESS}>"
        @sent_at = sent_at
      end
      def test_emojimail(to, sent_at = Time.now)
        @subject = "&#xE63E; 晴れ"
        @recipients = [ to ]
        @from = "text@example.com"
        @sent_at = sent_at
      end
      def receive(email)
        email
      end
    end
    TestMbMailer.template_root = SAMPLE_DIR
    TestMbMailer.delivery_method = :test
  end
  it "日本語ヘッダを作成するためのbase64メソッドが使用できる" do
    MbMail::MbMailer.instance_methods.should include('base64')
  end
  it "送信先および送信元に3つ以上の連続ドットを含むメールを正しく作成できる" do
    TestMbMailer.deliver_testmail
    TestMbMailer.deliveries.first.to.first.should == INVALID_ADDRESS
    TestMbMailer.deliveries.first.from.first.should == INVALID_ADDRESS
  end
  it "本文に含まれる機種依存文字を正しく送信できる" do
    TestMbMailer.deliveries.first.body.match(Regexp.new("㌧")).should_not be_nil
  end
  describe "件名と本文中に含まれる絵文字を" do
    it "Docomo端末に正しく変換して送信できる" do
      TestMbMailer.deliver_test_emojimail("example@docomo.ne.jp")
      TestMbMailer.deliveries.last.subject.include?([0xE63E].pack('U')).should be_true
      TestMbMailer.deliveries.last.body.include?([0xE63E].pack('U')).should be_true
    end
    it "Au端末に正しく変換して送信できる" do
      TestMbMailer.deliver_test_emojimail("example@ezweb.ne.jp")
      TestMbMailer.deliveries.last.subject.include?([0xE488].pack('U')).should be_true
      TestMbMailer.deliveries.last.body.include?([0xE488].pack('U')).should be_true
    end
    it "SoftBank端末に正しく変換して送信できる" do
      TestMbMailer.deliver_test_emojimail("example@softbank.ne.jp")
      TestMbMailer.deliveries.last.subject.include?([0xE04A].pack('U')).should be_true
      TestMbMailer.deliveries.last.body.include?([0xE04A].pack('U')).should be_true
    end
  end
  describe "受信処理において" do
    it "Docomo端末からの絵文字を含むメールを正しく変換して読み取る事ができる" do
      m = TestMbMailer.receive(File.open("#{SAMPLE_DIR}/docomo.eml").read)
      m.subject.include?("&#xe63e;").should be_true
      m.body.include?("&#xe63e;").should be_true
    end
    it "Au端末からの絵文字を含むメールを正しく変換して読み取る事ができる" do
      m = TestMbMailer.receive(File.open("#{SAMPLE_DIR}/ezweb.eml").read)
      m.subject.include?("&#xe488;").should be_true
      m.body.include?("&#xe488;").should be_true
    end
    it "SoftBank端末からの絵文字を含むメールを正しく変換して読み取る事ができる" do
      m = TestMbMailer.receive(File.open("#{SAMPLE_DIR}/softbank.eml").read)
      m.subject.include?("&#xf04a;").should be_true
      m.body.include?("&#xf04a;").should be_true
    end
  end
end
