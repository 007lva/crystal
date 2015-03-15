require "./type"

@[Link("xml2")]
lib LibXML
  type InputBuffer = Void*
  type XMLTextReader = Void*
  type XMLTextReaderLocator = Void*

  XML_READER_TYPE_NONE                   = 0
  XML_READER_TYPE_ELEMENT                = 1
  XML_READER_TYPE_ATTRIBUTE              = 2
  XML_READER_TYPE_TEXT                   = 3
  XML_READER_TYPE_CDATA                  = 4
  XML_READER_TYPE_ENTITY_REFERENCE       = 5
  XML_READER_TYPE_ENTITY                 = 6
  XML_READER_TYPE_PROCESSING_INSTRUCTION = 7
  XML_READER_TYPE_COMMENT                = 8
  XML_READER_TYPE_DOCUMENT               = 9
  XML_READER_TYPE_DOCUMENT_TYPE          = 10
  XML_READER_TYPE_DOCUMENT_FRAGMENT      = 11
  XML_READER_TYPE_NOTATION               = 12
  XML_READER_TYPE_WHITESPACE             = 13
  XML_READER_TYPE_SIGNIFICANT_WHITESPACE = 14
  XML_READER_TYPE_END_ELEMENT            = 15
  XML_READER_TYPE_END_ENTITY             = 16
  XML_READER_TYPE_XML_DECLARATION        = 17

  enum ParserSeverity
    VALIDITY_WARNING = 1
    VALIDITY_ERROR = 2
    WARNING = 3
    ERROR = 4
  end

  alias TextReaderErrorFunc = (Void*, UInt8*, ParserSeverity, XMLTextReaderLocator) ->

  fun xmlParserInputBufferCreateStatic(mem : UInt8*, size : Int32, encoding : Int32) : InputBuffer
  fun xmlParserInputBufferCreateIO(ioread : (Void*, UInt8*, Int32) -> Int32, ioclose : Void* -> Int32, ioctx : Void*, enc : Int32) : InputBuffer
  fun xmlNewTextReader(input : InputBuffer, uri : UInt8*) : XMLTextReader

  fun xmlTextReaderRead(reader : XMLTextReader) : Int32
  fun xmlTextReaderNodeType(reader : XMLTextReader) : XML::Type
  fun xmlTextReaderConstName(reader : XMLTextReader) : UInt8*
  fun xmlTextReaderIsEmptyElement(reader : XMLTextReader) : Int32
  fun xmlTextReaderConstValue(reader : XMLTextReader) : UInt8*
  fun xmlTextReaderHasAttributes(reader : XMLTextReader) : Int32
  fun xmlTextReaderAttributeCount(reader : XMLTextReader) : Int32
  fun xmlTextReaderMoveToFirstAttribute(reader : XMLTextReader) : Int32
  fun xmlTextReaderMoveToNextAttribute(reader : XMLTextReader) : Int32

  fun xmlTextReaderSetErrorHandler(reader : XMLTextReader, f : TextReaderErrorFunc) : Void

  fun xmlTextReaderLocatorLineNumber(XMLTextReaderLocator) : Int32
end
