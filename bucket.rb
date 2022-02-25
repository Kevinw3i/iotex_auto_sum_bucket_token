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
  GET_BUCKET_BY_QUERY = 'https://analytics.iotexscan.io/query'
  BUCKET_LIST = [0]
  BASE_AMOUNT = 1000000000000000000

  SEARCH_SKIP = 0
  SEARCH_COUNT = 500

  class << self
    def perform
      BUCKET_LIST.each do |bucket|
        @page_count = 0
        @skip = SEARCH_SKIP.dup
        @search_count = SEARCH_COUNT.dup
        @break_switch = false

        loop do
          get_stake_list(bucket)
          break if @break_switch
          @page_count += 1
          @skip = @search_count * @page_count
          puts "Bucket[#{bucket}](ongoing): #{variable_get(bucket)}"
          sleep(1)
        end
      end

      puts "DONE: "
      BUCKET_LIST.each do |bucket|
        puts "Bucket[#{bucket}]: #{variable_get(bucket)}"
      end
    end

    def get_stake_list(bucket)
      begin
        json_body = %Q[{"operationName":"action","variables":{"bucketIndex":#{bucket},"pagination":{"skip":#{@skip},"first":#{@search_count}}},"query":"query action($bucketIndex: Int!, $pagination: Pagination!) {  action {    byBucketIndex(bucketIndex: $bucketIndex) {      count      actions(pagination: $pagination) {        actHash        blkHash        timeStamp        actType        sender        recipient        amount        gasFee        __typename      }      __typename    }    __typename  }}"}]

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

        @break_switch = true and return if parsed_json[:data][:action][:byBucketIndex].nil?
        actions = parsed_json[:data][:action][:byBucketIndex][:actions]
        actions_count_amount(actions, bucket)
      rescue => exception
        puts exception
      end
    end

    def actions_count_amount(actions, bucket)
      bucket_amount = variable_get(bucket)
      actions.each { |action| bucket_amount = bucket_amount + (action[:amount].to_f/BASE_AMOUNT) }
      build_variable_set(bucket, bucket_amount)
    end

    def build_variable_set(bucket, amount)
      instance_variable_set("@bucket_#{bucket}", amount)
    end

    def variable_get(bucket)
      instance_variables.include?("@bucket_#{bucket}".to_sym) ? instance_variable_get("@bucket_#{bucket}".to_sym) : build_variable_set(bucket, 0)
    end
  end
end

Tools::Api.perform
