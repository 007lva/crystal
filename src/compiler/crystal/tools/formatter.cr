module Crystal
  class Formatter < Visitor
    def self.format(source)
      nodes = Parser.parse(source)

      formatter = new(source)
      nodes.accept formatter
      formatter.finish
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
      @column = 0
      @visibility_indent = nil
      @wrote_nelwine = false
    end

    def visit(node : Expressions)
      prelude indent: false

      old_indent = @indent
      column = @column
      base_indent = old_indent
      next_needs_indent = true

      has_paren = false
      has_begin = false

      unless starts_with_expressions?(node)
        if @token.type == :"("
          write "("
          next_needs_indent = false
          next_token
          has_paren = true
        elsif @token.keyword?(:begin)
          write "begin"
          write_line
          next_token_skip_space_or_newline
          if @token.type == :";"
            next_token_skip_space_or_newline
          end
          has_begin = true
          @indent = column + 2
          base_indent = @indent
        end
      end

      node.expressions.each_with_index do |exp, i|
        needs_two_lines = !last?(i, node.expressions) && !exp.is_a?(Attribute) && (needs_two_lines?(exp) || needs_two_lines?(node.expressions[i + 1]))

        @indent = 0 unless next_needs_indent
        exp.accept self
        @indent = base_indent

        skip_space

        if @token.type == :";"
          if needs_two_lines
            next_token_skip_space_or_newline
          else
            next_token_skip_space
            if @token.type == :NEWLINE
              write_line
              next_token_skip_space
              next_needs_indent = true
            else
              write "; " unless last?(i, node.expressions)
              skip_space_or_newline
              next_needs_indent = false
            end
          end
        else
          next_needs_indent = true
        end

        if last?(i, node.expressions)
          skip_space_or_newline last: true
        else
          if needs_two_lines
            skip_space_write_line
            write_line
          else
            consume_newlines
          end
        end
      end

      @indent = old_indent

      if has_paren
        check :")"
        write ")"
        next_token
      end

      if has_begin
        check_end
        next_token
        write_line
        @indent = column
        write_indent
        write "end"
      end

      false
    end

    def starts_with_expressions?(node)
      case node
      when Expressions
        first = node.expressions.first?
        first && starts_with_expressions?(first)
      when Call
        node.obj.is_a?(Expressions) || starts_with_expressions?(node.obj)
      else
        false
      end
    end

    def needs_two_lines?(node)
      case node
      when Def, ClassDef, ModuleDef, LibDef, StructOrUnionDef, Macro
        true
      else
        false
      end
    end

    def visit(node : Nop)
      prelude

      false
    end

    def visit(node : NilLiteral)
      prelude

      check_keyword :nil
      write "nil"
      next_token

      false
    end

    def visit(node : BoolLiteral)
      prelude

      check_keyword :false, :true
      write node.value
      next_token

      false
    end

    def visit(node : CharLiteral)
      prelude

      check :CHAR
      write @token.raw
      next_token

      false
    end

    def visit(node : SymbolLiteral)
      prelude

      check :SYMBOL
      write @token.raw
      next_token

      false
    end

    def visit(node : NumberLiteral)
      prelude

      check :NUMBER
      write @token.raw
      next_token

      false
    end

    def visit(node : StringLiteral)
      prelude

      check :DELIMITER_START

      write @token.raw
      next_string_token

      while @token.type == :STRING
        write @token.raw
        next_string_token
      end

      check :DELIMITER_END
      write @token.raw
      next_token

      false
    end

    def visit(node : StringInterpolation)
      prelude

      check :DELIMITER_START

      write @token.raw
      next_string_token

      delimiter_state = @token.delimiter_state

      node.expressions.each do |exp|
        if exp.is_a?(StringLiteral)
          write @token.raw
          next_string_token
        else
          check :INTERPOLATION_START
          write "\#{"
          delimiter_state = @token.delimiter_state
          next_token_skip_space_or_newline
          no_indent exp
          skip_space_or_newline
          check :"}"
          write "}"
          @token.delimiter_state = delimiter_state
          next_string_token
        end
      end

      check :DELIMITER_END
      write @token.raw
      next_token

      false
    end

    def visit(node : ArrayLiteral)
      prelude

      case @token.type
      when :"["
        format_array_or_tuple_elements node.elements, :"[", :"]"
      when :"[]"
        write "[]"
        next_token
      when :STRING_ARRAY_START
        first = true
        write "%w("
        while true
          next_string_array_token
          case @token.type
          when :STRING
            write " " unless first
            write @token.raw
            first = false
          when :STRING_ARRAY_END
            write ")"
            next_token
            break
          end
        end
        return false
      end

      if node_of = node.of
        skip_space_or_newline
        check_keyword :of
        write " of "
        next_token_skip_space_or_newline
        no_indent node_of
      end

      false
    end

    def visit(node : TupleLiteral)
      prelude

      format_array_or_tuple_elements node.elements, :"{", :"}"

      false
    end

    def format_array_or_tuple_elements(elements, prefix, suffix)
      check prefix
      write prefix
      next_token
      prefix_indent = @column
      base_indent = @column
      has_newlines = false

      old_indent = @indent
      @indent = 0

      skip_space
      if @token.type == :NEWLINE
        base_indent += 1
      end

      elements.each_with_index do |element, i|
        skip_space
        if @token.type == :NEWLINE
          @indent = base_indent
          write_line
          has_newlines = true
        elsif i > 0
          write " "
        end
        skip_space_or_newline
        element.accept self
        @indent = 0
        skip_space_or_newline

        if @token.type == :","
          write "," unless last?(i, elements)
          next_token
        end
      end

      @indent = old_indent

      skip_space_or_newline
      check suffix

      if has_newlines
        write ","
        write_line
        write_indent(prefix_indent - 1)
      end

      write suffix
      next_token
    end

    def visit(node : HashLiteral)
      prelude

      check :"{"
      write "{"
      next_token

      prefix_indent = @column
      base_indent = @column
      has_newlines = false

      old_indent = @indent
      @indent = 0

      skip_space
      if @token.type == :NEWLINE
        base_indent += 1
      end

      node.entries.each_with_index do |entry, i|
        skip_space
        if @token.type == :NEWLINE
          @indent = base_indent
          write_line
          has_newlines = true
        elsif i > 0
          write " "
        end
        skip_space_or_newline
        format_hash_entry entry
        @indent = 0
        skip_space_or_newline
        if @token.type == :","
          write "," unless last?(i, node.entries)
          next_token
        end
      end

      @indent = old_indent

      skip_space_or_newline
      check :"}"

      if has_newlines
        write ","
        write_line
        write_indent(prefix_indent - 1)
      end

      write "}"
      next_token

      if node_of = node.of
        skip_space_or_newline
        check_keyword :of
        write " of "
        next_token_skip_space_or_newline
        no_indent { format_hash_entry node_of }
      end

      false
    end

    def format_hash_entry(entry)
      if entry.key.is_a?(SymbolLiteral) && @token.type == :IDENT
        write @token
        write ": "
        next_token
        check :":"
      else
        entry.key.accept self
        skip_space_or_newline
        check :"=>"
        write " => "
      end
      next_token_skip_space_or_newline
      no_indent entry.value
    end

    def visit(node : RangeLiteral)
      node.from.accept self
      skip_space_or_newline
      if node.exclusive
        check :"..."
        write "..."
      else
        check :".."
        write ".."
      end
      next_token_skip_space_or_newline
      node.to.accept self
      false
    end

    def visit(node : Path)
      prelude

      # Sometimes the :: is not present because the parser generates ::Nil, for example
      if node.global && @token.type == :"::"
        write "::"
        next_token_skip_space_or_newline
      end

      node.names.each_with_index do |name, i|
        skip_space_or_newline
        check :CONST
        write @token.value
        next_token
        skip_space unless last?(i, node.names)
        if @token.type == :"::"
          write "::"
          next_token
        end
      end

      false
    end

    def visit(node : Generic)
      prelude

      name = node.name
      first_name = name.global && name.names.size == 1 && name.names.first

      # Check if it's T* instead of Pointer(T)
      if first_name == "Pointer" && @token.value != "Pointer"
        node.type_vars.first.accept self
        skip_space_or_newline
        check :"*"
        write "*"
        next_token
        return false
      end

      # Check if it's T[N] instead of StaticArray(T, N)
      if first_name == "StaticArray" && @token.value != "StaticArray"
        node.type_vars[0].accept self
        skip_space_or_newline
        check :"["
        write "["
        next_token_skip_space_or_newline
        node.type_vars[1].accept self
        skip_space_or_newline
        check :"]"
        write "]"
        next_token
        return false
      end

      # Check if it's {A, B} instead of Tuple(A, B)
      if first_name == "Tuple" && @token.value != "Tuple"
        check :"{"
        write "{"
        next_token_skip_space_or_newline
        node.type_vars.each_with_index do |type_var, i|
          no_indent type_var
          skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, node.type_vars)
            next_token_skip_space_or_newline
          end
        end
        check :"}"
        write "}"
        next_token
        return false
      end

      name.accept self
      skip_space_or_newline

      check :"("
      write "("
      next_token_skip_space_or_newline

      node.type_vars.each_with_index do |type_var, i|
        no_indent type_var
        skip_space_or_newline
        if @token.type == :","
          write ", " unless last?(i, node.type_vars)
          next_token_skip_space_or_newline
        end
      end

      check :")"
      write ")"
      next_token

      false
    end

    def visit(node : Union)
      has_parenthesis = false
      if @token.type == :"("
        write "("
        next_token_skip_space_or_newline
        has_parenthesis = true
      end

      node.types.each_with_index do |type, i|
        no_indent type
        skip_space_or_newline

        # This can happen if it's a nilable type written like T?
        case @token.type
        when :"?"
          write "?"
          next_token
          break
        when :"|"
          write " | " unless last?(i, node.types)
          next_token_skip_space_or_newline
        when :")"
          # This can happen in a case like (A)?
          break
        end
      end

      if has_parenthesis
        check :")"
        write ")"
        next_token_skip_space
      end

      # This can happen in a case like (A)?
      if @token.type == :"?"
        write "?"
        next_token
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

      if !@token.keyword?(keyword) && node.else.is_a?(Nop)
        # Suffix if/unless
        no_indent node.then
        skip_space_or_newline
        check_keyword keyword
        write " "
        write keyword
        write " "
        next_token_skip_space_or_newline
        no_indent node.cond
        return false
      end

      # This is the case of `cond ? exp1 : exp2`
      if keyword == :if && !@token.keyword?(:if)
        no_indent node.cond
        skip_space_or_newline
        check :"?"
        write " ? "
        next_token_skip_space_or_newline
        no_indent node.then
        skip_space_or_newline
        check :":"
        write " : "
        next_token_skip_space_or_newline
        no_indent node.else
        return false
      end

      column = @column

      check_keyword keyword
      write prefix
      next_token_skip_space_or_newline

      format_if_at_cond node, column

      false
    end

    def format_if_at_cond(node, column, check_end = true)
      no_indent node.cond

      format_nested node.then, column

      skip_space_or_newline

      node_else = node.else

      if @token.keyword?(:else)
        write_indent(column)
        write "else"
        next_token_skip_space

        format_nested node.else, column
      elsif node_else.is_a?(If) && @token.keyword?(:elsif)
        write_indent(column)
        write "elsif "
        next_token_skip_space_or_newline
        format_if_at_cond node_else, column, check_end: false
      end

      if check_end
        skip_space_or_newline
        check_end()
        write_indent(column)
        write "end"
        next_token
      end
    end

    def visit(node : While)
      format_while_or_until node, :while
    end

    def visit(node : Until)
      format_while_or_until node, :until
    end

    def format_while_or_until(node, keyword)
      prelude

      column = @column

      check_keyword keyword
      write keyword
      write " "
      next_token_skip_space_or_newline
      no_indent node.cond

      format_nested node.body, column
      skip_space_or_newline

      check_end
      write_indent(column)
      write "end"
      next_token

      false
    end

    def format_nested(node, column)
      if node.is_a?(Nop)
        skip_nop(column + 2)
      else
        skip_space_write_line
        indent(column + 2, node)
        skip_space_write_line
      end
    end

    def visit(node : Def)
      if @visibility_indent
        @visibility_indent = nil
      else
        prelude
      end

      if node.abstract
        check_keyword :abstract
        write "abstract "
        next_token_skip_space_or_newline
      end

      check_keyword :def
      write "def "
      next_token_skip_space_or_newline

      if receiver = node.receiver
        no_indent receiver
        skip_space_or_newline
        check :"."
        write "."
        next_token_skip_space_or_newline
      end

      write node.name
      next_token_skip_space
      next_token_skip_space if @token.type == :"="

      to_skip = write_def_args node
      body = node.body

      if to_skip > 0
        body = node.body
        if body.is_a?(Expressions)
          body.expressions = body.expressions[to_skip .. -1]
          if body.expressions.empty?
            body = Nop.new
          end
        else
          body = Nop.new
        end
      end

      unless node.abstract
        if body.is_a?(Nop)
          write_line
        else
          write_line
          indent body
          skip_space_write_line
        end

        skip_space_or_newline
        check_end
        write_indent
        write "end"
        next_token
      end

      false
    end

    def write_def_args(node)
      to_skip = 0

      # If there are no args, remove extra "()", if any
      if node.args.empty?
        if @token.type == :"("
          next_token_skip_space_or_newline

          if block_arg = node.block_arg
            check :"&"
            write "(&"
            next_token_skip_space
            to_skip += 1 if at_skip?
            no_indent block_arg
            skip_space_or_newline
            write ")"
          end

          check :")"
          next_token_skip_space_or_newline
        elsif block_arg = node.block_arg
          skip_space_or_newline
          check :"&"
          write " &"
          next_token_skip_space
          to_skip += 1 if at_skip?
          no_indent block_arg
          skip_space
        end
      else
        prefix_size = @column + 1

        old_indent = @indent
        next_needs_indent = false
        has_parenthesis = false
        @indent = 0

        if @token.type == :"("
          has_parenthesis = true
          write "("
          next_token_skip_space
          if @token.type == :NEWLINE
            write_line
            next_needs_indent = true
          end
          skip_space_or_newline
        else
          write " "
        end

        node.args.each_with_index do |arg, i|
          @indent = prefix_size if next_needs_indent

          if i == node.splat_index
            check :"*"
            write "*"
            next_token_skip_space_or_newline
          end

          to_skip += 1 if at_skip?
          arg.accept self
          @indent = 0
          skip_space_or_newline
          if @token.type == :","
            write "," unless last?(i, node.args)
            next_token_skip_space
            if @token.type == :NEWLINE
              unless last?(i, node.args)
                write_line
                next_needs_indent = true
              end
            else
              next_needs_indent = false
              write " " unless last?(i, node.args)
            end
            skip_space_or_newline
          end
        end

        if block_arg = node.block_arg
          check :"&"
          write ", &"
          next_token_skip_space
          no_indent block_arg
          skip_space
        end

        if has_parenthesis
          check :")"
          write ")"
          next_token_skip_space_or_newline
        end

        @indent = old_indent
      end

      to_skip
    end

    # The parser transforms `def foo(@x); end` to `def foo(x); @x = x; end` so if we
    # find an instance var we later need to skip the first expressions in the body
    def at_skip?
      @token.type == :INSTANCE_VAR || @token.type == :CLASS_VAR
    end

    def visit(node : Arg)
      prelude

      write @token.value
      next_token

      if default_value = node.default_value
        skip_space_or_newline
        check :"="
        write " = "
        next_token_skip_space_or_newline
        no_indent default_value
      end

      if restriction = node.restriction
        skip_space_or_newline
        check :":"
        write " : "
        next_token_skip_space_or_newline
        no_indent restriction
      end

      false
    end

    def visit(node : Splat)
      prelude

      check :"*"
      write "*"
      next_token_skip_space_or_newline
      no_indent node.exp

      false
    end

    def visit(node : BlockArg)
      write @token.value
      next_token_skip_space

      if (restriction = node.fun) && @token.type == :":"
        skip_space_or_newline
        check :":"
        write " : "
        next_token_skip_space_or_newline
        no_indent restriction
      end

      false
    end

    def visit(node : Fun)
      has_parenthesis = false
      if @token.type == :"("
        write "("
        next_token_skip_space_or_newline
        has_parenthesis = true
      end

      if inputs = node.inputs
        inputs.each_with_index do |input, i|
          input.accept self
          skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, inputs)
            next_token_skip_space_or_newline
          end
        end
        write " "
      end

      check :"->"
      write "-> "
      next_token_skip_space_or_newline

      if output = node.output
        output.accept self
      end

      if has_parenthesis
        check :")"
        write ")"
        next_token
      end

      false
    end

    def visit(node : Var)
      prelude
      write node.name
      next_token
      false
    end

    def visit(node : InstanceVar)
      prelude
      write node.name
      next_token
      false
    end

    def visit(node : ClassVar)
      prelude
      write node.name
      next_token
      false
    end

    def visit(node : Global)
      prelude
      write node.name
      next_token
      false
    end

    def visit(node : ReadInstanceVar)
      node.obj.accept self

      skip_space_or_newline
      check :"."
      write "."
      next_token_skip_space_or_newline
      write node.name
      next_token

      false
    end

    def visit(node : Call)
      if @visibility_indent
        @visibility_indent = nil
      else
        prelude
      end

      base_column = @column

      if obj = node.obj
        if node.name == "!" && @token.type == :"!"
          write "!"
          next_token_skip_space_or_newline
          no_indent obj
          return false
        end

        if node.name == "-" && @token.type == :"-"
          write "-"
          next_token_skip_space_or_newline
          no_indent obj
          return false
        end

        no_indent obj
        skip_space

        if @token.type != :"."
          # It's an operator
          if @token.type == :"["
            write "["
            next_token_skip_space_or_newline

            args = node.args

            if node.name == "[]="
              last_arg = args.pop
            end

            args.each_with_index do |arg, i|
              no_indent arg
              skip_space_or_newline
              if @token.type == :","
                unless last?(i, args)
                  write ", "
                end
                next_token_skip_space_or_newline
              end
            end
            check :"]"
            write "]"
            next_token

            if node.name == "[]?"
              skip_space

              # This might not be present in the case of `x[y] ||= z`
              if @token.type == :"?"
                write "?"
                next_token
              end
            end

            if last_arg
              skip_space_or_newline

              if @token.type != :"="
                # This is the case of `x[y] op= value`
                write " "
                write @token.type
                write " "
                next_token_skip_space_or_newline
                no_indent (last_arg as Call).args.first
                return false
              end

              write " = "
              next_token_skip_space_or_newline
              no_indent last_arg
            end

            return false
          elsif @token.type == :"[]"
            write "[]"
            next_token

            if node.name == "[]="
              skip_space_or_newline
              check :"="
              write " = "
              next_token_skip_space_or_newline
              no_indent node.args.first
            end

            return false
          else
            write " "
            write node.name

            # This is the case of a-1 and a+1
            if @token.type == :NUMBER
              write " "
              write @token.raw[1..-1]
              next_token
              return false
            end
          end

          next_token
          found_comment = skip_space
          if found_comment || @token.type == :NEWLINE
            skip_space_write_line
            indent(base_column + 2, node.args.first)
          else
            write " "
            no_indent node.args.first
          end
          return false
        end

        write "."
        next_token_skip_space_or_newline
      end

      assignment = node.name.ends_with?('=') && node.name != "==" && node.name != "==="

      if assignment
        write node.name[0 ... -1]
      else
        write node.name
      end
      next_token

      if assignment
        skip_space
        check :"="
        write " = "
        next_token_skip_space_or_newline
        no_indent node.args.first
        return false
      end

      has_parenthesis = false
      has_args = !node.args.empty? || node.named_args

      if @token.type == :"("
        check :"("
        write "("
        next_token_skip_space_or_newline
        has_parenthesis = true
        format_call_args(node)
        skip_space_or_newline
      elsif has_args || node.block_arg
        write " "
        skip_space
        format_call_args(node)
      end

      if block = node.block
        needs_space = !has_parenthesis || has_args
        skip_space
        if has_parenthesis && @token.type == :")"
          write ")"
          next_token_skip_space_or_newline
          format_block block, base_column, needs_space
          return false
        end
        format_block block, base_column, needs_space
      end

      if has_parenthesis
        check :")"
        write ")"
        next_token
      end

      false
    end

    def format_call_args(node)
      format_args node.args, node.named_args, node.block_arg
    end

    def format_args(args, named_args = nil, block_arg = nil)
      args.each_with_index do |arg, i|
        no_indent arg
        if last?(i, args)
        else
          skip_space
          check :","
          write ", "
          next_token_skip_space_or_newline
        end
      end

      if named_args
        skip_space
        unless args.empty?
          check :","
          write ", "
          next_token_skip_space_or_newline
        end

        named_args.each_with_index do |named_arg, i|
          no_indent named_arg
          unless last?(i, named_args)
            skip_space_or_newline
            if @token.type == :","
              write ", "
              next_token_skip_space_or_newline
            end
          end
        end
      end

      if block_arg
        skip_space_or_newline
        if @token.type == :","
          write ", "
          next_token
        end
        skip_space_or_newline
        check :"&"
        write "&"
        next_token_skip_space_or_newline
        no_indent block_arg
      end
    end

    def visit(node : NamedArgument)
      write node.name
      next_token_skip_space_or_newline
      check :":"
      write ": "
      next_token_skip_space_or_newline
      no_indent node.value

      false
    end

    def format_block(node, base_column, needs_space)
      if @token.type == :","
        write ","
        next_token_skip_space_or_newline
      end

      if @token.keyword?(:do)
        write " do"
        next_token_skip_space_or_newline
        format_block_args node.args
        skip_space_or_newline
        write_line
        indent(base_column + 2, node.body)
        skip_space_or_newline
        write_line
        check_end
        write_indent(base_column)
        write "end"
        next_token
      elsif @token.type == :"{"
        check :"{"
        write " {"
        next_token_skip_space
        format_block_args node.args
        if @token.type == :NEWLINE
          write_line
          indent(base_column + 2, node.body)
          skip_space_or_newline
          write_line
          check :"}"
          write_indent(base_column)
          write "}"
        else
          unless node.body.is_a?(Nop)
            write " "
            no_indent node.body
          end
          skip_space_or_newline
          check :"}"
          write " }"
        end
        next_token
      else
        # It's foo &.bar
        check :"&"
        next_token_skip_space_or_newline
        check :"."
        next_token_skip_space_or_newline
        write " " if needs_space
        write "&."
        call = node.body as Call
        call.obj = nil
        no_indent call
      end
    end

    def format_block_args(args)
      return if args.empty?

      check :"|"
      write " |"
      next_token_skip_space_or_newline
      args.each_with_index do |arg, i|
        no_indent arg
        skip_space_or_newline
        if @token.type == :","
          next_token_skip_space_or_newline
          write ", " unless last?(i, args)
        end
      end
      skip_space_or_newline
      check :"|"
      write "|"
      next_token_skip_space
    end

    def visit(node : IsA)
      node.obj.accept self
      skip_space_or_newline
      check :"."
      write "."
      next_token_skip_space_or_newline
      check_keyword :is_a?
      write "is_a?"
      next_token_skip_space_or_newline
      check :"("
      write "("
      next_token_skip_space_or_newline
      no_indent node.const
      skip_space_or_newline
      check :")"
      write ")"
      next_token

      false
    end

    def visit(node : Or)
      format_binary node, :"||", :"||="
    end

    def visit(node : And)
      format_binary node, :"&&", :"&&="
    end

    def format_binary(node, token, alternative)
      node.left.accept self
      skip_space_or_newline

      # This is the case of `left ||= right`
      if @token.type == alternative
        write " "
        write alternative
        write " "
        next_token_skip_space
        case right = node.right
        when Assign
          no_indent right.value
        when Call
          no_indent right.args.first
        end
        return false
      end

      check token
      write " "
      write token
      write " "
      next_token_skip_space_or_newline

      no_indent node.right

      false
    end

    def visit(node : Assign)
      node.target.accept self
      skip_space_or_newline

      if @token.type == :"="
        check :"="
        write " ="
        next_token_skip_space
        if @token.type == :NEWLINE
          next_token_skip_space_or_newline
          write_line
          indent node.value
        else
          write " "
          no_indent node.value
        end
      else
        # This is the case of `target op= value`
        write " "
        write @token.type
        write " "
        next_token_skip_space_or_newline
        call = node.value as Call
        no_indent call.args.first
      end

      false
    end

    def visit(node : Require)
      prelude

      check_keyword :require
      write "require "
      next_token_skip_space_or_newline

      no_indent StringLiteral.new(node.string)

      false
    end

    def visit(node : VisibilityModifier)
      prelude

      check_keyword node.modifier
      write node.modifier
      write " "
      next_token_skip_space_or_newline

      @visibility_indent = @indent
      node.exp.accept self
      @visibility_indent = nil

      false
    end

    def visit(node : MagicConstant)
      check node.name
      write node.name
      next_token

      false
    end

    def visit(node : ModuleDef)
      prelude

      check_keyword :module
      write "module "
      next_token_skip_space_or_newline

      no_indent node.name
      format_type_vars node.type_vars

      format_nested node.body, @indent
      write_indent

      skip_space_or_newline
      check_end
      write "end"
      next_token

      false
    end

    def visit(node : ClassDef)
      prelude

      if node.abstract
        check_keyword :abstract
        write "abstract "
        next_token_skip_space_or_newline
      end

      if node.struct
        check_keyword :struct
        write "struct "
      else
        check_keyword :class
        write "class "
      end
      next_token_skip_space_or_newline

      no_indent node.name
      format_type_vars node.type_vars

      if superclass = node.superclass
        skip_space_or_newline
        check :"<"
        write " < "
        next_token_skip_space_or_newline
        no_indent superclass
      end

      format_nested node.body, @indent
      write_indent

      skip_space_or_newline
      check_end
      write "end"
      next_token

      false
    end

    def format_type_vars(type_vars)
      if type_vars
        skip_space
        check :"("
        write "("
        next_token_skip_space_or_newline
        type_vars.each_with_index do |type_var, i|
          write type_var
          next_token_skip_space_or_newline
          if @token.type == :","
            write ", " unless last?(i, type_vars)
            next_token_skip_space_or_newline
          end
        end
        check :")"
        write ")"
        next_token_skip_space
      end
    end

    def visit(node : Include)
      prelude

      check_keyword :include
      write "include "
      next_token_skip_space_or_newline

      no_indent node.name

      false
    end

    def visit(node : Extend)
      prelude

      check_keyword :extend
      write "extend "
      next_token_skip_space_or_newline

      no_indent node.name

      false
    end

    def visit(node : DeclareVar)
      node.var.accept self
      skip_space_or_newline
      check :"::"
      write " :: "
      next_token_skip_space_or_newline
      no_indent node.declared_type

      false
    end

    def visit(node : ASTNode)
      node.raise "missing handler for #{node.class}"
      true
    end

    def visit(node : Return)
      format_control_expression node, :return
    end

    def visit(node : Break)
      format_control_expression node, :break
    end

    def visit(node : Next)
      format_control_expression node, :next
    end

    def format_control_expression(node, keyword)
      prelude

      check_keyword keyword
      write keyword
      next_token

      has_parenthesis = false
      if @token.type == :"("
        has_parenthesis = true
        write "("
        next_token_skip_space_or_newline
      end

      if exp = node.exp
        write " " unless has_parenthesis

        if exp.is_a?(TupleLiteral) && @token.type != :"{"
          exp.elements.each_with_index do |elem, i|
            no_indent elem
            skip_space_or_newline
            if @token.type == :","
              write ", " unless last?(i, exp.elements)
              next_token_skip_space_or_newline
            end
          end
        else
          no_indent exp
          skip_space_or_newline
        end
      end

      if has_parenthesis
        check :")"
        write ")"
        next_token
      end

      false
    end

    def visit(node : Yield)
      prelude

      check_keyword :yield
      write "yield"
      next_token

      prefix_indent = @column + 1
      base_indent = prefix_indent
      next_needs_indent = false
      has_newlines = false

      has_parenthesis = false
      if @token.type == :"("
        has_parenthesis = true
        write "("
        next_token_skip_space
        if @token.type == :NEWLINE
          write_line
          next_needs_indent = true
          base_indent += 2
        end
      else
        write " " unless node.exps.empty?
      end

      node.exps.each_with_index do |exp, i|
        write_indent(base_indent) if next_needs_indent
        no_indent exp
        skip_space
        if @token.type == :","
          write "," unless last?(i, node.exps)
          next_token_skip_space
          if @token.type == :NEWLINE
            write_line
            next_needs_indent = true
            has_newlines = true
            next_token_skip_space_or_newline
          else
            write " " unless last?(i, node.exps)
          end
        end
      end

      if has_parenthesis
        if has_newlines
          write ","
          write_line
          write_indent(prefix_indent - 1)
        end
        check :")"
        write ")"
        next_token
      end

      false
    end

    def visit(node : Case)
      prelude

      prefix_indent = @column

      check_keyword :case
      write "case"
      next_token_skip_space_or_newline

      if cond = node.cond
        write " "
        no_indent cond
      end

      skip_space_write_line

      node.whens.each_with_index do |a_when, i|
        indent(prefix_indent) { format_when(a_when, last?(i, node.whens)) }
        skip_space_or_newline
      end

      skip_space_or_newline

      if a_else = node.else
        check_keyword :else
        write_indent(prefix_indent)
        write "else"
        write_line
        next_token_skip_space_or_newline
        indent(prefix_indent + 2, a_else)
        skip_space_or_newline
        write_line
      end

      check_end
      write_indent(prefix_indent)
      write "end"
      next_token

      false
    end

    def format_when(node, is_last)
      prelude

      prefix_indent = @column

      check_keyword :when
      write "when"
      next_token_skip_space
      write " "
      base_indent = @column
      next_needs_indent = false
      node.conds.each_with_index do |cond, i|
        write_indent(base_indent) if next_needs_indent
        no_indent cond
        next_needs_indent = false
        unless last?(i, node.conds)
          skip_space_or_newline
          if @token.type == :","
            write ","
            next_token
            skip_space
            if @token.type == :NEWLINE
              write_line
              next_needs_indent = true
            else
              write " "
            end
          end
        end
      end
      skip_space
      if @token.type == :";" || @token.keyword?(:then)
        separator = @token.to_s
        next_token_skip_space
        if @token.type == :NEWLINE
          next_token_skip_space_or_newline
          write_line
          indent node.body
          write_line if is_last
        else
          write " " if separator == "then"
          write separator
          write " "
          no_indent node.body
          write_line
        end
      else
        format_nested(node.body, prefix_indent)
      end

      false
    end

    def visit(node : Attribute)
      prelude

      check :"@["
      write "@["
      next_token_skip_space_or_newline

      write @token
      next_token_skip_space

      if @token.type == :"("
        has_args = !node.args.empty? || node.named_args
        if has_args
          write "("
        end
        next_token_skip_space
        format_args node.args, node.named_args
        skip_space_or_newline
        check :")"
        write ")" if has_args
        next_token_skip_space_or_newline
      end

      check :"]"
      write "]"
      next_token

      false
    end

    def visit(node : Cast)
      node.obj.accept self
      skip_space_or_newline
      check_keyword :as
      write " as "
      next_token_skip_space_or_newline
      no_indent node.to
      false
    end

    def visit(node : TypeOf)
      prelude

      check_keyword :typeof
      write "typeof"
      next_token_skip_space_or_newline
      check :"("
      write "("
      next_token_skip_space_or_newline
      format_args node.expressions, nil
      skip_space_or_newline
      check :")"
      write ")"
      next_token

      false
    end

    def visit(node : Underscore)
      prelude

      check :UNDERSCORE
      write "_"
      next_token

      false
    end

    def visit(node : MultiAssign)
      prelude

      node.targets.each_with_index do |target, i|
        no_indent { target.accept self }
        skip_space_or_newline
        if @token.type == :","
          write ", " unless last?(i, node.targets)
          next_token_skip_space_or_newline
        end
      end

      check :"="
      write " ="
      next_token_skip_space
      if @token.type == :NEWLINE && node.values.size == 1
        next_token_skip_space_or_newline
        write_line
        indent node.values.first
      else
        write " "
        no_indent { format_mutli_assign_values node.values }
      end

      false
    end

    def format_mutli_assign_values(values)
      values.each_with_index do |value, i|
        no_indent { value.accept self }
        unless last?(i, values)
          skip_space_or_newline
          if @token.type == :","
            write ", "
            next_token_skip_space_or_newline
          end
        end
      end
    end

    def visit(node : ExceptionHandler)
      prelude

      # This is the case of a suffix rescue
      unless @token.keyword?(:begin)
        no_indent node.body
        skip_space_or_newline
        check_keyword :rescue
        write " rescue "
        next_token_skip_space_or_newline
        no_indent node.rescues.not_nil!.first.body
        return false
      end

      column = @column

      check_keyword :begin
      write "begin"
      next_token
      format_nested(node.body, column)

      if node_rescues = node.rescues
        node_rescues.each_with_index do |node_rescue, i|
          skip_space_or_newline
          check_keyword :rescue
          write "rescue"
          next_token
          if name = node_rescue.name
            skip_space_or_newline
            write " "
            write name
            next_token
            if types = node_rescue.types
              skip_space_or_newline
              check :":"
              write " : "
              next_token_skip_space_or_newline
              types.each_with_index do |type, j|
                no_indent type
                unless last?(j, types)
                  skip_space_or_newline
                  if @token.type == :"|"
                    write " | "
                    next_token_skip_space_or_newline
                  end
                end
              end
            end
          end
          format_nested(node_rescue.body, column)
        end
      end

      if node_else = node.else
        skip_space_or_newline
        check_keyword :else
        write "else"
        next_token
        format_nested(node_else, column)
      end

      if node_ensure = node.ensure
        skip_space_or_newline
        check_keyword :ensure
        write "ensure"
        next_token
        format_nested(node_ensure, column)
      end

      skip_space_or_newline
      check_end
      write "end"
      next_token

      false
    end

    def to_s(io)
      io << @output
    end

    def next_token
      @token = @lexer.next_token
    end

    def next_string_token
      @token = @lexer.next_string_token(@token.delimiter_state)
    end

    def next_string_array_token
      @token = @lexer.next_string_array_token
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
      base_column = @column
      has_space = false
      while @token.type == :SPACE
        next_token
        has_space = true
      end
      if @token.type == :COMMENT
        needs_space = has_space && base_column != 0
        write " " if needs_space
        write_comment(needs_indent: !needs_space)
        true
      else
        false
      end
    end

    def skip_space_or_newline(last = false)
      base_column = @column
      has_space = false
      has_newline = false
      while true
        case @token.type
        when :SPACE
          has_space = true
          next_token
        when :NEWLINE
          has_newline = true
          next_token
        else
          break
        end
      end
      if @token.type == :COMMENT
        needs_space = has_space && !has_newline && base_column != 0
        if needs_space
          write " "
        elsif last && has_newline
          write_line
        end
        write_comment(needs_indent: !needs_space)
        true
      else
        false
      end
    end

    def skip_space_write_line
      found_comment = skip_space
      write_line unless found_comment || @wrote_nelwine
      found_comment
    end

    def skip_nop(indent)
      skip_space_write_line
      indent(indent) { skip_space_or_newline }
    end

    def skip_semicolon
      while @token.type == :";"
        next_token
      end
    end

    def write_comment(needs_indent = true)
      while @token.type == :COMMENT
        write_indent if needs_indent
        value = @token.value.to_s.strip
        char_1 = value[1]?
        if char_1 && !char_1.whitespace?
          value = "\# #{value[1 .. -1].strip}"
        end
        write value
        next_token_skip_space
        consume_newlines
        skip_space_or_newline
      end
    end

    def consume_newlines
      if @token.type == :NEWLINE
        write_line
        next_token

        if @token.type == :NEWLINE
          write_line
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

    def indent(node : ASTNode)
      indent { node.accept self }
    end

    def indent(indent : Int)
      old_indent = @indent
      @indent = indent
      yield
      @indent = old_indent
    end

    def indent(indent : Int, node : ASTNode)
      indent(indent) { node.accept self }
    end

    def no_indent(node : ASTNode)
      no_indent { node.accept self }
    end

    def no_indent
      old_indent = @indent
      @indent = 0
      yield
      @indent = old_indent
    end

    def write_indent
      write_indent @indent
    end

    def write_indent(indent)
      indent.times { write " " }
    end

    def write(string : String)
      @output << string
      @column += string.size
      @wrote_nelwine = false
    end

    def write(obj)
      write obj.to_s
    end

    def write_line
      @output.puts
      @column = 0
      @wrote_nelwine = true
    end

    def finish
      skip_space
      write_line if @token.type == :NEWLINE
      skip_space_or_newline
    end

    def check_keyword(*keywords)
      raise "expecting keyword #{keywords.join " or "}, not `#{@token.type}, #{@token.value}`, at #{@token.location}" unless keywords.any? { |k| @token.keyword?(k) }
    end

    def check(token_type)
      raise "expecting #{token_type}, not `#{@token.type}, #{@token.value}`, at #{@token.location}" unless @token.type == token_type
    end

    def check_end
      check_keyword :end
    end

    def last?(index, collection)
      index == collection.size - 1
    end
  end
end
