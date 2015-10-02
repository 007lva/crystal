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

  assert_format "1 ? 2 : 3"
  assert_format "1 ?\n  2    :   \n 3", "1 ? 2 : 3"

  assert_format "[] of Int32\n1"

  assert_format "(1)"
  assert_format "  (  1;  2;   3  )  ", "(1; 2; 3)"
  assert_format "begin; 1; end", "begin\n  1\nend"
  assert_format "begin\n1\n2\n3\nend", "begin\n  1\n  2\n  3\nend"
  assert_format "begin\n1 ? 2 : 3\nend", "begin\n  1 ? 2 : 3\nend"
end
