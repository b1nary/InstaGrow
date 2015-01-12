module InstaGrow
  class TokenServer
    attr_accessor :code

    def initialize hostname, port, client_id, client_secret
      server = TCPServer.open port
      puts "-> Server started on #{port}, waiting for you @ http://#{hostname}:#{port}"

      @callback_url = "http://#{hostname}:#{port}/callback/"
      @main_url = "http://#{hostname}:#{port}"
      @token_url = "https://instagram.com/oauth/authorize/?redirect_uri=#{@callback_url}&client_id=#{client_id}&response_type=code&scope=comments+relationships+likes"

      loop {
        client = server.accept()

        out = ""
        while line = client.gets
          out += line.chomp
          break if line =~ /^\s*$/
        end

        if out.include? 'GET /callback/'
          @code = out.split('/callback/?code=')[1].split(" ")[0]
          resp = "<a href='#{@main_url}'>Reload (next?)</a>"
          headers = ["HTTP/1.1 200 /",
                     "Server: InstaGrow (Ruby Socket)",
                     "Content-Type: text/html; charset=UTF-8",
                     "Content-Length: #{resp.length}\r\n\r\n"].join("\r\n")
          client.puts headers
          client.puts resp
          client.close
          server.close
          break
        else
          resp = "Go to: #{@token_url}"
          headers = ["HTTP/1.1 307 Moved Permanently",
                     "Server: InstaGrow (Ruby Socket)",
                     "Location: #{@token_url}",
                     "Content-Type: text/html; charset=UTF-8",
                     "Content-Length: #{resp.length}\r\n\r\n"].join("\r\n")
          client.puts headers
          client.puts resp
          client.close
        end

      }

    end
  end
end
