require 'active_support/all'
require 'net/http'
require 'uri'
require 'json'
require 'colorize'
require 'date'

module Tools; end

class Tools::Telegram
  # Telegram
  DOMAIN = 'https://api.telegram.org/'
  TOKEN = ''
  METHOD = 'sendMessage'
  CHAT = '@IoTeXAlert'
  class << self
    def send_message(message)
      uri = URI.parse("#{DOMAIN}bot#{TOKEN}/#{METHOD}?chat_id=#{CHAT}&text=#{message}")
      request = Net::HTTP::Get.new(uri)
      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
    end
  end
end

class Tools::Api
  # IoTexScan
  GET_BUCKET_BY_QUERY = 'https://v2.iotexscan.io/api/services/bucket/queries/getBucketsData'
  BUCKET_LIST = []
  BASE_AMOUNT = 1000000000000000000
  ACT_TYPE = ['StakeCreate', 'DepositToStake']

  SEARCH_SKIP = 1
  SEARCH_COUNT = 1000

  class << self
    def perform
      BUCKET_LIST.each do |bucket|
        @page = SEARCH_SKIP.dup
        @search_count = SEARCH_COUNT.dup
        @break_switch = false

        loop do
          get_stake_list(bucket)
          break if @break_switch
          @page = @page + 1
          puts "Bucket[#{bucket}](ongoing): #{variable_get(bucket)}"
          sleep(1)
        end
      end

      BUCKET_LIST.each do |bucket|
        puts "Bucket[#{bucket}](DONE): #{variable_get(bucket)}"
      end
    end

    def get_stake_list(bucket)
      begin
        json_body = %Q[{"params":{"page":#{@page},"limit":#{@search_count},"bucket_id":#{bucket}},"meta":{}}]

        uri = URI.parse("#{GET_BUCKET_BY_QUERY}")
        request = Net::HTTP::Post.new(uri)
        request["Accept"] = "application/json"
        request["Content-Type"] = "application/json"
        request.body = json_body

        req_options = {
          use_ssl: uri.scheme == "https",
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        parsed_json = JSON.parse(response.body).with_indifferent_access

        @break_switch = true and return if parsed_json[:result][:buckets].blank?
        actions = parsed_json[:result][:buckets]
        actions_count_amount(actions, bucket)
      rescue => exception
        puts exception
      end
    end

    def actions_count_amount(actions, bucket)
      bucket_amount = variable_get(bucket)
      actions.each { |action| bucket_amount = bucket_amount + (action[:amount].to_f/BASE_AMOUNT) if ACT_TYPE.include?(action[:act_type]) }
      build_variable_set(bucket, bucket_amount)
    end

    def build_variable_set(bucket, amount)
      instance_variable_set("@bucket_#{bucket}", amount)
    end

    def variable_get(bucket)
      instance_variables.include?("@bucket_#{bucket}".to_sym) ? instance_variable_get("@bucket_#{bucket}".to_sym) : build_variable_set(bucket, 0.0)
    end
  end
end

Tools::Api.perform
