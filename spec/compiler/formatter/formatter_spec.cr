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
  assert_format "[\n1,\n2,\n3]", "[\n 1,\n 2,\n 3,\n]"
  assert_format "if 1\n[   1  ,    2  ,    3  ]\nend", "if 1\n  [1, 2, 3]\nend"
  assert_format "    [   1,   \n   2   ,   \n   3   ]   ", "[1,\n 2,\n 3,\n]"

  assert_format "Foo"
  assert_format "Foo:: Bar", "Foo::Bar"
  assert_format "Foo:: Bar", "Foo::Bar"
  assert_format "::Foo:: Bar", "::Foo::Bar"
  assert_format "Foo( A , 1 )", "Foo(A, 1)"

  %w(if unless).each do |keyword|
    assert_format "#{keyword} 1\n2\nend", "#{keyword} 1\n  2\nend"
    assert_format "#{keyword} 1\n2\nelse\nend", "#{keyword} 1\n  2\nelse\n\nend"
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
  assert_format "def   foo (  x  =   1 )  \n  end", "def foo(x = 1)\nend"
  assert_format "def   foo (  x  :  Int32 )  \n  end", "def foo(x : Int32)\nend"
  assert_format "def   foo (  x  =   1  :  Int32 )  \n  end", "def foo(x = 1 : Int32)\nend"
  assert_format "abstract  def   foo  \n  1", "abstract def foo\n1"
  assert_format "def foo( & block )\nend", "def foo(&block)\nend"
  assert_format "def foo  & block  \nend", "def foo &block\nend"
  assert_format "def foo( x , & block )\nend", "def foo(x, &block)\nend"
  assert_format "def foo( x , & block  : Int32 )\nend", "def foo(x, &block : Int32)\nend"
  assert_format "def foo( x , & block  : Int32 ->)\nend", "def foo(x, &block : Int32 -> )\nend"
  assert_format "def foo( x , & block  : Int32->Float64)\nend", "def foo(x, &block : Int32 -> Float64)\nend"
  assert_format "def foo( x , & block  :   ->)\nend", "def foo(x, &block : -> )\nend"

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
  assert_format "foo{|x| x}", "foo { |x| x }"
  assert_format "foo{|x|\n x}", "foo { |x|\n  x\n}"

  assert_format "foo . bar  =  1", "foo.bar = 1"

  assert_format "foo  x:  1", "foo x: 1"
  assert_format "foo  x:  1,  y:  2", "foo x: 1, y: 2"
  assert_format "foo a , b ,  x:  1", "foo a, b, x: 1"

  %w(return break next yield).each do |keyword|
    assert_format keyword
    assert_format "#{keyword}( 1 )", "#{keyword}(1)"
    assert_format "#{keyword}  1", "#{keyword} 1"
    assert_format "#{keyword}( 1 , 2 )", "#{keyword}(1, 2)"
    assert_format "#{keyword}  1 ,  2", "#{keyword} 1, 2"
  end

  assert_format "1   +   2", "1 + 2"
  assert_format "1   >   2", "1 > 2"
  assert_format "1   *   2", "1*2"
  assert_format "1 / 2", "1/2"
  assert_format "10/a", "10/a"

  assert_format "foo[]", "foo[]"
  assert_format "foo[ 1 , 2 ]", "foo[1, 2]"
  assert_format "foo[ 1,  2 ]?", "foo[1, 2]?"
  assert_format "foo[] =1", "foo[] = 1"
  assert_format "foo[ 1 , 2 ]   =3", "foo[1, 2] = 3"

  assert_format "1  ||  2", "1 || 2"
  assert_format "a  ||  b", "a || b"
  assert_format "1  &&  2", "1 && 2"

  assert_format "def foo\nend\ndef bar\nend"
  assert_format "def foo(x =  __FILE__ )\nend", "def foo(x = __FILE__)\nend"

  assert_format "a=1", "a = 1"

  assert_format "while 1\n2\nend", "while 1\n  2\nend"

  assert_format "a = begin\n1\n2\nend", "a = begin\n      1\n      2\n    end"
  assert_format "a = if 1\n2\n3\nend", "a = if 1\n      2\n      3\n    end"
  assert_format "a = if 1\n2\nelse\n3\nend", "a = if 1\n      2\n    else\n      3\n    end"
  assert_format "a = if 1\n2\nelsif 3\n4\nend", "a = if 1\n      2\n    elsif 3\n      4\n    end"

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
  assert_format "class Foo\n@x :: Int32\nend", "class Foo\n  @x :: Int32\nend"

  assert_format "x = 1\nx    +=   1", "x = 1\nx += 1"
  assert_format "x[ y ] += 1", "x[y] += 1"
  assert_format "class Foo\nx = 1\nend", "class Foo\n  x = 1\nend"
end
