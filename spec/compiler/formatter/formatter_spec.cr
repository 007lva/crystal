require "../../spec_helper"

private def assert_format(input, output = input, file = __FILE__, line = __LINE__)
  it "formats #{input.inspect}", file, line do
    Crystal::Formatter.format(input).should eq(output)
  end
end

describe Crystal::Formatter do
  assert_format "nil"

  assert_format "true"
  assert_format "false"

  assert_format "'\\n'"
  assert_format "'a'"
  assert_format "'\\u{0123}'"

  assert_format ":foo"
  assert_format ":\"foo\""

  assert_format "1"
  assert_format "1   ;    2", "1; 2"
  assert_format "1   ;\n    2", "1\n2"
  assert_format "1\n\n2", "1\n\n2"
  assert_format "1\n\n\n2", "1\n\n2"
  assert_format "1_234", "1_234"
  assert_format "0x1234_u32", "0x1234_u32"
  assert_format "0_u64", "0_u64"

  assert_format "   1", "1"
  assert_format "\n\n1", "1"
  assert_format "\n# hello\n1", "# hello\n1"
  assert_format "\n# hello\n\n1", "# hello\n\n1"
  assert_format "\n# hello\n\n\n1", "# hello\n\n1"
  assert_format "\n   # hello\n\n1", "# hello\n\n1"

  assert_format %("hello")
  assert_format %(%(hello))
  assert_format %(%<hello>)
  assert_format %(%[hello])
  assert_format %(%{hello})
  assert_format %("hel\\nlo")
  assert_format %("hel\nlo")

  assert_format "[] of Foo"
  assert_format "[\n]   of   \n   Foo  ", "[] of Foo"
  assert_format "[1, 2, 3]"
  assert_format "[1, 2, 3] of Foo"
  assert_format "  [   1  ,    2  ,    3  ]  ", "[1, 2, 3]"
  assert_format "[1, 2, 3,  ]", "[1, 2, 3]"
  assert_format "[1,\n2,\n3]", "[1,\n 2,\n 3,\n]"
  assert_format "[\n1,\n2,\n3]", "[\n  1,\n  2,\n  3,\n]"
  assert_format "if 1\n[   1  ,    2  ,    3  ]\nend", "if 1\n  [1, 2, 3]\nend"
  assert_format "    [   1,   \n   2   ,   \n   3   ]   ", "[1,\n 2,\n 3,\n]"

  assert_format "{1, 2, 3}"

  assert_format "{  } of  A   =>   B", "{} of A => B"
  assert_format "{ 1   =>   2 }", "{1 => 2}"
  assert_format "{ 1   =>   2 ,   3  =>  4 }", "{1 => 2, 3 => 4}"
  assert_format "{ 1   =>   2 ,\n   3  =>  4 }", "{1 => 2,\n 3 => 4,\n}"
  assert_format "{\n1   =>   2 ,\n   3  =>  4 }", "{\n  1 => 2,\n  3 => 4,\n}"
  assert_format "{ foo:  1 }", "{foo: 1}"

  assert_format "Foo"
  assert_format "Foo:: Bar", "Foo::Bar"
  assert_format "Foo:: Bar", "Foo::Bar"
  assert_format "::Foo:: Bar", "::Foo::Bar"
  assert_format "Foo( A , 1 )", "Foo(A, 1)"

  %w(if unless).each do |keyword|
    assert_format "#{keyword} 1\n2\nend", "#{keyword} 1\n  2\nend"
    assert_format "#{keyword} 1\n2\nelse\nend", "#{keyword} 1\n  2\nelse\nend"
    assert_format "#{keyword} 1\nelse\n2\nend", "#{keyword} 1\nelse\n  2\nend"
    assert_format "#{keyword} 1\n2\nelse\n3\nend", "#{keyword} 1\n  2\nelse\n  3\nend"
    assert_format "#{keyword} 1\n2\n3\nelse\n4\n5\nend", "#{keyword} 1\n  2\n  3\nelse\n  4\n  5\nend"
    assert_format "#{keyword} 1\n#{keyword} 2\n3\nelse\n4\nend\nend", "#{keyword} 1\n  #{keyword} 2\n    3\n  else\n    4\n  end\nend"
    assert_format "#{keyword} 1\n#{keyword} 2\nelse\n4\nend\nend", "#{keyword} 1\n  #{keyword} 2\n  else\n    4\n  end\nend"
    assert_format "#{keyword} 1\n    # hello\n 2\nend", "#{keyword} 1\n  # hello\n  2\nend"
    assert_format "#{keyword} 1\n2; 3\nelse\n3\nend", "#{keyword} 1\n  2; 3\nelse\n  3\nend"
  end

  assert_format "if 1\n2\nelsif\n3\n4\nend", "if 1\n  2\nelsif 3\n  4\nend"
  assert_format "if 1\n2\nelsif\n3\n4\nelsif 5\n6\nend", "if 1\n  2\nelsif 3\n  4\nelsif 5\n  6\nend"
  assert_format "if 1\n2\nelsif\n3\n4\nelse\n6\nend", "if 1\n  2\nelsif 3\n  4\nelse\n  6\nend"

  assert_format "if 1\n2\nend\nif 3\nend", "if 1\n  2\nend\nif 3\nend"
  assert_format "if 1\nelse\n2\nend\n3", "if 1\nelse\n  2\nend\n3"

  assert_format "1 ? 2 : 3"
  assert_format "1 ?\n  2    :   \n 3", "1 ? 2 : 3"

  assert_format "1   if   2", "1 if 2"
  assert_format "1   unless   2", "1 unless 2"

  assert_format "[] of Int32\n1"

  assert_format "(1)"
  assert_format "  (  1;  2;   3  )  ", "(1; 2; 3)"
  assert_format "begin; 1; end", "begin\n  1\nend"
  assert_format "begin\n1\n2\n3\nend", "begin\n  1\n  2\n  3\nend"
  assert_format "begin\n1 ? 2 : 3\nend", "begin\n  1 ? 2 : 3\nend"

  assert_format "def   foo  \n  end", "def foo\nend"
  assert_format "def foo\n1\nend", "def foo\n  1\nend"
  assert_format "def foo\n\n1\n\nend", "def foo\n  1\nend"
  assert_format "def foo()\n1\nend", "def foo\n  1\nend"
  assert_format "def foo   (   )   \n1\nend", "def foo\n  1\nend"
  assert_format "def self . foo\nend", "def self.foo\nend"
  assert_format "def   foo (  x )  \n  end", "def foo(x)\nend"
  assert_format "def   foo   x  \n  end", "def foo x\nend"
  assert_format "def   foo (  x , y )  \n  end", "def foo(x, y)\nend"
  assert_format "def   foo (  x , y , )  \n  end", "def foo(x, y)\nend"
  assert_format "def   foo (  x , y ,\n)  \n  end", "def foo(x, y)\nend"
  assert_format "def   foo (  x ,\n y )  \n  end", "def foo(x,\n        y)\nend"
  assert_format "def   foo (\nx ,\n y )  \n  end", "def foo(\n        x,\n        y)\nend"
  assert_format "def   foo (  @x)  \n  end", "def foo(@x)\nend"
  assert_format "def   foo (  @x, @y)  \n  end", "def foo(@x, @y)\nend"
  assert_format "def   foo (  @@x)  \n  end", "def foo(@@x)\nend"
  assert_format "def   foo (  &@block)  \n  end", "def foo(&@block)\nend"
  assert_format "def   foo (  x  =   1 )  \n  end", "def foo(x = 1)\nend"
  assert_format "def   foo (  x  :  Int32 )  \n  end", "def foo(x : Int32)\nend"
  assert_format "def   foo (  x  =   1  :  Int32 )  \n  end", "def foo(x = 1 : Int32)\nend"
  assert_format "abstract  def   foo  \n  1", "abstract def foo\n\n1"
  assert_format "def foo( & block )\nend", "def foo(&block)\nend"
  assert_format "def foo  & block  \nend", "def foo &block\nend"
  assert_format "def foo( x , & block )\nend", "def foo(x, &block)\nend"
  assert_format "def foo( x , & block  : Int32 )\nend", "def foo(x, &block : Int32)\nend"
  assert_format "def foo( x , & block  : Int32 ->)\nend", "def foo(x, &block : Int32 -> )\nend"
  assert_format "def foo( x , & block  : Int32->Float64)\nend", "def foo(x, &block : Int32 -> Float64)\nend"
  assert_format "def foo( x , & block  :   ->)\nend", "def foo(x, &block : -> )\nend"
  assert_format "def foo( x , * y )\nend", "def foo(x, *y)\nend"
  assert_format "class Bar\nprotected def foo(x)\na=b(c)\nend\nend", "class Bar\n  protected def foo(x)\n    a = b(c)\n  end\nend"
  assert_format "def foo=(x)\nend"
  assert_format "def +(x)\nend"

  assert_format "foo"
  assert_format "foo()"
  assert_format "foo(  )", "foo()"
  assert_format "foo  1", "foo 1"
  assert_format "foo  1  ,   2", "foo 1, 2"
  assert_format "foo(  1  ,   2 )", "foo(1, 2)"

  assert_format "foo . bar", "foo.bar"
  assert_format "foo . bar( x , y )", "foo.bar(x, y)"
  assert_format "foo do  \n x \n end", "foo do\n  x\nend"
  assert_format "foo do  | x | \n x \n end", "foo do |x|\n  x\nend"
  assert_format "foo do  | x , y | \n x \n end", "foo do |x, y|\n  x\nend"
  assert_format "if 1\nfoo do  | x , y | \n x \n end\nend", "if 1\n  foo do |x, y|\n    x\n  end\nend"
  assert_format "foo{}", "foo { }"
  assert_format "foo{|x| x}", "foo { |x| x }"
  assert_format "foo{|x|\n x}", "foo { |x|\n  x\n}"
  assert_format "foo   &.bar", "foo &.bar"
  assert_format "foo   &.bar( 1 , 2 )", "foo &.bar(1, 2)"
  assert_format "foo.bar  &.baz( 1 , 2 )", "foo.bar &.baz(1, 2)"
  assert_format "foo   &.bar", "foo &.bar"
  assert_format "foo   &.==(2)", "foo &.==(2)"
  assert_format "join io, &.inspect"
  assert_format "foo . bar  =  1", "foo.bar = 1"
  assert_format "foo  x:  1", "foo x: 1"
  assert_format "foo  x:  1,  y:  2", "foo x: 1, y: 2"
  assert_format "foo a , b ,  x:  1", "foo a, b, x: 1"
  assert_format "foo a , *b", "foo a, *b"
  assert_format "foo   &bar", "foo &bar"
  assert_format "foo 1 ,  &bar", "foo 1, &bar"
  assert_format "foo(&.bar)"
  assert_format "foo(1, &.bar)"

  %w(return break next yield).each do |keyword|
    assert_format keyword
    assert_format "#{keyword}( 1 )", "#{keyword}(1)"
    assert_format "#{keyword}  1", "#{keyword} 1"
    assert_format "#{keyword}( 1 , 2 )", "#{keyword}(1, 2)"
    assert_format "#{keyword}  1 ,  2", "#{keyword} 1, 2"
  end

  assert_format "yield 1\n2", "yield 1\n2"
  assert_format "yield 1 , \n2", "yield 1,\n      2"
  assert_format "yield 1 , \n2", "yield 1,\n      2"
  assert_format "yield(1 , \n2)", "yield(1,\n      2,\n     )"
  assert_format "yield(\n1 , \n2)", "yield(\n        1,\n        2,\n     )"

  assert_format "1   +   2", "1 + 2"
  assert_format "1   >   2", "1 > 2"
  assert_format "1   *   2", "1 * 2"
  assert_format "1/2", "1 / 2"
  assert_format "10/a", "10 / a"
  assert_format "! 1", "!1"
  assert_format "- 1", "-1"
  assert_format "a-1", "a - 1"
  assert_format "a+1", "a + 1"
  assert_format "1 + \n2", "1 +\n  2"
  assert_format "1 +  # foo\n2", "1 + # foo\n  2"
  assert_format "a = 1 +  # foo\n2", "a = 1 + # foo\n      2"

  assert_format "foo[]", "foo[]"
  assert_format "foo[ 1 , 2 ]", "foo[1, 2]"
  assert_format "foo[ 1,  2 ]?", "foo[1, 2]?"
  assert_format "foo[] =1", "foo[] = 1"
  assert_format "foo[ 1 , 2 ]   =3", "foo[1, 2] = 3"

  assert_format "1  ||  2", "1 || 2"
  assert_format "a  ||  b", "a || b"
  assert_format "1  &&  2", "1 && 2"

  assert_format "def foo(x =  __FILE__ )\nend", "def foo(x = __FILE__)\nend"

  assert_format "a=1", "a = 1"

  assert_format "while 1\n2\nend", "while 1\n  2\nend"
  assert_format "until 1\n2\nend", "until 1\n  2\nend"

  assert_format "a = begin\n1\n2\nend", "a = begin\n      1\n      2\n    end"
  assert_format "a = if 1\n2\n3\nend", "a = if 1\n      2\n      3\n    end"
  assert_format "a = if 1\n2\nelse\n3\nend", "a = if 1\n      2\n    else\n      3\n    end"
  assert_format "a = if 1\n2\nelsif 3\n4\nend", "a = if 1\n      2\n    elsif 3\n      4\n    end"
  assert_format "a = [\n1,\n2]", "a = [\n      1,\n      2,\n    ]"
  assert_format "a = while 1\n2\nend", "a = while 1\n      2\n    end"
  assert_format "a = case 1\nwhen 2\n3\nend", "a = case 1\n    when 2\n      3\n    end"
  assert_format "a = case 1\nwhen 2\n3\nelse\n4\nend", "a = case 1\n    when 2\n      3\n    else\n      4\n    end"
  assert_format "a = \nif 1\n2\nend", "a =\n  if 1\n    2\n  end"
  assert_format "a, b = \nif 1\n2\nend", "a, b =\n  if 1\n    2\n  end"

  assert_format %(require   "foo"), %(require "foo")

  assert_format "private   getter   foo", "private getter foo"

  assert_format %("foo \#{ 1  +  2 }"), %("foo \#{1 + 2}")

  assert_format "%w(one   two  three)", "%w(one two three)"

  assert_format "module   Moo \n\n 1  \n\nend", "module Moo\n  1\nend"
  assert_format "class   Foo \n\n 1  \n\nend", "class Foo\n  1\nend"
  assert_format "struct   Foo \n\n 1  \n\nend", "struct Foo\n  1\nend"
  assert_format "class   Foo  < \n  Bar \n\n 1  \n\nend", "class Foo < Bar\n  1\nend"
  assert_format "module Moo ( T )\nend", "module Moo(T)\nend"
  assert_format "class Foo ( T )\nend", "class Foo(T)\nend"
  assert_format "abstract  class Foo\nend", "abstract class Foo\nend"

  assert_format "@a", "@a"
  assert_format "@@a", "@@a"
  assert_format "$a", "$a"

  assert_format "foo . is_a? ( Bar )", "foo.is_a?(Bar)"

  assert_format "include  Foo", "include Foo"
  assert_format "extend  Foo", "extend Foo"

  assert_format "x  ::  Int32", "x :: Int32"
  assert_format "x  ::  Int32*", "x :: Int32*"
  assert_format "x  ::  A  |  B", "x :: A | B"
  assert_format "x  ::  A?", "x :: A?"
  assert_format "x  ::  Int32[ 8 ]", "x :: Int32[8]"
  assert_format "x  ::  (A | B)", "x :: (A | B)"
  assert_format "x  ::  (A -> B)", "x :: (A -> B)"
  assert_format "x  ::  (A -> B)?", "x :: (A -> B)?"
  assert_format "x  ::  {A, B}", "x :: {A, B}"
  assert_format "class Foo\n@x :: Int32\nend", "class Foo\n  @x :: Int32\nend"
  assert_format "class Foo\nx = 1\nend", "class Foo\n  x = 1\nend"

  assert_format "x = 1\nx    +=   1", "x = 1\nx += 1"
  assert_format "x[ y ] += 1", "x[y] += 1"
  assert_format "@x   ||=   1", "@x ||= 1"
  assert_format "@x   &&=   1", "@x &&= 1"
  assert_format "@x[ 1 ]   ||=   2", "@x[1] ||= 2"
  assert_format "@x[ 1 ]   &&=   2", "@x[1] &&= 2"

  assert_format "case  1 \n when 2 \n 3 \n end", "case 1\nwhen 2\n  3\nend"
  assert_format "case  1 \n when 2 \n 3 \n else \n 4 \n end", "case 1\nwhen 2\n  3\nelse\n  4\nend"
  assert_format "case  1 \n when 2 , 3 \n 4 \n end", "case 1\nwhen 2, 3\n  4\nend"
  assert_format "case  1 \n when 2 ,\n 3 \n 4 \n end", "case 1\nwhen 2,\n     3\n  4\nend"
  assert_format "case  1 \n when 2 ; 3 \n end", "case 1\nwhen 2; 3\nend"
  assert_format "case  1 \n when 2 ;\n 3 \n end", "case 1\nwhen 2\n  3\nend"
  assert_format "case  1 \n when 2 ; 3 \n when 4 ; 5\nend", "case 1\nwhen 2; 3\nwhen 4; 5\nend"
  assert_format "case  1 \n when 2 then 3 \n end", "case 1\nwhen 2 then 3\nend"
  assert_format "case  1 \n when 2 then \n 3 \n end", "case 1\nwhen 2\n  3\nend"
  assert_format "case  1 \n when 2 \n 3 \n when 4 \n 5 \n end", "case 1\nwhen 2\n  3\nwhen 4\n  5\nend"
  assert_format "if 1\ncase 1\nwhen 2\n3\nend\nend", "if 1\n  case 1\n  when 2\n    3\n  end\nend"

  assert_format "foo.@bar"

  assert_format "@[Foo]"
  assert_format "@[Foo()]", "@[Foo]"
  assert_format "@[Foo( 1, 2 )]", "@[Foo(1, 2)]"
  assert_format "@[Foo( 1, 2, foo: 3 )]", "@[Foo(1, 2, foo: 3)]"
  assert_format "@[Foo]\ndef foo\nend"

  assert_format "1   as   Int32", "1 as Int32"
  assert_format "foo.bar  as   Int32", "foo.bar as Int32"

  assert_format "1 .. 2", "1..2"
  assert_format "1 ... 2", "1...2"

  assert_format "typeof( 1, 2, 3 )", "typeof(1, 2, 3)"

  assert_format "_ = 1"

  assert_format "a , b  = 1  ,  2", "a, b = 1, 2"
  assert_format "a[1] , b[2] = 1  ,  2", "a[1], b[2] = 1, 2"

  assert_format "begin\n1\nensure\n2\nend", "begin\n  1\nensure\n  2\nend"
  assert_format "begin\n1\nrescue\n3\nensure\n2\nend", "begin\n  1\nrescue\n  3\nensure\n  2\nend"
  assert_format "begin\n1\nrescue   ex\n3\nend", "begin\n  1\nrescue ex\n  3\nend"
  assert_format "begin\n1\nrescue   ex   :   Int32 \n3\nend", "begin\n  1\nrescue ex : Int32\n  3\nend"
  assert_format "begin\n1\nrescue   ex   :   Int32  |  Float64  \n3\nend", "begin\n  1\nrescue ex : Int32 | Float64\n  3\nend"
  assert_format "begin\n1\nrescue   ex\n3\nelse\n4\nend", "begin\n  1\nrescue ex\n  3\nelse\n  4\nend"
  assert_format "1 rescue 2"

  assert_format "def foo\na = bar do\n1\nend\nend", "def foo\n  a = bar do\n        1\n      end\nend"
  assert_format "def foo\nend\ndef bar\nend", "def foo\nend\n\ndef bar\nend"
  assert_format "a = 1\ndef bar\nend", "a = 1\n\ndef bar\nend"
  assert_format "def foo\nend\n\n\n\ndef bar\nend", "def foo\nend\n\ndef bar\nend"
  assert_format "def foo\nend;def bar\nend", "def foo\nend\n\ndef bar\nend"
  assert_format "class Foo\nend\nclass Bar\nend", "class Foo\nend\n\nclass Bar\nend"

  assert_format "1   # foo", "1 # foo"
  assert_format "1  # foo\n2  # bar", "1 # foo\n2 # bar"
  assert_format "1  #foo  \n2  #bar", "1 # foo\n2 # bar"
  assert_format "if 1\n2  # foo\nend", "if 1\n  2 # foo\nend"
  assert_format "if 1\nelse\n2  # foo\nend", "if 1\nelse\n  2 # foo\nend"
  assert_format "if # some comment\n 2 # another\n 3 # final \n end # end ", "if  # some comment\n2 # another\n  3 # final\nend # end"
  assert_format "while 1\n2  # foo\nend", "while 1\n  2 # foo\nend"
  assert_format "def foo\n2  # foo\nend", "def foo\n  2 # foo\nend"
  assert_format "if 1\n# nothing\nend", "if 1\n  # nothing\nend"
  assert_format "if 1\nelse\n# nothing\nend", "if 1\nelse\n  # nothing\nend"
  assert_format "if 1 # foo\n2\nend", "if 1 # foo\n  2\nend"
  assert_format "if 1  # foo\nend", "if 1 # foo\nend"
  assert_format "while 1  # foo\nend", "while 1 # foo\nend"
  assert_format "while 1\n# nothing\nend", "while 1\n  # nothing\nend"
  assert_format "class Foo  # foo\nend", "class Foo # foo\nend"
  assert_format "class Foo\n# nothing\nend", "class Foo\n  # nothing\nend"
  assert_format "module Foo  # foo\nend", "module Foo # foo\nend"
  assert_format "module Foo\n# nothing\nend", "module Foo\n  # nothing\nend"
  assert_format "case 1 # foo\nwhen 2\nend", "case 1 # foo\nwhen 2\nend"
  assert_format "def foo\n# hello\n1\nend", "def foo\n  # hello\n  1\nend"
  assert_format "struct Foo(T)\n# bar\n1\nend", "struct Foo(T)\n  # bar\n  1\nend"
  assert_format "struct Foo\n  # bar\n  # baz\n1\nend", "struct Foo\n  # bar\n  # baz\n  1\nend"
  assert_format "(size - 1).downto(0) do |i|\n  yield @buffer[i]\nend"
  assert_format "(a).b { }\nc"
  assert_format "begin\n  a\nend.b { }\nc"
  assert_format "if a\n  b &c\nend"
  assert_format "foo (1).bar"
  assert_format "foo a: 1\nb"
  assert_format "if 1\n2 && 3\nend", "if 1\n  2 && 3\nend"
  assert_format "if 1\n  node.is_a?(T)\nend"
  assert_format "case 1\nwhen 2\n#comment\nend", "case 1\nwhen 2\n  # comment\nend"
  assert_format "case 1\nwhen 2\n\n#comment\nend", "case 1\nwhen 2\n  # comment\nend"
  assert_format "1 if 2\n# foo"
  assert_format "1 if 2\n# foo\n3"
  assert_format "1\n2\n# foo"
  assert_format "1\n2  \n  # foo", "1\n2\n# foo"
  assert_format "if 1\n2\n3\n# foo\nend", "if 1\n  2\n  3\n  # foo\nend"
  assert_format "def foo\n1\n2\n# foo\nend", "def foo\n  1\n  2\n  # foo\nend"
  assert_format "if 1\nif 2\n3 # foo\nend\nend", "if 1\n  if 2\n    3 # foo\n  end\nend"
end
