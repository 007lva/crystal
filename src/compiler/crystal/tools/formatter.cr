module Crystal
  class Formatter < Visitor
    def self.format(source)
      nodes = Parser.parse(source)

      formatter = new(source)
      nodes.accept formatter
      formatter.to_s
    end

    def initialize(source)
      @lexer = Lexer.new(source)
      @lexer.comments_enabled = true
      @lexer.count_whitespace = true
      @lexer.wants_raw = true
      @token = next_token

      @output = StringIO.new(source.bytesize)
      @indent = 0
    end

    def visit(node : Expressions)
      prelude indent: false

      old_indent = @indent
      base_ident = old_indent
      next_needs_indent = true

      has_paren = false
      has_begin = false

      if @token.type == :"("
        @output << "("
        next_needs_indent = false
        next_token
        has_paren = true
      elsif @token.keyword?(:begin)
        @output << "begin\n"
        next_token_skip_space_or_newline
        if @token.type == :";"
          next_token_skip_space_or_newline
        end
        has_begin = true
        @indent += 2
        base_ident = @indent
      end

      node.expressions.each_with_index do |exp, i|
        @indent = 0 unless next_needs_indent
        exp.accept self
        @indent = base_ident

        skip_space

        if @token.type == :";"
          if i != node.expressions.size - 1
            @output << "; "
          end
          next_token_skip_space_or_newline
          next_needs_indent = false
        else
          next_needs_indent = true
        end

        if i == node.expressions.size - 1
          skip_space_or_newline
        else
          consume_newlines
        end
      end

      @indent = old_indent

      if has_paren
        check :")"
        @output << ")"
        next_token
      end

      if has_begin
        check_keyword :end
        next_token
        @output << "\n"
        @indent -= 2
        write_indent
        @output << "end"
      end

      false
    end

    def visit(node : Nop)
      prelude

      false
    end

    def visit(node : NilLiteral)
      prelude

      check_keyword :nil
      @output << "nil"
      next_token

      false
    end

    def visit(node : BoolLiteral)
      prelude

      check_keyword :false, :true
      @output << node.value
      next_token

      false
    end

    def visit(node : CharLiteral)
      prelude

      check :CHAR
      @output << @token.raw
      next_token

      false
    end

    def visit(node : SymbolLiteral)
      prelude

      check :SYMBOL
      @output << @token.raw
      next_token

      false
    end

    def visit(node : NumberLiteral)
      prelude

      check :NUMBER
      @output << @token.raw
      next_token

      false
    end

    def visit(node : StringLiteral)
      prelude

      check :DELIMITER_START

      @output << @token.raw
      @token = @lexer.next_string_token(@token.delimiter_state)

      while @token.type == :STRING
        @output << @token.raw
        @token = @lexer.next_string_token(@token.delimiter_state)
      end

      check :DELIMITER_END
      @output << @token.raw
      next_token

      false
    end

    def visit(node : ArrayLiteral)
      prelude

      case @token.type
      when :"["
        @output << "["

        bracket_indent = @indent + 1
        has_newlines = false
        next_token

        old_indent = @indent
        @indent = 0

        node.elements.each_with_index do |element, i|
          skip_space
          if @token.type == :NEWLINE
            @indent = bracket_indent
            @output << "\n"
            has_newlines = true
          elsif i > 0
            @output << " "
          end
          skip_space_or_newline
          element.accept self
          @indent = 0
          skip_space_or_newline

          if @token.type == :","
            unless i == node.elements.size - 1
              @output << ","
            end
            next_token
          end
        end

        @indent = old_indent

        skip_space_or_newline
        check :"]"

        if has_newlines
          @output << ",\n"
          write_indent
        end

        @output << "]"
      when :"[]"
        @output << "[]"
      end

      next_token_skip_space

      if node_of = node.of
        check_keyword :of
        @output << " of "
        next_token_skip_space_or_newline
        no_indent { node_of.accept self }
      end

      false
    end

    def visit(node : Path)
      prelude

      if node.global
        check :"::"
        @output << "::"
        next_token_skip_space_or_newline
      end

      node.names.each do |name|
        skip_space_or_newline
        check :CONST
        @output << @token.value
        next_token_skip_space
        if @token.type == :"::"
          @output << "::"
          next_token
        end
      end

      false
    end

    def visit(node : If)
      visit_if_or_unless node, :if, "if "
    end

    def visit(node : Unless)
      visit_if_or_unless node, :unless, "unless "
    end

    def visit_if_or_unless(node, keyword, prefix)
      prelude

      # This is the case of `cond ? exp1 : exp2`
      if keyword == :if && !@token.keyword?(:if)
        no_indent { node.cond.accept self }
        skip_space_or_newline
        check :"?"
        @output << " ? "
        next_token_skip_space_or_newline
        no_indent { node.then.accept self }
        skip_space_or_newline
        check :":"
        @output << " : "
        next_token_skip_space_or_newline
        no_indent { node.else.accept self }
        return false
      end

      check_keyword keyword
      @output << prefix
      next_token_skip_space_or_newline

      no_indent do
        node.cond.accept self
      end

      @output.puts

      unless node.then.is_a?(Nop)
        indent do
          node.then.accept self
        end
        @output.puts
      end

      skip_space_or_newline

      if @token.keyword?(:else)
        write_indent
        @output.puts "else"
        next_token_skip_space_or_newline

        unless node.else.is_a?(Nop)
          indent do
            node.else.accept self
          end
        end
        @output.puts
      end

      write_indent
      @output << "end"

      false
    end

    def visit(node : ASTNode)
      node.raise "missing handler for #{node.class}"
      true
    end

    def to_s(io)
      io << @output
    end

    def next_token
      @token = @lexer.next_token
    end

    def next_token_skip_space
      next_token
      skip_space
    end

    def next_token_skip_space_or_newline
      next_token
      skip_space_or_newline
    end

    def skip_space
      while @token.type == :SPACE
        next_token
      end
    end

    def skip_space_or_newline
      while @token.type == :SPACE || @token.type == :NEWLINE
        next_token
      end
    end

    def skip_semicolon
      while @token.type == :";"
        next_token
      end
    end

    def write_comment
      while @token.type == :COMMENT
        write_indent
        @output << @token.value
        next_token_skip_space
        consume_newlines
        skip_space_or_newline
      end
    end

    def consume_newlines
      if @token.type == :NEWLINE
        @output.puts
        next_token

        if @token.type == :NEWLINE
          @output.puts
        end

        skip_space_or_newline
      end
    end

    def prelude(indent = true)
      skip_space_or_newline
      write_comment
      write_indent if indent
    end

    def indent
      @indent += 2
      yield
      @indent -= 2
    end

    def no_indent
      old_indent = @indent
      @indent = 0
      yield
      @indent = old_indent
    end

    def write_indent
      @indent.times { @output << " " }
    end

    def check_keyword(*keywords)
      raise "expecting keyword #{keywords.join " or "}, not #{@token.type}, #{@token.value}" unless keywords.any? { |k| @token.keyword?(k) }
    end

    def check(token_type)
      raise "expecting #{token_type}, not #{@token.type}" unless @token.type == token_type
    end
  end
end
