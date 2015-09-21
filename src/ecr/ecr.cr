# ECR is a template engine for embedding Crystal in HTML.
# 
# Quick example:
#
#     require "ecr"
#
#     class Greeting
#       def initialize(name)
#         @name = name
#       end
#       ecr_file "greeting.ecr"
#     end
#     
#     # greeting.ecr
#     <h1>Greeting, <%= @name %>!</h1>
#
#     Greeting.new("John")
#     #=> <h1>Greeting, John!</h1>

module ECR
  extend self

  DefaultBufferName = "__str__"

  def process_file(filename, buffer_name = DefaultBufferName)
    process_string File.read(filename), filename, buffer_name
  end

  def process_string(string, filename, buffer_name = DefaultBufferName)
    lexer = Lexer.new string

    String.build do |str|
      while true
        token = lexer.next_token
        case token.type
        when :STRING
          str << buffer_name
          str << " << "
          token.value.inspect(str)
          str << "\n"
        when :OUTPUT
          str << "("
          append_loc(str, filename, token)
          str << token.value
          str << ").to_s "
          str << buffer_name
          str << "\n"
        when :CONTROL
          append_loc(str, filename, token)
          str << token.value
          str << "\n"
        when :EOF
          break
        end
      end
    end
  end

  private def append_loc(str, filename, token)
    str << %(#<loc:")
    str << filename
    str << %(",)
    str << token.line_number
    str << %(,)
    str << token.column_number
    str << %(>)
  end
end

require "./lexer"


