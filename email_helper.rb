require 'pg'
require 'inifile'
require 'json'
require 'logger'

class EmailHelper
  attr_reader \
    :conn,
    :logger

  def initialize(channel="signups")
    config_file = IniFile.load("postgrest.conf")
    uri = config_file["global"]["db-uri"]
    @conn = PG::Connection.new(uri)
    @conn.exec("LISTEN #{channel}")

    @logger = Logger.new(STDERR)
    @logger.level = Logger::INFO
  end

  def send_email!(address, subject, payload)
    io = IO.popen("mail -s '#{subject}' #{address}", mode="w")
    io.write(payload)
    io.close
    logger.info("Sent email: '#{address}' subject: '#{subject}' body: '#{payload}'")
  end

  def run!
    loop do
      conn.wait_for_notify do |event, pid, payload|
        logger.info("NOTIFY '#{event}' from #{pid}, payload: '#{payload}'")
        if event == "signups"
          content = JSON.load(payload)
          send_email!(
            content["email"],
            "WidgetWerkz: verify your account",
            "Challenge token: http://widgetwerkz.development/confirm_email?challenge=#{content["challenge"]}"
          )
        end
      end
    end
  end
end

EmailHelper.new.run!