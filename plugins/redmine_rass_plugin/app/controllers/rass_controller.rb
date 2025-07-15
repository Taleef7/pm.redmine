require 'net/http'
require 'uri'
require 'json'

class RassController < ApplicationController
  def index
    @query = params[:q] # Get the query from the URL parameters
    @results = nil
    @error = nil

    if @query.present?
      begin
        # Define the URI for the RASS server's simple-ask endpoint
        uri = URI.parse('http://host.docker.internal:8000/ask')
        
        # Create the HTTP POST request
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
        request.body = { query: @query, top_k: 5 }.to_json
        
        # Send the request
        response = http.request(request)
        
        if response.is_a?(Net::HTTPSuccess)
          @results = JSON.parse(response.body)
        else
          @error = "RASS engine returned an error: #{response.code} #{response.message}"
        end
        
      rescue => e
        @error = "Could not connect to RASS engine: #{e.message}"
      end
    end
  end
end