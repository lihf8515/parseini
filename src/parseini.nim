#
#
#            Nim's Runtime Library
#        (c) Copyright 2010 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## The ``parseini`` module implements a high performance configuration file
## parser, evolved from ``parsecfg``.
## The configuration file's syntax is similar to the Windows ``.ini``
## format, but much more powerful, as it is not a line based parser. String
## literals, raw string literals and triple quoted string literals are 
## supported as in the Nim programming language.
## The module supports annotation statements, does not delete comment
## statements and redundant blank characters, leaving the original style
## and you can specify annotation delimiters.
##

## Examples
## --------
##
## This is a simple example of a configuration file.
##
## ::
##
##     charset="utf-8"
##     [Package]
##     name="hello"
##     --threads:"on"
##     [Author]
##     name="lihf8515"
##     qq="10214028"
##     email="lihaifeng@wxm.com"
##
    
## Specify annotation symbols, default annotation symbols are "#" and ";".
## The following example replaces the annotation symbol with "&".
## --------
## 
## .. code-block:: nim
##
##  import parseini
##  var cfg=loadConfig("config.ini","&")
    
## Support for read-write multivalued key.
## --------
## 
## ::
## 
## [Author]
## name="lihf8515"
## name = Li haifeng
##
## .. code-block:: nim
##
## import parseini
## var cfg=loadConfig("config.ini")
## cfg.add("Author","name","lhf")
## echo cfg.gets("Author","name")
    
## Create a configuration file.
## --------
## 
## .. code-block:: nim
##
## import parseini
## var cfg=newConfig()
## cfg.set("","charset","utf-8")
## cfg.set("Package","name","hello")
## cfg.set("Package","--threads","on")
## cfg.set("Author","name","lihf8515")
## cfg.set("Author","qq","10214028")
## cfg.set("Author","email","lihaifeng@wxm.com")
## cfg.write("config.ini")
## echo cfg

## Read the configuration file.
## If the specified key does not exist, return an empty string.
## Support custom default return values.
## --------
## 
## .. code-block:: nim
## 
## import parseini
## var cfg = loadConfig("config.ini")
## var charset = cfg.get("","charset")
## var threads = cfg.get("Package","--threads")
## var pname = cfg.get("Package","name")
## var name = cfg.get("Author","name")
## var qq = cfg.get("Author","qq")
## var email = cfg.get("Author","email","10214028@qq.com")
## echo pname & "\n" & name & "\n" & qq & "\n" & email

## Modify the configuration file. Support whether key values use quotation marks.
## When the last parameter is false, it indicates that the key value does not need to be wrapped in double quotes during actual storage.
## --------
## 
## .. code-block:: nim
## 
## import parseini
## var cfg = loadConfig("config.ini")
## cfg.set("Author","name","lhf")
## cfg.set("Author","qq","10214028",false)
## cfg.write("config.ini")
## echo cfg

## Delete key value pairs from the configuration file. 
## Also supports deleting "Section".
## --------
## 
## .. code-block:: nim
## 
## import parseini
## var cfg = loadConfig("config.ini")
## cfg.del("Author","email")
## cfg.del("Author")
## cfg.write("config.ini")
## echo cfg

import
  strutils, lexbase, streams, tables

include "system/inclrtl"

type
  CfgEventKind* = enum # enumeration of all events that may occur when parsing
    cfgEof,            # end of file reached
    cfgSectionStart,   # a ``[section]`` has been parsed
    cfgKeyValuePair,   # a ``key=value`` pair has been detected
    cfgOption,         # a ``--key=value`` command line option
    cfgError           # an error occurred during parsing

  CfgEvent* = object of RootObj  # describes a parsing event
    kind*: CfgEventKind          # the kind of the event
    section*: string             # `section` contains the name of the
    sectionVal*: SectionPair     # parsed section start (syntax: ``[section]``)
                                 # 'sectionVal' is the other part of `section`
    key*: string                 # contains the (key, value) pair if an option.
    keyVal*: KeyValPair          # of the form ``--key: value`` or an ordinary
                                 # ``key= value`` pair has been parsed.
                                 # ``value==""`` if it was not specified in the
                                 # configuration file.
                                 
    msg*: string                 # the parser encountered an error: `msg`
                                 # contains the error message. No exceptions
                                 # are thrown if a parse error occurs.

  SectionPair = tuple            
    tokenFrontBlank: string     # Blank in front of the `[`
    tokenLeft: string           # `[`
    sectionFrontBlank: string   # Blank in front of the `section`
    sectionRearBlank: string    # Whitespace after `section`
    tokenRight: string          # `]`
    tokenRearBlank: string      # Whitespace after `]`
    comment: string              
                          
  KeyValPair = tuple             
    keyFrontBlank: string       # Blank in front of the `key`
    keyRearBlank: string        # Whitespace after `key`
    token: string               # `=` or `:`
    valFrontBlank: string       # Blank in front of the `value`
    value: string               # value
    valRearBlank: string        # Whitespace after `value`
    comment: string              

  CfgParser* = object of BaseLexer # the parser object.
    literal: string                # the parsed (string) literal
    filename: string
    commentSeparato: string

# implementation

proc open*(c: var CfgParser, input: Stream, filename: string,
           lineOffset = 0) {.rtl, extern: "npc$1".} =
  ## initializes the parser with an input stream. `Filename` is only used
  ## for nice error messages. `lineOffset` can be used to influence the line
  ## number information in the generated error messages.
  lexbase.open(c, input)
  c.filename = filename
  c.literal = ""
  c.commentSeparato = "#;"
  inc(c.lineNumber, lineOffset)

proc close*(c: var CfgParser) {.rtl, extern: "npc$1".} =
  ## closes the parser `c` and its associated input stream.
  lexbase.close(c)

proc getColumn*(c: CfgParser): int {.rtl, extern: "npc$1".} =
  ## get the current column the parser has arrived at.
  result = getColNumber(c, c.bufpos)

proc getLine*(c: CfgParser): int {.rtl, extern: "npc$1".} =
  ## get the current line the parser has arrived at.
  result = c.lineNumber

proc getFilename*(c: CfgParser): string {.rtl, extern: "npc$1".} =
  ## get the filename of the file that the parser processes.
  result = c.filename

proc handleHexChar(c: var CfgParser, xi: var int) =
  case c.buf[c.bufpos]
  of '0'..'9':
    xi = (xi shl 4) or (ord(c.buf[c.bufpos]) - ord('0'))
    inc(c.bufpos)
  of 'a'..'f':
    xi = (xi shl 4) or (ord(c.buf[c.bufpos]) - ord('a') + 10)
    inc(c.bufpos)
  of 'A'..'F':
    xi = (xi shl 4) or (ord(c.buf[c.bufpos]) - ord('A') + 10)
    inc(c.bufpos)
  else:
    discard

proc handleDecChars(c: var CfgParser, xi: var int) =
  while c.buf[c.bufpos] in {'0'..'9'}:
    xi = (xi * 10) + (ord(c.buf[c.bufpos]) - ord('0'))
    inc(c.bufpos)

proc getEscapedChar(c: var CfgParser) =
  inc(c.bufpos)               # skip '\'
  case c.buf[c.bufpos]
  of 'n', 'N':
    add(c.literal, "\n")
    inc(c.bufpos)
  of 'r', 'R', 'c', 'C':
    add(c.literal, '\c')
    inc(c.bufpos)
  of 'l', 'L':
    add(c.literal, '\L')
    inc(c.bufpos)
  of 'f', 'F':
    add(c.literal, '\f')
    inc(c.bufpos)
  of 'e', 'E':
    add(c.literal, '\e')
    inc(c.bufpos)
  of 'a', 'A':
    add(c.literal, '\a')
    inc(c.bufpos)
  of 'b', 'B':
    add(c.literal, '\b')
    inc(c.bufpos)
  of 'v', 'V':
    add(c.literal, '\v')
    inc(c.bufpos)
  of 't', 'T':
    add(c.literal, '\t')
    inc(c.bufpos)
  of '\'', '"':
    add(c.literal, c.buf[c.bufpos])
    inc(c.bufpos)
  of '\\':
    add(c.literal, '\\')
    inc(c.bufpos)
  of 'x', 'X':
    inc(c.bufpos)
    var xi = 0
    handleHexChar(c, xi)
    handleHexChar(c, xi)
    add(c.literal, chr(xi))
  of '0'..'9':
    var xi = 0
    handleDecChars(c, xi)
    if (xi <= 255): add(c.literal, chr(xi))
    else: discard
  else: discard

proc handleCRLF(c: var CfgParser, pos: int): int =
  case c.buf[pos]
  of '\c': result = lexbase.handleCR(c, pos)
  of '\L': result = lexbase.handleLF(c, pos)
  else: result = pos

proc errorStr*(c: CfgParser, msg: string): string {.rtl, extern: "npc$1".} =
  ## returns a properly formatted error message containing current line and
  ## column information.
  result = `%`("$1($2, $3) Error: $4",
               [c.filename, $getLine(c), $getColumn(c), msg])

proc warningStr*(c: CfgParser, msg: string): string {.rtl, extern: "npc$1".} =
  ## returns a properly formatted warning message containing current line and
  ## column information.
  result = `%`("$1($2, $3) Warning: $4",
               [c.filename, $getLine(c), $getColumn(c), msg])

proc ignoreMsg*(c: CfgParser, e: CfgEvent): string {.rtl, extern: "npc$1".} =
  ## returns a properly formatted warning message containing that
  ## an entry is ignored.
  case e.kind
  of cfgSectionStart: result = c.warningStr("section ignored: " & e.section)
  of cfgKeyValuePair: result = c.warningStr("key ignored: " & e.key)
  of cfgOption:
    result = c.warningStr("command ignored: " & e.key & ": " & e.keyVal.value)
  of cfgError: result = e.msg
  of cfgEof: result = ""

# =========================================================================

proc replace(s: string): string =
  result = ""
  for c in s:
    case c
    of '\\':
      result.add(r"\\")
    of {'\c', '\L'}:
      result.add(r"\n")
    else:
      result.add(c)

proc mySplit(s: string): tuple =
  var ll=s.len-1
  var t: tuple[front: string, rear: string]
  for i in countdown(ll, 0):
    if not (s[i] in {' ', '\t'}):
      t.front = s[0..i]
      t.rear = s[i+1..ll]
      break
  result = t

proc readBlank(c: var CfgParser) =
  setLen(c.literal, 0)
  while true:
    if c.buf[c.bufpos] in {' ', '\t'}:
      add(c.literal, c.buf[c.bufpos])
      inc(c.bufpos)
    else:
      break

proc readSection(c: var CfgParser) =
  setLen(c.literal, 0)
  while true:
    if c.buf[c.bufpos] in {']', '\c', '\L', lexbase.EndOfFile}: break
    add(c.literal, c.buf[c.bufpos])
    inc(c.bufpos)

proc readComment(c: var CfgParser) =
  setLen(c.literal, 0)
  while true:
    if c.buf[c.bufpos] in {'\c', '\L', lexbase.EndOfFile}:
      break
    else:
      add(c.literal, c.buf[c.bufpos])
      inc(c.bufpos)

proc readKey(c: var CfgParser) =
  setLen(c.literal, 0)
  while true:
    if c.buf[c.bufpos] in {'=', ':', '\c', '\L', lexbase.EndOfFile}: break
    add(c.literal, c.buf[c.bufpos])
    inc(c.bufpos)

proc readValue(c: var CfgParser, rawMode: bool) =
  setLen(c.literal, 0)
  if c.buf[c.bufpos] == '"' and c.buf[c.bufpos + 1] == '"' and c.buf[c.bufpos + 2] == '"':
    # long string literal:
    inc(c.bufpos, 3)               # skip """
                              # skip leading newline:
    c.literal = c.literal & "\"\"\""
    c.bufpos = handleCRLF(c, c.bufpos)
    while true:
      case c.buf[c.bufpos]
      of '"':
        if (c.buf[c.bufpos + 1] == '"') and (c.buf[c.bufpos + 2] == '"'): break
        add(c.literal, '"')
        inc(c.bufpos)
      of '\c', '\L':
        c.bufpos = handleCRLF(c, c.bufpos)
        add(c.literal, "\n")
      of lexbase.EndOfFile:
        break
      else:
        add(c.literal, c.buf[c.bufpos])
        inc(c.bufpos)
    add(c.literal, "\"\"\"")
    inc(c.bufpos, 3)       # skip the three """
  else:
    # ordinary string literal
    if c.buf[c.bufpos] == '"':
      c.literal = "\""
      inc(c.bufpos)
      while true:
        case c.buf[c.bufpos]
        of '"':
          add(c.literal, c.buf[c.bufpos])
          inc(c.bufpos)
          break
        of '\c', '\L', lexbase.EndOfFile:
          break
        of '\\':
          if not rawMode:
            getEscapedChar(c)
          else:
            add(c.literal, c.buf[c.bufpos])
            inc(c.bufpos)
        else:
          add(c.literal, c.buf[c.bufpos])
          inc(c.bufpos)
    else:
      setLen(c.literal, 0)
      while true:
        if c.commentSeparato.contains(c.buf[c.bufpos]): break
        if c.buf[c.bufpos] in {'\c', '\L', lexbase.EndOfFile}: break
        add(c.literal, c.buf[c.bufpos])
        inc(c.bufpos)

proc handleLineComment(c: var CfgParser, frontBlank: string): CfgEvent =
  ## Handling the entire line is an annotation situation.
  result.kind = cfgKeyValuePair
  result.keyVal.keyFrontBlank = frontBlank
  readComment(c)
  result.keyVal.comment = c.literal
  c.bufpos = handleCRLF(c, c.bufpos)

proc handleSectionComment(c: var CfgParser, frontBlank, 
                          sectionFrontBlank: string): CfgEvent =
  ## Handle annotated situations in section
  result.kind = cfgKeyValuePair
  result.keyVal.keyFrontBlank = frontBlank
  readComment(c)
  result.keyVal.comment = '[' & sectionFrontBlank & c.literal
  c.bufpos = handleCRLF(c, c.bufpos)

proc handleValueComment(c: var CfgParser, ret: var CfgEvent) =
  var temp = mySplit(c.literal)
  ret.keyVal.value = temp[0]
  ret.keyVal.valRearBlank = temp[1]
  case c.buf[c.bufpos]
  of '\c', '\L', lexbase.EndOfFile:
    ret.keyVal.comment = ""
    c.bufpos = handleCRLF(c, c.bufpos)
  else: # read to comment characte
    readComment(c)
    ret.keyVal.comment = c.literal
    c.bufpos = handleCRLF(c, c.bufpos)

proc next*(c: var CfgParser): CfgEvent {.rtl, extern: "npc$1".} =
  ## retrieves the first/next event. This controls the parser.
  readBlank(c) # read the blank space in the front of the line.
  var frontBlank = c.literal
  if c.commentSeparato.contains(c.buf[c.bufpos]):
    result = handleLineComment(c, frontBlank)
    return
  case c.buf[c.bufpos]
  of lexbase.EndOfFile:
    result.kind = cfgEof
  of '\c', '\L': # comment field processing as key value section.
    result = handleLineComment(c, frontBlank)
  of '[': # it could be `section`
    inc(c.bufpos) # skip `[`
    readBlank(c) # read blank in front of `section`
    var sectionFrontBlank = c.literal
    if c.commentSeparato.contains(c.buf[c.bufpos]):
      result = handleSectionComment(c, frontBlank, sectionFrontBlank)
    case c.buf[c.bufpos]
    of ']', '\c', '\L', lexbase.EndOfFile: # is not a valid `section`,
      result = handleSectionComment(c, frontBlank, sectionFrontBlank)
    else: # read valid characte.
      readSection(c)
      case c.buf[c.bufpos]
      of '\c', '\L', lexbase.EndOfFile:            # did not read `]`，
                                                   # comment field processing
                                                   # as key value section.
        result = handleSectionComment(c, frontBlank, sectionFrontBlank)
      else: ## read `]`
        result.kind = cfgSectionStart
        result.sectionVal.tokenFrontBlank = frontBlank
        result.sectionVal.tokenLeft = "["
        result.sectionVal.sectionFrontBlank = sectionFrontBlank
        var temp = mySplit(c.literal)
        result.section = temp[0]
        result.sectionVal.sectionRearBlank = temp[1]
        result.sectionVal.tokenRight ="]"
        inc(c.bufpos) # skip `]`
        readBlank(c) # read the whitespace after `]`
        result.sectionVal.tokenRearBlank = c.literal
        readComment(c)
        result.sectionVal.comment = c.literal
        c.bufpos = handleCRLF(c, c.bufpos)
  else: # is the key value, does the key value processing
    result.kind = cfgKeyValuePair
    result.keyVal.keyFrontBlank = frontBlank
    readKey(c) # read key
    var temp = mySplit(c.literal)
    if temp[0].startsWith("--"):
      result.kind = cfgOption
    else:
      result.kind = cfgKeyValuePair
    case c.buf[c.bufpos]
    of '\c', '\L', lexbase.EndOfFile: # did not read `=` or `:`
      if result.kind == cfgKeyValuePair:
        result.keyVal.comment = c.literal
        c.bufpos = handleCRLF(c, c.bufpos)
      else:
        result.key = temp[0]
        result.keyVal.keyRearBlank = temp[1]
        c.bufpos = handleCRLF(c, c.bufpos)
    else:
      result.key = temp[0]
      result.keyVal.keyRearBlank = temp[1]
      if c.buf[c.bufpos] == ':':
        result.keyVal.token = ":"
      else:
        result.keyVal.token = "="
      inc(c.bufpos)
      readBlank(c) # read the blank front of the value
      case c.buf[c.bufpos]
      of lexbase.EndOfFile: # value not read
        result.keyVal.valFrontBlank = c.literal
        c.bufpos = handleCRLF(c, c.bufpos)
      of '\c', '\L':
        c.bufpos = handleCRLF(c, c.bufpos)
        readBlank(c) # read the blank front of the value
        if c.buf[c.bufpos] == '"' and c.buf[c.bufpos+1] == '"' and c.buf[c.bufpos+2] == '"':
          result.keyVal.valFrontBlank = c.literal
          readValue(c, true)
          handleValueComment(c, result)
        else:
          result.keyVal.valFrontBlank = c.literal
          c.bufpos = handleCRLF(c, c.bufpos)
      else: # read valid value
        result.keyVal.valFrontBlank = c.literal
        if c.buf[c.bufpos] == '"':
          readValue(c, false) # escape characte
        else:
          readValue(c, true) # non-escape characte
        handleValueComment(c, result)

# ================= Configuration file related operations ===================
type
  Config* = OrderedTableRef[string, (SectionPair, 
                                     OrderedTableRef[string, KeyValPair])]

proc newConfig*(): Config =
  ## Create a new configuration table.
  ## Useful when wanting to create a configuration file.
  result = newOrderedTable[string, (SectionPair, 
                                    OrderedTableRef[string, KeyValPair])]()

proc loadConfig*(stream: Stream, filename: string = "[stream]",
                 commentSeparato: string = "#;"): Config =
  ## loadConfig the specified configuration from stream into a new `Config`
  ## instance.`filename` parameter is only used for nicer error messages.
  ## `commentSeparato` default value is `"#"` and `";"`.
  var dict = newOrderedTable[string, (SectionPair, 
                                      OrderedTableRef[string, KeyValPair])]()
  var curSection = "" # Current section,
                      # the default value of the current section is "",
                      # which means that the current section is a common
  var p: CfgParser
  p.commentSeparato = commentSeparato
  open(p, stream, filename)
  while true:
    var e = next(p)
    case e.kind
    of cfgEof:
      break
    of cfgSectionStart: # Only look for the first time the Section
      var tp: tuple[sec: SectionPair, kv: OrderedTableRef[string, KeyValPair]]
      var t = newOrderedTable[string, KeyValPair]()
      curSection = e.section
      tp.sec = e.sectionVal
      tp.kv = t
      dict[curSection] = tp
    of cfgKeyValuePair, cfgOption:
      var tp: tuple[sec: SectionPair, kv: OrderedTableRef[string, KeyValPair]]
      var t = newOrderedTable[string, KeyValPair]()
      if dict.hasKey(curSection):
        tp = dict[curSection]
        t = tp.kv
      t.add(e.key, e.keyVal)
      tp.kv = t
      dict[curSection] = tp
    of cfgError:
      break
  close(p)
  result = dict

proc loadConfig*(filename: string, commentSeparato: string = "#;"): Config =
  ## loadConfig the specified configuration file into a new `Config` instance.
  ## `commentSeparato` default value `"#"` and `";"`.
  let file = open(filename, fmRead)
  let fileStream = newFileStream(file)
  defer: fileStream.close()
  result = fileStream.loadConfig(filename, commentSeparato)

proc writeConfig*(dict: Config, stream: Stream) =
  ## Writes the contents of the table to the specified stream.
  for section, tp in dict.pairs():
    var secPair = tp[0]
    var kvPair = tp[1]
    if section != "": # Not general section
      stream.writeLine(secPair.tokenFrontBlank & secPair.tokenLeft &
                       secPair.sectionFrontBlank & section &
                       secPair.sectionRearBlank & secPair.tokenRight &
                       secPair.tokenRearBlank & secPair.comment)
    for key, kv in kvPair.pairs():
      var s = ""
      s.add(kv.keyFrontBlank)
      s.add(key)
      s.add(kv.keyRearBlank)
      s.add(kv.token)
      s.add(kv.valFrontBlank)
      if kv.value.startsWith("\"\"\"") and kv.value.endsWith("\"\"\""):
        s.add(kv.value)
      elif (kv.value.startsWith("r\"") or kv.value.startsWith("R\"")) and kv.value.endsWith('"'):
        s.add(kv.value)
      elif kv.value.startsWith('"') and kv.value.endsWith('"'):
        s.add(replace(kv.value))
      else:
        s.add(kv.value)
      s.add(kv.valRearBlank)
      s.add(kv.comment)
      stream.writeLine(s)

proc write*(dict: Config, stream: Stream) =
  ## Writes the contents of the table to the specified stream.
  writeConfig(dict, stream)

proc `$`*(dict: Config): string =
  ## Writes the contents of the table to string.
  let stream = newStringStream()
  defer: stream.close()
  dict.write(stream)
  result = stream.data

proc writeConfig*(dict: Config, filename: string) =
  ## Writes the contents of the table to the specified configuration file.
  let file = open(filename, fmWrite)
  defer: file.close()
  let fileStream = newFileStream(file)
  dict.writeConfig(fileStream)

proc write*(dict: Config, filename: string) =
  ## Writes the contents of the table to the specified configuration file.
  writeConfig(dict, filename)

proc getSectionValue*(dict: Config, section, key: string, defaultVal: string = ""): string =
  ## Gets the key value of the specified Section.
  ## Returns the specified default value if the specified key does not exist.
  if dict.haskey(section):
    let kv = dict[section][1]
    if kv.hasKey(key):
      result = kv[key].value
    elif kv.hasKey('"' & key & '"'):
      result = kv['"' & key & '"'].value
    if result != "":
      if result.startsWith("\"\"\"") and result.endsWith("\"\"\""):
        result = result.substr(3, len(result) - 4)
      elif (result.startsWith("r\"") or result.startsWith("R\"")) and result.endsWith('"'):
        result = result.substr(2, len(result) - 2)
      elif result.startsWith('"') and result.endsWith('"'):
        result = result.substr(1, len(result) - 2)
    else:
      result = defaultVal
  else:
    result = defaultVal

proc get*(dict: Config, section, key: string, defaultVal = ""): string =
  ## Gets the key value of the specified Section.
  ## Returns the specified default value if the specified key does not exist.
  result = getSectionValue(dict, section, key, defaultVal)

proc gets*(dict: Config, section, key: string): seq[string] =
  ## Gets multiple values for the specified key.
  var s: seq[string]
  s = @[]
  if dict.haskey(section):
    for kv in dict[section][1].pairs:
      if kv[0] == key:
        if kv[1].value.startsWith("\"\"\"") and kv[1].value.endsWith("\"\"\""):
          s.add(kv[1].value.substr(3, len(kv[1].value) - 4))
        elif (kv[1].value.startsWith("r\"") or kv[1].value.startsWith("R\"")) and kv[1].value.endsWith('"'):
          s.add(kv[1].value.substr(2, len(kv[1].value) - 2))
        elif kv[1].value.startsWith('"') and kv[1].value.endsWith('"'):
          s.add(kv[1].value.substr(1, len(kv[1].value) - 2))
        else:
          s.add(kv[1].value)
  result = s

proc setSectionKey*(dict: var Config, section, key, value: string, quotationMarks: bool = true) =
  ## Sets the key value of the specified Section.
  ## If key exists, modify its value, or if key does not exist, add it.
  ## Specify whether 'value' uses quotation marks.
  var tp: tuple[sec: SectionPair, kv: OrderedTableRef[string, KeyValPair]]
  var t = newOrderedTable[string, KeyValPair]()
  var kvp: KeyValPair
  if dict.hasKey(section):
    tp = dict[section]
    t = tp.kv
    var tempKey = ""
    if t.hasKey(key):
      tempKey = key
    elif t.hasKey('"' & key & '"'):
      tempKey = '"' & key & '"'
    if tempKey != "":
      if quotationMarks:
        t[tempKey].value = "\"" & value & "\""
      else:
        t[tempKey].value = value
    else:
      if key.startsWith("--"):
        kvp.token = ":"
      else:
        kvp.token = "="
      if quotationMarks:
        kvp.value = "\"" & value & "\""
      else:
        kvp.value = value
      t.add(key, kvp)
    tp.kv = t
    dict[section] = tp
  else:
    if key.startsWith("--"):
      kvp.token = ":"
    else:
      kvp.token = "="
    if quotationMarks:
      kvp.value = "\"" & value & "\""
    else:
      kvp.value = value
    t.add(key, kvp)
    tp.kv = t
    tp.sec.tokenLeft = "["
    tp.sec.tokenRight = "]"
    dict[section] = tp

proc set*(dict: var Config, section, key, value: string, quotationMarks: bool = true) =
  ## Sets the key value of the specified Section.
  ## If key exists, modify its value, or if key does not exist, add it.
  ## Specify whether 'value' uses quotation marks.
  setSectionKey(dict, section, key, value, quotationMarks)

proc add*(dict: var Config, section, key, value: string, quotationMarks: bool = true) =
  ## Add the key value of the specified Section.
  ## Whether there is a key, add it. This method is often used to 
  ## add duplicate key with multiple values.
  var tp: tuple[sec: SectionPair, kv: OrderedTableRef[string, KeyValPair]]
  var t = newOrderedTable[string, KeyValPair]()
  var kvp: KeyValPair
  if dict.hasKey(section):
    tp = dict[section]
    t = tp.kv
    if key.startsWith("--"):
      kvp.token = ":"
    else:
      kvp.token = "="
    if quotationMarks:
      kvp.value = "\"" & value & "\""
    else:
      kvp.value = value
    t.add(key, kvp)
    tp.kv = t
    dict[section] = tp
  else:
    if key.startsWith("--"):
      kvp.token = ":"
    else:
      kvp.token = "="
    if quotationMarks:
      kvp.value = "\"" & value & "\""
    else:
      kvp.value = value
    t.add(key, kvp)
    tp.kv = t
    tp.sec.tokenLeft = "["
    tp.sec.tokenRight = "]"
    dict[section] = tp

proc delSection*(dict: var Config, section: string) =
  ## Deletes the specified section and all of its sub keys.
  tables.del(dict, section)

proc del*(dict: var Config, section: string) =
  ## Deletes the specified section and all of its sub keys.
  delSection(dict, section)

proc delSectionKey*(dict: var Config, section, key: string) =
  ## Delete the key of the specified section.
  if dict.haskey(section):
    if dict[section][1].hasKey(key):
      if dict[section][1].len() == 1:
        tables.del(dict, section)
      else:
        tables.del(dict[section][1], key)

proc del*(dict: var Config, section, key: string) =
  ## Deletes the key of the specified section.
  delSectionKey(dict, section, key)
