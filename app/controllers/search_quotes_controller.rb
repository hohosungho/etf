require 'open-uri'
require 'nokogiri'
require 'uri'
require 'net/http'
require 'openssl'

class SearchQuotesController < ApplicationController

  def show
    start_str = params["start_dt"]
    end_str = params["end_dt"]
    ticker = params[:ticker]
    if is_correct_dt_format(start_str) && is_correct_dt_format(end_str)
      render json:show_ranged_ticker_info(start_str, end_str,ticker)
    else
      render json:get_error_json_format("invalid params",1003), status: 400
    end
  end
end

def get_utc_unix_timestamp(date)
  dt = Date.iso8601(date.to_s)
  return Time.utc(dt.year, dt.month, dt.day, 0, 0).to_i
end

def is_correct_dt_format(date)
  if(date==nil || date.length == 0)
    return false
  end
  return date.match?(/\d{4}-\d{2}-\d{2}/)
end

def show_ranged_ticker_info(start_str,end_str,ticker)
  start_unix = get_utc_unix_timestamp(start_str)
  end_unix = get_utc_unix_timestamp(end_str)
  base_url = "https://finance.yahoo.com/quote/#{ticker}/history?"
  params = "period1=%d&period2=%d&interval=%s&filter=history&frequency=%sincludeAdjustedClose=true" %
            [ start_unix, end_unix, "1d", "1d" ]
  res_json = process_url_crawling(base_url+params)
  detail = call_yahoo_finance_api(ticker)
  return res_json.merge(detail)
end

def call_yahoo_finance_api(ticker)
  url = URI("https://yfapi.net/v6/finance/quote?region=US&lang=en&symbols=#{ticker}")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Get.new(url)
  request["x-api-key"] = Rails.configuration.yahoofinance['api_key']

  response = http.request(request)
  return {
    "quote_detail": JSON.parse(response.read_body)
  }
end

def process_url_crawling(url)
  begin
    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.59"
    doc = Nokogiri::HTML(open(url, "User-Agent" => user_agent))
    quote = doc.xpath("/html/body/div[1]/div/div/div[1]/div/div[2]/div/div/div[5]/div/div/div/div[2]/div[1]/div[1]/h1").text.strip
    if quote != nil && quote.length != 0
      quote_full = quote[0.. quote.index('(')-1]
      quote_ticker = quote[quote.index('(')+1..quote.index(')')-1]

      data = doc.css("tr").select
      result = fill_ranged_quote_info_from_crawled_table(data)
      return {
        "result": result
      }
    else
      return get_error_json_format("Can't find given ticker", 1002), status: 400
    end
  rescue OpenURI::HTTPError => e
    puts e.message
    return get_error_json_format("Can't access #{ url }", 1001), status: 500
  end
end

def get_error_json_format(code,msg)
  error_json = {
    "error": msg,
    "code": code
  }
  return error_json
end

def fill_ranged_quote_info_from_crawled_table(data)
  res = []
  data.map do |item|
    row=[]
    for e in item.css("td").select do
      row.push(e.text.strip)
      # puts e.text.strip
    end
    # puts "==========================="
    _quote = Quote.new
    _quote.date = row[0]
    _quote.open = row[1]
    _quote.high = row[2]
    _quote.low = row[3]
    _quote.close = row[4]
    _quote.adj_close = row[5]
    _quote.volume = row[6]

    if _quote.valid?
         res.append(_quote)
    end
  end
  return res
end
